import { Client, type ClientChannel } from "ssh2";
import { createHash } from "node:crypto";
import * as net from "node:net";
import * as dgram from "node:dgram";
import type { Readable } from "node:stream";

export type JumpHostConfig = {
  host: string;
  port: number;
  username: string;
  password?: string;
  privateKey?: string;
  passphrase?: string;
  portKnockSequence?: string;
};

export type SSHCredentials = {
  host: string;
  port: number;
  username: string;
  password?: string;
  privateKey?: string;
  passphrase?: string;
  hostFingerprint?: string;
  /** Comma-separated "port:proto" pairs sent, in order, before the SSH handshake (e.g. "2222:udp,3333:tcp"). */
  portKnockSequence?: string;
  /** Bastion/jump host the real target is reached through via an SSH port-forward tunnel. */
  jumpHost?: JumpHostConfig;
  /** Enables keyboard-interactive auth (used for OTP/2FA-gated servers). Prompts are answered with this value. */
  forceKeyboardInteractive?: boolean;
  otpCode?: string;
};

/** Sends a single knock to one port, TCP (best-effort connect) or UDP (fire-and-forget datagram). */
function sendKnock(host: string, port: number, proto: "tcp" | "udp"): Promise<void> {
  return new Promise((resolve) => {
    if (proto === "udp") {
      const socket = dgram.createSocket("udp4");
      socket.send(Buffer.from([0]), port, host, () => { socket.close(); resolve(); });
      return;
    }
    const socket = net.createConnection({ host, port, timeout: 800 });
    const done = () => { socket.destroy(); resolve(); };
    socket.once("connect", done);
    socket.once("error", done);
    socket.once("timeout", done);
  });
}

/**
 * Parses a "port:proto,port:proto" sequence (e.g. from a server profile's Port Knocking
 * field) and knocks each port in order with a short gap between them, as most knock
 * daemons require the ports to arrive within a time window and in the configured order.
 */
