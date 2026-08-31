export type ServiceStatus = "success" | "warning" | "error" | "info" | "neutral";

export const statusLabel: Record<ServiceStatus, string> = {
  success: "Success",
  warning: "Warning",
  error: "Error",
  info: "Info",
  neutral: "Neutral",
};

export function isActionable(status: ServiceStatus) {
  return status === "warning" || status === "error";
}
