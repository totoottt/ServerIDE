import { useMemo, useState } from "react";
import { Alert, Modal, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from "react-native";
import { router } from "expo-router";
import * as Clipboard from "expo-clipboard";
import { ScreenContainer } from "@/components/screen-container";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { useColors } from "@/hooks/use-colors";
import { useServerStore, type ServerAuthMethod, type ServerColor, type ServerProfile, type ServerRole } from "@/lib/server-store";
import { validateServerDraft } from "@/lib/server-profile";
import { readServerSecret, saveServerSecret, deleteServerSecret } from "@/lib/server-secrets";

type MenuAction = { label: string; icon: string; onPress: () => void; danger?: boolean };

const colorsByName: Record<ServerColor, string> = { blue: "#4DA3FF", purple: "#A78BFA", green: "#35D07F", orange: "#FFB547", red: "#FF5C70" };
const authLabels: Record<ServerAuthMethod, string> = { "ssh-key": "SSH key", password: "Password", agent: "SSH agent" };
const roleLabels: Record<ServerRole, string> = { ssh: "SSH", sftp: "SFTP" };
const KNOCK_HINT = "Format: port:tcp or port:udp, comma-separated (e.g. 2222:udp,3333:tcp)";
const KNOCK_PATTERN = /^(\d{1,5}:(tcp|udp))(,\d{1,5}:(tcp|udp))*$/i;

export default function ServersScreen() {
  const colors = useColors();
  const { servers, activeServerId, activeServer, addServer, updateServer, removeServer, selectServer } = useServerStore();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [host, setHost] = useState("");
  const [port, setPort] = useState("22");
  const [username, setUsername] = useState("");
  const [authMethod, setAuthMethod] = useState<ServerAuthMethod>("ssh-key");
  const [color, setColor] = useState<ServerColor>("blue");
  const [group, setGroup] = useState("Personal");
  const [showForm, setShowForm] = useState(false);
  const [password, setPassword] = useState("");
  const [privateKey, setPrivateKey] = useState("");
  const [passphrase, setPassphrase] = useState("");
  const [menuServer, setMenuServer] = useState<ServerProfile | null>(null);
  const [query, setQuery] = useState("");
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(new Set());

  // Extended profile fields
  const [roles, setRoles] = useState<ServerRole[]>(["ssh", "sftp"]);
  const [tags, setTags] = useState("");
  const [terminalFontSize, setTerminalFontSize] = useState("12");
  const [portKnockSequence, setPortKnockSequence] = useState("");
  const [forceKeyboardInteractive, setForceKeyboardInteractive] = useState(false);
  const [jumpEnabled, setJumpEnabled] = useState(false);
  const [jumpHost, setJumpHost] = useState("");
  const [jumpPort, setJumpPort] = useState("22");
  const [jumpUsername, setJumpUsername] = useState("");
  const [jumpPassword, setJumpPassword] = useState("");
  const [jumpPrivateKey, setJumpPrivateKey] = useState("");
  const [jumpPassphrase, setJumpPassphrase] = useState("");
  const [showAdvanced, setShowAdvanced] = useState(false);

  const filteredServers = useMemo(() => { const needle = query.trim().toLowerCase(); return needle ? servers.filter((server) => [server.name, server.host, ...server.tags].some((value) => value.toLowerCase().includes(needle))) : servers; }, [servers, query]);
  const groups = useMemo(() => Array.from(new Set(filteredServers.map((server) => server.group))), [filteredServers]);
  const reset = () => {
    setEditingId(null); setName(""); setHost(""); setPort("22"); setUsername(""); setAuthMethod("ssh-key"); setColor("blue"); setGroup("Personal");
    setPassword(""); setPrivateKey(""); setPassphrase("");
    setRoles(["ssh", "sftp"]); setTags(""); setTerminalFontSize("12"); setPortKnockSequence(""); setForceKeyboardInteractive(false);
    setJumpEnabled(false); setJumpHost(""); setJumpPort("22"); setJumpUsername(""); setJumpPassword(""); setJumpPrivateKey(""); setJumpPassphrase("");
    setShowAdvanced(false);
  };
  const openEdit = async (server: ServerProfile) => {
    const secret = await readServerSecret(server.id);
    setEditingId(server.id); setName(server.name); setHost(server.host); setPort(String(server.port)); setUsername(server.username);
    setAuthMethod(server.authMethod); setColor(server.color); setGroup(server.group);
    setPassword(secret?.password ?? ""); setPrivateKey(secret?.privateKey ?? ""); setPassphrase(secret?.passphrase ?? "");
    setRoles(server.roles?.length ? server.roles : ["ssh", "sftp"]);
    setTags((server.tags ?? []).join(", "));
    setTerminalFontSize(String(server.terminalFontSize ?? 12));
    setPortKnockSequence(server.portKnockSequence ?? "");
    setForceKeyboardInteractive(server.forceKeyboardInteractive ?? false);
    setJumpEnabled(server.jumpHost?.enabled ?? false);
    setJumpHost(server.jumpHost?.host ?? "");
    setJumpPort(String(server.jumpHost?.port ?? 22));
    setJumpUsername(server.jumpHost?.username ?? "");
    setJumpPassword(secret?.jumpHostPassword ?? "");
    setJumpPrivateKey(secret?.jumpHostPrivateKey ?? "");
    setJumpPassphrase(secret?.jumpHostPassphrase ?? "");
    setShowAdvanced(false);
    setShowForm(true);
  };
  const toggleRole = (role: ServerRole) => setRoles((current) => current.includes(role) ? (current.length > 1 ? current.filter((item) => item !== role) : current) : [...current, role]);
  const save = async () => {
    const validationError = validateServerDraft({ name, host, port: Number(port), username });
    if (validationError) { Alert.alert("Check server details", validationError); return; }
    if (portKnockSequence.trim() && !KNOCK_PATTERN.test(portKnockSequence.trim())) { Alert.alert("Check port knocking sequence", KNOCK_HINT); return; }
    if (jumpEnabled && (!jumpHost.trim() || !jumpUsername.trim())) { Alert.alert("Check jump host", "Enter a jump host and username, or turn the jump host off."); return; }
    const payload = {
      name: name.trim(), host: host.trim(), port: Number(port) || 22, username: username.trim(), authMethod, color, group: group.trim() || "Personal", favorite: false, notes: "",
      roles, tags: tags.split(",").map((tag) => tag.trim()).filter(Boolean),
      terminalFontSize: Number(terminalFontSize) || 12,
      portKnockSequence: portKnockSequence.trim(),
      forceKeyboardInteractive,
      jumpHost: jumpEnabled ? { enabled: true, host: jumpHost.trim(), port: Number(jumpPort) || 22, username: jumpUsername.trim() } : null,
    };
    const saved = editingId ? (await updateServer(editingId, payload), { id: editingId }) : await addServer(payload);
    const hasSecret = password || privateKey || passphrase || (jumpEnabled && (jumpPassword || jumpPrivateKey));
    if (hasSecret) await saveServerSecret(saved.id, {
      password: password || undefined, privateKey: privateKey || undefined, passphrase: passphrase || undefined,
      jumpHostPassword: jumpEnabled ? (jumpPassword || undefined) : undefined,
      jumpHostPrivateKey: jumpEnabled ? (jumpPrivateKey || undefined) : undefined,
      jumpHostPassphrase: jumpEnabled ? (jumpPassphrase || undefined) : undefined,
    });
    else await deleteServerSecret(saved.id);
    setShowForm(false); reset();
  };
  const deleteServer = (id: string) => Alert.alert("Remove server?", "The local profile will be deleted from this device.", [{ text: "Cancel", style: "cancel" }, { text: "Remove", style: "destructive", onPress: () => void removeServer(id) }]);

  const cloneServer = async (server: ServerProfile) => {
    const secret = await readServerSecret(server.id);
    const clone = await addServer({ name: `${server.name} copy`, host: server.host, port: server.port, username: server.username, authMethod: server.authMethod, color: server.color, group: server.group, favorite: false, notes: server.notes, roles: server.roles, tags: server.tags, terminalFontSize: server.terminalFontSize, portKnockSequence: server.portKnockSequence, forceKeyboardInteractive: server.forceKeyboardInteractive, jumpHost: server.jumpHost });
    if (secret) await saveServerSecret(clone.id, secret);
  };
  const copyConnectionString = async (server: ServerProfile) => { await Clipboard.setStringAsync(`ssh://${server.username}@${server.host}:${server.port}`); Alert.alert("Copied", "Connection string copied to clipboard."); };
  const openSSH = (server: ServerProfile) => { void selectServer(server.id); router.push("/(tabs)/ssh"); };
  const openSFTP = (server: ServerProfile) => { void selectServer(server.id); router.push("/(tabs)/files"); };

  const menuActions: MenuAction[] = menuServer ? [
    ...(menuServer.roles?.includes("ssh") ?? true ? [{ label: "SSH", icon: "chevron.left.forwardslash.chevron.right", onPress: () => openSSH(menuServer) }] : []),
    ...(menuServer.roles?.includes("sftp") ?? true ? [{ label: "SFTP", icon: "folder.fill", onPress: () => openSFTP(menuServer) }] : []),
    { label: "Edit", icon: "gearshape.fill", onPress: () => void openEdit(menuServer) },
    { label: "Clone", icon: "paperplane.fill", onPress: () => void cloneServer(menuServer) },
    { label: menuServer.favorite ? "Unfavorite" : "Favorite", icon: "checkmark.shield.fill", onPress: () => void updateServer(menuServer.id, { favorite: !menuServer.favorite }) },
    { label: "Copy connection", icon: "paperplane.fill", onPress: () => void copyConnectionString(menuServer) },
    { label: "Delete", icon: "chevron.right", onPress: () => deleteServer(menuServer.id), danger: true },
  ] : [];

  return <ScreenContainer className="px-5" containerClassName="bg-background"><ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
    <View style={styles.header}><View><Text style={[styles.kicker, { color: colors.muted }]}>SERVER IDE / SERVERS</Text><Text style={[styles.title, { color: colors.foreground }]}>Your servers</Text><Text style={[styles.subtitle, { color: colors.muted }]}>Profiles are stored on this device.</Text></View><Pressable onPress={() => { reset(); setShowForm(true); }} style={({ pressed }) => [styles.add, { backgroundColor: colors.primary, opacity: pressed ? 0.72 : 1 }]}><Text style={[styles.plus, { color: colors.background }]}>+</Text></Pressable></View>
    <View style={[styles.activeCard, { backgroundColor: colors.surface, borderColor: colors.border }]}><View style={[styles.serverIcon, { backgroundColor: activeServer ? `${colorsByName[activeServer.color]}22` : `${colors.primary}22` }]}><IconSymbol name="paperplane.fill" size={20} color={activeServer ? colorsByName[activeServer.color] : colors.primary} /></View><View style={styles.flex}><Text style={[styles.cardLabel, { color: colors.muted }]}>SELECTED PROFILE</Text><Text style={[styles.activeName, { color: colors.foreground }]}>{activeServer?.name ?? "No server selected"}</Text><Text style={[styles.sub, { color: colors.muted }]}>{activeServer ? `${activeServer.username}@${activeServer.host}:${activeServer.port}` : "Add a server to begin"}</Text></View><View style={[styles.dot, { backgroundColor: colors.error }]} /></View>
    <View style={styles.sectionRow}><Text style={[styles.section, { color: colors.foreground }]}>All servers</Text><Text style={[styles.count, { color: colors.muted }]}>{servers.length} profiles</Text></View><TextInput value={query} onChangeText={setQuery} placeholder="Search name, host, or tag" placeholderTextColor={colors.muted} style={[styles.search, { color: colors.foreground, backgroundColor: colors.surface, borderColor: colors.border }]} />
    {servers.length === 0 ? <View style={[styles.empty, { backgroundColor: colors.surface, borderColor: colors.border }]}><IconSymbol name="folder.fill" size={26} color={colors.muted} /><Text style={[styles.emptyTitle, { color: colors.foreground }]}>No server profiles yet</Text><Text style={[styles.emptyText, { color: colors.muted }]}>Add a host, port and username. Credentials stay outside this profile and will be handled by the secure connection layer.</Text><Pressable onPress={() => { reset(); setShowForm(true); }} style={[styles.emptyButton, { backgroundColor: colors.primary }]}><Text style={{ color: colors.background, fontWeight: "800" }}>Add first server</Text></Pressable></View> : groups.map((groupName) => <View key={groupName}><Pressable onPress={() => setCollapsedGroups((current) => { const next = new Set(current); if (next.has(groupName)) next.delete(groupName); else next.add(groupName); return next; })} style={styles.groupHeader}><Text style={[styles.group, { color: colors.muted }]}>{groupName.toUpperCase()}</Text><Text style={{ color: colors.muted }}>{collapsedGroups.has(groupName) ? "＋" : "－"}</Text></Pressable>{!collapsedGroups.has(groupName) && filteredServers.filter((server) => server.group === groupName).map((server) => <Pressable key={server.id} onPress={() => void selectServer(server.id)} onLongPress={() => setMenuServer(server)} delayLongPress={280} style={({ pressed }) => [styles.row, { backgroundColor: colors.surface, borderColor: server.id === activeServerId ? colors.primary : colors.border, opacity: pressed ? 0.78 : 1 }]}><View style={[styles.serverIcon, { backgroundColor: `${colorsByName[server.color]}22` }]}><IconSymbol name="paperplane.fill" size={18} color={colorsByName[server.color]} /></View><View style={styles.flex}><View style={styles.nameLine}><Text style={[styles.serverName, { color: colors.foreground }]}>{server.name}</Text>{server.id === activeServerId && <View style={[styles.activePill, { backgroundColor: `${colors.primary}22` }]}><Text style={{ color: colors.primary, fontSize: 9, fontWeight: "800" }}>SELECTED</Text></View>}</View><Text style={[styles.sub, { color: colors.muted }]}>{server.username}@{server.host}:{server.port}</Text><Text style={[styles.auth, { color: colors.primary }]}>{authLabels[server.authMethod]}</Text></View><Pressable onPress={() => openEdit(server)} hitSlop={8}><Text style={{ color: colors.primary, fontWeight: "800" }}>EDIT</Text></Pressable><Pressable onPress={() => deleteServer(server.id)} hitSlop={8}><Text style={{ color: colors.error, fontWeight: "800" }}>×</Text></Pressable></Pressable>)}</View>)}
    <Text style={[styles.note, { color: colors.muted }]}>Connection credentials are encrypted in the device Keychain/Keystore and are never included in the normal server profile.</Text>
    <Modal visible={!!menuServer} transparent animationType="fade" onRequestClose={() => setMenuServer(null)}>
      <Pressable style={styles.menuBackdrop} onPress={() => setMenuServer(null)}>
        <Pressable style={[styles.menuCard, { backgroundColor: colors.surface, borderColor: colors.border }]} onPress={() => {}}>
          <Text style={[styles.menuTitle, { color: colors.foreground }]}>{menuServer?.name}</Text>
          <Text style={[styles.menuSubtitle, { color: colors.muted }]}>{menuServer ? `${menuServer.username}@${menuServer.host}` : ""}</Text>
          {menuActions.map((item, index) => <Pressable key={item.label} onPress={() => { setMenuServer(null); item.onPress(); }} style={({ pressed }) => [styles.menuRow, index < menuActions.length - 1 && { borderBottomWidth: 1, borderBottomColor: colors.border }, pressed && { opacity: 0.6 }]}>
            <IconSymbol name={item.icon as any} size={17} color={item.danger ? colors.error : colors.primary} />
            <Text style={{ color: item.danger ? colors.error : colors.foreground, fontSize: 14, fontWeight: "700" }}>{item.label}</Text>
          </Pressable>)}
        </Pressable>
      </Pressable>
    </Modal>
    {showForm && <View style={[styles.form, { backgroundColor: colors.surface, borderColor: colors.primary }]}><View style={styles.formHeader}><Text style={[styles.formTitle, { color: colors.foreground }]}>{editingId ? "Edit server" : "Add server"}</Text><Pressable onPress={() => { setShowForm(false); reset(); }}><Text style={{ color: colors.muted, fontWeight: "800" }}>CLOSE</Text></Pressable></View>{([["Name", name, setName, "My production server"], ["Host / IP", host, setHost, "server.example.com"], ["Username", username, setUsername, "deploy"]] as const).map(([label, value, setter, placeholder]) => <View key={label} style={styles.field}><Text style={[styles.fieldLabel, { color: colors.muted }]}>{label}</Text><TextInput value={value} onChangeText={setter} placeholder={placeholder} placeholderTextColor={colors.muted} autoCapitalize="none" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View>)}<View style={styles.inline}><View style={styles.half}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Port</Text><TextInput value={port} onChangeText={setPort} keyboardType="number-pad" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View><View style={styles.half}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Group</Text><TextInput value={group} onChangeText={setGroup} placeholder="Personal" placeholderTextColor={colors.muted} style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View></View><Text style={[styles.fieldLabel, { color: colors.muted }]}>SSH / SFTP credentials</Text><TextInput value={authMethod === "ssh-key" ? privateKey : password} onChangeText={authMethod === "ssh-key" ? setPrivateKey : setPassword} secureTextEntry={authMethod !== "ssh-key"} multiline={authMethod === "ssh-key"} placeholder={authMethod === "ssh-key" ? "Private key" : "Password"} placeholderTextColor={colors.muted} style={[styles.input, { color: colors.foreground, borderColor: colors.border, marginBottom: 10 }]} /><TextInput value={passphrase} onChangeText={setPassphrase} secureTextEntry placeholder="Private key passphrase (optional)" placeholderTextColor={colors.muted} style={[styles.input, { color: colors.foreground, borderColor: colors.border, marginBottom: 10 }]} /><Text style={[styles.hint, { color: colors.muted, marginBottom: 10 }]}>Password-first connection; host fingerprint screens are not required.</Text><Text style={[styles.fieldLabel, { color: colors.muted, marginTop: 14 }]}>Authentication</Text><View style={styles.chips}>{(Object.keys(authLabels) as ServerAuthMethod[]).map((method) => <Pressable key={method} onPress={() => setAuthMethod(method)} style={[styles.chip, { backgroundColor: authMethod === method ? `${colors.primary}22` : colors.background, borderColor: authMethod === method ? colors.primary : colors.border }]}><Text style={{ color: authMethod === method ? colors.primary : colors.muted, fontSize: 11, fontWeight: "800" }}>{authLabels[method]}</Text></Pressable>)}</View><Text style={[styles.fieldLabel, { color: colors.muted }]}>Accent</Text><View style={styles.chips}>{(Object.keys(colorsByName) as ServerColor[]).map((item) => <Pressable key={item} onPress={() => setColor(item)} style={[styles.colorChip, { backgroundColor: colorsByName[item], borderColor: color === item ? colors.foreground : "transparent" }]} />)}</View>

<Text style={[styles.fieldLabel, { color: colors.muted, marginTop: 4 }]}>Roles</Text><View style={styles.chips}>{(Object.keys(roleLabels) as ServerRole[]).map((role) => <Pressable key={role} onPress={() => toggleRole(role)} style={[styles.chip, { backgroundColor: roles.includes(role) ? `${colors.primary}22` : colors.background, borderColor: roles.includes(role) ? colors.primary : colors.border }]}><Text style={{ color: roles.includes(role) ? colors.primary : colors.muted, fontSize: 11, fontWeight: "800" }}>{roleLabels[role]}</Text></Pressable>)}</View>

<View style={styles.field}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Tags</Text><TextInput value={tags} onChangeText={setTags} placeholder="production, db, eu-west (comma separated)" placeholderTextColor={colors.muted} autoCapitalize="none" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View>

<Pressable onPress={() => setShowAdvanced((value) => !value)} style={({ pressed }) => [styles.advancedToggle, { borderColor: colors.border, opacity: pressed ? 0.7 : 1 }]}>
  <Text style={{ color: colors.primary, fontSize: 11, fontWeight: "800" }}>{showAdvanced ? "HIDE ADVANCED SETTINGS" : "TERMINAL, PORT KNOCKING, 2FA & JUMP HOST"}</Text>
  <IconSymbol name={showAdvanced ? "chevron.right" : "chevron.right"} size={14} color={colors.primary} />
</Pressable>

{showAdvanced && <View style={styles.advancedBox}>
  <Text style={[styles.fieldLabel, { color: colors.muted }]}>Terminal Settings</Text>
  <View style={styles.inline}><View style={styles.half}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Font size</Text><TextInput value={terminalFontSize} onChangeText={setTerminalFontSize} keyboardType="number-pad" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View></View>

  <View style={styles.field}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Port Knocking</Text><TextInput value={portKnockSequence} onChangeText={setPortKnockSequence} placeholder="2222:udp,3333:tcp" placeholderTextColor={colors.muted} autoCapitalize="none" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /><Text style={[styles.hint, { color: colors.muted }]}>{KNOCK_HINT}. Sent right before every connection attempt, in order.</Text></View>

  <View style={styles.switchRow}><Text style={[styles.fieldLabel, { color: colors.muted, marginBottom: 0 }]}>Force Keyboard Interactive (2FA)</Text><Switch value={forceKeyboardInteractive} onValueChange={setForceKeyboardInteractive} trackColor={{ true: colors.primary, false: colors.border }} /></View>
  {forceKeyboardInteractive && <Text style={[styles.hint, { color: colors.muted }]}>OTP/2FA will be requested each time you connect.</Text>}

  <View style={styles.switchRow}><Text style={[styles.fieldLabel, { color: colors.muted, marginBottom: 0 }]}>Jump Host</Text><Switch value={jumpEnabled} onValueChange={setJumpEnabled} trackColor={{ true: colors.primary, false: colors.border }} /></View>
  {jumpEnabled && <View>
    <View style={styles.inline}><View style={[styles.half, { flex: 2 }]}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Jump host</Text><TextInput value={jumpHost} onChangeText={setJumpHost} placeholder="bastion.example.com" placeholderTextColor={colors.muted} autoCapitalize="none" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View><View style={styles.half}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Port</Text><TextInput value={jumpPort} onChangeText={setJumpPort} keyboardType="number-pad" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View></View>
    <View style={styles.field}><Text style={[styles.fieldLabel, { color: colors.muted }]}>Jump user</Text><TextInput value={jumpUsername} onChangeText={setJumpUsername} placeholder="bastion-user" placeholderTextColor={colors.muted} autoCapitalize="none" style={[styles.input, { color: colors.foreground, borderColor: colors.border }]} /></View>
    <TextInput value={authMethod === "ssh-key" ? jumpPrivateKey : jumpPassword} onChangeText={authMethod === "ssh-key" ? setJumpPrivateKey : setJumpPassword} secureTextEntry={authMethod !== "ssh-key"} multiline={authMethod === "ssh-key"} placeholder={authMethod === "ssh-key" ? "Jump host private key" : "Jump host password"} placeholderTextColor={colors.muted} style={[styles.input, { color: colors.foreground, borderColor: colors.border, marginBottom: 10 }]} />
    <Text style={[styles.hint, { color: colors.muted }]}>Traffic tunnels through this host to reach the server above — useful when the real server has no public IP.</Text>
  </View>}
</View>}

<Pressable onPress={() => void save()} style={({ pressed }) => [styles.save, { backgroundColor: colors.primary, opacity: pressed ? 0.72 : 1 }]}><Text style={{ color: colors.background, fontWeight: "800" }}>{editingId ? "Save changes" : "Save server"}</Text></Pressable></View>}
  </ScrollView></ScreenContainer>;
}

const styles = StyleSheet.create({ content: { paddingTop: 12, paddingBottom: 40 }, search: { minHeight: 44, borderRadius: 13, borderWidth: 1, paddingHorizontal: 14, marginBottom: 8, fontSize: 13 }, groupHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" }, header: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 22 }, kicker: { fontSize: 11, fontWeight: "800", letterSpacing: 1.3 }, title: { fontSize: 30, fontWeight: "800", marginTop: 6 }, subtitle: { fontSize: 12, marginTop: 5 }, add: { width: 48, height: 48, borderRadius: 16, alignItems: "center", justifyContent: "center" }, plus: { fontSize: 30, fontWeight: "400", lineHeight: 32 }, activeCard: { borderRadius: 20, borderWidth: 1, padding: 16, flexDirection: "row", alignItems: "center", gap: 12, marginBottom: 22 }, serverIcon: { width: 44, height: 44, borderRadius: 14, alignItems: "center", justifyContent: "center" }, flex: { flex: 1 }, cardLabel: { fontSize: 10, fontWeight: "800", letterSpacing: 1.2 }, activeName: { fontSize: 18, fontWeight: "800", marginTop: 3 }, sub: { fontSize: 11, marginTop: 4 }, dot: { width: 9, height: 9, borderRadius: 5 }, sectionRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }, section: { fontSize: 18, fontWeight: "800" }, count: { fontSize: 11 }, group: { fontSize: 10, letterSpacing: 1.2, fontWeight: "800", marginTop: 10, marginBottom: 8 }, row: { borderRadius: 17, borderWidth: 1, padding: 13, flexDirection: "row", alignItems: "center", gap: 10, marginBottom: 8 }, nameLine: { flexDirection: "row", alignItems: "center", gap: 8 }, serverName: { fontSize: 15, fontWeight: "800" }, auth: { fontSize: 10, marginTop: 6, fontWeight: "700" }, activePill: { paddingHorizontal: 6, paddingVertical: 3, borderRadius: 6 }, empty: { borderRadius: 20, borderWidth: 1, padding: 24, alignItems: "center" }, emptyTitle: { fontSize: 16, fontWeight: "800", marginTop: 12 }, emptyText: { fontSize: 12, lineHeight: 18, textAlign: "center", marginTop: 8 }, emptyButton: { borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12, marginTop: 18 }, note: { fontSize: 10, lineHeight: 15, marginTop: 18, textAlign: "center" }, form: { borderRadius: 20, borderWidth: 1, padding: 16, marginTop: 22 }, formHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 18 }, formTitle: { fontSize: 18, fontWeight: "800" }, field: { marginBottom: 13 }, fieldLabel: { fontSize: 10, fontWeight: "800", letterSpacing: 0.9, marginBottom: 6 }, input: { borderWidth: 1, borderRadius: 12, paddingHorizontal: 12, paddingVertical: 11, fontSize: 13 }, inline: { flexDirection: "row", gap: 10 }, half: { flex: 1, marginBottom: 13 }, chips: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginBottom: 16 }, chip: { borderWidth: 1, borderRadius: 10, paddingHorizontal: 10, paddingVertical: 8 }, colorChip: { width: 28, height: 28, borderRadius: 14, borderWidth: 2 }, save: { alignItems: "center", borderRadius: 13, paddingVertical: 13, marginTop: 2 }, verifyButton: { alignItems: "center", borderWidth: 1, borderRadius: 10, paddingVertical: 10, marginBottom: 14 }, advancedToggle: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", borderWidth: 1, borderRadius: 12, paddingHorizontal: 12, paddingVertical: 12, marginTop: 4, marginBottom: 4 }, advancedBox: { gap: 4, marginTop: 10, marginBottom: 6 }, hint: { fontSize: 10, lineHeight: 14, marginTop: -6, marginBottom: 10 }, switchRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: 10, marginBottom: 6 }, menuBackdrop: { flex: 1, backgroundColor: "#00000099", alignItems: "center", justifyContent: "center", padding: 24 }, menuCard: { width: "100%", maxWidth: 320, borderRadius: 18, borderWidth: 1, paddingVertical: 8, paddingHorizontal: 4 }, menuTitle: { fontSize: 15, fontWeight: "800", paddingHorizontal: 16, paddingTop: 10 }, menuSubtitle: { fontSize: 11, paddingHorizontal: 16, paddingBottom: 8 }, menuRow: { flexDirection: "row", alignItems: "center", gap: 12, paddingHorizontal: 16, paddingVertical: 13 } });
