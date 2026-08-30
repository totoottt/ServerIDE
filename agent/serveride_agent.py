#!/usr/bin/env python3
"""ServerIDE HTTPS-behind-proxy agent. Python 3.10+, standard library only."""

from __future__ import annotations

import argparse
import base64
import hmac
import json
import mimetypes
import os
import platform
import shutil
import signal
import socket
import subprocess
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

MAX_BODY = 8 * 1024 * 1024
MAX_OUTPUT = 512 * 1024
MAX_TEXT_FILE = 2 * 1024 * 1024


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_cpu() -> tuple[int, int]:
    fields = Path("/proc/stat").read_text().splitlines()[0].split()[1:]
    values = [int(value) for value in fields]
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    return sum(values), idle


def cpu_percent() -> float:
    first_total, first_idle = read_cpu()
    time.sleep(0.12)
    second_total, second_idle = read_cpu()
    total_delta = max(second_total - first_total, 1)
    return round(100 * (1 - (second_idle - first_idle) / total_delta), 1)


def memory_info() -> tuple[int, int]:
    rows = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        key, value = line.split(":", 1)
        rows[key] = int(value.strip().split()[0]) * 1024
    total = rows.get("MemTotal", 0)
    available = rows.get("MemAvailable", rows.get("MemFree", 0))
    return total - available, total


def safe_output(value: bytes) -> str:
    return value[:MAX_OUTPUT].decode("utf-8", errors="replace")


def proc_processes() -> list[dict]:
    items = []
    clock_ticks = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
    page_size = os.sysconf("SC_PAGE_SIZE")
    for directory in Path("/proc").iterdir():
        if not directory.name.isdigit():
            continue
        try:
            stat = (directory / "stat").read_text().split()
            status = (directory / "status").read_text().splitlines()
            uid = next(int(line.split()[1]) for line in status if line.startswith("Uid:"))
            try:
                import pwd
                user = pwd.getpwuid(uid).pw_name
            except (KeyError, ImportError):
                user = str(uid)
            command = (directory / "cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace").strip() or stat[1].strip("()")
            rss_pages = int(stat[23])
            cpu_seconds = (int(stat[13]) + int(stat[14])) / clock_ticks
            items.append({"pid": int(directory.name), "user": user, "status": stat[2], "cpuPercent": round(cpu_seconds, 1), "memoryBytes": rss_pages * page_size, "command": command})
        except (OSError, ValueError, StopIteration, IndexError):
            continue
    return sorted(items, key=lambda item: item["memoryBytes"], reverse=True)[:250]


def txt_records(name: str) -> list[str]:
    try:
        result = subprocess.run(["dig", "+short", "TXT", name], capture_output=True, timeout=8, check=False)
        return [line.strip().strip('"').replace('" "', "") for line in result.stdout.decode(errors="replace").splitlines() if line.strip()]
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []


class AgentServer(ThreadingHTTPServer):
    token: str
    allowed_root: Path


