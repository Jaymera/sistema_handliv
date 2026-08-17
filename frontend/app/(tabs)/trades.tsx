import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ScrollView, Text, View } from "react-native";
import { useState } from "react";

import { featuresApi, tradesApi } from "@/api/client";
import { C, Card, Empty, Input, Loading, PrimaryButton, SectionTitle, StatCard, UpsellCard } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";

export default function TradesScreen() {
  const qc = useQueryClient();
  const [asset, setAsset] = useState("");
  const [result, setResult] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  const { data: features, isLoading: fLoading } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const { data: tradesData, isLoading } = useQuery({
    queryKey: ["trades"],
    queryFn: tradesApi.list,
    enabled: !!features?.features.trading_panel,
  });

  const addTrade = useMutation({
    mutationFn: () =>
      tradesApi.add({ asset_symbol: asset.trim(), result_pct: parseFloat(result.replace(",", ".")), note: note.trim() || undefined }),
    onSuccess: () => {
      setAsset(""); setResult(""); setNote(""); setError(null); setOk(true);
      setTimeout(() => setOk(false), 2500);
      qc.invalidateQueries({ queryKey: ["trades"] });
    },
    onError: (e: any) => setError(e?.message ?? "Erro ao cadastrar trade"),
  });

  const removeTrade = useMutation({
    mutationFn: (id: string) => tradesApi.remove(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trades"] }),
  });

  if (fLoading) return <Loading label="Carregando..." />;

  const f = features?.features;
  const links = features?.links;
  if (!f?.trading_panel) {
    return (
      <View className="flex-1 bg-night px-4 pt-4">
        <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
        <Text className="text-ink text-2xl font-bold mb-4">Trades & Resultados</Text>
        <UpsellCard
          title="Painel de Trading"
          message="Cadastre seus trades, acompanhe ganhos, perdas e seu win rate. Disponível nos planos Start e Ultimate."
          planLabel="START · R$97/MÊS OU ULTIMATE · R$297/MÊS"
          onWhatsapp={() => { if (typeof window !== "undefined") window.open(links?.whatsapp || WHATSAPP, "_blank"); }}
          onPlans={() => router.push("/pricing")}
        />
      </View>
    );
  }

  const trades = tradesData?.items ?? [];
  const wins = trades.filter((t) => t.result_pct > 0);
  const losses = trades.filter((t) => t.result_pct < 0);
  const totalWin = wins.reduce((s, t) => s + t.result_pct, 0);
  const totalLoss = losses.reduce((s, t) => s + Math.abs(t.result_pct), 0);
  const winRate = trades.length > 0 ? ((wins.length / trades.length) * 100).toFixed(1) : "0";
  const total = totalWin - totalLoss;

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
      <Text className="text-ink text-2xl font-bold mb-4">Trades & Resultados</Text>

      {/* Stats */}
      {trades.length > 0 ? (
        <View className="mb-6">
          <View className="flex-row gap-3 mb-3">
            <StatCard label="TRADES" value={String(trades.length)} />
            <StatCard label="WIN RATE" value={`${winRate}%`} color={C.accent} />
            <StatCard label="RESULTADO" value={`${total >= 0 ? "+" : ""}${total.toFixed(2)}%`} color={total >= 0 ? C.up : C.down} />
          </View>
          <View className="flex-row gap-3">
            <StatCard label="VITÓRIAS" value={String(wins.length)} color={C.up} />
            <StatCard label="GANHOS" value={`+${totalWin.toFixed(2)}%`} color={C.up} />
            <StatCard label="DERROTAS" value={String(losses.length)} color={C.down} />
            <StatCard label="PERDAS" value={`-${totalLoss.toFixed(2)}%`} color={C.down} />
          </View>
        </View>
      ) : null}

      {/* Form */}
      <SectionTitle>＋ Cadastrar trade</SectionTitle>
      <Card className="p-4 mb-6">
        <Input value={asset} onChangeText={setAsset} placeholder="Ativo (ex: PETR4, AAPL)" autoCapitalize="characters" />
        <Input value={result} onChangeText={setResult} placeholder="Resultado % (ex: 2.5 ou -1.5)" keyboardType="numeric" />
        <Input value={note} onChangeText={setNote} placeholder="Nota (opcional)" />
        {error ? <Text className="text-down text-sm mb-2">{error}</Text> : null}
        {ok ? <Text className="text-up text-sm mb-2">Trade cadastrado com sucesso!</Text> : null}
        <PrimaryButton
          label="Cadastrar trade"
          loading={addTrade.isPending}
          disabled={!asset.trim() || !result.trim()}
          onPress={() => addTrade.mutate()}
        />
      </Card>

      {/* History */}
      <SectionTitle>Histórico</SectionTitle>
      {isLoading ? (
        <Loading />
      ) : trades.length > 0 ? (
        <View className="gap-2">
          {trades.map((t) => (
            <Card key={t.id} className="px-4 py-3 flex-row items-center justify-between">
              <View className="flex-1">
                <View className="flex-row items-center gap-2">
                  <Text className="text-ink font-bold">{t.asset_symbol}</Text>
                  <Text className="font-bold" style={{ color: t.result_pct >= 0 ? C.up : C.down }}>
                    {t.result_pct >= 0 ? "+" : ""}{t.result_pct.toFixed(2)}%
                  </Text>
                </View>
                {t.note ? <Text className="text-ink-soft text-xs" numberOfLines={1}>{t.note}</Text> : null}
                {t.created_at ? (
                  <Text className="text-ink-faint text-[11px] mt-0.5">
                    {new Date(t.created_at).toLocaleDateString("pt-BR")} {new Date(t.created_at).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}
                  </Text>
                ) : null}
              </View>
              <Text
                className="text-down text-xs font-bold px-3 py-2"
                onPress={() => removeTrade.mutate(t.id)}
              >
                EXCLUIR
              </Text>
            </Card>
          ))}
        </View>
      ) : (
        <Empty text="Nenhum trade cadastrado ainda. Registre seu primeiro resultado acima." />
      )}
    </ScrollView>
  );
}
