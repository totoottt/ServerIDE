import type { Server } from "node:http";
import { WebSocket, WebSocketServer } from "ws";
import { openSSHPTY } from "./ssh-service";
import { sshCredentialsSchema } from "./ssh-validation";

type ClientMessage =
  | { type: "start"; credentials: unknown; cols?: number; rows?: number }
  | { type: "input"; data: string }
  | { type: "resize"; cols: number; rows: number }
  | { type: "close" };

function send(socket: WebSocket, value: unknown) {
  if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(value));
}

export function registerSSHRealtime(server: Server) {
  const wss = new WebSocketServer({ server, path: "/api/ssh/pty" });
  wss.on("connection", (socket) => {
    let stream: Awaited<ReturnType<typeof openSSHPTY>>["stream"] | null = null;
    let client: Awaited<ReturnType<typeof openSSHPTY>>["client"] | null = null;
    let started = false;

    socket.on("message", async (raw) => {
      let message: ClientMessage;
      try { message = JSON.parse(raw.toString()) as ClientMessage; } catch { return send(socket, { type: "error", message: "Invalid message" }); }
      if (message.type === "start") {
        if (started) return;
        const parsed = sshCredentialsSchema.safeParse(message.credentials);
        if (!parsed.success) return send(socket, { type: "error", message: "Invalid SSH credentials" });
        started = true;
        try {
          const opened = await openSSHPTY(parsed.data, message.cols, message.rows);
          client = opened.client;
          stream = opened.stream;
          stream.on("data", (chunk: Buffer) => send(socket, { type: "data", data: chunk.toString("utf8") }));
          stream.on("close", (code: number | null) => { send(socket, { type: "closed", code }); socket.close(); });
          stream.on("error", (error: Error) => send(socket, { type: "error", message: error.message }));
          send(socket, { type: "ready" });
        } catch (error) {
          started = false;
          send(socket, { type: "error", message: error instanceof Error ? error.message : "SSH PTY connection failed" });
        }
      } else if (message.type === "input" && stream) {
        stream.write(message.data);
      } else if (message.type === "resize" && stream) {
        stream.setWindow(Math.max(40, Math.min(message.rows, 200)), Math.max(80, Math.min(message.cols, 240)), 0, 0);
      } else if (message.type === "close") {
        stream?.end();
        client?.end();
        socket.close();
      }
    });

    socket.on("close", () => { stream?.end(); client?.end(); });
    socket.on("error", () => { stream?.end(); client?.end(); });
  });
  return wss;
}
