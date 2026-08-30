import { useEffect, useMemo, useRef, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { ScreenContainer } from "@/components/screen-container";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { useColors } from "@/hooks/use-colors";
import { useServerStore } from "@/lib/server-store";
import { readServerSecret } from "@/lib/server-secrets";
import { getApiBaseUrl } from "@/constants/oauth";

const stages = ["Network", "Auth", "Shell", "PTY", "Ready"];

export default function SSHScreen() {
  const colors = useColors("dark");
  const { activeServer } = useServerStore();
  const [password, setPassword] = useState("");
  const [privateKey, setPrivateKey] = useState("");
  const [fingerprint, setFingerprint] = useState("");
  const [command, setCommand] = useState("");
  const [lines, setLines] = useState<string[]>(["# Select a server and enter credentials to begin."]);
  const [connected, setConnected] = useState(false);
  const [expandedAuth, setExpandedAuth] = useState(false);
  const socketRef = useRef<WebSocket | null>(null);
  const pendingInput = useRef<string[]>([]);

  const credentials = useMemo(() => activeServer ? {
    host: activeServer.host,
    port: activeServer.port,
    username: activeServer.username,
    ...(activeServer.authMethod === "ssh-key" ? { privateKey } : { password }),
    ...(fingerprint ? { hostFingerprint: fingerprint } : {}),
  } : null, [activeServer, password, privateKey, fingerprint]);

  useEffect(() => () => { socketRef.current?.close(); }, []);
  useEffect(() => { let cancelled = false; if (!activeServer) return; void readServerSecret(activeServer.id).then((secret) => { if (!cancelled && secret) { setPassword(secret.password ?? ""); setPrivateKey(secret.privateKey ?? ""); setFingerprint(secret.hostFingerprint ?? ""); } }); return () => { cancelled = true; }; }, [activeServer]);

  const connectLive = () => {
    if (!credentials) return;
    if (socketRef.current?.readyState === WebSocket.OPEN || socketRef.current?.readyState === WebSocket.CONNECTING) return;
    const socket = new WebSocket(`${getApiBaseUrl().replace(/^http/, "ws")}/api/ssh/pty`);
    socketRef.current = socket;
    socket.onopen = () => {
      socket.send(JSON.stringify({ type: "start", credentials, cols: 100, rows: 30 }));
      pendingInput.current.splice(0).forEach((data) => socket.send(JSON.stringify({ type: "input", data })));
    };
    socket.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data as string) as { type: string; data?: string; message?: string; code?: number | null };
        if (message.type === "ready") { setConnected(true); setLines((current) => [...current, "[PTY] live session ready"]); }
        if (message.type === "data") setLines((current) => [...current, ...(message.data ?? "").replace(/\\r/g, "").split("\\n").filter(Boolean)]);
        if (message.type === "error") { setConnected(false); setLines((current) => [...current, `ERROR: ${message.message ?? "SSH session failed"}`]); }
        if (message.type === "closed") { setConnected(false); setLines((current) => [...current, `[PTY] session closed (${message.code ?? "unknown"})`]); }
      } catch { setLines((current) => [...current, "ERROR: Invalid PTY event"]); }
    };
    socket.onerror = () => { setConnected(false); setLines((current) => [...current, "ERROR: Live SSH channel unavailable"]); };
    socket.onclose = () => { setConnected(false); };
  };

  const run = async (value: string) => {
    if (!value.trim()) return;
    setLines((current) => [...current, `$ ${value}`]);
    setCommand("");
    if (!credentials) {
      setLines((current) => [...current, "ERROR: Select a server profile first."]);
      return;
    }
    if (!password && !privateKey) {
      setLines((current) => [...current, "ERROR: Add a password or private key for this session."]);
      return;
    }
    try {
      if (socketRef.current?.readyState === WebSocket.OPEN) socketRef.current.send(JSON.stringify({ type: "input", data: `${value}\n` }));
      else { pendingInput.current.push(`${value}\n`); connectLive(); }
    } catch (error) {
      setConnected(false);
      setLines((current) => [...current, `ERROR: ${error instanceof Error ? error.message : "SSH request failed"}`]);
    }
  };

  const statusColor = connected ? "#35D07F" : "#FFB84D";
  const completedStages = connected ? 5 : 0;

  return <ScreenContainer className="px-5" containerClassName="bg-background">
    <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
      <View style={styles.header}>
        <View><Text style={[styles.kicker, { color: colors.muted }]}>REMOTE WORKSPACE</Text><Text style={[styles.title, { color: colors.foreground }]}>SSH terminal</Text></View>
        <View style={[styles.connection, { backgroundColor: `${statusColor}18` }]}><View style={[styles.dot, { backgroundColor: statusColor }]} /><Text style={{ color: statusColor, fontSize: 11, fontWeight: "800" }}>{connected ? "READY" : "IDLE"}</Text></View>
      </View>

      <View style={[styles.session, { backgroundColor: colors.surface, borderColor: colors.border }]}>
        <View style={styles.sessionTop}><View style={[styles.sessionIcon, { backgroundColor: "#4DA3FF18" }]}><IconSymbol name="chevron.left.forwardslash.chevron.right" size={19} color="#4DA3FF" /></View><View style={styles.flex}><Text style={[styles.sessionName, { color: colors.foreground }]}>{activeServer?.name ?? "No server selected"}</Text><Text style={[styles.sub, { color: colors.muted }]}>{activeServer ? `${activeServer.username}@${activeServer.host}:${activeServer.port}` : "Open Servers to add a profile"}</Text></View><Text style={{ color: statusColor, fontSize: 10, fontWeight: "700" }}>{connected ? "Connected" : "Not connected"}</Text></View>
        {stages.map((stage, index) => <View key={stage} style={styles.stage}><View style={[styles.stageLine, { backgroundColor: index === stages.length - 1 ? "transparent" : index < completedStages - 1 ? "#35D07F" : colors.border }]} /><View style={[styles.stageIcon, { backgroundColor: index < completedStages ? "#35D07F" : colors.surface, borderColor: index < completedStages ? "#35D07F" : colors.border }]}><Text style={{ color: index < completedStages ? "#07111B" : colors.muted, fontSize: 10, fontWeight: "800" }}>{index < completedStages ? "✓" : "·"}</Text></View><View><Text style={[styles.stageTitle, { color: colors.foreground }]}>{stage}</Text><Text style={[styles.sub, { color: colors.muted }]}>{index < completedStages ? "Complete" : "Waiting for request"}</Text></View></View>)}
        <Pressable onPress={() => setExpandedAuth((value) => !value)} style={({ pressed }) => [styles.close, { borderColor: colors.border, opacity: pressed ? 0.7 : 1 }]}><Text style={{ color: colors.primary, fontWeight: "800" }}>{expandedAuth ? "Hide credentials" : "Credentials for this session"}</Text></Pressable>
        {expandedAuth && <View style={styles.authBox}><TextInput value={activeServer?.authMethod === "ssh-key" ? privateKey : password} onChangeText={activeServer?.authMethod === "ssh-key" ? setPrivateKey : setPassword} secureTextEntry={activeServer?.authMethod !== "ssh-key"} multiline={activeServer?.authMethod === "ssh-key"} placeholder={activeServer?.authMethod === "ssh-key" ? "Paste private key" : "Password"} placeholderTextColor="#586574" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /><TextInput value={fingerprint} onChangeText={setFingerprint} placeholder="Host fingerprint: SHA256:..." placeholderTextColor="#586574" autoCapitalize="none" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /><Text style={[styles.sub, { color: colors.muted }]}>Credentials stay in memory for this screen and are not saved to the profile.</Text></View>}
      </View>

      <View style={[styles.terminal, { backgroundColor: "#0B0F13", borderColor: colors.border }]}><View style={styles.terminalBar}><Text style={{ color: "#35D07F", fontSize: 11, fontWeight: "700" }}>{activeServer?.name ?? "server"} • bash</Text><Text style={{ color: colors.muted, fontSize: 10 }}>{connected ? "LIVE" : "LOCAL"}</Text></View><View style={styles.output}>{lines.map((line, index) => <Text key={`${line}-${index}`} style={[styles.line, { color: line.startsWith("ERROR") || line.startsWith("[stderr]") ? "#FF5C70" : line.startsWith("$") ? "#4DA3FF" : colors.foreground }]}>{line}</Text>)}</View><View style={[styles.commandRow, { borderTopColor: colors.border }]}><Text style={{ color: "#35D07F", fontWeight: "800" }}>$</Text><TextInput value={command} onChangeText={setCommand} onSubmitEditing={() => void run(command)} returnKeyType="done" placeholder="Type a command..." placeholderTextColor="#586574" style={[styles.commandInput, { color: colors.foreground }]} /></View></View>
      <View style={styles.toolRow}>{["ESC", "CTRL", "TAB", "↑", "↓", "CLEAR"].map((tool) => <Pressable key={tool} onPress={() => tool === "CLEAR" ? setLines([]) : setLines((current) => [...current, `> ${tool} pressed`])} style={({ pressed }) => [styles.tool, { backgroundColor: colors.surface, borderColor: colors.border, opacity: pressed ? 0.6 : 1 }]}><Text style={{ color: colors.muted, fontSize: 10, fontWeight: "800" }}>{tool}</Text></Pressable>)}</View>
    </ScrollView>
  </ScreenContainer>;
}

