import "../../src/global.css";

import { router } from "expo-router";
import { useState } from "react";
import { KeyboardAvoidingView, Platform, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { useAuthStore } from "@/state/authStore";
import { C, Card, Input, PrimaryButton } from "@/components/ui";

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
    <KeyboardAvoidingView className="flex-1 bg-night" behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: "center", paddingHorizontal: 24, paddingVertical: 40 }}>
        <View className="items-center mb-8">
          <View className="w-14 h-14 rounded-2xl items-center justify-center mb-3" style={{ backgroundColor: C.brand + "22" }}>
            <Ionicons name="person-add" size={26} color={C.brand} />
          </View>
          <Text className="text-ink text-2xl font-bold">Criar conta</Text>
          <Text className="text-ink-soft text-sm mt-1">Comece grátis no plano Free</Text>
        </View>

        <Card className="p-5">
          <Input value={name} onChangeText={setName} placeholder="Nome completo" />
          <Input value={email} onChangeText={setEmail} placeholder="Email" autoCapitalize="none" keyboardType="email-address" />
          <Input value={phone} onChangeText={setPhone} placeholder="Celular (opcional)" keyboardType="phone-pad" />
          <Input value={password} onChangeText={setPassword} placeholder="Senha (mín 8, letras+números)" secureTextEntry onSubmitEditing={submit} />
          {error ? <Text className="text-down text-sm mb-3">{error}</Text> : null}
          <PrimaryButton label="Cadastrar" onPress={submit} loading={loading} />
        </Card>

        <Text className="text-ink-soft text-sm text-center mt-5">
          Já tem conta?{" "}
          <Text className="text-accent font-semibold" onPress={() => router.push("/auth/login")}>
            Entrar
          </Text>
        </Text>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
