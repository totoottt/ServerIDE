import { useMemo, useState } from "react";
import { Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { ScreenContainer } from "@/components/screen-container";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { useColors } from "@/hooks/use-colors";

const metrics = [
  { label: "CPU Usage", value: "18.4%", detail: "4 cores · stable", color: "#4DA3FF", icon: "chevron.left.forwardslash.chevron.right" as const },
  { label: "Memory", value: "3.2 / 8 GB", detail: "40% allocated", color: "#B58CFF", icon: "paperplane.fill" as const },
  { label: "Storage", value: "128 GB", detail: "62% used", color: "#46D8E7", icon: "paperplane.fill" as const },
];

const activity = [
  { title: "SSH session ready", detail: "memo · 2 minutes ago", tone: "success", icon: "chevron.left.forwardslash.chevron.right" as const },
  { title: "Network scan completed", detail: "eth0 · 5 minutes ago", tone: "info", icon: "paperplane.fill" as const },
  { title: "Backup needs attention", detail: "daily snapshot · warning", tone: "paperplane.fill", icon: "paperplane.fill" as const },
];

export default function HomeScreen() {
  const colors = useColors("dark");
  const [online, setOnline] = useState(true);
  const [toast, setToast] = useState("Ready for a server");
  const [showServerSheet, setShowServerSheet] = useState(false);
  const [server, setServer] = useState({ name: "Demo server", host: "server.example.com", port: "22", username: "developer" });
  const [draft, setDraft] = useState(server);
  const palette = useMemo(() => ({ success: "#35D07F", info: "#4DA3FF", warning: "#FFB547" }), []);

  const action = (message: string) => {
    setToast(message);
    setTimeout(() => setToast(server.name === "Demo server" ? "Ready for a server" : `${server.name} is ready`), 2200);
  };

  return (
    <ScreenContainer className="px-5" containerClassName="bg-background">
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <View>
            <Text style={[styles.eyebrow, { color: colors.muted }]}>SERVER IDE / OVERVIEW</Text>
            <Text style={[styles.title, { color: colors.foreground }]}>Good morning.</Text>
          </View>
          <Pressable onPress={() => setOnline(!online)} style={({ pressed }) => [styles.statusButton, { borderColor: online ? "#35D07F55" : "#FF5C7055", opacity: pressed ? 0.7 : 1 }]}>
            <View style={[styles.dot, { backgroundColor: online ? "#35D07F" : "#FF5C70" }]} />
            <Text style={[styles.statusText, { color: online ? "#35D07F" : "#FF5C70" }]}>{online ? "ONLINE" : "OFFLINE"}</Text>
          </Pressable>
        </View>

        <Pressable onPress={() => { setDraft(server); setShowServerSheet(true); }} style={({ pressed }) => [styles.serverCard, { backgroundColor: colors.surface, borderColor: colors.border, opacity: pressed ? 0.72 : 1 }]}>
          <View style={styles.serverTop}>
            <View style={[styles.serverIcon, { backgroundColor: "#4DA3FF18" }]}><IconSymbol name="paperplane.fill" size={22} color="#4DA3FF" /></View>
            <View style={styles.flex}><Text style={[styles.cardLabel, { color: colors.muted }]}>ACTIVE SERVER</Text><Text style={[styles.serverName, { color: colors.foreground }]}>{server.name}</Text><Text style={[styles.serverMeta, { color: colors.muted }]}>{server.username}@{server.host}:{server.port}</Text></View>
            <IconSymbol name="chevron.right" size={20} color={colors.muted} />
          </View>
          <View style={[styles.divider, { backgroundColor: colors.border }]} />
          <View style={styles.serverStats}><View><Text style={[styles.statValue, { color: colors.foreground }]}>42 ms</Text><Text style={[styles.statCaption, { color: colors.muted }]}>LATENCY</Text></View><View><Text style={[styles.statValue, { color: "#35D07F" }]}>Ready</Text><Text style={[styles.statCaption, { color: colors.muted }]}>STATUS</Text></View><View><Text style={[styles.statValue, { color: colors.foreground }]}>2m ago</Text><Text style={[styles.statCaption, { color: colors.muted }]}>UPDATED</Text></View></View>
        </Pressable>

        <View style={styles.sectionHeader}><Text style={[styles.sectionTitle, { color: colors.foreground }]}>System health</Text><Text style={[styles.sectionLink, { color: colors.primary }]} onPress={() => action("Metrics refreshed")}>Refresh</Text></View>
        <View style={styles.metricGrid}>{metrics.map((metric) => <Pressable key={metric.label} onPress={() => action(`${metric.label} details opened`)} style={({ pressed }) => [styles.metricCard, { backgroundColor: colors.surface, borderColor: colors.border, opacity: pressed ? 0.72 : 1 }]}><View style={[styles.metricIcon, { backgroundColor: `${metric.color}18` }]}><IconSymbol name={metric.icon} size={18} color={metric.color} /></View><Text style={[styles.metricLabel, { color: colors.muted }]}>{metric.label}</Text><Text style={[styles.metricValue, { color: colors.foreground }]}>{metric.value}</Text><Text style={[styles.metricDetail, { color: metric.color }]}>{metric.detail}</Text></Pressable>)}</View>

        <View style={styles.sectionHeader}><Text style={[styles.sectionTitle, { color: colors.foreground }]}>Quick actions</Text></View>
        <View style={styles.actionRow}><Pressable onPress={() => action("Opening terminal...")} style={({ pressed }) => [styles.action, { backgroundColor: "#4DA3FF", opacity: pressed ? 0.8 : 1 }]}><IconSymbol name="chevron.left.forwardslash.chevron.right" size={19} color="#07111B" /><Text style={styles.actionText}>Open SSH</Text></Pressable><Pressable onPress={() => action("Network scan started")} style={({ pressed }) => [styles.action, { backgroundColor: colors.surface, borderColor: colors.border, opacity: pressed ? 0.7 : 1 }]}><IconSymbol name="paperplane.fill" size={19} color="#46D8E7" /><Text style={[styles.actionText, { color: colors.foreground }]}>Run scan</Text></Pressable></View>

        <View style={styles.sectionHeader}><Text style={[styles.sectionTitle, { color: colors.foreground }]}>Recent activity</Text><Text style={[styles.sectionLink, { color: colors.primary }]} onPress={() => action("Activity marked as read")}>View all</Text></View>
        <View style={[styles.activityCard, { backgroundColor: colors.surface, borderColor: colors.border }]}>{activity.map((item, index) => <Pressable key={item.title} onPress={() => action(item.title)} style={({ pressed }) => [styles.activityRow, index < activity.length - 1 && { borderBottomWidth: 1, borderBottomColor: colors.border }, pressed && { opacity: 0.65 }]}><View style={[styles.activityIcon, { backgroundColor: `${palette[item.tone as keyof typeof palette]}18` }]}><IconSymbol name={item.icon} size={17} color={palette[item.tone as keyof typeof palette]} /></View><View style={styles.flex}><Text style={[styles.activityTitle, { color: colors.foreground }]}>{item.title}</Text><Text style={[styles.activityDetail, { color: colors.muted }]}>{item.detail}</Text></View><IconSymbol name="chevron.right" size={18} color={colors.muted} /></Pressable>)}</View>
        <Text style={[styles.toast, { color: colors.muted }]}>{toast}</Text>

        <Modal visible={showServerSheet} transparent animationType="slide" onRequestClose={() => setShowServerSheet(false)}>
          <View style={styles.modalBackdrop}>
            <View style={[styles.sheet, { backgroundColor: colors.surface, borderColor: colors.border }]}>
              <View style={styles.sheetHandle} />
              <Text style={[styles.sheetKicker, { color: colors.muted }]}>SERVER MANAGER</Text>
              <Text style={[styles.sheetTitle, { color: colors.foreground }]}>Add your server</Text>
              <Text style={[styles.sheetHint, { color: colors.muted }]}>Design preview — connection will be enabled later.</Text>
              {([['name', 'Display name'], ['host', 'Host or IP'], ['port', 'Port'], ['username', 'Username']] as const).map(([key, placeholder]) => (
                <TextInput key={key} value={draft[key]} onChangeText={(value) => setDraft({ ...draft, [key]: value })} placeholder={placeholder} placeholderTextColor={colors.muted} style={[styles.input, { color: colors.foreground, borderColor: colors.border, backgroundColor: colors.background }]} autoCapitalize="none" />
              ))}
              <View style={styles.sheetActions}>
                <Pressable onPress={() => setShowServerSheet(false)} style={({ pressed }) => [styles.sheetCancel, { borderColor: colors.border, opacity: pressed ? 0.7 : 1 }]}><Text style={{ color: colors.muted, fontWeight: "800" }}>Cancel</Text></Pressable>
                <Pressable onPress={() => { setServer(draft); setOnline(false); setShowServerSheet(false); action(`${draft.name || "Server"} saved locally`); }} style={({ pressed }) => [styles.sheetSave, { backgroundColor: colors.primary, opacity: pressed ? 0.8 : 1 }]}><Text style={styles.sheetSaveText}>Save server</Text></Pressable>
              </View>
            </View>
          </View>
        </Modal>
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({ modalBackdrop: { flex: 1, justifyContent: "flex-end", backgroundColor: "#00000099" }, sheet: { borderTopLeftRadius: 26, borderTopRightRadius: 26, borderWidth: 1, padding: 20, paddingBottom: 28 }, sheetHandle: { width: 42, height: 4, borderRadius: 4, backgroundColor: "#536171", alignSelf: "center", marginBottom: 18 }, sheetKicker: { fontSize: 10, fontWeight: "800", letterSpacing: 1.2 }, sheetTitle: { fontSize: 24, fontWeight: "800", marginTop: 7 }, sheetHint: { fontSize: 11, marginTop: 6, marginBottom: 16 }, input: { minHeight: 46, borderWidth: 1, borderRadius: 13, paddingHorizontal: 13, marginBottom: 9, fontSize: 13 }, sheetActions: { flexDirection: "row", gap: 10, marginTop: 7 }, sheetCancel: { flex: 1, minHeight: 47, borderRadius: 13, borderWidth: 1, alignItems: "center", justifyContent: "center" }, sheetSave: { flex: 1.4, minHeight: 47, borderRadius: 13, alignItems: "center", justifyContent: "center" }, sheetSaveText: { color: "#07111B", fontWeight: "800" }, content: { paddingTop: 12, paddingBottom: 32 }, header: { flexDirection: "row", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 24 }, eyebrow: { fontSize: 11, fontWeight: "700", letterSpacing: 1.4, marginBottom: 7 }, title: { fontSize: 30, fontWeight: "800", letterSpacing: -0.8 }, statusButton: { flexDirection: "row", alignItems: "center", gap: 7, borderWidth: 1, borderRadius: 20, paddingHorizontal: 11, paddingVertical: 8 }, dot: { width: 7, height: 7, borderRadius: 4 }, statusText: { fontSize: 10, fontWeight: "800", letterSpacing: 0.8 }, serverCard: { borderRadius: 22, borderWidth: 1, padding: 16, marginBottom: 25 }, serverTop: { flexDirection: "row", alignItems: "center", gap: 12 }, serverIcon: { width: 44, height: 44, borderRadius: 14, alignItems: "center", justifyContent: "center" }, flex: { flex: 1 }, cardLabel: { fontSize: 10, fontWeight: "700", letterSpacing: 1.1 }, serverName: { fontSize: 19, fontWeight: "800", marginTop: 2 }, serverMeta: { fontSize: 11, marginTop: 3 }, divider: { height: 1, marginVertical: 15 }, serverStats: { flexDirection: "row", justifyContent: "space-between" }, statValue: { fontSize: 15, fontWeight: "800" }, statCaption: { fontSize: 9, fontWeight: "700", letterSpacing: 0.7, marginTop: 4 }, sectionHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 11, marginTop: 2 }, sectionTitle: { fontSize: 17, fontWeight: "800" }, sectionLink: { fontSize: 12, fontWeight: "700" }, metricGrid: { flexDirection: "row", gap: 9, marginBottom: 24 }, metricCard: { flex: 1, minHeight: 140, borderRadius: 17, borderWidth: 1, padding: 12 }, metricIcon: { width: 32, height: 32, borderRadius: 10, alignItems: "center", justifyContent: "center", marginBottom: 13 }, metricLabel: { fontSize: 10, fontWeight: "600" }, metricValue: { fontSize: 16, fontWeight: "800", marginTop: 5 }, metricDetail: { fontSize: 10, marginTop: 6, fontWeight: "600" }, actionRow: { flexDirection: "row", gap: 10, marginBottom: 24 }, action: { flex: 1, minHeight: 49, borderRadius: 15, borderWidth: 1, borderColor: "transparent", flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8 }, actionText: { color: "#07111B", fontSize: 13, fontWeight: "800" }, activityCard: { borderRadius: 18, borderWidth: 1, paddingHorizontal: 14 }, activityRow: { minHeight: 66, flexDirection: "row", alignItems: "center", gap: 12 }, activityIcon: { width: 34, height: 34, borderRadius: 11, alignItems: "center", justifyContent: "center" }, activityTitle: { fontSize: 13, fontWeight: "700" }, activityDetail: { fontSize: 11, marginTop: 4 }, toast: { textAlign: "center", fontSize: 11, marginTop: 18 }, });
