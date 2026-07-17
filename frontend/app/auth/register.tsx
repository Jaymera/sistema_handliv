import "../../src/global.css";

import { router } from "expo-router";
import { useState } from "react";
import { ActivityIndicator, Pressable, Text, TextInput, View } from "react-native";

import { useAuthStore } from "@/state/authStore";

export default function RegisterScreen() {
  const register = useAuthStore((s) => s.register);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit() {
    setError(null);
    setLoading(true);
    try {
      await register({ name: name.trim(), email: email.trim(), phone: phone.trim() || undefined, password });
      router.replace("/");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Erro ao cadastrar");
    } finally {
      setLoading(false);
    }
  }

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-6 gap-4">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white">Criar conta</Text>
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={name} onChangeText={setName} placeholder="Nome" placeholderTextColor="#888" />
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={email} onChangeText={setEmail} placeholder="Email" placeholderTextColor="#888" autoCapitalize="none" keyboardType="email-address" />
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={phone} onChangeText={setPhone} placeholder="Celular" placeholderTextColor="#888" />
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={password} onChangeText={setPassword} placeholder="Senha (mín 8, letras+números)" placeholderTextColor="#888" secureTextEntry />
      {error ? <Text className="text-red-500">{error}</Text> : null}
      <Pressable className="bg-blue-600 px-4 py-3 rounded-md items-center disabled:opacity-50" onPress={submit} disabled={loading}>
        {loading ? <ActivityIndicator color="#fff" /> : <Text className="text-white font-semibold">Cadastrar</Text>}
      </Pressable>
    </View>
  );
}