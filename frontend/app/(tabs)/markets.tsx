import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, FlatList, Pressable, Text, View } from "react-native";
import { useState } from "react";

import { assetsApi } from "@/api/client";

export default function MarketsScreen() {
  const [market, setMarket] = useState<string | null>(null);
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ["assets", { market, page, limit: 100 }],
    queryFn: () => assetsApi.list({ market: market || undefined, page, limit: 100 }),
  });

  const markets = ["B3", "NASDAQ", "NYSE", "CRYPTO", "FOREX", "COMMODITY"];

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-4">
      <Text className="text-neutral-900 dark:text-white text-xl font-bold mb-3">Mercados</Text>

      {/* Market filter chips */}
      <FlatList
        horizontal
        data={["Todos", ...markets]}
        keyExtractor={(item) => item}
        renderItem={({ item }) => {
          const active = (item === "Todos" && !market) || market === item;
          return (
            <Pressable
              onPress={() => { setMarket(item === "Todos" ? null : item); setPage(1); }}
              className={`px-4 py-2 rounded-full mr-2 ${active ? "bg-blue-600" : "bg-neutral-100 dark:bg-neutral-800"}`}
            >
              <Text className={active ? "text-white font-semibold" : "text-neutral-500"}>{item}</Text>
            </Pressable>
          );
        }}
        className="mb-3"
      />

      {isLoading ? (
        <ActivityIndicator size="large" color="#2563eb" />
      ) : data && data.items.length > 0 ? (
        <FlatList
          data={data.items as any[]}
          keyExtractor={(item) => item.symbol}
          renderItem={({ item }) => (
            <Pressable
              className="flex-row justify-between items-center bg-neutral-50 dark:bg-neutral-900 rounded-xl px-4 py-3 mb-1"
              onPress={() => router.push(`/asset/${item.symbol}`)}
            >
              <View>
                <Text className="text-neutral-900 dark:text-white font-bold">{item.display_symbol}</Text>
                <Text className="text-neutral-500 text-sm" numberOfLines={1}>{item.name}</Text>
              </View>
              <Text className="text-neutral-400 text-xs bg-neutral-200 dark:bg-neutral-800 px-2 py-1 rounded-full">
                {item.market}
              </Text>
            </Pressable>
          )}
        />
      ) : (
        <Text className="text-neutral-500">Nenhum ativo disponível.</Text>
      )}
    </View>
  );
}