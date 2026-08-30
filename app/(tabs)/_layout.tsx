import { Tabs } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Platform } from "react-native";

import { HapticTab } from "@/components/haptic-tab";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { useColors } from "@/hooks/use-colors";

export default function TabLayout() {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const bottomPadding = Platform.OS === "web" ? 12 : Math.max(insets.bottom, 8);
  const tabBarHeight = 56 + bottomPadding;

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.muted,
        headerShown: false,
        tabBarButton: HapticTab,
        tabBarStyle: { paddingTop: 8, paddingBottom: bottomPadding, height: tabBarHeight, backgroundColor: colors.background, borderTopColor: colors.border, borderTopWidth: 0.5 },
      }}
    >
      <Tabs.Screen name="index" options={{ title: "Overview", tabBarIcon: ({ color }) => <IconSymbol size={25} name="house.fill" color={color} /> }} />
      <Tabs.Screen name="servers" options={{ title: "Servers", tabBarIcon: ({ color }) => <IconSymbol size={25} name="paperplane.fill" color={color} /> }} />
      <Tabs.Screen name="processes" options={{ title: "Processes", tabBarIcon: ({ color }) => <IconSymbol size={25} name="chevron.left.forwardslash.chevron.right" color={color} /> }} />
      <Tabs.Screen name="network" options={{ title: "Network", tabBarIcon: ({ color }) => <IconSymbol size={25} name="paperplane.fill" color={color} /> }} />
      <Tabs.Screen name="ssh" options={{ title: "SSH", tabBarIcon: ({ color }) => <IconSymbol size={25} name="chevron.left.forwardslash.chevron.right" color={color} /> }} />
      <Tabs.Screen name="files" options={{ title: "Files", tabBarIcon: ({ color }) => <IconSymbol size={25} name="folder.fill" color={color} /> }} />
      <Tabs.Screen name="checks" options={{ title: "Checks", tabBarIcon: ({ color }) => <IconSymbol size={25} name="checkmark.shield.fill" color={color} /> }} />
      <Tabs.Screen name="settings" options={{ title: "Settings", tabBarIcon: ({ color }) => <IconSymbol size={25} name="gearshape.fill" color={color} /> }} />
    </Tabs>
  );
}
