import { Platform } from "react-native";

import themeConfig from "../../theme.config";

export type ColorScheme = "light" | "dark";
export type ThemeVariant = "midnight" | "ocean" | "slate";

export const ThemeColors = themeConfig.themeColors;

type ThemeColorTokens = typeof ThemeColors;
type ThemeColorName = keyof ThemeColorTokens;
type SchemePalette = Record<ColorScheme, Record<ThemeColorName, string>>;
type SchemePaletteItem = SchemePalette[ColorScheme];

function buildSchemePalette(colors: ThemeColorTokens): SchemePalette {
  const palette: SchemePalette = { light: {} as SchemePalette["light"], dark: {} as SchemePalette["dark"] };
  (Object.keys(colors) as ThemeColorName[]).forEach((name) => {
    palette.light[name] = colors[name].light;
    palette.dark[name] = colors[name].dark;
  });
  return palette;
}

export const SchemeColors = buildSchemePalette(ThemeColors);

export type RuntimePalette = SchemePaletteItem & {
  text: string;
  background: string;
  tint: string;
  icon: string;
  tabIconDefault: string;
  tabIconSelected: string;
  border: string;
  info: string;
  overlay: string;
  terminal: string;
};

function buildRuntimePalette(base: SchemePaletteItem): RuntimePalette {
  return {
    ...base,
    text: base.foreground,
    background: base.background,
    tint: base.primary,
    icon: base.muted,
    tabIconDefault: base.muted,
    tabIconSelected: base.primary,
    border: base.border,
    info: base.primary,
    overlay: "rgba(0,0,0,0.62)",
    terminal: base.background,
  };
}

export const VariantColors: Record<ThemeVariant, RuntimePalette> = {
  midnight: buildRuntimePalette({
    primary: "#4DA3FF", background: "#07090C", surface: "#11161C", foreground: "#F5F7FA", muted: "#8E9AA8", border: "#2A3440", success: "#35D07F", warning: "#FFB547", error: "#FF5C70",
  }),
  ocean: buildRuntimePalette({
    primary: "#55C7E8", background: "#06151D", surface: "#0B202A", foreground: "#F2FBFF", muted: "#8AAAB5", border: "#1D4654", success: "#39D98A", warning: "#FFC857", error: "#FF6B7A",
  }),
  slate: buildRuntimePalette({
    primary: "#A78BFA", background: "#111318", surface: "#1A1E27", foreground: "#F4F4F5", muted: "#969BA8", border: "#343B49", success: "#4ADE80", warning: "#FBBF24", error: "#FB7185",
  }),
};

export const Colors = {
  light: buildRuntimePalette(SchemeColors.light),
  dark: VariantColors.midnight,
} satisfies Record<ColorScheme, RuntimePalette>;

export type ThemeColorPalette = RuntimePalette;

export const Fonts = Platform.select({
  ios: { sans: "system-ui", serif: "ui-serif", rounded: "ui-rounded", mono: "ui-monospace" },
  default: { sans: "normal", serif: "serif", rounded: "normal", mono: "monospace" },
  web: { sans: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif", serif: "Georgia, 'Times New Roman', serif", rounded: "'SF Pro Rounded', 'Hiragino Maru Gothic ProN', Meiryo, sans-serif", mono: "SFMono-Regular, Menlo, Monaco, Consolas, monospace" },
});
