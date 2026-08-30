import { Platform } from "react-native";
import * as SecureStore from "expo-secure-store";

export type ServerSecret = {
  password?: string;
  privateKey?: string;
  passphrase?: string;
  hostFingerprint?: string;
  jumpHostPassword?: string;
  jumpHostPrivateKey?: string;
  jumpHostPassphrase?: string;
};

const keyFor = (serverId: string) => `server-ide.secret.${serverId}`;

export async function readServerSecret(serverId: string): Promise<ServerSecret | null> {
  const key = keyFor(serverId);
  const raw = Platform.OS === "web" ? sessionStorage.getItem(key) : await SecureStore.getItemAsync(key);
  return raw ? JSON.parse(raw) as ServerSecret : null;
}

export async function saveServerSecret(serverId: string, secret: ServerSecret) {
  const value = JSON.stringify(secret);
  if (Platform.OS === "web") sessionStorage.setItem(keyFor(serverId), value);
  else await SecureStore.setItemAsync(keyFor(serverId), value, { keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY });
}

export async function deleteServerSecret(serverId: string) {
  if (Platform.OS === "web") sessionStorage.removeItem(keyFor(serverId));
  else await SecureStore.deleteItemAsync(keyFor(serverId));
}