const styles = StyleSheet.create({ content: { paddingTop: 12, paddingBottom: 32 }, header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }, kicker: { fontSize: 11, fontWeight: "800", letterSpacing: 1.3 }, title: { fontSize: 30, fontWeight: "800", marginTop: 6 }, connection: { borderRadius: 18, paddingHorizontal: 11, paddingVertical: 8, flexDirection: "row", gap: 7, alignItems: "center" }, dot: { width: 7, height: 7, borderRadius: 4 }, session: { borderRadius: 20, borderWidth: 1, padding: 16, marginBottom: 15 }, sessionTop: { flexDirection: "row", alignItems: "center", gap: 10, marginBottom: 17 }, sessionIcon: { width: 38, height: 38, borderRadius: 12, alignItems: "center", justifyContent: "center" }, flex: { flex: 1 }, sessionName: { fontSize: 14, fontWeight: "800" }, sub: { fontSize: 10, marginTop: 4 }, stage: { minHeight: 42, flexDirection: "row", alignItems: "center", gap: 10 }, stageLine: { position: "absolute", width: 2, height: 42, left: 11, top: 22 }, stageIcon: { width: 24, height: 24, borderRadius: 12, borderWidth: 1, alignItems: "center", justifyContent: "center", zIndex: 1 }, stageTitle: { fontSize: 12, fontWeight: "700" }, close: { height: 42, borderRadius: 13, borderWidth: 1, alignItems: "center", justifyContent: "center", marginTop: 13 }, authBox: { gap: 8, marginTop: 12 }, input: { minHeight: 42, borderWidth: 1, borderRadius: 11, paddingHorizontal: 12, paddingVertical: 10, fontSize: 12 }, terminal: { borderRadius: 18, borderWidth: 1, overflow: "hidden", minHeight: 280 }, terminalBar: { padding: 12, borderBottomWidth: 1, borderBottomColor: "#252D37", flexDirection: "row", justifyContent: "space-between" }, output: { padding: 14, gap: 8, minHeight: 220 }, line: { fontSize: 11, fontFamily: "monospace", lineHeight: 16 }, commandRow: { borderTopWidth: 1, minHeight: 48, paddingHorizontal: 13, flexDirection: "row", alignItems: "center", gap: 8 }, commandInput: { flex: 1, fontFamily: "monospace", fontSize: 12 }, toolRow: { flexDirection: "row", gap: 6, marginTop: 10 }, tool: { flex: 1, borderRadius: 9, borderWidth: 1, alignItems: "center", paddingVertical: 9 } });
