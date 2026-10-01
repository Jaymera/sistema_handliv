import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, useWindowDimensions, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";

import { assetsApi, watchlistApi } from "@/api/client";
import { C, Card, Empty, FavoriteStar, MarketBadge } from "@/components/ui";

const MARKETS = ["B3", "NASDAQ", "NYSE", "CRYPTO", "FOREX", "COMMODITY"];
const TYPES = [{key:"stock",label:"Ações"},{key:"fii",label:"FIIs"},{key:"etf",label:"ETFs"},{key:"bdr",label:"BDRs"},{key:"reit",label:"REITs"},{key:"crypto",label:"Cripto"},{key:"forex",label:"Forex"},{key:"commodity",label:"Commodities"}];

export default function MarketsScreen() {
  const [market, setMarket] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [assetType, setAssetType] = useState<string | null>(null);
  const [listView, setListView] = useState(false);
  const [page, setPage] = useState(1);
  const { width } = useWindowDimensions();
  const columns = width >= 1180 ? 3 : width >= 720 ? 2 : 1;
  const qc = useQueryClient();

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["assets", { market, assetType, q, page, limit: 60 }],
    queryFn: () => assetsApi.list({ market: market || undefined, type: assetType || undefined, q: q.trim() || undefined, page, limit: 60 }),
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
      <ScrollView contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32, width: '100%', maxWidth: 1240, alignSelf: 'center' }}>
        {/* Header */}
        <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV / EXPLORAR</Text>
        <Text className="text-ink text-2xl font-bold mb-2">Explore. Selecione. Analise.</Text>
        <Text className="text-ink-soft text-sm mb-4">Busque um ativo para consultar fechamentos diários, indicadores, fundamentos e notícias disponíveis. A análise não é cotação em tempo real.</Text>

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

        <Text className="text-ink-faint text-xs font-bold mb-2">CLASSE DO ATIVO</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{flexGrow:0,marginBottom:18}}>
          <View className="flex-row gap-2">{[{key:"",label:"Todas as classes"},...TYPES].map(type => <Pressable key={type.key} accessibilityRole="button" accessibilityState={{selected:(assetType || "") === type.key}}
            onPress={() => {setAssetType(type.key || null);setPage(1);}} style={{paddingHorizontal:12,paddingVertical:9,borderRadius:7,borderWidth:1,borderColor:assetType === type.key ? C.accent : C.line,backgroundColor:C.surface}}>
            <Text style={{color:assetType === type.key ? C.accent : C.soft,fontSize:12}}>{type.label}</Text></Pressable>)}</View>
        </ScrollView>
        <View className="flex-row items-center justify-between mb-3" style={{gap:10,flexWrap:'wrap'}}>
          <Text className="text-ink-faint text-xs">CATÁLOGO · SEM COTAÇÃO EM TEMPO REAL</Text>
          <View className="flex-row gap-2">{[false,true].map(list => <Pressable key={String(list)} accessibilityRole="button" accessibilityLabel={list ? "Visualização em lista" : "Visualização em cards"} accessibilityState={{selected:listView === list}} onPress={() => setListView(list)} style={{padding:9,borderRadius:6,borderWidth:1,borderColor:listView === list ? C.accent : C.line}}>
            <Ionicons name={list ? 'list' : 'grid-outline'} size={17} color={listView === list ? C.accent : C.soft} /></Pressable>)}</View>
        </View>
        {/* Catalog count is the server's filtered total, not a quote feed. */}
        {data ? <View className="flex-row items-center justify-between mb-3">
          <Text className="text-ink font-bold text-sm">{data.total} ativo{data.total === 1 ? '' : 's'} encontrado{data.total === 1 ? '' : 's'}</Text>
          <Text className="text-ink-faint text-xs">{market ?? 'Todos os mercados'}</Text>
        </View> : null}
        {isError ? <View style={{padding:18,gap:12,borderWidth:1,borderColor:C.line,borderRadius:10}}>
          <Text className="text-ink-soft">Não foi possível consultar o catálogo. Não confunda falha de conexão com ausência de ativos.</Text>
          <Pressable accessibilityRole="button" onPress={() => {void refetch();}}><Text className="text-brand">Tentar novamente</Text></Pressable>
        </View> : isLoading ? (
          <ActivityIndicator className="py-10" color={C.brand} />
        ) : items.length > 0 ? (
          <>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
            {items.map((item) => (
              <Card key={item.symbol} className="flex-row items-center px-4 py-3" style={{ width: listView || columns === 1 ? '100%' : columns === 2 ? '49%' : '32%', minWidth: 0 }}>
                <Pressable className="flex-1" onPress={() => router.push(`/asset/${item.symbol}`)} accessibilityRole="button" accessibilityLabel={`Analisar ${item.display_symbol || item.symbol}`}>
                  <View className="flex-row items-center gap-2">
                    <Text className="text-ink font-bold text-base">{item.display_symbol || item.symbol}</Text>
                    <MarketBadge market={item.market} />
                  </View>
                  <Text className="text-ink-soft text-sm" numberOfLines={1}>{item.name}</Text>
                  <View className="flex-row items-center justify-between mt-2" style={{gap:8,flexWrap:'wrap'}}>
                    <Text className="text-ink-faint text-xs">{TYPES.find(t=>t.key === item.asset_type)?.label || item.asset_type || 'Classe não informada'} · {item.currency || 'Moeda não informada'}</Text>
                    <Text className="text-brand text-xs">Abrir workspace →</Text>
                  </View>
                </Pressable>
                <FavoriteStar
                  active={watchSymbols.has(item.symbol)}
                  onPress={() => toggle.mutate({ symbol: item.symbol, active: watchSymbols.has(item.symbol) })}
                />
              </Card>
            ))}
          </View>
          <View className="flex-row gap-2 mt-3">
            {page > 1 ? <Pressable className="flex-1 py-3 rounded-xl border items-center" style={{ borderColor: C.line, backgroundColor: C.surface }} onPress={() => setPage((p) => Math.max(1, p - 1))}>
              <Text className="text-brand font-bold">Página anterior</Text>
            </Pressable> : null}
            {hasMore ? <Pressable className="flex-1 py-3 rounded-xl border items-center" style={{ borderColor: C.line, backgroundColor: C.surface }} onPress={() => setPage((p) => p + 1)}>
              <Text className="text-brand font-bold">Próxima página</Text>
            </Pressable> : null}
          </View>
          </>
        ) : (
          <Empty text={q.trim() ? `Nenhum resultado para "${q.trim()}".` : "Nenhum ativo disponível neste mercado."} />
        )}
      </ScrollView>
    </View>
  );
}
