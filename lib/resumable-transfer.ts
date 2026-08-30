import AsyncStorage from "@react-native-async-storage/async-storage";
import { File } from "expo-file-system";
import type { SSHCredentials } from "@/server/ssh-service";
import { createTRPCClient } from "@/lib/trpc";

const CHUNK_SIZE = 512 * 1024;
const STORAGE_PREFIX = "server-ide.transfer.";

export type TransferCheckpoint = {
  id: string;
  direction: "download" | "upload";
  localUri: string;
  remotePath: string;
  totalBytes: number;
  completedBytes: number;
  status: "paused" | "running" | "resuming" | "completed" | "failed";
  updatedAt: number;
};

export type TransferProgress = TransferCheckpoint & { speedBytesPerSecond: number; etaSeconds: number };

function bytesFromBase64(value: string) {
  const binary = globalThis.atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function base64FromBytes(bytes: Uint8Array) {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 1) binary += String.fromCharCode(bytes[index]);
  return globalThis.btoa(binary);
}

async function saveCheckpoint(checkpoint: TransferCheckpoint) {
  await AsyncStorage.setItem(`${STORAGE_PREFIX}${checkpoint.id}`, JSON.stringify(checkpoint));
}

export async function getTransferCheckpoint(id: string) {
  const raw = await AsyncStorage.getItem(`${STORAGE_PREFIX}${id}`);
  return raw ? JSON.parse(raw) as TransferCheckpoint : null;
}

export async function downloadRemoteFile(credentials: SSHCredentials, remotePath: string, localUri: string, onProgress?: (progress: TransferProgress) => void) {
  const client = createTRPCClient();
  const stat = await client.ssh.stat.mutate({ credentials, path: remotePath });
  const id = `download:${credentials.host}:${remotePath}:${localUri}`;
  const existing = await getTransferCheckpoint(id);
  const file = new File(localUri);
  if (!file.exists) file.create({ intermediates: true });
  const localSize = file.size;
  let completedBytes = Math.min(existing?.completedBytes ?? 0, Math.min(localSize, stat.size));
  const startedAt = Date.now();
  const handle = file.open();
  handle.offset = completedBytes;
  try {
    while (completedBytes < stat.size) {
      const length = Math.min(CHUNK_SIZE, stat.size - completedBytes);
      const result = await client.ssh.readChunk.mutate({ credentials, path: remotePath, offset: completedBytes, length });
      const bytes = bytesFromBase64(result.dataBase64);
      if (!bytes.length) throw new Error("Remote transfer returned an empty chunk");
      handle.writeBytes(bytes);
      completedBytes += bytes.length;
      const elapsed = Math.max(1, Date.now() - startedAt) / 1000;
      const speed = completedBytes / elapsed;
      const checkpoint: TransferCheckpoint = { id, direction: "download", localUri, remotePath, totalBytes: stat.size, completedBytes, status: completedBytes >= stat.size ? "completed" : existing?.completedBytes ? "resuming" : "running", updatedAt: Date.now() };
      await saveCheckpoint(checkpoint);
      onProgress?.({ ...checkpoint, speedBytesPerSecond: speed, etaSeconds: Math.max(0, Math.ceil((stat.size - completedBytes) / Math.max(1, speed))) });
    }
    return { id, localUri, completedBytes };
  } catch (error) {
    const checkpoint: TransferCheckpoint = { id, direction: "download", localUri, remotePath, totalBytes: stat.size, completedBytes, status: "paused", updatedAt: Date.now() };
    await saveCheckpoint(checkpoint);
    throw error;
  } finally { handle.close(); }
}

export async function uploadLocalFile(credentials: SSHCredentials, localUri: string, remotePath: string, onProgress?: (progress: TransferProgress) => void) {
  const client = createTRPCClient();
  const file = new File(localUri);
  const totalBytes = file.size;
  const id = `upload:${credentials.host}:${remotePath}:${localUri}`;
  const existing = await getTransferCheckpoint(id);
  let completedBytes = Math.min(existing?.completedBytes ?? 0, totalBytes);
  const startedAt = Date.now();
  const handle = file.open();
  handle.offset = completedBytes;
  try {
    while (completedBytes < totalBytes) {
      const bytes = handle.readBytes(Math.min(CHUNK_SIZE, totalBytes - completedBytes));
      const result = await client.ssh.writeChunk.mutate({ credentials, path: remotePath, offset: completedBytes, dataBase64: base64FromBytes(bytes) });
      completedBytes = result.offset;
      const elapsed = Math.max(1, Date.now() - startedAt) / 1000;
      const speed = completedBytes / elapsed;
      const checkpoint: TransferCheckpoint = { id, direction: "upload", localUri, remotePath, totalBytes, completedBytes, status: completedBytes >= totalBytes ? "completed" : existing?.completedBytes ? "resuming" : "running", updatedAt: Date.now() };
      await saveCheckpoint(checkpoint);
      onProgress?.({ ...checkpoint, speedBytesPerSecond: speed, etaSeconds: Math.max(0, Math.ceil((totalBytes - completedBytes) / Math.max(1, speed))) });
    }
    return { id, localUri, completedBytes };
  } catch (error) {
    await saveCheckpoint({ id, direction: "upload", localUri, remotePath, totalBytes, completedBytes, status: "paused", updatedAt: Date.now() });
    throw error;
  } finally { handle.close(); }
}
