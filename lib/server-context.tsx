import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { serverAgent, type ServerHealth, type ServerProfile } from "./server-agent";

const PROFILE_KEY = "serveride.agent.profile.v1";
const TOKEN_KEY = "serveride.agent.token.v1";

type ServerContextValue = {
  ready: boolean;
  profile: ServerProfile;
  configured: boolean;
  health: ServerHealth | null;
  connectionError: string | null;
  saveProfile: (profile: ServerProfile) => Promise<void>;
  refreshHealth: () => Promise<ServerHealth>;
  clearProfile: () => Promise<void>;
};

const emptyProfile: ServerProfile = { name: "My server", baseUrl: "", token: "" };
const ServerContext = createContext<ServerContextValue | null>(null);

export function ServerProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false);
  const [profile, setProfile] = useState<ServerProfile>(emptyProfile);
  const [health, setHealth] = useState<ServerHealth | null>(null);
  const [connectionError, setConnectionError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([AsyncStorage.getItem(PROFILE_KEY), SecureStore.getItemAsync(TOKEN_KEY)])
      .then(([stored, token]) => {
        const metadata = stored ? JSON.parse(stored) : {};
        setProfile({ ...emptyProfile, ...metadata, token: token ?? "" });
      })
      .catch(() => setProfile(emptyProfile))
      .finally(() => setReady(true));
  }, []);

  const saveProfile = useCallback(async (next: ServerProfile) => {
    const normalized = { ...next, name: next.name.trim() || "My server", baseUrl: next.baseUrl.trim().replace(/\/+$/, ""), token: next.token.trim() };
    await AsyncStorage.setItem(PROFILE_KEY, JSON.stringify({ name: normalized.name, baseUrl: normalized.baseUrl }));
    await SecureStore.setItemAsync(TOKEN_KEY, normalized.token);
    setProfile(normalized);
    setHealth(null);
    setConnectionError(null);
  }, []);

  const clearProfile = useCallback(async () => {
    await Promise.all([AsyncStorage.removeItem(PROFILE_KEY), SecureStore.deleteItemAsync(TOKEN_KEY)]);
    setProfile(emptyProfile);
    setHealth(null);
    setConnectionError(null);
  }, []);

  const refreshHealth = useCallback(async () => {
    try {
      const next = await serverAgent.health(profile);
      setHealth(next);
      setConnectionError(null);
      return next;
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unable to reach server agent";
      setConnectionError(message);
      throw error;
    }
  }, [profile]);

  const value = useMemo<ServerContextValue>(() => ({
    ready,
    profile,
    configured: Boolean(profile.baseUrl && profile.token),
    health,
    connectionError,
    saveProfile,
    refreshHealth,
    clearProfile,
  }), [ready, profile, health, connectionError, saveProfile, refreshHealth, clearProfile]);

  return <ServerContext.Provider value={value}>{children}</ServerContext.Provider>;
}

export function useServer() {
  const value = useContext(ServerContext);
  if (!value) throw new Error("useServer must be used inside ServerProvider");
  return value;
}
