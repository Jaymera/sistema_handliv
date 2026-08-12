import "../src/global.css";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useColorScheme } from "react-native";
import { useEffect } from "react";

import { useAuthStore } from "@/state/authStore";

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, staleTime: 60_000 } },
});

export default function RootLayout() {
  const scheme = useColorScheme();
  const hydrated = useAuthStore((s) => s.hydrated);
  const hydrate = useAuthStore((s) => s.hydrate);

  useEffect(() => {
    hydrate().catch(() => useAuthStore.setState({ hydrated: true }));
  }, [hydrate]);

  if (!hydrated) {
    return null;
  }

  return (
    <QueryClientProvider client={queryClient}>
      <StatusBar style={scheme === "dark" ? "light" : "dark"} />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="asset/[symbol]" options={{ headerShown: true, title: "Ativo" }} />
        <Stack.Screen name="auth/login" options={{ headerShown: true, title: "Entrar" }} />
        <Stack.Screen name="auth/register" options={{ headerShown: true, title: "Criar conta" }} />
        <Stack.Screen name="auth/forgot" options={{ headerShown: true, title: "Esqueci a senha" }} />
        <Stack.Screen name="auth/reset" options={{ headerShown: true, title: "Redefinir senha" }} />
        <Stack.Screen name="backtest/new" options={{ headerShown: true, title: "Backtest" }} />
        <Stack.Screen name="admin" options={{ headerShown: true, title: "Admin" }} />
        <Stack.Screen name="pricing" options={{ headerShown: false }} />
        <Stack.Screen name="trading-panel" options={{ headerShown: true, title: "Painel de Trading" }} />
      </Stack>
    </QueryClientProvider>
  );
}