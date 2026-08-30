import { useEffect, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from "react-native";
import { ScreenContainer } from "@/components/screen-container";
import { useColors } from "@/hooks/use-colors";
import { useServer } from "@/lib/server-context";
import { errorMessage, serverAgent } from "@/lib/server-agent";

export default function SettingsScreen() {
  const colors = useColors("dark");
  const { profile, configured, saveProfile, clearProfile } = useServer();
  const [draft, setDraft] = useState(profile);
  const [testing, setTesting] = useState(false);
  const [notice, setNotice] = useState(configured ? "Server agent configured" : "Add your HTTPS agent connection");
  const [largeText, setLargeText] = useState(false);
  const [haptics, setHaptics] = useState(true);
  useEffect(() => setDraft(profile), [profile]);

  async function testAndSave() {
    setTesting(true); setNotice("Testing secure connection…");
    try { await serverAgent.health(draft); await saveProfile(draft); setNotice("Connected and saved securely"); }
    catch (error) { setNotice(errorMessage(error)); }
    finally { setTesting(false); }
  }

  return <ScreenContainer className="px-5" containerClassName="bg-background"><ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
    <Text style={[styles.kicker, { color: colors.muted }]}>SERVER IDE / PREFERENCES</Text><Text style={[styles.title, { color: colors.foreground }]}>Make it yours.</Text><Text style={[styles.subtitle, { color: colors.muted }]}>The Midnight palette and accent colors stay consistent across every workspace.</Text>
    <Text style={[styles.section, { color: colors.foreground }]}>Server connection</Text>
    <View style={[styles.card, { backgroundColor: colors.surface, borderColor: colors.border }]}><Text style={[styles.label, { color: colors.muted }]}>AGENT HTTPS CONNECTION</Text>
      <TextInput value={draft.name} onChangeText={(name) => setDraft({ ...draft, name })} placeholder="Display name" placeholderTextColor={colors.muted} style={[styles.input, { color: colors.foreground, borderColor: colors.border, backgroundColor: colors.background }]} />
      <TextInput value={draft.baseUrl} onChangeText={(baseUrl) => setDraft({ ...draft, baseUrl })} placeholder="https://example.com/serveride-agent" placeholderTextColor={colors.muted} autoCapitalize="none" keyboardType="url" style={[styles.input, { color: colors.foreground, borderColor: colors.border, backgroundColor: colors.background }]} />
      <TextInput value={draft.token} onChangeText={(token) => setDraft({ ...draft, token })} placeholder="Agent access token" placeholderTextColor={colors.muted} autoCapitalize="none" secureTextEntry style={[styles.input, { color: colors.foreground, borderColor: colors.border, backgroundColor: colors.background }]} />
      <Text style={[styles.hint, { color: colors.muted }]}>The token is stored in iOS Keychain. Use HTTPS; never expose the agent over plain HTTP.</Text>
      <View style={styles.buttonRow}><Pressable disabled={testing} onPress={testAndSave} style={({ pressed }) => [styles.primary, { backgroundColor: colors.primary, opacity: pressed || testing ? 0.65 : 1 }]}><Text style={styles.primaryText}>{testing ? "TESTING…" : "TEST & SAVE"}</Text></Pressable>{configured && <Pressable onPress={async () => { await clearProfile(); setNotice("Connection removed from this device"); }} style={[styles.secondary, { borderColor: "#FF5C7055" }]}><Text style={{ color: "#FF5C70", fontWeight: "800", fontSize: 11 }}>REMOVE</Text></Pressable>}</View>
      <Text style={[styles.notice, { color: notice.includes("Connected") ? colors.success : colors.muted }]}>{notice}</Text>
    </View>
    <Text style={[styles.section, { color: colors.foreground }]}>Appearance</Text>
    <View style={[styles.card, { backgroundColor: colors.surface, borderColor: colors.border }]}><Text style={[styles.label, { color: colors.muted }]}>LOCKED DESIGN PALETTE</Text>
      <View style={styles.themeRow}>{[{ name: "Midnight", color: "#07090C", active: true }, { name: "Blue", color: "#4DA3FF" }, { name: "Success", color: "#35D07F" }].map((theme) => <View key={theme.name} style={[styles.themeOption, { borderColor: theme.active ? colors.primary : colors.border }]}><View style={[styles.themeSwatch, { backgroundColor: theme.color }]} /><Text style={[styles.themeName, { color: colors.foreground }]}>{theme.name}</Text></View>)}</View>
      <View style={[styles.row, { borderTopColor: colors.border }]}><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Larger terminal text</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Improves terminal readability</Text></View><Switch value={largeText} onValueChange={setLargeText} trackColor={{ false: colors.border, true: colors.primary }} thumbColor="#F4F7FA" /></View>
      <View style={[styles.row, { borderTopColor: colors.border }]}><View style={styles.rowCopy}><Text style={[styles.rowTitle, { color: colors.foreground }]}>Haptic feedback</Text><Text style={[styles.rowDetail, { color: colors.muted }]}>Action confirmation feedback</Text></View><Switch value={haptics} onValueChange={setHaptics} trackColor={{ false: colors.border, true: colors.success }} thumbColor="#F4F7FA" /></View>
    </View>
  </ScrollView></ScreenContainer>;
}

const styles = StyleSheet.create({ content: { paddingTop: 14, paddingBottom: 40 }, kicker: { fontSize: 10, fontWeight: "800", letterSpacing: 1.4 }, title: { fontSize: 31, fontWeight: "800", marginTop: 7, letterSpacing: -0.8 }, subtitle: { fontSize: 12, lineHeight: 18, marginTop: 7, maxWidth: 340 }, section: { fontSize: 17, fontWeight: "800", marginTop: 26, marginBottom: 11 }, card: { borderRadius: 19, borderWidth: 1, paddingHorizontal: 15, paddingBottom: 15 }, label: { fontSize: 10, fontWeight: "800", letterSpacing: 1.1, marginTop: 15, marginBottom: 11 }, input: { minHeight: 46, borderWidth: 1, borderRadius: 13, paddingHorizontal: 13, marginBottom: 9, fontSize: 12 }, hint: { fontSize: 10, lineHeight: 15 }, buttonRow: { flexDirection: "row", gap: 9, marginTop: 13 }, primary: { flex: 1, minHeight: 46, borderRadius: 13, alignItems: "center", justifyContent: "center" }, primaryText: { color: "#07111B", fontSize: 11, fontWeight: "900" }, secondary: { minWidth: 92, minHeight: 46, borderRadius: 13, borderWidth: 1, alignItems: "center", justifyContent: "center" }, notice: { fontSize: 10, lineHeight: 15, marginTop: 11, textAlign: "center" }, themeRow: { flexDirection: "row", gap: 9 }, themeOption: { flex: 1, borderWidth: 1, borderRadius: 13, padding: 8 }, themeSwatch: { height: 38, borderRadius: 9 }, themeName: { fontSize: 10, fontWeight: "700", marginTop: 7 }, row: { minHeight: 64, borderTopWidth: 1, flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 12, marginTop: 14 }, rowCopy: { flex: 1 }, rowTitle: { fontSize: 13, fontWeight: "700" }, rowDetail: { fontSize: 10, marginTop: 4, lineHeight: 15 } });
