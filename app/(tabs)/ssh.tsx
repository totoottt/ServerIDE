import { useEffect, useMemo, useRef, useState } from "react";
import { Keyboard, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import * as Clipboard from "expo-clipboard";
import { ScreenContainer } from "@/components/screen-container";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { useColors } from "@/hooks/use-colors";
import { useServerStore } from "@/lib/server-store";
import { readServerSecret } from "@/lib/server-secrets";
import { getApiBaseUrl } from "@/constants/oauth";

const stages = ["Network", "Auth", "Shell", "PTY", "Ready"];
const snippets = [
  { label: "Status", command: "uptime" },
  { label: "Storage", command: "df -h" },
  { label: "Processes", command: "ps aux --sort=-%mem | head" },
];

export default function SSHScreen() {
  const colors = useColors("dark");
  const { activeServer } = useServerStore();
  const [password, setPassword] = useState("");
  const [privateKey, setPrivateKey] = useState("");
  const [fingerprint, setFingerprint] = useState("");
  const [command, setCommand] = useState("");
  const [lines, setLines] = useState<string[]>(["# Server IDE live terminal", "# Select a server and open a session."]);
  const [connected, setConnected] = useState(false);
  const [expandedAuth, setExpandedAuth] = useState(false);
  const [notice, setNotice] = useState("Command Shelf is ready");
  const socketRef = useRef<WebSocket | null>(null);
  const pendingInput = useRef<string[]>([]);
  const commandInputRef = useRef<TextInput>(null);

  const credentials = useMemo(() => activeServer ? {
    host: activeServer.host,
    port: activeServer.port,
    username: activeServer.username,
    ...(activeServer.authMethod === "ssh-key" ? { privateKey } : { password }),
    ...(fingerprint ? { hostFingerprint: fingerprint } : {}),
  } : null, [activeServer, password, privateKey, fingerprint]);

  useEffect(() => () => { socketRef.current?.close(); }, []);
  useEffect(() => {
    let cancelled = false;
    if (!activeServer) return;
    void readServerSecret(activeServer.id).then((secret) => {
      if (!cancelled && secret) {
        setPassword(secret.password ?? "");
        setPrivateKey(secret.privateKey ?? "");
        setFingerprint(secret.hostFingerprint ?? "");
      }
    });
    return () => { cancelled = true; };
  }, [activeServer]);

  const connectLive = () => {
    if (!credentials) return;
    if (socketRef.current?.readyState === WebSocket.OPEN || socketRef.current?.readyState === WebSocket.CONNECTING) return;
    setNotice("Opening encrypted live channel…");
    const socket = new WebSocket(`${getApiBaseUrl().replace(/^http/, "ws")}/api/ssh/pty`);
    socketRef.current = socket;
    socket.onopen = () => {
      socket.send(JSON.stringify({ type: "start", credentials, cols: 100, rows: 30 }));
      pendingInput.current.splice(0).forEach((data) => socket.send(JSON.stringify({ type: "input", data })));
    };
    socket.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data as string) as { type: string; data?: string; message?: string; code?: number | null };
        if (message.type === "ready") {
          setConnected(true);
          setNotice("Live PTY session connected");
          setLines((current) => [...current, "[session] PTY ready"]);
        }
        if (message.type === "data") setLines((current) => [...current, ...(message.data ?? "").replace(/\r/g, "").split("\n").filter(Boolean)]);
        if (message.type === "error") {
          setConnected(false);
          setNotice("Connection failed — verify host fingerprint and credentials");
          setLines((current) => [...current, `ERROR: ${message.message ?? "SSH session failed"}`]);
        }
        if (message.type === "closed") {
          setConnected(false);
          setNotice("Session closed");
          setLines((current) => [...current, `[session] closed (${message.code ?? "unknown"})`]);
        }
      } catch { setLines((current) => [...current, "ERROR: Invalid PTY event"]); }
    };
    socket.onerror = () => {
      setConnected(false);
      setNotice("Live channel unavailable — tap a snippet or run a command to retry");
      setLines((current) => [...current, "ERROR: Live SSH channel unavailable"]);
    };
    socket.onclose = () => { setConnected(false); };
  };

  const sendInput = (data: string) => {
    if (socketRef.current?.readyState === WebSocket.OPEN) socketRef.current.send(JSON.stringify({ type: "input", data }));
    else { pendingInput.current.push(data); connectLive(); }
  };

  const run = (value: string) => {
    if (!value.trim()) return;
    setLines((current) => [...current, `$ ${value}`]);
    setCommand("");
    if (!credentials) {
      setLines((current) => [...current, "ERROR: Select a server profile first."]);
      return;
    }
    if (!password && !privateKey) {
      setLines((current) => [...current, "ERROR: Add a password or private key for this session."]);
      setExpandedAuth(true);
      return;
    }
    sendInput(`${value}\n`);
  };

  const copyOutput = async () => {
    await Clipboard.setStringAsync(lines.join("\n"));
    setNotice("Terminal output copied to clipboard");
  };
  const pasteIntoCommand = async () => {
    const clipboardText = await Clipboard.getStringAsync();
    if (!clipboardText) { setNotice("Clipboard is empty"); return; }
    setCommand((current) => `${current}${clipboardText}`);
    commandInputRef.current?.focus();
    setNotice("Clipboard placed in command input");
  };
  const sendShortcut = (label: string, data: string) => {
    sendInput(data);
    setNotice(`${label} sent to live session`);
  };

  const statusColor = connected ? colors.success : colors.warning;
  const completedStages = connected ? stages.length : 0;

  return <ScreenContainer className="px-5" containerClassName="bg-background">
    <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
      <View style={styles.header}>
        <View><Text style={[styles.kicker, { color: colors.muted }]}>OPERATIONAL CANVAS</Text><Text style={[styles.title, { color: colors.foreground }]}>Live terminal</Text></View>
        <View style={[styles.connection, { backgroundColor: `${statusColor}18` }]}><View style={[styles.dot, { backgroundColor: statusColor }]} /><Text style={{ color: statusColor, fontSize: 11, fontWeight: "800" }}>{connected ? "LIVE" : "STANDBY"}</Text></View>
      </View>

      <View style={[styles.sessionRibbon, { backgroundColor: colors.surface, borderColor: colors.border }]}>
        <View style={[styles.sessionIcon, { backgroundColor: `${colors.primary}18` }]}><IconSymbol name="chevron.left.forwardslash.chevron.right" size={19} color={colors.primary} /></View>
        <View style={styles.flex}><Text style={[styles.sessionName, { color: colors.foreground }]}>{activeServer?.name ?? "No server selected"}</Text><Text style={[styles.sub, { color: colors.muted }]}>{activeServer ? `${activeServer.username}@${activeServer.host}:${activeServer.port}` : "Open Servers to add a profile"}</Text></View>
        <Pressable onPress={() => setExpandedAuth((value) => !value)} style={({ pressed }) => [styles.credentialButton, { borderColor: colors.border, opacity: pressed ? 0.7 : 1 }]}><Text style={{ color: colors.primary, fontSize: 10, fontWeight: "800" }}>AUTH</Text></Pressable>
      </View>
      <View style={styles.stageRow}>{stages.map((stage, index) => <View key={stage} style={styles.stageMini}><View style={[styles.stageIcon, { backgroundColor: index < completedStages ? colors.success : colors.surface, borderColor: index < completedStages ? colors.success : colors.border }]}><Text style={{ color: index < completedStages ? colors.background : colors.muted, fontSize: 9, fontWeight: "900" }}>{index < completedStages ? "✓" : index + 1}</Text></View><Text style={[styles.stageLabel, { color: index < completedStages ? colors.success : colors.muted }]}>{stage}</Text></View>)}</View>
      {expandedAuth && <View style={[styles.authBox, { borderColor: colors.border, backgroundColor: colors.surface }]}><TextInput value={activeServer?.authMethod === "ssh-key" ? privateKey : password} onChangeText={activeServer?.authMethod === "ssh-key" ? setPrivateKey : setPassword} secureTextEntry={activeServer?.authMethod !== "ssh-key"} multiline={activeServer?.authMethod === "ssh-key"} placeholder={activeServer?.authMethod === "ssh-key" ? "Private key" : "Password"} placeholderTextColor={colors.muted} style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /><TextInput value={fingerprint} onChangeText={setFingerprint} placeholder="Host fingerprint: SHA256:…" placeholderTextColor={colors.muted} autoCapitalize="none" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /><Text style={[styles.sub, { color: colors.muted }]}>Credentials are encrypted on the device and never echoed in terminal output.</Text></View>}

      <View style={[styles.terminal, { backgroundColor: "#0B0F13", borderColor: colors.border }]}>
        <View style={styles.terminalBar}><Text style={{ color: colors.success, fontSize: 11, fontWeight: "800" }}>{activeServer?.name ?? "server"} / bash</Text><Text style={{ color: colors.muted, fontSize: 10 }}>{connected ? "STREAMING" : "OFFLINE"}</Text></View>
        <View style={styles.output}>{lines.map((line, index) => <Text selectable key={`${line}-${index}`} style={[styles.line, { color: line.startsWith("ERROR") || line.startsWith("[stderr]") ? colors.error : line.startsWith("$") ? colors.primary : colors.foreground }]}>{line}</Text>)}</View>
        <View style={[styles.commandRow, { borderTopColor: colors.border }]}><Text style={{ color: colors.success, fontWeight: "900" }}>$</Text><TextInput ref={commandInputRef} value={command} onChangeText={setCommand} onSubmitEditing={() => run(command)} returnKeyType="done" placeholder="Write a command…" placeholderTextColor="#586574" style={[styles.commandInput, { color: colors.foreground }]} /></View>
      </View>

      <View style={[styles.commandShelf, { backgroundColor: colors.surface, borderColor: colors.border }]}>
        <View style={styles.shelfHeader}><View><Text style={[styles.shelfTitle, { color: colors.foreground }]}>Command Shelf</Text><Text style={[styles.sub, { color: colors.muted }]}>{notice}</Text></View><Pressable onPress={() => Keyboard.dismiss()}><Text style={{ color: colors.primary, fontSize: 11, fontWeight: "800" }}>HIDE KEYS</Text></Pressable></View>
        <View style={styles.shortcutGrid}>
          <Pressable onPress={() => void copyOutput()} style={({ pressed }) => [styles.shelfAction, { borderColor: colors.border, opacity: pressed ? 0.65 : 1 }]}><Text style={[styles.shelfActionText, { color: colors.foreground }]}>COPY OUTPUT</Text></Pressable>
          <Pressable onPress={() => void pasteIntoCommand()} style={({ pressed }) => [styles.shelfAction, { borderColor: colors.border, opacity: pressed ? 0.65 : 1 }]}><Text style={[styles.shelfActionText, { color: colors.foreground }]}>PASTE INPUT</Text></Pressable>
          <Pressable onPress={() => setLines([])} style={({ pressed }) => [styles.shelfAction, { borderColor: colors.border, opacity: pressed ? 0.65 : 1 }]}><Text style={[styles.shelfActionText, { color: colors.muted }]}>CLEAR VIEW</Text></Pressable>
        </View>
        <View style={styles.keyRow}>{[["ESC", "\u001b"], ["CTRL+C", "\u0003"], ["TAB", "\t"], ["↑", "\u001b[A"], ["↓", "\u001b[B"]].map(([label, data]) => <Pressable key={label} onPress={() => sendShortcut(label, data)} style={({ pressed }) => [styles.key, { backgroundColor: colors.background, borderColor: colors.border, opacity: pressed ? 0.6 : 1 }]}><Text style={{ color: colors.primary, fontSize: 10, fontWeight: "900" }}>{label}</Text></Pressable>)}</View>
        <Text style={[styles.snippetLabel, { color: colors.muted }]}>QUICK RUNS</Text><View style={styles.snippetRow}>{snippets.map((snippet) => <Pressable key={snippet.label} onPress={() => run(snippet.command)} style={({ pressed }) => [styles.snippet, { backgroundColor: `${colors.primary}14`, opacity: pressed ? 0.65 : 1 }]}><Text style={{ color: colors.primary, fontSize: 10, fontWeight: "800" }}>{snippet.label}</Text></Pressable>)}</View>
      </View>
    </ScrollView>
  </ScreenContainer>;
}

