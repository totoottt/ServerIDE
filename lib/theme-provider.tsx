import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { Appearance, View, useColorScheme as useSystemColorScheme } from "react-native";
import { colorScheme as nativewindColorScheme, vars } from "nativewind";

import { VariantColors, type ColorScheme, type RuntimePalette, type ThemeVariant } from "@/constants/theme";

const THEME_KEY = "server-ide.theme.variant";
const LARGE_TEXT_KEY = "server-ide.preferences.large-text";

type ThemeContextValue = {
  colorScheme: ColorScheme;
  themeVariant: ThemeVariant;
  colors: RuntimePalette;
  largeText: boolean;
  setThemeVariant: (variant: ThemeVariant) => void;
  setColorScheme: (scheme: ColorScheme) => void;
  setLargeText: (enabled: boolean) => void;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

function applyPalette(scheme: ColorScheme, palette: RuntimePalette) {
  nativewindColorScheme.set(scheme);
  Appearance.setColorScheme?.(scheme);
  if (typeof document !== "undefined") {
    const root = document.documentElement;
    root.dataset.theme = scheme;
    root.classList.toggle("dark", scheme === "dark");
    Object.entries(palette).forEach(([token, value]) => root.style.setProperty(`--color-${token}`, value));
  }
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const systemScheme = useSystemColorScheme() ?? "dark";
  const [colorScheme, setColorSchemeState] = useState<ColorScheme>("dark");
  const [themeVariant, setThemeVariantState] = useState<ThemeVariant>("midnight");
  const [largeText, setLargeTextState] = useState(false);
  const colors = VariantColors[themeVariant];

  useEffect(() => {
    let active = true;
    Promise.all([AsyncStorage.getItem(THEME_KEY), AsyncStorage.getItem(LARGE_TEXT_KEY)]).then(([storedTheme, storedLargeText]) => {
      if (!active) return;
      if (storedTheme === "midnight" || storedTheme === "ocean" || storedTheme === "slate") setThemeVariantState(storedTheme);
      if (storedLargeText === "true") setLargeTextState(true);
      setColorSchemeState("dark");
    });
    return () => { active = false; };
  }, [systemScheme]);

  useEffect(() => { applyPalette(colorScheme, colors); }, [colorScheme, colors]);

  const setThemeVariant = useCallback((variant: ThemeVariant) => {
    setThemeVariantState(variant);
    void AsyncStorage.setItem(THEME_KEY, variant);
  }, []);
  const setColorScheme = useCallback((scheme: ColorScheme) => setColorSchemeState(scheme), []);
  const setLargeText = useCallback((enabled: boolean) => {
    setLargeTextState(enabled);
    void AsyncStorage.setItem(LARGE_TEXT_KEY, String(enabled));
  }, []);

  const themeVariables = useMemo(() => vars(Object.fromEntries(Object.entries(colors).filter(([key]) => !["text", "tint", "icon", "tabIconDefault", "tabIconSelected", "info", "overlay", "terminal"].includes(key)).map(([key, value]) => [`color-${key}`, value]))), [colors]);
  const value = useMemo(() => ({ colorScheme, themeVariant, colors, largeText, setThemeVariant, setColorScheme, setLargeText }), [colorScheme, themeVariant, colors, largeText, setThemeVariant, setColorScheme, setLargeText]);

  return <ThemeContext.Provider value={value}><View style={[{ flex: 1 }, themeVariables]}>{children}</View></ThemeContext.Provider>;
}

export function useThemeContext(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useThemeContext must be used within ThemeProvider");
  return ctx;
}
