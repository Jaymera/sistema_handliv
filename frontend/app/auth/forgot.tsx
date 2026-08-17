import "../../src/global.css";

import { useState } from "react";
import { KeyboardAvoidingView, Platform, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { authApi } from "@/api/client";
import { C, Card, Input, PrimaryButton } from "@/components/ui";

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
    <KeyboardAvoidingView className="flex-1 bg-night" behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: "center", paddingHorizontal: 24, paddingVertical: 40 }}>
        <View className="items-center mb-8">
          <View className="w-14 h-14 rounded-2xl items-center justify-center mb-3" style={{ backgroundColor: C.accent + "22" }}>
            <Ionicons name="key" size={26} color={C.accent} />
          </View>
          <Text className="text-ink text-2xl font-bold">Esqueci a senha</Text>
        </View>

        <Card className="p-5">
          {sent ? (
            <Text className="text-ink-soft text-center leading-6">
              Se o email existir, enviamos um link de redefinição (validade 30 min). Verifique sua caixa de entrada.
            </Text>
          ) : (
            <>
              <Input value={email} onChangeText={setEmail} placeholder="Email" autoCapitalize="none" keyboardType="email-address" onSubmitEditing={submit} />
              <PrimaryButton label="Enviar link" onPress={submit} loading={loading} />
            </>
          )}
        </Card>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
