import { AES } from "@stablelib/aes";
import { GCM } from "@stablelib/gcm";
import { deriveKey } from "@stablelib/pbkdf2";
import { SHA256 } from "@stablelib/sha256";

const FORMAT = "server-ide-export";
const VERSION = 1;
const ITERATIONS = 310_000;
const KEY_LENGTH = 32;
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

type ExportEnvelope = {
  format: typeof FORMAT;
  version: number;
  kdf: "PBKDF2-SHA256";
  iterations: number;
  salt: string;
  cipher: "AES-256-GCM";
  nonce: string;
  ciphertext: string;
};

function randomBytes(length: number) {
  const bytes = new Uint8Array(length);
  const cryptoObject = (globalThis as { crypto?: Crypto }).crypto;
  if (!cryptoObject?.getRandomValues) throw new Error("Secure random generator unavailable");
  cryptoObject.getRandomValues(bytes);
  return bytes;
}

function toBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return globalThis.btoa(binary);
}

function fromBase64(value: string) {
  const binary = globalThis.atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function derive(password: string, salt: Uint8Array, iterations: number) {
  return deriveKey(SHA256, textEncoder.encode(password), salt, iterations, KEY_LENGTH);
}

export function encryptServerExport(payload: unknown, password: string): string {
  if (password.length < 10) throw new Error("Export password must contain at least 10 characters");
  const salt = randomBytes(16);
  const nonce = randomBytes(12);
  const key = derive(password, salt, ITERATIONS);
  const associatedData = textEncoder.encode(`${FORMAT}:${VERSION}`);
  const sealed = new GCM(new AES(key)).seal(nonce, textEncoder.encode(JSON.stringify(payload)), associatedData);
  const envelope: ExportEnvelope = { format: FORMAT, version: VERSION, kdf: "PBKDF2-SHA256", iterations: ITERATIONS, salt: toBase64(salt), cipher: "AES-256-GCM", nonce: toBase64(nonce), ciphertext: toBase64(sealed) };
  return JSON.stringify(envelope);
}

export function decryptServerExport(serialized: string, password: string): unknown {
  let envelope: ExportEnvelope;
  try { envelope = JSON.parse(serialized) as ExportEnvelope; } catch { throw new Error("Invalid encrypted export file"); }
  if (envelope.format !== FORMAT || envelope.version !== VERSION || envelope.kdf !== "PBKDF2-SHA256" || envelope.cipher !== "AES-256-GCM") throw new Error("Unsupported encrypted export format");
  const salt = fromBase64(envelope.salt);
  const nonce = fromBase64(envelope.nonce);
  const key = derive(password, salt, envelope.iterations);
  const associatedData = textEncoder.encode(`${FORMAT}:${VERSION}`);
  const opened = new GCM(new AES(key)).open(nonce, fromBase64(envelope.ciphertext), associatedData);
  if (!opened) throw new Error("Unable to decrypt export file");
  try { return JSON.parse(textDecoder.decode(opened)); } catch { throw new Error("Decrypted export contains invalid data"); }
}
