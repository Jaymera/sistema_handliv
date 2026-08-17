import "../src/global.css";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Stack, router } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { AppState, AppStateStatus } from "react-native";
import { useEffect } from "react";

import { C } from "@/components/ui";
import { useAuthStore } from "@/state/authStore";

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, staleTime: 60_000 } },
});

/** Desloga automaticamente após 60 minutos de inatividade. */
function useSessionTimeout() {
  useEffect(() => {
    const check = () => {
      const s = useAuthStore.getState();
      if (s.accessToken && s.isSessionExpired()) {
        s.logout().catch(() => {});
        router.replace("/auth/login");
      }
    };
    check();
    const interval = setInterval(check, 30_000);
    const sub = AppState.addEventListener("change", (state: AppStateStatus) => {
      if (state === "active") {
        useAuthStore.getState().touchActivity();
        check();
      }
    });
    return () => {
      clearInterval(interval);
      sub.remove();
    };
  }, []);
}

export default function RootLayout() {
  const hydrated = useAuthStore((s) => s.hydrated);
  const hydrate = useAuthStore((s) => s.hydrate);

  useEffect(() => {
    hydrate().catch(() => useAuthStore.setState({ hydrated: true }));
  }, [hydrate]);

  useSessionTimeout();

  if (!hydrated) {
    return null;
  }

  return (
    <QueryClientProvider client={queryClient}>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: C.bg },
        }}
      >
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="asset/[symbol]"
          options={{
            headerShown: true,
            title: "Ativo",
            headerStyle: { backgroundColor: C.deep },
            headerTintColor: C.ink,
            headerTitleStyle: { fontWeight: "700" },
          }}
        />
        <Stack.Screen
          name="auth/login"
          options={{ headerShown: false, title: "Entrar" }}
        />
        <Stack.Screen name="auth/register" options={{ headerShown: false, title: "Criar conta" }} />
        <Stack.Screen name="auth/forgot" options={{ headerShown: false, title: "Esqueci a senha" }} />
        <Stack.Screen name="auth/reset" options={{ headerShown: false, title: "Redefinir senha" }} />
        <Stack.Screen
          name="backtest/new"
          options={{
            headerShown: true,
            title: "Backtest",
            headerStyle: { backgroundColor: C.deep },
            headerTintColor: C.ink,
          }}
        />
        <Stack.Screen
          name="admin"
          options={{
            headerShown: true,
            title: "Admin",
            headerStyle: { backgroundColor: C.deep },
            headerTintColor: C.ink,
          }}
        />
        <Stack.Screen name="pricing" options={{ headerShown: false }} />
        <Stack.Screen
          name="trading-panel"
          options={{ headerShown: false, title: "Painel de Trading" }}
        />
      </Stack>
    </QueryClientProvider>
  );
}
