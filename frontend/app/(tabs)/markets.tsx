import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";

import { assetsApi, watchlistApi } from "@/api/client";
import { C, Card, Empty, FavoriteStar, MarketBadge } from "@/components/ui";

const MARKETS = ["B3", "NASDAQ", "NYSE", "CRYPTO", "FOREX", "COMMODITY"];

export default function MarketsScreen() {
  const [market, setMarket] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["assets", { market, q, page, limit: 60 }],
    queryFn: () => assetsApi.list({ market: market || undefined, q: q.trim() || undefined, page, limit: 60 }),
  });

  const { data: watchlist } = useQuery({ queryKey: ["watchlist"], queryFn: watchlistApi.list });
  const watchSymbols = new Set((watchlist ?? []).map((w) => w.asset.symbol));

  const toggle = useMutation({
    mutationFn: async ({ symbol, active }: { symbol: string; active: boolean }) => {
      if (active) await watchlistApi.remove(symbol);
      else await watchlistApi.add(symbol);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["watchlist"] }),
  });

  const items = (data?.items ?? []) as any[];
  const hasMore = data ? page * data.limit < data.total : false;

  return (
    <View className="flex-1 bg-night">
      <ScrollView contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
        {/* Header */}
        <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
        <Text className="text-ink text-2xl font-bold mb-4">Mercados</Text>

        {/* Search */}
        <View className="flex-row items-center bg-night-700 border border-night-500 rounded-xl px-3 mb-4">
          <Ionicons name="search" size={18} color={C.faint} />
          <TextInput
            className="flex-1 px-2 py-3.5 text-ink text-base"
            value={q}
            onChangeText={(t) => { setQ(t); setPage(1); }}
            placeholder="Buscar ativo (ex: PETR, Apple, BTC)"
            placeholderTextColor={C.faint}
            autoCapitalize="none"
          />
          {q.length > 0 ? (
            <Pressable hitSlop={8} onPress={() => { setQ(""); setPage(1); }}>
              <Ionicons name="close-circle" size={18} color={C.faint} />
            </Pressable>
          ) : null}
        </View>

        {/* Market filter chips */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={{ flexGrow: 0, marginBottom: 16 }}
        >
          <View className="flex-row gap-2">
            {[{ key: "Todos" }, ...MARKETS.map((m) => ({ key: m }))].map(({ key }) => {
              const active = key === "Todos" ? !market : market === key;
              return (
                <Pressable
                  key={key}
                  onPress={() => { setMarket(key === "Todos" ? null : key); setPage(1); }}
                  className="px-4 py-2 rounded-full border"
                  style={active
                    ? { backgroundColor: C.brand, borderColor: C.brand }
                    : { backgroundColor: C.surface, borderColor: C.line }}
                >
                  <Text className="text-sm font-bold" style={{ color: active ? "#04110C" : C.soft }}>
                    {key}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </ScrollView>

        {/* List */}
        {isLoading ? (
          <ActivityIndicator className="py-10" color={C.brand} />
        ) : items.length > 0 ? (
          <View className="gap-2">
            {items.map((item) => (
              <Card key={item.symbol} className="flex-row items-center px-4 py-3">
                <Pressable className="flex-1" onPress={() => router.push(`/asset/${item.symbol}`)}>
                  <View className="flex-row items-center gap-2">
                    <Text className="text-ink font-bold text-base">{item.display_symbol || item.symbol}</Text>
                    <MarketBadge market={item.market} />
                  </View>
                  <Text className="text-ink-soft text-sm" numberOfLines={1}>
                    {item.name}
                  </Text>
                </Pressable>
                <FavoriteStar
                  active={watchSymbols.has(item.symbol)}
                  onPress={() => toggle.mutate({ symbol: item.symbol, active: watchSymbols.has(item.symbol) })}
                />
              </Card>
            ))}
            {hasMore ? (
              <Pressable
                className="mt-2 py-3 rounded-xl border items-center"
                style={{ borderColor: C.line, backgroundColor: C.surface }}
                onPress={() => setPage((p) => p + 1)}
              >
                <Text className="text-brand font-bold">Carregar mais</Text>
              </Pressable>
            ) : null}
          </View>
        ) : (
          <Empty text={q.trim() ? `Nenhum resultado para "${q.trim()}".` : "Nenhum ativo disponível neste mercado."} />
        )}
      </ScrollView>
    </View>
  );
}
