import "../src/global.css";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { useState } from "react";

import { mt5Api, featuresApi, tradesApi } from "@/api/client";

const WHATSAPP = "https://wa.me/551152866453";
const DISCORD = "https://discord.com/invite/6X3MamvS5T";
const CURSOS = "https://handliv.kpages.online/cursos";
const HANDLIV = "https://handliv.com";

export default function TradingPanelScreen() {
  const qc = useQueryClient();
  const [accounts, setAccounts] = useState("");
  const [broker, setBroker] = useState("");
  const [msg, setMsg] = useState<string | null>(null);

  // Trade form
  const [tradeAsset, setTradeAsset] = useState("");
  const [tradeResult, setTradeResult] = useState("");
  const [tradeNote, setTradeNote] = useState("");

  const { data: features } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const { data: mt5Data, isLoading } = useQuery({ queryKey: ["mt5"], queryFn: mt5Api.list });
  const { data: tradesData, isLoading: tLoading } = useQuery({ queryKey: ["trades"], queryFn: tradesApi.list });

  const f = features?.features;
  const links = features?.links || { whatsapp: WHATSAPP, discord: DISCORD, cursos: CURSOS, copy_trading: WHATSAPP, robots_indicators: WHATSAPP, trading_panel: "", auto_robot: WHATSAPP };

  const open = (url: string) => {
    if (url && typeof window !== "undefined") window.open(url, "_blank");
  };

  const handleAddMT5 = async () => {
    if (!accounts.trim()) return;
    try {
      const res = await mt5Api.add(accounts.trim(), broker.trim());
      setMsg(`${res.count} conta(s) MT5 cadastrada(s)`);
      setAccounts("");
      qc.invalidateQueries({ queryKey: ["mt5"] });
    } catch {
      setMsg("Erro ao cadastrar");
    }
  };

  const handleDeleteMT5 = async (id: string) => {
    try {
      await mt5Api.remove(id);
      qc.invalidateQueries({ queryKey: ["mt5"] });
    } catch {}
  };

  const handleAddTrade = async () => {
    if (!tradeAsset.trim() || !tradeResult.trim()) return;
    try {
      await tradesApi.add({
        asset_symbol: tradeAsset.trim(),
        result_pct: parseFloat(tradeResult),
        note: tradeNote.trim(),
      });
      setTradeAsset("");
      setTradeResult("");
      setTradeNote("");
      qc.invalidateQueries({ queryKey: ["trades"] });
    } catch {}
  };

  const handleDeleteTrade = async (id: string) => {
    try {
      await tradesApi.remove(id);
      qc.invalidateQueries({ queryKey: ["trades"] });
    } catch {}
  };

  // Calculate stats
  const trades = tradesData?.items || [];
  const wins = trades.filter((t) => t.result_pct > 0);
  const losses = trades.filter((t) => t.result_pct < 0);
  const totalWin = wins.reduce((s, t) => s + t.result_pct, 0);
  const totalLoss = losses.reduce((s, t) => s + Math.abs(t.result_pct), 0);
  const winRate = trades.length > 0 ? ((wins.length / trades.length) * 100).toFixed(1) : "0";

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white mb-2">Painel de Trading</Text>

      {/* Plan badge */}
      {features ? (
        <View className="bg-blue-50 dark:bg-blue-950 rounded-xl px-4 py-3 mb-4">
          <Text className="text-blue-600 dark:text-blue-400 font-bold">Plano: {features.plan_code.toUpperCase()}</Text>
          {!features.payment_ok && features.plan_code !== "free" ? (
            <Text className="text-red-500 text-sm mt-1">⚠ Pagamento atrasado. Regularize sua assinatura.</Text>
          ) : null}
        </View>
      ) : null}

      {/* Link back to Recursos */}
      <View className="bg-neutral-100 dark:bg-neutral-900 rounded-xl px-4 py-3 mb-6">
        <Text className="text-neutral-500 text-sm">
          Acesse os recursos do seu plano (Robôs, Copy Trading, Sala ao Vivo, Cursos) na aba{" "}
          <Text className="font-bold text-neutral-900 dark:text-white" onPress={() => router.push("/(tabs)/recursos")}>
            Recursos
          </Text>.
        </Text>
      </View>

      {/* Robô Automático: MT5 + Download info */}
      {f?.auto_robot ? (
        <View className="mb-6">
          <Text className="text-lg font-bold text-neutral-900 dark:text-white mb-2">
            🤖 Robô Automático - Contas MT5
          </Text>
          <View className="bg-blue-50 dark:bg-blue-950 rounded-xl p-3 mb-3">
            <Text className="text-blue-700 dark:text-blue-300 text-sm">
              📥 Faça o download do Robô Automático no site da Handliv:{" "}
              <Text className="font-bold text-blue-600" onPress={() => open(HANDLIV)}>handliv.com</Text>
            </Text>
          </View>
          <Text className="text-neutral-500 text-sm mb-2">
            Cadastre suas contas MT5 (separe por vírgula para múltiplas)
          </Text>
          <TextInput
            className="border border-neutral-300 dark:border-neutral-700 rounded-xl px-3 py-3 text-neutral-900 dark:text-white mb-2"
            value={accounts} onChangeText={setAccounts}
            placeholder="ex: 216546,15616165,15155" placeholderTextColor="#888"
          />
          <TextInput
            className="border border-neutral-300 dark:border-neutral-700 rounded-xl px-3 py-3 text-neutral-900 dark:text-white mb-2"
            value={broker} onChangeText={setBroker}
            placeholder="Corretora (opcional)" placeholderTextColor="#888"
          />
          <Pressable className="bg-blue-600 rounded-xl py-3 items-center mb-2" onPress={handleAddMT5}>
            <Text className="text-white font-semibold">＋ Cadastrar Contas</Text>
          </Pressable>
          {msg ? <Text className="text-green-600 text-sm mb-2">{msg}</Text> : null}

          {isLoading ? <ActivityIndicator /> : mt5Data && mt5Data.items.length > 0 ? (
            <View className="gap-1">
              {mt5Data.items.map((a) => (
                <View key={a.id} className="flex-row justify-between items-center bg-neutral-50 dark:bg-neutral-900 rounded-xl px-4 py-3">
                  <View>
                    <Text className="text-neutral-900 dark:text-white font-semibold">{a.account_number}</Text>
                    {a.broker ? <Text className="text-neutral-500 text-sm">{a.broker}</Text> : null}
                  </View>
                  <Pressable onPress={() => handleDeleteMT5(a.id)}>
                    <Text className="text-red-500 text-sm">Remover</Text>
                  </Pressable>
                </View>
              ))}
            </View>
          ) : <Text className="text-neutral-500">Nenhuma conta MT5 cadastrada.</Text>}
        </View>
      ) : null}

      {/* Painel de Trading: cadastro de ganhos/perdas */}
      {f?.trading_panel ? (
        <View className="mb-6">
          <Text className="text-lg font-bold text-neutral-900 dark:text-white mb-2">
            📉 Resultados de Trading
          </Text>

          {/* Stats */}
          {trades.length > 0 ? (
            <View className="flex-row gap-2 mb-4">
              <StatCard label="Trades" value={String(trades.length)} bg="#f5f5f4" color="#444" />
              <StatCard label="Vitórias" value={String(wins.length)} bg="#dcfce7" color="#16a34a" />
              <StatCard label="Derrotas" value={String(losses.length)} bg="#fee2e2" color="#dc2626" />
              <StatCard label="Win Rate" value={`${winRate}%`} bg="#dbeafe" color="#2563eb" />
            </View>
          ) : null}

          {trades.length > 0 ? (
            <View className="flex-row gap-2 mb-4">
              <StatCard label="Ganhos" value={`+${totalWin.toFixed(2)}%`} bg="#dcfce7" color="#16a34a" />
              <StatCard label="Perdas" value={`-${totalLoss.toFixed(2)}%`} bg="#fee2e2" color="#dc2626" />
              <StatCard label="Total" value={`${(totalWin - totalLoss).toFixed(2)}%`} bg={(totalWin - totalLoss) >= 0 ? "#dcfce7" : "#fee2e2"} color={(totalWin - totalLoss) >= 0 ? "#16a34a" : "#dc2626"} />
            </View>
          ) : null}

          {/* Form */}
          <Text className="text-neutral-900 dark:text-white font-semibold mb-2">Cadastrar Trade</Text>
          <TextInput
            className="border border-neutral-300 dark:border-neutral-700 rounded-xl px-3 py-3 text-neutral-900 dark:text-white mb-2"
            value={tradeAsset} onChangeText={setTradeAsset}
            placeholder="Ativo (ex: PETR4, AAPL)" placeholderTextColor="#888"
          />
          <TextInput
            className="border border-neutral-300 dark:border-neutral-700 rounded-xl px-3 py-3 text-neutral-900 dark:text-white mb-2"
            value={tradeResult} onChangeText={setTradeResult}
            placeholder="Resultado % (ex: 2.5 ou -1.5)" placeholderTextColor="#888" keyboardType="numeric"
          />
          <TextInput
            className="border border-neutral-300 dark:border-neutral-700 rounded-xl px-3 py-3 text-neutral-900 dark:text-white mb-2"
            value={tradeNote} onChangeText={setTradeNote}
            placeholder="Nota (opcional)" placeholderTextColor="#888"
          />
          <Pressable className="bg-blue-600 rounded-xl py-3 items-center mb-4" onPress={handleAddTrade}>
            <Text className="text-white font-semibold">＋ Cadastrar Trade</Text>
          </Pressable>

          {/* Trade list */}
          {tLoading ? <ActivityIndicator /> : trades.length > 0 ? (
            <View className="gap-1">
              {trades.map((t) => (
                <View key={t.id} className="flex-row justify-between items-center bg-neutral-50 dark:bg-neutral-900 rounded-xl px-4 py-3">
                  <View className="flex-1">
                    <View className="flex-row items-center gap-2">
                      <Text className="text-neutral-900 dark:text-white font-semibold">{t.asset_symbol}</Text>
                      <Text style={{ color: t.result_pct >= 0 ? "#16a34a" : "#dc2626" }} className="font-bold">
                        {t.result_pct >= 0 ? "+" : ""}{t.result_pct.toFixed(2)}%
                      </Text>
                    </View>
                    {t.note ? <Text className="text-neutral-500 text-sm">{t.note}</Text> : null}
                    <Text className="text-neutral-400 text-xs">{new Date(t.created_at).toLocaleDateString("pt-BR")}</Text>
                  </View>
                  <Pressable onPress={() => handleDeleteTrade(t.id)}>
                    <Text className="text-red-500 text-sm">Excluir</Text>
                  </Pressable>
                </View>
              ))}
            </View>
          ) : <Text className="text-neutral-500">Nenhum trade cadastrado.</Text>}
        </View>
      ) : (
        <View className="bg-amber-50 dark:bg-amber-950 rounded-xl p-4 items-center">
          <Text className="text-amber-700 dark:text-amber-400 font-semibold text-center">
            Painel de Trading disponível nos planos Start e Ultimate
          </Text>
          <Pressable className="bg-amber-500 px-4 py-2 rounded-lg mt-2" onPress={() => open(links.whatsapp)}>
            <Text className="text-white font-semibold">Falar no WhatsApp</Text>
          </Pressable>
        </View>
      )}
    </ScrollView>
  );
}

function StatCard({ label, value, bg, color }: { label: string; value: string; bg: string; color: string }) {
  return (
    <View className="flex-1 rounded-xl px-3 py-3 items-center" style={{ backgroundColor: bg }}>
      <Text style={{ color }} className="text-xl font-bold">{value}</Text>
      <Text className="text-neutral-500 text-xs">{label}</Text>
    </View>
  );
}