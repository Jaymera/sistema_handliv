import "../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { ActivityIndicator, ScrollView, Text, View } from "react-native";

import { adminApi } from "@/api/client";

export default function AdminScreen() {
  const { data: weights, isLoading: wLoading } = useQuery({
    queryKey: ["weights"],
    queryFn: adminApi.weights,
  });
  const { data: users, isLoading: uLoading } = useQuery({
    queryKey: ["admin-users"],
    queryFn: adminApi.users,
  });

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white">
        Painel Admin
      </Text>

      <Text className="mt-5 text-neutral-900 dark:text-white font-semibold">
        Pesos do motor
      </Text>
      {wLoading ? (
        <ActivityIndicator />
      ) : weights ? (
        <View className="mt-2 gap-1">
          <Text className="text-neutral-900 dark:text-white">
            Técnica: {Math.round(weights.technical_weight * 100)}%
          </Text>
          <Text className="text-neutral-900 dark:text-white">
            Valuation: {Math.round(weights.valuation_weight * 100)}%
          </Text>
          <Text className="text-neutral-900 dark:text-white">
            Sentimento: {Math.round(weights.sentiment_weight * 100)}%
          </Text>
          <Text className="text-neutral-500">
            Confiança mín.: {weights.min_confidence}
          </Text>
        </View>
      ) : null}

      <Text className="mt-5 text-neutral-900 dark:text-white font-semibold">
        Usuários
      </Text>
      {uLoading ? (
        <ActivityIndicator />
      ) : users && (users as any).items ? (
        <View className="mt-2 gap-1">
          {(users as any).items.map((u: any, i: number) => (
            <View
              key={u.id ?? i}
              className="flex-row justify-between border-b border-neutral-200 dark:border-neutral-800 py-2"
            >
              <View>
                <Text className="text-neutral-900 dark:text-white">
                  {u.name}
                </Text>
                <Text className="text-neutral-500 text-sm">{u.email}</Text>
              </View>
              <Text className="text-neutral-500 text-sm">
                {u.role} {u.is_active ? "✓" : "✗"}
              </Text>
            </View>
          ))}
        </View>
      ) : (
        <Text className="text-neutral-500">Nenhum usuário.</Text>
      )}
    </ScrollView>
  );
}