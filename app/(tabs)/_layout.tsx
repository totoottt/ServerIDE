import { Tabs } from "expo-router";
import { Platform } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { HapticTab } from "@/components/haptic-tab";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { useColors } from "@/hooks/use-colors";

export default function TabLayout() {
  const colors = useColors("dark"); const insets = useSafeAreaInsets(); const bottomPadding = Platform.OS === "web" ? 12 : Math.max(insets.bottom, 8);
  return <Tabs screenOptions={{ headerShown: false, tabBarActiveTintColor: colors.primary, tabBarInactiveTintColor: colors.muted, tabBarButton: HapticTab, tabBarStyle: { paddingTop: 8, paddingBottom: bottomPadding, height: 58 + bottomPadding, backgroundColor: "#0B0F13", borderTopColor: colors.border, borderTopWidth: 1 }, tabBarLabelStyle: { fontSize: 9, fontWeight: "700" } }}>
    <Tabs.Screen name="index" options={{ title: "Overview", tabBarIcon: ({ color }) => <IconSymbol name="house.fill" size={21} color={color} /> }} />
    <Tabs.Screen name="processes" options={{ title: "Processes", tabBarIcon: ({ color }) => <IconSymbol name="chevron.left.forwardslash.chevron.right" size={21} color={color} /> }} />
    <Tabs.Screen name="network" options={{ title: "Network", tabBarIcon: ({ color }) => <IconSymbol name="paperplane.fill" size={21} color={color} /> }} />
    <Tabs.Screen name="ssh" options={{ title: "SSH", tabBarIcon: ({ color }) => <IconSymbol name="chevron.left.forwardslash.chevron.right" size={21} color={color} /> }} />
    <Tabs.Screen name="files" options={{ title: "Files", tabBarIcon: ({ color }) => <IconSymbol name="paperplane.fill" size={21} color={color} /> }} />
    <Tabs.Screen name="checks" options={{ title: "Checks", tabBarIcon: ({ color }) => <IconSymbol name="paperplane.fill" size={21} color={color} /> }} />
    <Tabs.Screen name="settings" options={{ title: "Settings", tabBarIcon: ({ color }) => <IconSymbol name="chevron.right" size={21} color={color} /> }} />
  </Tabs>;
}
