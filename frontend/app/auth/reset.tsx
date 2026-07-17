import "../../src/global.css";

import { router } from "expo-router";
import { useState } from "react";
import { ActivityIndicator, Pressable, Text, TextInput, View } from "react-native";

import { authApi } from "@/api/client";

export default function ResetScreen() {
  const [token, setToken] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setError(null);
    setLoading(true);
    try {
      await authApi.reset(token.trim(), password);
      router.replace("/auth/login");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Erro ao redefinir");
    } finally {
      setLoading(false);
    }
  }

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-6 gap-4">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white">Redefinir senha</Text>
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={token} onChangeText={setToken} placeholder="Token recebido por email" placeholderTextColor="#888" autoCapitalize="none" />
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={password} onChangeText={setPassword} placeholder="Nova senha" placeholderTextColor="#888" secureTextEntry />
      {error ? <Text className="text-red-500">{error}</Text> : null}
      <Pressable className="bg-blue-600 px-4 py-3 rounded-md items-center disabled:opacity-50" onPress={submit} disabled={loading}>
        {loading ? <ActivityIndicator color="#fff" /> : <Text className="text-white font-semibold">Redefinir</Text>}
      </Pressable>
    </View>
  );
}