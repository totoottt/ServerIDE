import * as SplashScreen from "expo-splash-screen";
import React from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

type Props = {
  children: React.ReactNode;
};

type State = {
  error: Error | null;
};

/**
 * Catches any render-time error anywhere below it in the tree and shows a
 * visible error screen instead of leaving the app on a frozen splash /
 * blank screen with no explanation.
 *
 * IMPORTANT: this only catches errors thrown during React render. Errors
 * thrown before React ever renders (e.g. while a module is being imported)
 * will NOT be caught here — see the global handler installed in
 * app/_layout.tsx for that case.
 */
export class AppErrorBoundary extends React.Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    // Make sure the native splash screen is never left stuck on screen
    // just because the app crashed before it could hide it.
    SplashScreen.hideAsync().catch(() => undefined);
    console.error("[AppErrorBoundary] Caught render error:", error, info.componentStack);
  }

  render() {
    if (this.state.error) {
      return (
        <ScrollView contentContainerStyle={styles.container}>
          <View style={styles.card}>
            <Text style={styles.title}>حدث خطأ أثناء تشغيل التطبيق</Text>
            <Text style={styles.message}>{this.state.error.message}</Text>
            {this.state.error.stack ? (
              <Text style={styles.stack}>{this.state.error.stack}</Text>
            ) : null}
          </View>
        </ScrollView>
      );
    }
    return this.props.children;
  }
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    backgroundColor: "#07090C",
    padding: 20,
    paddingTop: 64,
  },
  card: {
    backgroundColor: "#12161B",
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: "#252D37",
  },
  title: {
    color: "#FF5C70",
    fontSize: 17,
    fontWeight: "800",
    marginBottom: 10,
  },
  message: {
    color: "#F4F7FA",
    fontSize: 14,
    marginBottom: 12,
  },
  stack: {
    color: "#8E9AA8",
    fontSize: 11,
    fontFamily: "monospace",
  },
});
