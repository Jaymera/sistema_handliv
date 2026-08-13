import "../../src/global.css";

import { useRouter } from "expo-router";
import { Pressable, ScrollView, Text, View } from "react-native";

import { useAuthStore } from "@/state/authStore";

export default function ProfileScreen() {
  const { user, logout } = useAuthStore();
  const router = useRouter();

  const planLabel = (user?.plan?.code ?? "free").toUpperCase();

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4">
      {/* Header */}
      <View className="mb-5">
        <Text className="text-neutral-900 dark:text-white text-2xl font-bold">Perfil</Text>
        {user ? (
          <Text className="text-neutral-500 mt-1">{user.name} • {user.email}</Text>
        ) : null}
      </View>

      {/* Plan card */}
      {user ? (
        <View className="bg-gradient-to-r from-blue-600 to-indigo-600 rounded-2xl px-5 py-4 mb-4">
          <Text className="text-white text-xs font-semibold tracking-wide">PLANO ATUAL</Text>
          <Text className="text-white text-2xl font-bold mt-1">{planLabel}</Text>
        </View>
      ) : null}

      {/* Menu */}
      <View className="gap-2">
        <MenuItem icon="🚀" label="Recursos da Assinatura" onPress={() => router.push("/(tabs)/recursos")} />
        <MenuItem icon="📉" label="Painel de Trading & MT5" onPress={() => router.push("/trading-panel")} />
        <MenuItem icon="💳" label="Ver Planos & Assinar" onPress={() => { if (typeof window !== "undefined") window.open("https://handliv.com", "_blank"); }} />
        {user?.role === "super_admin" ? (
          <MenuItem icon="🛠️" label="Painel Admin" onPress={() => router.push("/admin")} />
        ) : null}
      </View>

      <Pressable
        className="mt-6 bg-red-500 px-4 py-3 rounded-xl items-center"
        onPress={() => {
          logout();
          router.replace("/auth/login");
        }}
      >
        <Text className="text-white font-semibold">Sair da Conta</Text>
      </Pressable>
    </ScrollView>
  );
}

function MenuItem({ icon, label, onPress }: { icon: string; label: string; onPress: () => void }) {
  return (
    <Pressable
      className="flex-row items-center justify-between bg-neutral-50 dark:bg-neutral-900 rounded-xl px-4 py-3.5"
      onPress={onPress}
    >
      <View className="flex-row items-center">
        <Text className="text-xl mr-3">{icon}</Text>
        <Text className="text-neutral-900 dark:text-white font-semibold">{label}</Text>
      </View>
      <Text className="text-neutral-400 text-lg">›</Text>
    </Pressable>
  );
}