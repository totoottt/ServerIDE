#!/usr/bin/env python3
"""ServerIDE remote file operations. Invoked over SSH; requires Python 3."""
import base64
import ctypes
import errno
import hashlib
import json
import os
import stat
import sys

MAX_FILE = 5 * 1024 * 1024


def upload_path(path):
    if not os.path.basename(path).startswith(".serveride-upload-"):
        raise ValueError("Invalid upload staging path")
    return path


def operate(a):
    op = a["op"]
    path = os.path.abspath(os.path.expanduser(a.get("path", ".")))
    if op == "list":
        path = os.path.realpath(path)
        entries = []
        with os.scandir(path) as rows:
            for row in rows:
                if len(entries) >= 10000:
                    raise ValueError("Folder exceeds 10,000 entries; open a smaller folder")
                info = row.stat(follow_symlinks=False)
                entries.append({"name": row.name, "path": row.path,
                                "isDirectory": stat.S_ISDIR(info.st_mode),
                                "size": info.st_size, "modified": info.st_mtime,
                                "permissions": stat.filemode(info.st_mode)})
        return {"path": path, "files": entries}
    if op == "read":
        with open(path, "rb") as f:
            data = f.read(MAX_FILE + 1)
        if len(data) > MAX_FILE:
            raise ValueError("File exceeds the 5 MiB transfer limit")
        return {"data": base64.b64encode(data).decode(), "sha256": hashlib.sha256(data).hexdigest()}
    if op == "mkdir":
        os.mkdir(path)
    elif op == "create":
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(fd)
    elif op == "rename":
        destination = os.path.abspath(a["destination"])
        libc = ctypes.CDLL(None, use_errno=True)
        rename = libc.renameat2
        rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        rename.restype = ctypes.c_int
        if rename(-100, os.fsencode(path), -100, os.fsencode(destination), 1) != 0:
            error = ctypes.get_errno()
            raise OSError(error, os.strerror(error))
    elif op == "delete":
        if path == "/":
            raise ValueError("Cannot delete filesystem root")
        if os.path.isdir(path) and not os.path.islink(path):
            os.rmdir(path)  # Empty directories only.
        else:
            os.unlink(path)
    elif op == "uploadStart":
        upload_path(path)
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(fd)
    elif op == "uploadChunk":
        upload_path(path)
        data = base64.b64decode(a["data"], validate=True)
        if len(data) > 24576:
            raise ValueError("Oversized upload chunk")
        fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_NOFOLLOW)
        with os.fdopen(fd, "ab") as f:
            if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
                raise ValueError("Staging target is not a regular file")
            if os.fstat(f.fileno()).st_size + len(data) > MAX_FILE:
                raise ValueError("File exceeds the 5 MiB transfer limit")
            f.write(data)
    elif op == "uploadFinish":
        upload_path(path)
        if not stat.S_ISREG(os.lstat(path).st_mode):
            raise ValueError("Staging target is not a regular file")
        if os.path.getsize(path) != a["size"]:
            raise ValueError("Upload size mismatch")
        os.link(path, a["destination"], follow_symlinks=False)  # Atomic, never replaces target.
        os.unlink(path)
    elif op == "uploadReplace":
        upload_path(path)
        destination = os.path.abspath(a["destination"])
        backup = os.path.abspath(a["backup"])
        if os.path.dirname(path) != os.path.dirname(destination) or os.path.dirname(backup) != os.path.dirname(destination):
            raise ValueError("Save staging and backup must be next to the original file")
        if not os.path.basename(backup).startswith(".serveride-backup-"):
            raise ValueError("Invalid backup path")
        with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as staged:
            staged_info = os.fstat(staged.fileno())
            if not stat.S_ISREG(staged_info.st_mode) or staged_info.st_nlink != 1 or staged_info.st_size != a["size"] or staged_info.st_size > MAX_FILE:
                raise ValueError("Invalid staged save size or type")
        with os.fdopen(os.open(destination, os.O_RDONLY | os.O_NOFOLLOW), "rb") as original:
            info = os.fstat(original.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
                raise ValueError("Only regular files without hard links can be edited")
            old = original.read(MAX_FILE + 1)
        if len(old) > MAX_FILE or hashlib.sha256(old).hexdigest() != a["expectedSHA256"]:
            raise ValueError("File changed on the server. Reopen it before saving; your local draft is unchanged.")
        # Preserve owner and POSIX mode; fail before replacement if not permitted.
        os.chown(path, info.st_uid, info.st_gid)
        os.chmod(path, stat.S_IMODE(info.st_mode))
        # Preserve extended attributes, including POSIX ACLs. A permission error
        # must abort rather than silently weaken the original file's access rules.
        for name in os.listxattr(destination, follow_symlinks=False):
            os.setxattr(path, name, os.getxattr(destination, name, follow_symlinks=False), follow_symlinks=False)
        with open(path, "rb") as staged:
            os.fsync(staged.fileno())
        backup_fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(backup_fd, "wb") as f:
            f.write(old)
            f.flush()
            os.fsync(f.fileno())
        current = os.lstat(destination)
        if (current.st_dev, current.st_ino, current.st_size, current.st_mtime_ns) != (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns):
            raise ValueError("File changed while saving. Original was not replaced; backup retained.")
        os.replace(path, destination)
        return {"path": backup}
    elif op == "uploadCancel":
        upload_path(path)
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
    else:
        raise ValueError("Unknown file operation")
    return {}


def main():
    try:
        arguments = json.loads(base64.b64decode(sys.argv[1], validate=True))
        print(json.dumps(dict(ok=True, **operate(arguments)), ensure_ascii=True))
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=True))


if __name__ == "__main__":
    main()
