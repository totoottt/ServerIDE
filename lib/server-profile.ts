export type ServerDraft = { name: string; host: string; port: number; username: string };

export function validateServerDraft(draft: ServerDraft): string | null {
  if (!draft.name.trim()) return "Enter a server name.";
  if (!draft.host.trim()) return "Enter a hostname or IP address.";
  if (!Number.isInteger(draft.port) || draft.port < 1 || draft.port > 65535) return "Port must be between 1 and 65535.";
  if (!draft.username.trim()) return "Enter the SSH username.";
  if (/\s/.test(draft.host.trim())) return "Host cannot contain spaces.";
  return null;
}
