import "../../src/global.css";

import { router } from "expo-router";
import { useState } from "react";
import { KeyboardAvoidingView, Platform, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { useAuthStore } from "@/state/authStore";
import { C, Card, GhostButton, Input, PrimaryButton } from "@/components/ui";

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
    <KeyboardAvoidingView className="flex-1 bg-night" behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: "center", paddingHorizontal: 24, paddingVertical: 40 }}>
        {/* Brand */}
        <View className="items-center mb-8">
          <View className="w-16 h-16 rounded-2xl items-center justify-center mb-3" style={{ backgroundColor: C.brand + "22" }}>
            <Ionicons name="trending-up" size={30} color={C.brand} />
          </View>
          <Text className="text-ink text-3xl font-bold">Handliv</Text>
          <Text className="text-ink-soft text-sm mt-1">Trading Intelligence Platform</Text>
        </View>

        <Card className="p-5">
          <Text className="text-ink text-xl font-bold mb-4">Entrar</Text>
          <Input
            value={email}
            onChangeText={setEmail}
            placeholder="Email"
            autoCapitalize="none"
            keyboardType="email-address"
          />
          <Input
            value={password}
            onChangeText={setPassword}
            placeholder="Senha"
            secureTextEntry
            onSubmitEditing={submit}
          />
          {error ? <Text className="text-down text-sm mb-3">{error}</Text> : null}
          <PrimaryButton label="Entrar" onPress={submit} loading={loading} />

          <View className="flex-row justify-center gap-5 mt-4">
            <Text className="text-accent text-sm font-semibold" onPress={() => router.push("/auth/register")}>
              Criar conta
            </Text>
            <Text className="text-ink-soft text-sm" onPress={() => router.push("/auth/forgot")}>
              Esqueci a senha
            </Text>
          </View>
        </Card>

        <View className="mt-6">
          <GhostButton
            label="Ver planos & preços"
            color={C.brand}
            onPress={() => router.push("/pricing")}
          />
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
