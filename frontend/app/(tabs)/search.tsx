import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, FlatList, Pressable, Text, TextInput, View } from "react-native";
import { useState } from "react";

import { assetsApi } from "@/api/client";

export default function SearchScreen() {
  const [q, setQ] = useState("");
  const { data, isLoading } = useQuery({
    queryKey: ["assets", { q }],
    queryFn: () => assetsApi.list({ q, limit: 50 }),
    enabled: q.length > 0,
  });

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-4">
      <Text className="text-neutral-900 dark:text-white text-xl font-bold mb-3">
        Buscar ativos
      </Text>
      <TextInput
        className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white mb-3"
        value={q}
        onChangeText={setQ}
        placeholder="Digite o símbolo ou nome (ex: PETR, Apple)"
        placeholderTextColor="#888"
        autoCapitalize="none"
      />
      {isLoading ? (
        <ActivityIndicator />
      ) : q.length > 0 && data && data.items.length > 0 ? (
        <FlatList
          data={data.items as any[]}
          keyExtractor={(item) => item.symbol}
          renderItem={({ item }) => (
            <Pressable
              className="flex-row justify-between items-center border-b border-neutral-200 dark:border-neutral-800 py-3"
              onPress={() => router.push(`/asset/${item.symbol}`)}
            >
              <View>
                <Text className="text-neutral-900 dark:text-white font-semibold">
                  {item.display_symbol}
                </Text>
                <Text className="text-neutral-500 text-sm">{item.name}</Text>
              </View>
              <Text className="text-neutral-400 text-xs bg-neutral-100 dark:bg-neutral-800 px-2 py-1 rounded">
                {item.market}
              </Text>
            </Pressable>
          )}
        />
      ) : q.length > 0 ? (
        <Text className="text-neutral-500">Nenhum resultado para "{q}".</Text>
      ) : (
        <Text className="text-neutral-500">Digite para buscar.</Text>
      )}
    </View>
  );
}