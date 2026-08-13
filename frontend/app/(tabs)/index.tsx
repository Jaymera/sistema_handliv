import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router, Redirect } from "expo-router";
import { ActivityIndicator, Dimensions, FlatList, Pressable, ScrollView, Text, View } from "react-native";
import { LineChart } from "react-native-chart-kit";

import { useAuthStore } from "@/state/authStore";
import { watchlistApi, assetsApi } from "@/api/client";

const screenWidth = Dimensions.get("window").width;

export default function DashboardScreen() {
  const hydrated = useAuthStore((s) => s.hydrated);
  const token = useAuthStore((s) => s.accessToken);
  const user = useAuthStore((s) => s.user);

  if (!hydrated) return null;
  if (!token) return <Redirect href="/auth/login" />;

  const { data: watchlist, isLoading: wlLoading } = useQuery({
    queryKey: ["watchlist"],
    queryFn: watchlistApi.list,
  });
  const { data: suggested, isLoading: sgLoading } = useQuery({
    queryKey: ["suggested"],
    queryFn: watchlistApi.suggested,
  });
  const { data: assets, isLoading: aLoading } = useQuery({
    queryKey: ["assets", { limit: 200 }],
    queryFn: () => assetsApi.list({ limit: 100 }),
  });

  // Count by market
  const marketCounts: Record<string, number> = {};
  (assets?.items as any[])?.forEach((a) => {
    marketCounts[a.market] = (marketCounts[a.market] || 0) + 1;
  });

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4" nestedScrollEnabled>
      {/* Greeting */}
      <View className="mb-4">
        <Text className="text-neutral-900 dark:text-white text-2xl font-bold">
          Olá, {user?.name?.split(" ")[0] ?? "Investidor"} 👋
        </Text>
        <Text className="text-neutral-500">Aqui está o resumo do seu mercado hoje.</Text>
      </View>

      {/* Stat Cards */}
      <View className="flex-row gap-3 mb-4">
        <View className="flex-1 bg-blue-50 dark:bg-blue-950 rounded-2xl p-4">
          <Text className="text-blue-600 dark:text-blue-400 text-3xl font-bold">
            {watchlist?.length ?? 0}
          </Text>
          <Text className="text-neutral-500 text-sm">Na Watchlist</Text>
        </View>
        <View className="flex-1 bg-green-50 dark:bg-green-950 rounded-2xl p-4">
          <Text className="text-green-600 dark:text-green-400 text-3xl font-bold">
            {(assets?.items as any[])?.length ?? 0}
          </Text>
          <Text className="text-neutral-500 text-sm">Ativos</Text>
        </View>
        <View className="flex-1 bg-amber-50 dark:bg-amber-950 rounded-2xl p-4">
          <Text className="text-amber-600 dark:text-amber-400 text-3xl font-bold">
            {Object.keys(marketCounts).length}
          </Text>
          <Text className="text-neutral-500 text-sm">Mercados</Text>
        </View>
      </View>

      {/* Market breakdown */}
      <Text className="text-neutral-900 dark:text-white text-lg font-bold mb-2">Mercados</Text>
      <View className="flex-row flex-wrap gap-2 mb-4">
        {Object.entries(marketCounts).map(([market, count]) => {
          const colors: Record<string, string> = {
            B3: "#2563eb", NASDAQ: "#16a34a", NYSE: "#d97706",
            CRYPTO: "#7c3aed", FOREX: "#0891b2", COMMODITY: "#ea580c",
          };
          const bg = colors[market] + "15";
          return (
            <View key={market} className="px-3 py-2 rounded-xl" style={{ backgroundColor: bg }}>
              <Text style={{ color: colors[market] || "#737373" }} className="font-semibold">
                {market} • {count}
              </Text>
            </View>
          );
        })}
      </View>

      {/* Watchlist */}
      <Text className="text-neutral-900 dark:text-white text-lg font-bold mb-2">
        ⭐ Minha Watchlist
      </Text>
      {wlLoading ? (
        <ActivityIndicator className="mb-4" />
      ) : watchlist && watchlist.length > 0 ? (
        <View className="mb-4 gap-1">
          {watchlist.map((w, i) => (
            <Pressable
              key={i}
              className="flex-row justify-between items-center bg-neutral-50 dark:bg-neutral-900 rounded-xl px-4 py-3"
              onPress={() => router.push(`/asset/${w.asset.symbol}`)}
            >
              <View>
                <Text className="text-neutral-900 dark:text-white font-semibold">{w.asset.symbol}</Text>
                <Text className="text-neutral-500 text-sm">{w.asset.name}</Text>
              </View>
              <Text className="text-neutral-400">›</Text>
            </Pressable>
          ))}
        </View>
      ) : (
        <Text className="text-neutral-500 mb-4">Sua watchlist está vazia. Adicione ativos sugeridos abaixo.</Text>
      )}

      {/* Suggested */}
      <Text className="text-neutral-900 dark:text-white text-lg font-bold mb-2">
        🔥 Sugeridos para Você
      </Text>
      {sgLoading ? (
        <ActivityIndicator className="mb-4" />
      ) : suggested && suggested.length > 0 ? (
        <View className="mb-4 gap-1">
          {suggested.slice(0, 10).map((s, i) => (
            <Pressable
              key={i}
              className="flex-row justify-between items-center bg-neutral-50 dark:bg-neutral-900 rounded-xl px-4 py-3"
              onPress={() => router.push(`/asset/${s.symbol}`)}
            >
              <View>
                <Text className="text-neutral-900 dark:text-white font-semibold">{s.symbol}</Text>
                <Text className="text-neutral-500 text-sm">{s.name}</Text>
              </View>
              <View className="flex-row items-center gap-2">
                <Text className="text-neutral-400 text-xs bg-neutral-200 dark:bg-neutral-800 px-2 py-1 rounded-full">
                  {s.market}
                </Text>
                <Text className="text-neutral-400">›</Text>
              </View>
            </Pressable>
          ))}
        </View>
      ) : (
        <Text className="text-neutral-500 mb-4">Nenhum ativo sugerido disponível.</Text>
      )}

      {/* Quick actions */}
      <View className="flex-row gap-3 mb-6">
        <Pressable
          className="flex-1 bg-blue-600 rounded-xl py-3 items-center"
          onPress={() => router.push("/(tabs)/markets")}
        >
          <Text className="text-white font-semibold">Ver Mercados</Text>
        </Pressable>
        <Pressable
          className="flex-1 bg-neutral-200 dark:bg-neutral-800 rounded-xl py-3 items-center"
          onPress={() => router.push("/(tabs)/search")}
        >
          <Text className="text-neutral-900 dark:text-white font-semibold">Buscar Ativo</Text>
        </Pressable>
        <Pressable
          className="px-4 bg-amber-500 rounded-xl py-3 items-center"
          onPress={() => { if (typeof window !== "undefined") window.open("https://handliv.com", "_blank"); }}
        >
          <Text className="text-white font-semibold">Assinar</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}