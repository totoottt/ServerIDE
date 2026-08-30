import { Client, type ClientChannel } from "ssh2";
import { createHash } from "node:crypto";

export type SSHCredentials = {
  host: string;
  port: number;
  username: string;
  password?: string;
  privateKey?: string;
  passphrase?: string;
  hostFingerprint?: string;
};

export function connect(credentials: SSHCredentials): Promise<Client> {
  return new Promise((resolve, reject) => {
    const client = new Client();
    const timer = setTimeout(() => { client.end(); reject(new Error("SSH connection timed out")); }, 12_000);
    client.once("ready", () => { clearTimeout(timer); resolve(client); });
    client.once("error", (error) => { clearTimeout(timer); reject(error); });
    const { hostFingerprint, ...connection } = credentials;
    client.connect({ ...connection, tryKeyboard: false, readyTimeout: 10_000, hostVerifier: (key: Buffer) => {
      if (!hostFingerprint) return false;
      const fingerprint = `SHA256:${createHash("sha256").update(key).digest("base64").replace(/=+$/, "")}`;
      return fingerprint === hostFingerprint;
    } });
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

export async function listRemoteDirectory(credentials: SSHCredentials, path: string) {
  const client = await connect(credentials);
  try {
    return await new Promise<Array<{ name: string; type: string; size: number; modifiedAt: number }>>((resolve, reject) => {
      client.sftp((error, sftp) => {
        if (error) return reject(error);
        sftp.readdir(path, (readError, list) => {
          if (readError) return reject(readError);
          resolve(list.map((entry) => ({ name: entry.filename, type: entry.attrs.isDirectory() ? "directory" : "file", size: entry.attrs.size, modifiedAt: entry.attrs.mtime * 1000 })));
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
