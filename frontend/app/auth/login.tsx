import "../../src/global.css";

import { router } from "expo-router";
import { useState } from "react";
import { ActivityIndicator, Pressable, Text, TextInput, View } from "react-native";

import { authApi } from "@/api/client";
import { useAuthStore } from "@/state/authStore";

export default function LoginScreen() {
  const login = useAuthStore((s) => s.login);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit() {
    setError(null);
    setLoading(true);
    try {
      await login({ email: email.trim(), password });
      router.replace("/");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Erro ao entrar");
    } finally {
      setLoading(false);
    }
  }

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-6 gap-4">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white">Entrar</Text>
      <TextInput
        className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white"
        value={email}
        onChangeText={setEmail}
        placeholder="Email"
        placeholderTextColor="#888"
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <TextInput
        className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white"
        value={password}
        onChangeText={setPassword}
        placeholder="Senha"
        placeholderTextColor="#888"
        secureTextEntry
      />
      {error ? <Text className="text-red-500">{error}</Text> : null}
      <Pressable
        className="bg-blue-600 px-4 py-3 rounded-md items-center disabled:opacity-50"
        onPress={submit}
        disabled={loading}
      >
        {loading ? <ActivityIndicator color="#fff" /> : <Text className="text-white font-semibold">Entrar</Text>}
      </Pressable>
      <Pressable onPress={() => router.push("/auth/register")}>
        <Text className="text-blue-600 text-center">Criar conta</Text>
      </Pressable>
      <Pressable onPress={() => router.push("/auth/forgot")}>
        <Text className="text-blue-600 text-center text-sm">Esqueci a senha</Text>
      </Pressable>
      <Pressable
        className="mt-4 bg-amber-500 px-4 py-3 rounded-md items-center"
        onPress={() => { if (typeof window !== "undefined") window.open("https://handliv.com", "_blank"); }}
      >
        <Text className="text-white font-semibold">Ver Planos & Preços</Text>
      </Pressable>
    </View>
  );
}