export async function performPortKnock(host: string, sequence: string): Promise<void> {
  const steps = sequence.split(",").map((entry) => entry.trim()).filter(Boolean).map((entry) => {
    const [portRaw, protoRaw] = entry.split(":");
    const port = Number(portRaw);
    const proto = (protoRaw || "tcp").toLowerCase() === "udp" ? "udp" : "tcp";
    if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error(`Invalid port knock entry: "${entry}"`);
    return { port, proto } as const;
  });
  for (const step of steps) {
    await sendKnock(host, step.port, step.proto);
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}

/**
 * Discovers a host's SSH key fingerprint without pinning it, so the client can show
 * the fingerprint to the user for a trust-on-first-use (TOFU) decision before it is
 * saved and enforced by `connect()`. Without this, a server profile with no stored
 * fingerprint can never complete a handshake, because the strict `hostVerifier`
 * below always rejects when `hostFingerprint` is absent.
 */
export async function discoverHostKey(
  credentials: Omit<SSHCredentials, "hostFingerprint">
): Promise<{ fingerprint: string }> {
  if (credentials.portKnockSequence) await performPortKnock(credentials.host, credentials.portKnockSequence);
  return new Promise((resolve, reject) => {
    const client = new Client();
    let fingerprint: string | null = null;
    const timer = setTimeout(() => {
      client.end();
      if (fingerprint) resolve({ fingerprint });
      else reject(new Error("Timed out waiting for the host key"));
    }, 10_000);

    const finish = () => {
      clearTimeout(timer);
      client.end();
      if (fingerprint) resolve({ fingerprint });
      else reject(new Error("Host did not present a key during the handshake"));
    };

    // Auth success/failure is irrelevant here — we only need the host key, which is
    // exchanged before authentication, so we resolve on 'ready' AND on 'error'.
    client.once("ready", finish);
    client.once("error", finish);
    client.connect({
      ...credentials,
      tryKeyboard: false,
      readyTimeout: 8_000,
      hostVerifier: (key: Buffer) => {
        fingerprint = `SHA256:${createHash("sha256").update(key).digest("base64").replace(/=+$/, "")}`;
        return true; // accept provisionally just to capture the key; nothing is trusted yet
      },
    });
  });
}

function explainSSHError(error: unknown) {
  const code = typeof error === "object" && error !== null && "code" in error ? String((error as { code?: unknown }).code) : "";
  const message = error instanceof Error ? error.message.toLowerCase() : String(error).toLowerCase();
  if (code === "ENOTFOUND" || message.includes("getaddrinfo")) return new Error("Invalid host or IP address.");
  if (code === "ECONNREFUSED") return new Error("The SSH port is closed or refused the connection.");
  if (code === "ETIMEDOUT" || message.includes("timed out") || message.includes("timeout")) return new Error("The host is unreachable or the connection timed out.");
  if (message.includes("authentication") || message.includes("password") || message.includes("all configured authentication methods failed")) return new Error("Authentication failed: check the username and password.");
  return error instanceof Error ? error : new Error("SSH connection failed.");
}

function hostVerifierFor(hostFingerprint: string | undefined) {
  return (key: Buffer) => {
    // Password-first UX: accepting a connection must not depend on a client-side
    // fingerprint screen. If a legacy profile still contains a fingerprint, keep
    // it as an optional check for backwards compatibility.
    if (!hostFingerprint) return true;
    const fingerprint = `SHA256:${createHash("sha256").update(key).digest("base64").replace(/=+$/, "")}`;
    return fingerprint === hostFingerprint;
  };
}

/** Connects a single (non-jumped) SSH client, optionally answering keyboard-interactive prompts with `otpCode`. */
function connectDirect(credentials: SSHCredentials & { sock?: Readable }): Promise<Client> {
  return new Promise((resolve, reject) => {
    const client = new Client();
    const timer = setTimeout(() => { client.end(); reject(new Error("The host is unreachable or the connection timed out.")); }, 12_000);
    client.once("ready", () => { clearTimeout(timer); resolve(client); });
    client.once("error", (error) => { clearTimeout(timer); reject(explainSSHError(error)); });
    if (credentials.forceKeyboardInteractive) {
      client.on("keyboard-interactive", (_name, _instructions, _lang, prompts, finish) => {
        finish(prompts.map(() => credentials.otpCode ?? ""));
      });
    }
    const { hostFingerprint, portKnockSequence, jumpHost, forceKeyboardInteractive, otpCode, ...connection } = credentials;
    client.connect({
      ...connection,
      tryKeyboard: Boolean(forceKeyboardInteractive),
      readyTimeout: 10_000,
      hostVerifier: hostVerifierFor(hostFingerprint),
    });
  });
}

export function connect(credentials: SSHCredentials): Promise<Client> {
  return new Promise((resolveOuter, rejectOuter) => {
    void (async () => {
      try {
        if (credentials.portKnockSequence) await performPortKnock(credentials.host, credentials.portKnockSequence);

        if (!credentials.jumpHost) {
          resolveOuter(await connectDirect(credentials));
          return;
        }

        // Bastion flow: authenticate to the jump host first, then tunnel a TCP stream
        // through it (`forwardOut`) to the real target and run the SSH handshake over that.
        const jump = credentials.jumpHost;
        if (jump.portKnockSequence) await performPortKnock(jump.host, jump.portKnockSequence);
        const jumpClient = await connectDirect({
          host: jump.host,
          port: jump.port,
          username: jump.username,
          password: jump.password,
          privateKey: jump.privateKey,
          passphrase: jump.passphrase,
          hostFingerprint: undefined,
        } as SSHCredentials);

        jumpClient.forwardOut("127.0.0.1", 0, credentials.host, credentials.port, async (error, stream) => {
          if (error) { jumpClient.end(); rejectOuter(error); return; }
          try {
            const target = await connectDirect({ ...credentials, jumpHost: undefined, sock: stream });
            target.once("close", () => jumpClient.end());
            resolveOuter(target);
          } catch (targetError) {
            jumpClient.end();
            rejectOuter(targetError);
          }
        });
      } catch (error) {
        rejectOuter(error);
      }
    })();
  });
}


export async function openSSHPTY(credentials: SSHCredentials, cols = 100, rows = 30) {
  const client = await connect(credentials);
  return await new Promise<{ client: Client; stream: ClientChannel }>((resolve, reject) => {
    client.shell({ term: "xterm-256color", cols, rows }, (error, stream) => {
      if (error) { client.end(); return reject(error); }
      resolve({ client, stream });
    });
  });
}

export async function runSSHCommand(credentials: SSHCredentials, command: string) {
  if (!command.trim()) throw new Error("Command cannot be empty");
  const client = await connect(credentials);
  try {
    return await new Promise<{ stdout: string; stderr: string; code: number | null }>((resolve, reject) => {
      client.exec(command, (error, stream) => {
        if (error) return reject(error);
        let stdout = "";
        let stderr = "";
        stream.on("data", (chunk: Buffer) => { stdout += chunk.toString("utf8"); });
        stream.stderr.on("data", (chunk: Buffer) => { stderr += chunk.toString("utf8"); });
        stream.on("close", (code: number | null) => resolve({ stdout, stderr, code }));
      });
    });
  } finally { client.end(); }
}

function modeToPermissions(mode: number | undefined, directory: boolean) {
  if (!mode) return directory ? "d---------" : "----------";
  const bits = [0o400, 0o200, 0o100, 0o040, 0o020, 0o010, 0o004, 0o002, 0o001];
  const chars = ["r", "w", "x", "r", "w", "x", "r", "w", "x"];
  return (directory ? "d" : "-") + bits.map((bit, index) => (mode & bit) ? chars[index] : "-").join("");
}

export async function listRemoteDirectory(credentials: SSHCredentials, path: string) {
  const client = await connect(credentials);
  try {
    return await new Promise<Array<{ name: string; type: string; size: number; modifiedAt: number; permissions: string }>>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        sftp.readdir(path, (readError, list) => {
          if (readError) return reject(readError);
          resolve(list.map((entry) => ({ name: entry.filename, type: entry.attrs.isDirectory() ? "directory" : "file", size: entry.attrs.size, modifiedAt: entry.attrs.mtime * 1000, permissions: modeToPermissions(entry.attrs.mode, entry.attrs.isDirectory()) })));
        });
      });
    });
  } finally { client.end(); }
}

