import "../../src/global.css";

import { useState } from "react";
import { ActivityIndicator, Pressable, Text, TextInput, View } from "react-native";

import { authApi } from "@/api/client";

export default function ForgotScreen() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  async function submit() {
    setLoading(true);
    try {
      await authApi.forgot(email.trim());
      setSent(true);
    } finally {
      setLoading(false);
    }
  }

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-6 gap-4">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white">Esqueci a senha</Text>
      {sent ? (
        <Text className="text-neutral-700 dark:text-neutral-300">
          Se o email existir, enviamos um link de redefinição (validade 30 min).
        </Text>
      ) : (
        <>
          <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={email} onChangeText={setEmail} placeholder="Email" placeholderTextColor="#888" autoCapitalize="none" keyboardType="email-address" />
          <Pressable className="bg-blue-600 px-4 py-3 rounded-md items-center disabled:opacity-50" onPress={submit} disabled={loading}>
            {loading ? <ActivityIndicator color="#fff" /> : <Text className="text-white font-semibold">Enviar link</Text>}
          </Pressable>
        </>
      )}
    </View>
  );
}