class Handler(BaseHTTPRequestHandler):
    server_version = "ServerIDE-Agent/1.0"

    def log_message(self, fmt: str, *args) -> None:
        print(f"[{self.log_date_time_string()}] {self.address_string()} {fmt % args}")

    def send_json(self, status: int, payload: object) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def authorized(self) -> bool:
        supplied = self.headers.get("Authorization", "")
        expected = f"Bearer {self.server.token}"
        return hmac.compare_digest(supplied.encode(), expected.encode())

    def body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length > MAX_BODY:
            raise ValueError("Request body is too large")
        return json.loads(self.rfile.read(length) or b"{}")

    def resolve(self, value: str) -> Path:
        requested = Path(value or ".")
        if not requested.is_absolute():
            requested = self.server.allowed_root / requested
        resolved = requested.resolve(strict=False)
        root = self.server.allowed_root
        if resolved != root and root not in resolved.parents:
            raise PermissionError("Path is outside SERVERIDE_ROOT")
        return resolved

    def do_GET(self) -> None:
        if not self.authorized():
            return self.send_json(401, {"error": "Invalid agent token"})
        try:
            parsed = urlparse(self.path)
            query = parse_qs(parsed.query)
            if parsed.path == "/v1/health":
                used_memory, total_memory = memory_info()
                disk = shutil.disk_usage(self.server.allowed_root)
                uptime = float(Path("/proc/uptime").read_text().split()[0])
                return self.send_json(200, {
                    "hostname": socket.gethostname(), "platform": platform.platform(), "uptimeSeconds": int(uptime),
                    "cpu": {"usagePercent": cpu_percent(), "cores": os.cpu_count() or 1},
                    "memory": {"usedBytes": used_memory, "totalBytes": total_memory, "usagePercent": round(used_memory * 100 / max(total_memory, 1), 1)},
                    "storage": {"usedBytes": disk.used, "totalBytes": disk.total, "usagePercent": round(disk.used * 100 / max(disk.total, 1), 1)},
                    "updatedAt": now_iso(),
                })
            if parsed.path == "/v1/processes":
                proc = subprocess.run(["ps", "-eo", "pid=,user=,stat=,%cpu=,rss=,args=", "--sort=-%cpu"], capture_output=True, timeout=10)
                processes = []
                for line in proc.stdout.decode(errors="replace").splitlines()[:250]:
                    parts = line.strip().split(None, 5)
                    if len(parts) < 6:
                        continue
                    pid, user, stat, cpu, rss, command = parts
                    processes.append({"pid": int(pid), "user": user, "status": stat, "cpuPercent": float(cpu), "memoryBytes": int(rss) * 1024, "command": command})
                if not processes:
                    processes = proc_processes()
                return self.send_json(200, {"processes": processes})
            if parsed.path == "/v1/network":
                wanted = query.get("interface", [""])[0]
                rows = []
                for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
                    name, values = line.split(":", 1)
                    fields = values.split()
                    if name.strip() != "lo":
                        rows.append((name.strip(), int(fields[0]), int(fields[8])))
                if not rows:
                    for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
                        name, values = line.split(":", 1); fields = values.split(); rows.append((name.strip(), int(fields[0]), int(fields[8])))
                selected = next((row for row in rows if row[0] == wanted), rows[0] if rows else ("unknown", 0, 0))
                return self.send_json(200, {"interface": selected[0], "rxBytes": selected[1], "txBytes": selected[2], "sampledAt": now_iso()})
            if parsed.path == "/v1/files":
                directory = self.resolve(query.get("path", [str(self.server.allowed_root)])[0])
                if not directory.is_dir():
                    raise NotADirectoryError("Path is not a directory")
                entries = []
                for item in sorted(directory.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower())):
                    stat = item.lstat()
                    kind = "symlink" if item.is_symlink() else "folder" if item.is_dir() else "file"
                    entries.append({"name": item.name, "path": str(item), "type": kind, "size": stat.st_size, "modifiedAt": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat()})
                return self.send_json(200, {"path": str(directory), "entries": entries})
            if parsed.path == "/v1/file":
                file_path = self.resolve(query.get("path", [""])[0])
                if not file_path.is_file() or file_path.is_symlink():
                    raise FileNotFoundError("Regular file not found")
                size = file_path.stat().st_size
                if size > MAX_TEXT_FILE:
                    return self.send_json(413, {"error": "Preview is limited to 2 MB"})
                data = file_path.read_bytes()
                try:
                    content, encoding = data.decode("utf-8"), "utf8"
                except UnicodeDecodeError:
                    content, encoding = base64.b64encode(data).decode(), "base64"
                return self.send_json(200, {"path": str(file_path), "content": content, "encoding": encoding, "size": size, "mimeType": mimetypes.guess_type(file_path.name)[0]})
            if parsed.path == "/v1/checks":
                domain = query.get("domain", [""])[0].strip().lower().rstrip(".")
                if not domain or any(ch not in "abcdefghijklmnopqrstuvwxyz0123456789.-" for ch in domain):
                    raise ValueError("Invalid domain")
                spf = [r for r in txt_records(domain) if r.lower().startswith("v=spf1")]
                dmarc = [r for r in txt_records(f"_dmarc.{domain}") if r.lower().startswith("v=dmarc1")]
                dkim = txt_records(f"default._domainkey.{domain}")
                try:
                    socket.getaddrinfo(domain, 25)
                    smtp = True
                except socket.gaierror:
                    smtp = False
                checks = [
                    {"name": "SPF", "status": "Good" if spf else "Warning", "detail": spf[0] if spf else "No SPF TXT record found"},
                    {"name": "DKIM", "status": "Good" if dkim else "Info", "detail": dkim[0] if dkim else "No default DKIM selector found; selector may be custom"},
                    {"name": "DMARC", "status": "Good" if dmarc else "Warning", "detail": dmarc[0] if dmarc else "No DMARC TXT record found"},
                    {"name": "Blacklists", "status": "Info", "detail": "Blacklist checks require a configured DNSBL provider"},
                    {"name": "SMTP", "status": "Good" if smtp else "Warning", "detail": "Domain resolves" if smtp else "Domain does not resolve"},
                ]
                return self.send_json(200, {"domain": domain, "checkedAt": now_iso(), "checks": checks})
            return self.send_json(404, {"error": "Unknown endpoint"})
        except (ValueError, PermissionError, FileNotFoundError, NotADirectoryError) as error:
            return self.send_json(400, {"error": str(error)})
        except Exception as error:
            return self.send_json(500, {"error": f"Agent error: {error}"})

    def do_POST(self) -> None:
        if not self.authorized():
            return self.send_json(401, {"error": "Invalid agent token"})
        try:
            if self.path == "/v1/command":
                data = self.body()
                command = str(data.get("command", "")).strip()
                if not command or len(command) > 8192:
                    raise ValueError("Command is empty or too long")
                cwd = self.resolve(str(data.get("cwd") or self.server.allowed_root))
                started = time.monotonic()
                result = subprocess.run(["/bin/bash", "-lc", command], cwd=cwd, capture_output=True, timeout=120, env={**os.environ, "TERM": "xterm-256color"})
                return self.send_json(200, {"stdout": safe_output(result.stdout), "stderr": safe_output(result.stderr), "exitCode": result.returncode, "cwd": str(cwd), "durationMs": int((time.monotonic() - started) * 1000)})
            if self.path == "/v1/process/stop":
                pid = int(self.body().get("pid", 0))
                if pid <= 1 or pid == os.getpid():
                    raise ValueError("Protected process")
                os.kill(pid, signal.SIGTERM)
                return self.send_json(200, {"success": True})
            if self.path == "/v1/mkdir":
                target = self.resolve(str(self.body().get("path", "")))
                target.mkdir(parents=False, exist_ok=False)
                return self.send_json(201, {"success": True})
            return self.send_json(404, {"error": "Unknown endpoint"})
        except subprocess.TimeoutExpired:
            return self.send_json(408, {"error": "Command exceeded 120 seconds"})
        except (ValueError, PermissionError, FileExistsError, ProcessLookupError) as error:
            return self.send_json(400, {"error": str(error)})
        except Exception as error:
            return self.send_json(500, {"error": f"Agent error: {error}"})

    def do_PUT(self) -> None:
        if not self.authorized():
            return self.send_json(401, {"error": "Invalid agent token"})
        try:
            if self.path != "/v1/file":
                return self.send_json(404, {"error": "Unknown endpoint"})
            data = self.body()
            target = self.resolve(str(data.get("path", "")))
            if target.is_symlink():
                raise PermissionError("Refusing to overwrite a symlink")
            raw = str(data.get("content", ""))
            content = base64.b64decode(raw, validate=True) if data.get("encoding") == "base64" else raw.encode()
            if len(content) > MAX_BODY:
                raise ValueError("File exceeds 8 MB write limit")
            temporary = target.with_name(f".{target.name}.serveride-{os.getpid()}.tmp")
            temporary.write_bytes(content)
            os.replace(temporary, target)
            return self.send_json(200, {"success": True, "size": len(content)})
        except (ValueError, PermissionError) as error:
            return self.send_json(400, {"error": str(error)})
        except Exception as error:
            return self.send_json(500, {"error": f"Agent error: {error}"})

    def do_DELETE(self) -> None:
        if not self.authorized():
            return self.send_json(401, {"error": "Invalid agent token"})
        try:
            if self.path != "/v1/file":
                return self.send_json(404, {"error": "Unknown endpoint"})
            target = self.resolve(str(self.body().get("path", "")))
            if target == self.server.allowed_root:
                raise PermissionError("Cannot delete SERVERIDE_ROOT")
            if target.is_dir() and not target.is_symlink():
                target.rmdir()
            else:
                target.unlink()
            return self.send_json(200, {"success": True})
        except (ValueError, PermissionError, OSError) as error:
            return self.send_json(400, {"error": str(error)})


def main() -> None:
    parser = argparse.ArgumentParser(description="ServerIDE server agent")
    parser.add_argument("--host", default=os.getenv("SERVERIDE_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.getenv("SERVERIDE_PORT", "8787")))
    parser.add_argument("--root", default=os.getenv("SERVERIDE_ROOT", "/root"))
    args = parser.parse_args()
    token = os.getenv("SERVERIDE_AGENT_TOKEN", "")
    if len(token) < 24:
        raise SystemExit("SERVERIDE_AGENT_TOKEN must contain at least 24 characters")
    server = AgentServer((args.host, args.port), Handler)
    server.token = token
    server.allowed_root = Path(args.root).resolve(strict=True)
    print(f"ServerIDE agent listening on http://{args.host}:{args.port}; root={server.allowed_root}")
    server.serve_forever()


if __name__ == "__main__":
    main()
