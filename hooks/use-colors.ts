import { Colors, type ColorScheme, type ThemeColorPalette } from "@/constants/theme";
import { useThemeContext } from "@/lib/theme-provider";

export function useColors(colorSchemeOverride?: ColorScheme): ThemeColorPalette {
  try {
    return useThemeContext().colors;
  } catch {
    return Colors[colorSchemeOverride ?? "dark"];
  }
}
