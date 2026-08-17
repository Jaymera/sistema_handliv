import "../../src/global.css";

import { router } from "expo-router";
import { useState } from "react";
import { KeyboardAvoidingView, Platform, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { authApi } from "@/api/client";
import { C, Card, Input, PrimaryButton } from "@/components/ui";

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
    <KeyboardAvoidingView className="flex-1 bg-night" behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: "center", paddingHorizontal: 24, paddingVertical: 40 }}>
        <View className="items-center mb-8">
          <View className="w-14 h-14 rounded-2xl items-center justify-center mb-3" style={{ backgroundColor: C.brand + "22" }}>
            <Ionicons name="lock-closed" size={26} color={C.brand} />
          </View>
          <Text className="text-ink text-2xl font-bold">Redefinir senha</Text>
        </View>

        <Card className="p-5">
          <Input value={token} onChangeText={setToken} placeholder="Token recebido por email" autoCapitalize="none" />
          <Input value={password} onChangeText={setPassword} placeholder="Nova senha" secureTextEntry onSubmitEditing={submit} />
          {error ? <Text className="text-down text-sm mb-3">{error}</Text> : null}
          <PrimaryButton label="Redefinir" onPress={submit} loading={loading} />
        </Card>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
