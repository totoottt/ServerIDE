export type ServerProfile = {
  name: string;
  baseUrl: string;
  token: string;
};

export type ServerHealth = {
  hostname: string;
  platform: string;
  uptimeSeconds: number;
  latencyMs?: number;
  cpu: { usagePercent: number; cores: number };
  memory: { usedBytes: number; totalBytes: number; usagePercent: number };
  storage: { usedBytes: number; totalBytes: number; usagePercent: number };
  updatedAt: string;
};

export type ServerProcess = {
  pid: number;
  command: string;
  user: string;
  status: string;
  cpuPercent: number;
  memoryBytes: number;
};

export type NetworkSnapshot = {
  interface: string;
  rxBytes: number;
  txBytes: number;
  sampledAt: string;
};

export type RemoteEntry = {
  name: string;
  path: string;
  type: "file" | "folder" | "symlink";
  size: number;
  modifiedAt: string;
};

export type DomainCheck = {
  name: "SPF" | "DKIM" | "DMARC" | "Blacklists" | "SMTP";
  status: "Good" | "Warning" | "Info" | "Error";
  detail: string;
};

type RequestOptions = {
  method?: "GET" | "POST" | "PUT" | "DELETE";
  body?: unknown;
  timeoutMs?: number;
};

function normalizedBaseUrl(value: string) {
  return value.trim().replace(/\/+$/, "");
}

async function request<T>(profile: ServerProfile, path: string, options: RequestOptions = {}): Promise<T> {
  const baseUrl = normalizedBaseUrl(profile.baseUrl);
  if (!/^https?:\/\//i.test(baseUrl)) throw new Error("Agent URL must start with https://");
  if (!profile.token.trim()) throw new Error("Agent access token is required");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), options.timeoutMs ?? 15_000);
  try {
    const response = await fetch(`${baseUrl}${path}`, {
      method: options.method ?? "GET",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        Authorization: `Bearer ${profile.token.trim()}`,
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
      signal: controller.signal,
    });
    const text = await response.text();
    const data = text ? JSON.parse(text) : null;
    if (!response.ok) throw new Error(data?.error || `Agent request failed (${response.status})`);
    return data as T;
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") throw new Error("Agent request timed out");
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

export const serverAgent = {
  async health(profile: ServerProfile) {
    const started = Date.now();
    const result = await request<ServerHealth>(profile, "/v1/health");
    return { ...result, latencyMs: Date.now() - started };
  },
  processes: (profile: ServerProfile) => request<{ processes: ServerProcess[] }>(profile, "/v1/processes"),
  stopProcess: (profile: ServerProfile, pid: number) => request<{ success: boolean }>(profile, "/v1/process/stop", { method: "POST", body: { pid } }),
  network: (profile: ServerProfile, iface?: string) => request<NetworkSnapshot>(profile, `/v1/network${iface ? `?interface=${encodeURIComponent(iface)}` : ""}`),
  command: (profile: ServerProfile, command: string, cwd?: string) => request<{ stdout: string; stderr: string; exitCode: number; cwd: string }>(profile, "/v1/command", { method: "POST", body: { command, cwd }, timeoutMs: 125_000 }),
  files: (profile: ServerProfile, path: string) => request<{ path: string; entries: RemoteEntry[] }>(profile, `/v1/files?path=${encodeURIComponent(path)}`),
  readFile: (profile: ServerProfile, path: string) => request<{ path: string; content: string; encoding: "utf8" | "base64"; size: number }>(profile, `/v1/file?path=${encodeURIComponent(path)}`),
  writeFile: (profile: ServerProfile, path: string, content: string) => request<{ success: boolean }>(profile, "/v1/file", { method: "PUT", body: { path, content, encoding: "utf8" } }),
  mkdir: (profile: ServerProfile, path: string) => request<{ success: boolean }>(profile, "/v1/mkdir", { method: "POST", body: { path } }),
  deleteEntry: (profile: ServerProfile, path: string) => request<{ success: boolean }>(profile, "/v1/file", { method: "DELETE", body: { path } }),
  checks: (profile: ServerProfile, domain: string) => request<{ domain: string; checkedAt: string; checks: DomainCheck[] }>(profile, `/v1/checks?domain=${encodeURIComponent(domain)}`, { timeoutMs: 30_000 }),
};

export function formatBytes(bytes: number) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / 1024 ** index).toFixed(index > 1 ? 1 : 0)} ${units[index]}`;
}

export function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "Unknown connection error";
}
