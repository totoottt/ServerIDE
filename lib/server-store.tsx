import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

export type ServerAuthMethod = "ssh-key" | "password" | "agent";
export type ServerColor = "blue" | "purple" | "green" | "orange" | "red";
export type ServerRole = "ssh" | "sftp";

export type JumpHostProfile = {
  enabled: boolean;
  host: string;
  port: number;
  username: string;
  portKnockSequence?: string;
};

export type ServerProfile = {
  id: string;
  name: string;
  host: string;
  port: number;
  username: string;
  authMethod: ServerAuthMethod;
  color: ServerColor;
  group: string;
  favorite: boolean;
  notes: string;
  createdAt: string;
  roles: ServerRole[];
  tags: string[];
  portKnockSequence: string;
  forceKeyboardInteractive: boolean;
  jumpHost: JumpHostProfile | null;
  terminalFontSize: number;
};

const DEFAULT_ROLES: ServerRole[] = ["ssh", "sftp"];
const withDefaults = (server: Partial<ServerProfile> & Pick<ServerProfile, "id" | "name" | "host" | "port" | "username" | "authMethod" | "color" | "group" | "favorite" | "notes" | "createdAt">): ServerProfile => ({
  roles: DEFAULT_ROLES,
  tags: [],
  portKnockSequence: "",
  forceKeyboardInteractive: false,
  jumpHost: null,
  terminalFontSize: 12,
  ...server,
});

type ServerStoreValue = {
  servers: ServerProfile[];
  activeServerId: string | null;
  ready: boolean;
  activeServer: ServerProfile | null;
  addServer: (input: Omit<ServerProfile, "id" | "createdAt">) => Promise<ServerProfile>;
  updateServer: (id: string, input: Partial<Omit<ServerProfile, "id" | "createdAt">>) => Promise<void>;
  removeServer: (id: string) => Promise<void>;
  selectServer: (id: string) => Promise<void>;
};

const SERVERS_KEY = "server-ide.server-profiles.v1";
const ACTIVE_KEY = "server-ide.active-server.v1";
const ServerContext = createContext<ServerStoreValue | null>(null);

async function persist(servers: ServerProfile[], activeServerId: string | null) {
  await Promise.all([AsyncStorage.setItem(SERVERS_KEY, JSON.stringify(servers)), activeServerId ? AsyncStorage.setItem(ACTIVE_KEY, activeServerId) : AsyncStorage.removeItem(ACTIVE_KEY)]);
}

export function ServerProvider({ children }: { children: React.ReactNode }) {
  const [servers, setServers] = useState<ServerProfile[]>([]);
  const [activeServerId, setActiveServerId] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    Promise.all([AsyncStorage.getItem(SERVERS_KEY), AsyncStorage.getItem(ACTIVE_KEY)]).then(([storedServers, storedActive]) => {
      try {
        const decoded = storedServers ? JSON.parse(storedServers) : [];
        if (Array.isArray(decoded)) setServers(decoded.map((server: ServerProfile) => withDefaults(server)));
        if (storedActive) setActiveServerId(storedActive);
      } finally {
        setReady(true);
      }
    }).catch(() => setReady(true));
  }, []);

  const addServer = useCallback(async (input: Omit<ServerProfile, "id" | "createdAt">) => {
    const server: ServerProfile = withDefaults({ ...input, id: `server-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`, createdAt: new Date().toISOString() });
    setServers((current) => { const next = [server, ...current]; const nextActive = activeServerId ?? server.id; setActiveServerId(nextActive); void persist(next, nextActive); return next; });
    return server;
  }, [activeServerId]);

  const updateServer = useCallback(async (id: string, input: Partial<Omit<ServerProfile, "id" | "createdAt">>) => {
    setServers((current) => { const next = current.map((server) => server.id === id ? { ...server, ...input } : server); void persist(next, activeServerId); return next; });
  }, [activeServerId]);

  const removeServer = useCallback(async (id: string) => {
    setServers((current) => { const next = current.filter((server) => server.id !== id); const nextActive = activeServerId === id ? next[0]?.id ?? null : activeServerId; setActiveServerId(nextActive); void persist(next, nextActive); return next; });
  }, [activeServerId]);

  const selectServer = useCallback(async (id: string) => { setActiveServerId(id); await AsyncStorage.setItem(ACTIVE_KEY, id); }, []);
  const activeServer = useMemo(() => servers.find((server) => server.id === activeServerId) ?? servers[0] ?? null, [servers, activeServerId]);
  const value = useMemo(() => ({ servers, activeServerId, ready, activeServer, addServer, updateServer, removeServer, selectServer }), [servers, activeServerId, ready, activeServer, addServer, updateServer, removeServer, selectServer]);

  return <ServerContext.Provider value={value}>{children}</ServerContext.Provider>;
}

export function useServerStore() {
  const value = useContext(ServerContext);
  if (!value) throw new Error("useServerStore must be used within ServerProvider");
  return value;
}
