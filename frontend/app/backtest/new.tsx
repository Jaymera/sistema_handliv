import "../../src/global.css";

import { useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, View } from "react-native";

import { backtestsApi } from "@/api/client";

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
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4 gap-3">
      <Text className="text-2xl font-bold text-neutral-900 dark:text-white">Novo backtest</Text>
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={symbol} onChangeText={setSymbol} placeholder="Símbolo (ex.: PETR4.SA)" placeholderTextColor="#888" />
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={startDate} onChangeText={setStartDate} placeholder="Data início (YYYY-MM-DD)" placeholderTextColor="#888" />
      <TextInput className="border border-neutral-300 dark:border-neutral-700 rounded-md px-3 py-3 text-neutral-900 dark:text-white" value={endDate} onChangeText={setEndDate} placeholder="Data fim (YYYY-MM-DD)" placeholderTextColor="#888" />
      {error ? <Text className="text-red-500">{error}</Text> : null}
      {result ? <Text className="text-green-600">{result}</Text> : null}
      <Pressable className="bg-blue-600 px-4 py-3 rounded-md items-center disabled:opacity-50" onPress={submit} disabled={loading}>
        {loading ? <ActivityIndicator color="#fff" /> : <Text className="text-white font-semibold">Executar</Text>}
      </Pressable>
    </ScrollView>
  );
}