import '../../src/global.css';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useLocalSearchParams, router } from 'expo-router';
import { Pressable, Text, View } from 'react-native';
import { assetsApi, watchlistApi } from '@/api/client';
import { AssetTerminal, TerminalSkeleton } from '@/features/asset-terminal/AssetTerminal';
import { T } from '@/features/asset-terminal/visuals';

export default function AssetScreen() {
  const { symbol } = useLocalSearchParams<{ symbol: string }>();
  const sym = decodeURIComponent(symbol ?? '');
  const qc = useQueryClient();
  const { data, isLoading, isFetching, isError, refetch } = useQuery({
    queryKey: ["live-analysis", sym],
    queryFn: () => assetsApi.liveAnalysis(sym),
    enabled: Boolean(sym),
  });
  const { data: watchlist } = useQuery({ queryKey: ["watchlist"], queryFn: watchlistApi.list });
  const inWatchlist = (watchlist ?? []).some((w) => w.asset.symbol === sym);
  const toggle = useMutation({
    mutationFn: async () => {
      if (inWatchlist) await watchlistApi.remove(sym);
      else await watchlistApi.add(sym);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["watchlist"] }),
  });

  if (isLoading) return <TerminalSkeleton symbol={sym} />;
  if (!data) return <View style={{ flex: 1, backgroundColor: T.bg, alignItems: 'center', justifyContent: 'center', gap: 14, padding: 20 }}>
    <Text style={{ color: T.ink }}>Não foi possível carregar dados de {sym}.</Text>
    <Pressable onPress={() => void refetch()}><Text style={{ color: T.cyan }}>Tentar novamente</Text></Pressable>
  </View>;

  return <View style={{ flex: 1 }}>
    {isError ? <View style={{ backgroundColor: T.panel, padding: 8 }}><Text style={{ color: T.amber, textAlign: 'center' }}>Não foi possível atualizar. Exibindo a última análise recebida.</Text></View> : null}
    <AssetTerminal key={sym} data={data} inWatchlist={inWatchlist} onToggle={() => toggle.mutate()}
      onBack={() => router.back()} onRefresh={() => { void refetch(); }} refreshing={isFetching} />
  </View>;
}
