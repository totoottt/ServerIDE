import { useState } from "react";
import { Alert, Pressable, ScrollView, StyleSheet, Switch, Text, View } from "react-native";
import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system/legacy";
import * as Sharing from "expo-sharing";
import { useServerStore } from "@/lib/server-store";
import { readServerSecret, saveServerSecret } from "@/lib/server-secrets";
import { decryptServerExport, encryptServerExport } from "@/lib/encrypted-server-export";
import { ScreenContainer } from "@/components/screen-container";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { useColors } from "@/hooks/use-colors";
import { useThemeContext } from "@/lib/theme-provider";
import type { ThemeVariant } from "@/constants/theme";

const themes: { id: ThemeVariant; name: string; color: string }[] = [
  { id: "midnight", name: "Midnight", color: "#07090C" },
  { id: "ocean", name: "Ocean", color: "#08202B" },
  { id: "slate", name: "Slate", color: "#171B22" },
];

export default function SettingsScreen() {
  const colors = useColors();
  const { themeVariant, setThemeVariant, largeText, setLargeText } = useThemeContext();
  const { servers, addServer } = useServerStore();
  const [haptics, setHaptics] = useState(true);
  const [sync, setSync] = useState(false);
  const [toast, setToast] = useState("Guest mode · saved on this device");

  const notify = (message: string) => {
    setToast(message);
    setTimeout(() => setToast("Guest mode · saved on this device"), 2200);
  };

  const exportServers = () => { Alert.alert("Encrypted backup", "The export contains sensitive connection credentials and will be encrypted with a password.", [{ text: "Cancel", style: "cancel" }, { text: "Continue", onPress: () => Alert.prompt("Export password", "Use at least 10 characters.", async (password) => { if (!password) return; try { const payload = { version: 1, exportedAt: new Date().toISOString(), servers: await Promise.all(servers.map(async (server) => ({ profile: server, secret: await readServerSecret(server.id) }))) }; const serialized = encryptServerExport(payload, password); const uri = `${FileSystem.cacheDirectory ?? ""}server-ide-export.json`; await FileSystem.writeAsStringAsync(uri, serialized); if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: "application/json", dialogTitle: "Share encrypted Server IDE backup" }); notify("Encrypted backup created"); } catch (error) { notify(error instanceof Error ? error.message : "Unable to create encrypted backup"); } }) }]); };
  const importServers = async () => { const result = await DocumentPicker.getDocumentAsync({ type: "application/json", copyToCacheDirectory: true }); if (result.canceled) return; const uri = result.assets[0].uri; Alert.prompt("Import password", "Enter the password used for this encrypted backup.", async (password) => { if (!password) return; try { const serialized = await FileSystem.readAsStringAsync(uri); const decoded = decryptServerExport(serialized, password) as { servers?: { profile: Record<string, unknown>; secret?: Record<string, unknown> | null }[] }; if (!Array.isArray(decoded.servers)) throw new Error("Invalid server backup"); let imported = 0; for (const item of decoded.servers) { const profile = item.profile; const { id: _id, createdAt: _createdAt, ...newProfile } = profile; const server = await addServer(newProfile as never); if (item.secret) await saveServerSecret(server.id, item.secret as never); imported += 1; } notify(`${imported} server profiles imported`); } catch (error) { notify(error instanceof Error ? error.message : "Unable to import encrypted backup"); } }); };

  return (
    <ScreenContainer className="px-5" containerClassName="bg-background">
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        <Text style={[styles.kicker, { color: colors.muted }]}>SERVER IDE / PREFERENCES</Text>
        <Text style={[styles.title, { color: colors.foreground }]}>Make it yours.</Text>
        <Text style={[styles.subtitle, { color: colors.muted }]}>Customize your workspace without changing the app identity.</Text>

        <Text style={[styles.section, { color: colors.foreground }]}>Appearance</Text>
        <View style={[styles.card, { backgroundColor: colors.surface, borderColor: colors.border }]}>
          <Text style={[styles.label, { color: colors.muted }]}>THEME</Text>
          <View style={styles.themeRow}>
            {themes.map((theme) => (
              <Pressable key={theme.id} onPress={() => { setThemeVariant(theme.id); notify(`${theme.name} theme selected across the app`); }} style={({ pressed }) => [styles.themeOption, { borderColor: themeVariant === theme.id ? colors.primary : colors.border, opacity: pressed ? 0.7 : 1 }]}>
                <View style={[styles.themeSwatch, { backgroundColor: theme.color, borderColor: themeVariant === theme.id ? colors.primary : colors.border }]}>{themeVariant === theme.id && <View style={[styles.swatchDot, { backgroundColor: colors.success }]} />}</View>
                <Text style={[styles.themeName, { color: colors.foreground }]}>{theme.name}</Text>
              </Pressable>
            ))}
          </View>
          <View style={[styles.row, { borderTopColor: colors.border }]}><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Larger text</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Increase editor and terminal readability</Text></View><Switch value={largeText} onValueChange={(value) => { setLargeText(value); notify(value ? "Larger text enabled across the app" : "Larger text disabled"); }} trackColor={{ false: colors.border, true: colors.primary }} thumbColor={colors.foreground} /></View>
          <View style={[styles.row, { borderTopColor: colors.border }]}><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Haptic feedback</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Press and action confirmation feedback</Text></View><Switch value={haptics} onValueChange={setHaptics} trackColor={{ false: colors.border, true: colors.success }} thumbColor={colors.foreground} /></View>
        </View>

        <Text style={[styles.section, { color: colors.foreground }]}>Workspace layout</Text>
        <View style={[styles.card, { backgroundColor: colors.surface, borderColor: colors.border }]}>
          {["Terminal", "Files", "Editor", "Preview"].map((item, index) => <Pressable key={item} onPress={() => notify(`${item} moved to position ${index + 1}`)} style={({ pressed }) => [styles.layoutRow, { borderBottomColor: colors.border, opacity: pressed ? 0.65 : 1 }]}><View style={[styles.dragIcon, { backgroundColor: colors.background }]}><Text style={{ color: colors.muted }}>≡</Text></View><Text style={[styles.rowTitle, { color: colors.foreground }]}>{item}</Text><Text style={[styles.position, { color: colors.primary }]}>{index + 1}</Text></Pressable>)}
        </View>

        <Text style={[styles.section, { color: colors.foreground }]}>Secure server backup</Text>
        <View style={[styles.card, { backgroundColor: colors.surface, borderColor: colors.border }]}><View style={styles.row}><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Export encrypted backup</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Passwords and private keys are encrypted before sharing.</Text></View><Pressable onPress={exportServers} style={[styles.backupButton, { backgroundColor: `${colors.primary}18` }]}><Text style={{ color: colors.primary, fontWeight: "800", fontSize: 11 }}>EXPORT</Text></Pressable></View><View style={styles.row}><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Import encrypted backup</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Profiles are added only after successful decryption.</Text></View><Pressable onPress={() => void importServers()} style={[styles.backupButton, { backgroundColor: `${colors.success}18` }]}><Text style={{ color: colors.success, fontWeight: "800", fontSize: 11 }}>IMPORT</Text></Pressable></View></View>

        <Text style={[styles.section, { color: colors.foreground }]}>Sync & account</Text>
        <View style={[styles.card, { backgroundColor: colors.surface, borderColor: colors.border }]}>
          <View style={styles.accountRow}><View style={[styles.accountIcon, { backgroundColor: `${colors.primary}18` }]}><IconSymbol name="paperplane.fill" size={18} color={colors.primary} /></View><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Guest workspace</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Settings stay on this device</Text></View></View>
          <View style={[styles.row, { borderTopColor: colors.border }]}><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Sync across devices</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Sign in only when you want sync</Text></View><Switch value={sync} onValueChange={(value) => { setSync(value); notify(value ? "Sign in to sync selected" : "Guest mode selected"); }} trackColor={{ false: colors.border, true: colors.primary }} thumbColor={colors.foreground} /></View>
        </View>
        <Text style={[styles.toast, { color: colors.muted }]}>{toast}</Text>
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({ content: { paddingTop: 14, paddingBottom: 40 }, kicker: { fontSize: 10, fontWeight: "800", letterSpacing: 1.4 }, title: { fontSize: 31, fontWeight: "800", marginTop: 7, letterSpacing: -0.8 }, subtitle: { fontSize: 12, lineHeight: 18, marginTop: 7, maxWidth: 320 }, section: { fontSize: 17, fontWeight: "800", marginTop: 26, marginBottom: 11 }, card: { borderRadius: 19, borderWidth: 1, paddingHorizontal: 15 }, label: { fontSize: 10, fontWeight: "800", letterSpacing: 1.1, marginTop: 15, marginBottom: 11 }, themeRow: { flexDirection: "row", gap: 9 }, themeOption: { flex: 1, borderWidth: 1, borderRadius: 13, padding: 8 }, themeSwatch: { height: 44, borderRadius: 9, borderWidth: 1, alignItems: "flex-end", justifyContent: "flex-end", padding: 6 }, swatchDot: { width: 8, height: 8, borderRadius: 4 }, themeName: { fontSize: 10, fontWeight: "700", marginTop: 7 }, row: { minHeight: 64, borderTopWidth: 1, flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 12 }, rowCopy: { flex: 1 }, rowTitle: { fontSize: 13, fontWeight: "700" }, rowDetail: { fontSize: 10, marginTop: 4, lineHeight: 15 }, layoutRow: { minHeight: 54, borderBottomWidth: 1, flexDirection: "row", alignItems: "center", gap: 11 }, dragIcon: { width: 31, height: 31, borderRadius: 9, alignItems: "center", justifyContent: "center" }, position: { fontSize: 12, fontWeight: "800" }, accountRow: { minHeight: 74, flexDirection: "row", alignItems: "center", gap: 11 }, accountIcon: { width: 38, height: 38, borderRadius: 12, alignItems: "center", justifyContent: "center" }, backupButton: { borderRadius: 10, paddingHorizontal: 10, paddingVertical: 9 }, toast: { textAlign: "center", fontSize: 11, marginTop: 18 } });
