import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router, Redirect } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { useAuthStore } from "@/state/authStore";
import { watchlistApi, assetsApi, featuresApi } from "@/api/client";
import { Badge, C, Card, Empty, FavoriteStar, Loading, MarketBadge, PLAN_THEME, SectionTitle, StatCard, openUrl } from "@/components/ui";

export default function DashboardScreen() {
  const hydrated = useAuthStore((s) => s.hydrated);
  const token = useAuthStore((s) => s.accessToken);
  const user = useAuthStore((s) => s.user);
  const qc = useQueryClient();

  const { data: watchlist, isLoading: wlLoading } = useQuery({
    queryKey: ["watchlist"],
    queryFn: watchlistApi.list,
  });
  const { data: suggested } = useQuery({
    queryKey: ["suggested"],
    queryFn: watchlistApi.suggested,
  });
  const { data: assets } = useQuery({
    queryKey: ["assets", { limit: 100 }],
    queryFn: () => assetsApi.list({ limit: 100 }),
  });
  const { data: features } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });

  const toggle = useMutation({
    mutationFn: async ({ symbol, active }: { symbol: string; active: boolean }) => {
      if (active) await watchlistApi.remove(symbol);
      else await watchlistApi.add(symbol);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["watchlist"] }),
  });

  if (!hydrated) return null;
  if (!token) return <Redirect href="/auth/login" />;

  const watchSymbols = new Set((watchlist ?? []).map((w) => w.asset.symbol));
  const marketCounts: Record<string, number> = {};
  (assets?.items as any[])?.forEach((a) => {
    marketCounts[a.market] = (marketCounts[a.market] || 0) + 1;
  });

  const plan = PLAN_THEME[features?.plan_code ?? "free"] ?? PLAN_THEME.free;

  return (
    <ScrollView
      className="flex-1 bg-night"
      contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}
      nestedScrollEnabled
    >
      {/* Header */}
      <View className="flex-row items-center justify-between mb-5">
        <View>
          <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV · TRADING INTELLIGENCE</Text>
          <Text className="text-ink text-2xl font-bold">Olá, {user?.name?.split(" ")[0] ?? "Investidor"}</Text>
          <Text className="text-ink-soft text-sm mt-0.5">Aqui está o resumo do seu mercado hoje.</Text>
        </View>
        <Badge text={plan.label} color={plan.color} />
      </View>

      {/* Stat Cards */}
      <View className="flex-row gap-3 mb-6">
        <StatCard label="NA WATCHLIST" value={String(watchlist?.length ?? 0)} color={C.amber} />
        <StatCard label="ATIVOS" value={String((assets?.items as any[])?.length ?? 0)} color={C.brand} />
        <StatCard label="MERCADOS" value={String(Object.keys(marketCounts).length)} color={C.accent} />
      </View>

      {/* Quick actions */}
      <View className="flex-row gap-3 mb-6">
        <Pressable
          className="flex-1 bg-brand rounded-xl py-3 items-center flex-row justify-center gap-2"
          onPress={() => router.push("/(tabs)/markets")}
        >
          <Ionicons name="trending-up" size={18} color="#04110C" />
          <Text className="font-bold text-[#04110C]">Explorar mercados</Text>
        </Pressable>
        <Pressable
          className="flex-1 rounded-xl py-3 items-center flex-row justify-center gap-2 border"
          style={{ borderColor: C.line, backgroundColor: C.surface }}
          onPress={() => openUrl("https://handliv.com")}
        >
          <Ionicons name="diamond-outline" size={18} color={C.brand} />
          <Text className="text-ink font-semibold">Assinar plano</Text>
        </Pressable>
      </View>

      {/* Watchlist */}
      <SectionTitle action={<Text className="text-ink-faint text-xs">{watchlist?.length ?? 0} ativos</Text>}>
        ⭐ Minha Watchlist
      </SectionTitle>
      {wlLoading ? (
        <Loading />
      ) : watchlist && watchlist.length > 0 ? (
        <View className="gap-2 mb-6">
          {watchlist.map((w, i) => (
            <Card key={i} className="flex-row items-center px-4 py-3">
              <Pressable className="flex-1" onPress={() => router.push(`/asset/${w.asset.symbol}`)}>
                <View className="flex-row items-center gap-2">
                  <Text className="text-ink font-bold text-base">{w.asset.symbol}</Text>
                  <MarketBadge market={(w.asset as any).market} />
                </View>
                <Text className="text-ink-soft text-sm" numberOfLines={1}>
                  {w.asset.name}
                </Text>
              </Pressable>
              <FavoriteStar
                active
                onPress={() => toggle.mutate({ symbol: w.asset.symbol, active: true })}
              />
            </Card>
          ))}
        </View>
      ) : (
        <View className="mb-6">
          <Empty text="Sua watchlist está vazia. Toque na estrela dos ativos sugeridos para favoritar." />
        </View>
      )}

      {/* Suggested */}
      <SectionTitle>🔥 Sugeridos para você</SectionTitle>
      {suggested && suggested.length > 0 ? (
        <View className="gap-2 mb-6">
          {suggested.slice(0, 12).map((s, i) => (
            <Card key={i} className="flex-row items-center px-4 py-3">
              <Pressable className="flex-1" onPress={() => router.push(`/asset/${s.symbol}`)}>
                <View className="flex-row items-center gap-2">
                  <Text className="text-ink font-bold text-base">{s.symbol}</Text>
                  <MarketBadge market={s.market} />
                </View>
                <Text className="text-ink-soft text-sm" numberOfLines={1}>
                  {s.name}
                </Text>
              </Pressable>
              <FavoriteStar
                active={watchSymbols.has(s.symbol)}
                onPress={() => toggle.mutate({ symbol: s.symbol, active: watchSymbols.has(s.symbol) })}
              />
            </Card>
          ))}
        </View>
      ) : (
        <ActivityIndicator color={C.brand} />
      )}
    </ScrollView>
  );
}
