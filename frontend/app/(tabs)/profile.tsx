import "../../src/global.css";

import { useRouter } from "expo-router";
import { Text, TouchableOpacity, View } from "react-native";

import { useAuthStore } from "@/state/authStore";

export default function ProfileScreen() {
  const { user, logout } = useAuthStore();
  const router = useRouter();

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-4">
      <Text className="text-neutral-900 dark:text-white text-xl font-bold">Perfil</Text>
      {user ? (
        <Text className="text-neutral-700 dark:text-neutral-300 mt-2">
          {user.name} • {user.email}
        </Text>
      ) : null}
      <TouchableOpacity
        className="mt-4 bg-red-500 px-4 py-3 rounded-md"
        onPress={() => {
          logout();
          router.replace("/auth/login");
        }}
      >
        <Text className="text-white font-semibold">Sair</Text>
      </TouchableOpacity>
      {user?.role === "super_admin" ? (
        <TouchableOpacity
          className="mt-3 bg-blue-600 px-4 py-3 rounded-md"
          onPress={() => router.push("/admin")}
        >
          <Text className="text-white font-semibold">Painel Admin</Text>
        </TouchableOpacity>
      ) : null}
    </View>
  );
}