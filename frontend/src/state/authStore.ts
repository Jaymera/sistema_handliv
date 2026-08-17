import { create } from "zustand";
import { Platform } from "react-native";

import { Credentials } from "@/types/auth";
import * as SecureStore from "expo-secure-store";
import { authApi } from "@/api/client";

const secureStorage = {
  async getItem(key: string): Promise<string | null> {
    if (Platform.OS === "web") return localStorage.getItem(key);
    return SecureStore.getItemAsync(key);
  },
  async setItem(key: string, value: string): Promise<void> {
    if (Platform.OS === "web") localStorage.setItem(key, value);
    else await SecureStore.setItemAsync(key, value);
  },
  async deleteItem(key: string): Promise<void> {
    if (Platform.OS === "web") localStorage.removeItem(key);
    else await SecureStore.deleteItemAsync(key);
  },
};

interface User {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  role: "user" | "super_admin";
  locale: string;
  theme: string;
  force_password_change: boolean;
  plan?: { code: string; name: string; limits: Record<string, unknown> } | null;
}

interface AuthState {
  hydrated: boolean;
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  lastActivityAt?: number;
  hydrate: () => Promise<void>;
  login: (c: Credentials) => Promise<void>;
  register: (c: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
  touchActivity: () => void;
  isSessionExpired: () => boolean;
}

interface RegisterRequest {
  name: string;
  email: string;
  phone?: string;
  password: string;
}

const KEY_ACCESS = "auth.access";
const KEY_REFRESH = "auth.refresh";
const KEY_USER = "auth.user";
const KEY_LAST_ACTIVITY = "auth.lastActivity";

/** Sessão expira após 60 minutos sem atividade. */
export const SESSION_TIMEOUT_MS = 60 * 60 * 1000;

async function persistTokens(access: string, refresh: string, user: User) {
  await Promise.all([
    secureStorage.setItem(KEY_ACCESS, access),
    secureStorage.setItem(KEY_REFRESH, refresh),
    secureStorage.setItem(KEY_USER, JSON.stringify(user)),
    secureStorage.setItem(KEY_LAST_ACTIVITY, String(Date.now())),
  ]);
}

async function clearTokens() {
  await Promise.all([
    secureStorage.deleteItem(KEY_ACCESS),
    secureStorage.deleteItem(KEY_REFRESH),
    secureStorage.deleteItem(KEY_USER),
    secureStorage.deleteItem(KEY_LAST_ACTIVITY),
  ]);
}

export const useAuthStore = create<AuthState>((set, get) => ({
  hydrated: false,
  user: null,
  accessToken: null,
  refreshToken: null,
  hydrate: async () => {
    const [access, refresh, userJson, lastAct] = await Promise.all([
      secureStorage.getItem(KEY_ACCESS),
      secureStorage.getItem(KEY_REFRESH),
      secureStorage.getItem(KEY_USER),
      secureStorage.getItem(KEY_LAST_ACTIVITY),
    ]);
    const lastActivityAt = lastAct ? parseInt(lastAct, 10) : access ? Date.now() : 0;
    set({ accessToken: access, refreshToken: refresh, user: userJson ? JSON.parse(userJson) : null, hydrated: true, lastActivityAt });
  },
  login: async (c) => {
    const data = await authApi.login(c);
    await persistTokens(data.access_token, data.refresh_token, data.user);
    set({ accessToken: data.access_token, refreshToken: data.refresh_token, user: data.user });
  },
  register: async (c) => {
    const data = await authApi.register(c);
    await persistTokens(data.access_token, data.refresh_token, data.user);
    set({ accessToken: data.access_token, refreshToken: data.refresh_token, user: data.user });
  },
  logout: async () => {
    const refresh = get().refreshToken;
    if (refresh) {
      try {
        await authApi.logout(refresh);
      } catch {}
    }
    await clearTokens();
    set({ user: null, accessToken: null, refreshToken: null });
  },
  refresh: async () => {
    const refresh = get().refreshToken;
    if (!refresh) {
      throw new Error("no refresh token");
    }
    const data = await authApi.refresh(refresh);
    await persistTokens(data.access_token, data.refresh_token, data.user);
    set({ accessToken: data.access_token, refreshToken: data.refresh_token, user: data.user });
  },
  touchActivity: () => {
    const now = Date.now();
    if (get().accessToken) {
      set({ lastActivityAt: now });
      if (Platform.OS === "web") localStorage.setItem(KEY_LAST_ACTIVITY, String(now));
    }
  },
  isSessionExpired: () => {
    const state = get();
    if (!state.accessToken) return false;
    const last = state.lastActivityAt ?? 0;
    return Date.now() - last > SESSION_TIMEOUT_MS;
  },
}));