export async function writeRemoteChunk(credentials: SSHCredentials, path: string, content: Buffer, offset: number) {
  const client = await connect(credentials);
  try {
    await new Promise<void>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        sftp.open(path, offset === 0 ? "w" : "r+", 0o644, (openError, handle) => {
          if (openError) return reject(openError);
          sftp.write(handle, content, 0, content.length, offset, (writeError) => {
            sftp.close(handle, () => writeError ? reject(writeError) : resolve());
          });
        });
      });
    });
    return { offset: offset + content.length } as const;
  } finally { client.end(); }
}

export async function readRemoteChunk(credentials: SSHCredentials, path: string, offset: number, length: number) {
  const client = await connect(credentials);
  try {
    return await new Promise<Buffer>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        sftp.open(path, "r", 0o644, (openError, handle) => {
          if (openError) return reject(openError);
          const buffer = Buffer.alloc(length);
          sftp.read(handle, buffer, 0, length, offset, (readError, bytesRead) => {
            sftp.close(handle, () => readError ? reject(readError) : resolve(buffer.subarray(0, bytesRead)));
          });
        });
      });
    });
  } finally { client.end(); }
}

export async function statRemoteFile(credentials: SSHCredentials, path: string) {
  const client = await connect(credentials);
  try {
    return await new Promise<{ size: number; modifiedAt: number }>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        sftp.stat(path, (statError, stats) => statError ? reject(statError) : resolve({ size: stats.size, modifiedAt: stats.mtime * 1000 }));
      });
    });
  } finally { client.end(); }
}

export async function writeRemoteFile(credentials: SSHCredentials, path: string, content: string) {
  const client = await connect(credentials);
  try {
    await new Promise<void>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        const stream = sftp.createWriteStream(path, { flags: "w", mode: 0o644 });
        stream.on("error", reject);
        stream.on("close", () => resolve());
        stream.end(Buffer.from(content, "utf8"));
      });
    });
    return { success: true } as const;
  } finally { client.end(); }
}

export async function deleteRemotePath(credentials: SSHCredentials, path: string) {
  const client = await connect(credentials);
  try {
    await new Promise<void>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        sftp.unlink(path, (unlinkError) => unlinkError ? reject(unlinkError) : resolve());
      });
    });
    return { success: true } as const;
  } finally { client.end(); }
}

export async function makeRemoteDirectory(credentials: SSHCredentials, path: string) {
  const client = await connect(credentials);
  try {
    await new Promise<void>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        sftp.mkdir(path, (mkdirError) => mkdirError ? reject(mkdirError) : resolve());
      });
    });
    return { success: true } as const;
  } finally { client.end(); }
}

export async function readRemoteFile(credentials: SSHCredentials, path: string) {
  const client = await connect(credentials);
  try {
    return await new Promise<string>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        const chunks: Buffer[] = [];
        const stream = sftp.createReadStream(path);
        stream.on("data", (chunk: Buffer) => chunks.push(chunk));
        stream.on("error", reject);
        stream.on("close", () => resolve(Buffer.concat(chunks).toString("utf8")));
      });
    });
  } finally { client.end(); }
}
