import "../../src/global.css";

import { useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { backtestsApi } from "@/api/client";
import { C, Card, Input, PrimaryButton } from "@/components/ui";

export default function NewBacktestScreen() {
  const [symbol, setSymbol] = useState("");
  const [startDate, setStartDate] = useState("2024-01-01");
  const [endDate, setEndDate] = useState("2026-06-30");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setError(null);
    setResult(null);
    setLoading(true);
    try {
      const data = await backtestsApi.enqueue({ symbol: symbol.toUpperCase(), start_date: startDate, end_date: endDate });
      setResult(`Backtest enfileirado: ${data.id} (${data.status})`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Erro");
    } finally {
      setLoading(false);
    }
  }

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 24, paddingTop: 18, paddingBottom: 32 }}>
      <View className="items-center mb-6">
        <View className="w-14 h-14 rounded-2xl items-center justify-center mb-3" style={{ backgroundColor: C.purple + "22" }}>
          <Ionicons name="flask" size={26} color={C.purple} />
        </View>
        <Text className="text-ink text-2xl font-bold">Novo backtest</Text>
        <Text className="text-ink-soft text-sm mt-1">Teste estratégias em dados históricos</Text>
      </View>

      <Card className="p-5">
        <Input value={symbol} onChangeText={setSymbol} placeholder="Símbolo (ex.: PETR4.SA)" autoCapitalize="characters" />
        <Input value={startDate} onChangeText={setStartDate} placeholder="Data início (AAAA-MM-DD)" />
        <Input value={endDate} onChangeText={setEndDate} placeholder="Data fim (AAAA-MM-DD)" onSubmitEditing={submit} />
        {error ? <Text className="text-down text-sm mb-3">{error}</Text> : null}
        {result ? (
          <View className="rounded-xl p-3 mb-3" style={{ backgroundColor: C.up + "14", borderWidth: 1, borderColor: C.up + "44" }}>
            <Text className="text-up text-sm">{result}</Text>
          </View>
        ) : null}
        <PrimaryButton label="Executar backtest" onPress={submit} loading={loading} color={C.purple} />
      </Card>
    </ScrollView>
  );
}
