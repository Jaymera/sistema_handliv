import "../src/global.css";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";

import { adminApi } from "@/api/client";

export default function AdminScreen() {
  const qc = useQueryClient();
  const { data: weights, isLoading: wLoading } = useQuery({ queryKey: ["weights"], queryFn: adminApi.weights });
  const { data: usersData, isLoading: uLoading } = useQuery({ queryKey: ["admin-users"], queryFn: adminApi.users });

  const toggleActive = async (userId: string, current: boolean) => {
    try {
      await adminApi.patchUser(userId, { is_active: !current });
      qc.invalidateQueries({ queryKey: ["admin-users"] });
    } catch {}
  };

  const changePlan = async (userId: string, planCode: string) => {
    try {
      await adminApi.patchUser(userId, { plan_code: planCode });
      qc.invalidateQueries({ queryKey: ["admin-users"] });
    } catch {}
  };

  const planColors: Record<string, string> = {
    free: "#737373", start: "#2563eb", ultimate: "#7c3aed",
  };

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white">Painel Admin</Text>

      {/* Pesos */}
      <Text className="mt-5 text-neutral-900 dark:text-white font-semibold">Pesos do motor</Text>
      {wLoading ? (
        <ActivityIndicator />
      ) : weights ? (
        <View className="mt-2 gap-1">
          <Text className="text-neutral-900 dark:text-white">Técnica: {Math.round(weights.technical_weight * 100)}%</Text>
          <Text className="text-neutral-900 dark:text-white">Valuation: {Math.round(weights.valuation_weight * 100)}%</Text>
          <Text className="text-neutral-900 dark:text-white">Sentimento: {Math.round(weights.sentiment_weight * 100)}%</Text>
          <Text className="text-neutral-500">Confiança mín.: {weights.min_confidence}</Text>
        </View>
      ) : null}

      {/* Usuários */}
      <Text className="mt-6 text-lg font-bold text-neutral-900 dark:text-white">Usuários</Text>
      {uLoading ? (
        <ActivityIndicator />
      ) : usersData && usersData.items.length > 0 ? (
        <View className="mt-2 gap-2">
          {usersData.items.map((u) => (
            <View key={u.id} className="border border-neutral-200 dark:border-neutral-800 rounded-2xl p-4">
              {/* Header */}
              <View className="flex-row justify-between items-start mb-2">
                <View className="flex-1">
                  <Text className="text-neutral-900 dark:text-white font-bold text-base">{u.name}</Text>
                  <Text className="text-neutral-500 text-sm">{u.email}</Text>
                  {u.last_login_at ? (
                    <Text className="text-neutral-400 text-xs">Último login: {new Date(u.last_login_at).toLocaleDateString("pt-BR")}</Text>
                  ) : null}
                </View>
                {/* Status badge */}
                <View className={`px-3 py-1 rounded-full ${u.is_active ? "bg-green-100" : "bg-red-100"}`}>
                  <Text className={u.is_active ? "text-green-700 text-xs font-bold" : "text-red-700 text-xs font-bold"}>
                    {u.is_active ? "✓ ATIVO" : "✗ INATIVO"}
                  </Text>
                </View>
              </View>

              {/* Plan badge */}
              <View className="flex-row items-center gap-2 mb-2">
                <View className="px-3 py-1 rounded-full" style={{ backgroundColor: (planColors[u.plan_code] || "#737373") + "20" }}>
                  <Text style={{ color: planColors[u.plan_code] || "#737373" }} className="text-xs font-bold">
                    {u.plan_name.toUpperCase()}
                  </Text>
                </View>
                <Text className="text-neutral-500 text-xs">Status: {u.subscription_status}</Text>
                {u.role === "super_admin" ? (
                  <Text className="text-amber-600 text-xs font-bold">ADMIN</Text>
                ) : null}
              </View>

              {/* Actions */}
              <View className="flex-row gap-2 flex-wrap">
                <Pressable
                  className={`px-3 py-2 rounded-lg ${u.is_active ? "bg-red-500" : "bg-green-500"}`}
                  onPress={() => toggleActive(u.id, u.is_active)}
                >
                  <Text className="text-white text-sm font-semibold">
                    {u.is_active ? "Desativar" : "Ativar"}
                  </Text>
                </Pressable>

                {/* Trocar plano */}
                {(["free", "start", "ultimate"] as const).map((code) => (
                  <Pressable
                    key={code}
                    className={`px-3 py-2 rounded-lg ${u.plan_code === code ? "bg-blue-600" : "bg-neutral-200 dark:bg-neutral-800"}`}
                    onPress={() => changePlan(u.id, code)}
                  >
                    <Text className={u.plan_code === code ? "text-white text-sm font-semibold" : "text-neutral-700 dark:text-neutral-300 text-sm font-semibold"}>
                      {code.toUpperCase()}
                    </Text>
                  </Pressable>
                ))}
              </View>
            </View>
          ))}
        </View>
      ) : (
        <Text className="text-neutral-500">Nenhum usuário.</Text>
      )}
    </ScrollView>
  );
}