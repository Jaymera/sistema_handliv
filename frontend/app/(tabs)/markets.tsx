import "../../src/global.css";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { useState } from "react";

import { assetsApi, watchlistApi } from "@/api/client";

const MARKETS = ["B3", "NASDAQ", "NYSE", "CRYPTO", "FOREX", "COMMODITY"];

const MARKET_COLORS: Record<string, string> = {
  B3: "#2563eb",
  NASDAQ: "#16a34a",
  NYSE: "#d97706",
  CRYPTO: "#7c3aed",
  FOREX: "#0891b2",
  COMMODITY: "#ea580c",
};

export default function MarketsScreen() {
  const qc = useQueryClient();
  const [market, setMarket] = useState<string | null>(null);
  const [q, setQ] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["assets", { market, q }],
    queryFn: () => assetsApi.list({ market: market || undefined, q: q || undefined, limit: 100 }),
  });

  const { data: watchlist } = useQuery({
    queryKey: ["watchlist"],
    queryFn: watchlistApi.list,
  });

  const inWatchlist = (symbol: string) =>
    (watchlist as { asset: { symbol: string } }[] | undefined)?.some(
      (w) => w.asset.symbol === symbol,
    ) ?? false;

  const toggleWatchlist = async (symbol: string) => {
    try {
      if (inWatchlist(symbol)) await watchlistApi.remove(symbol);
      else await watchlistApi.add(symbol);
      qc.invalidateQueries({ queryKey: ["watchlist"] });
    } catch {}
  };

  const assets = (data?.items as any[]) ?? [];

  return (
    <View className="flex-1 bg-white dark:bg-neutral-950 p-4">
      <Text className="text-neutral-900 dark:text-white text-xl font-bold mb-3">Mercados</Text>

      {/* Search bar (moved from Busca tab) */}
      <View className="flex-row items-center border border-neutral-300 dark:border-neutral-700 rounded-xl px-3 mb-3">
        <Text className="text-neutral-400 mr-2">🔍</Text>
        <TextInput
          className="flex-1 py-3 text-neutral-900 dark:text-white"
          value={q}
          onChangeText={setQ}
          placeholder="Buscar símbolo ou nome (ex: PETR, Apple)"
          placeholderTextColor="#888"
          autoCapitalize="none"
          autoCorrect={false}
        />
        {q.length > 0 ? (
          <Pressable onPress={() => setQ("")}>
            <Text className="text-neutral-400">✕</Text>
          </Pressable>
        ) : null}
      </View>

      {/* Market chips */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} className="mb-3" contentContainerStyle={{ gap: 8 }}>
        {["Todos", ...MARKETS].map((item) => {
          const active = (item === "Todos" && !market) || market === item;
          return (
            <Pressable
              key={item}
              onPress={() => setMarket(item === "Todos" ? null : item)}
              className={`px-4 py-2 rounded-full ${active ? "" : "bg-neutral-100 dark:bg-neutral-800"}`}
              style={active ? { backgroundColor: MARKET_COLORS[item] || "#2563eb" } : undefined}
            >
              <Text className={active ? "text-white font-semibold" : "text-neutral-500"}>
                {item}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>

      {isLoading ? (
        <ActivityIndicator size="large" color="#2563eb" className="mt-10" />
      ) : assets.length > 0 ? (
        <ScrollView contentContainerStyle={{ paddingBottom: 24 }}>
          {assets.map((item) => {
            const starred = inWatchlist(item.symbol);
            const color = MARKET_COLORS[item.market] || "#737373";
            return (
              <Pressable
                key={item.symbol}
                className="flex-row justify-between items-center bg-neutral-50 dark:bg-neutral-900 rounded-xl px-4 py-3 mb-2"
                onPress={() => router.push(`/asset/${encodeURIComponent(item.symbol)}`)}
              >
                <View className="flex-1 pr-2">
                  <View className="flex-row items-center gap-2">
                    <Text className="text-neutral-900 dark:text-white font-bold">
                      {item.display_symbol}
                    </Text>
                    <View className="px-2 py-0.5 rounded-full" style={{ backgroundColor: color + "20" }}>
                      <Text style={{ color }} className="text-xs font-semibold">{item.market}</Text>
                    </View>
                  </View>
                  <Text className="text-neutral-500 text-sm mt-0.5" numberOfLines={1}>
                    {item.name}
                  </Text>
                </View>
                <Pressable
                  hitSlop={8}
                  onPress={() => toggleWatchlist(item.symbol)}
                  className="p-1"
                >
                  <Text style={{ color: starred ? "#f59e0b" : "#a1a1aa", fontSize: 22 }}>
                    {starred ? "★" : "☆"}
                  </Text>
                </Pressable>
              </Pressable>
            );
          })}
        </ScrollView>
      ) : (
        <Text className="text-neutral-500 text-center mt-10">
          {q ? `Nenhum resultado para "${q}".` : "Nenhum ativo disponível neste mercado."}
        </Text>
      )}
    </View>
  );
}