const styles = StyleSheet.create({
  content: { paddingTop: 12, paddingBottom: 32, gap: 12 },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 6 },
  kicker: { fontSize: 10, fontWeight: "900", letterSpacing: 1.4 }, title: { fontSize: 30, fontWeight: "900", marginTop: 6 },
  connection: { borderRadius: 18, paddingHorizontal: 11, paddingVertical: 8, flexDirection: "row", gap: 7, alignItems: "center" }, dot: { width: 7, height: 7, borderRadius: 4 },
  sessionRibbon: { borderRadius: 18, borderWidth: 1, padding: 13, flexDirection: "row", alignItems: "center", gap: 10 }, sessionIcon: { width: 38, height: 38, borderRadius: 12, alignItems: "center", justifyContent: "center" }, flex: { flex: 1 }, sessionName: { fontSize: 14, fontWeight: "900" }, sub: { fontSize: 10, marginTop: 4, lineHeight: 14 }, credentialButton: { height: 32, paddingHorizontal: 10, justifyContent: "center", borderWidth: 1, borderRadius: 10 },
  stageRow: { flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 4 }, stageMini: { alignItems: "center", gap: 5 }, stageIcon: { width: 23, height: 23, borderRadius: 12, borderWidth: 1, alignItems: "center", justifyContent: "center" }, stageLabel: { fontSize: 8, fontWeight: "800" },
  authBox: { borderRadius: 16, borderWidth: 1, padding: 12, gap: 8 }, input: { minHeight: 42, borderWidth: 1, borderRadius: 11, paddingHorizontal: 12, paddingVertical: 10, fontSize: 12 },
  terminal: { borderRadius: 18, borderWidth: 1, overflow: "hidden", minHeight: 294 }, terminalBar: { padding: 12, borderBottomWidth: 1, borderBottomColor: "#252D37", flexDirection: "row", justifyContent: "space-between" }, output: { padding: 14, gap: 7, minHeight: 220 }, line: { fontSize: 11, fontFamily: "monospace", lineHeight: 16 }, commandRow: { borderTopWidth: 1, minHeight: 48, paddingHorizontal: 13, flexDirection: "row", alignItems: "center", gap: 8 }, commandInput: { flex: 1, fontFamily: "monospace", fontSize: 12 },
  commandShelf: { borderRadius: 18, borderWidth: 1, padding: 13, gap: 11 }, shelfHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start" }, shelfTitle: { fontSize: 14, fontWeight: "900" }, shortcutGrid: { flexDirection: "row", gap: 7 }, shelfAction: { flex: 1, height: 34, borderWidth: 1, borderRadius: 10, justifyContent: "center", alignItems: "center" }, shelfActionText: { fontSize: 9, fontWeight: "900", textAlign: "center" }, keyRow: { flexDirection: "row", gap: 6 }, key: { flex: 1, height: 34, borderRadius: 10, borderWidth: 1, justifyContent: "center", alignItems: "center" }, snippetLabel: { fontSize: 9, fontWeight: "900", letterSpacing: 1.1, marginTop: 2 }, snippetRow: { flexDirection: "row", gap: 7 }, snippet: { flex: 1, minHeight: 34, borderRadius: 10, alignItems: "center", justifyContent: "center", paddingHorizontal: 5 },
});
