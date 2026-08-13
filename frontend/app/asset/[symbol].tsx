import "../../src/global.css";

import { useLocalSearchParams, router } from "expo-router";
import { ActivityIndicator, Dimensions, Pressable, ScrollView, Text, View } from "react-native";
import { useQuery } from "@tanstack/react-query";
import { LineChart } from "react-native-chart-kit";

import { assetsApi, watchlistApi } from "@/api/client";

const screenWidth = Dimensions.get("window").width;

export default function AssetScreen() {
  const { symbol } = useLocalSearchParams<{ symbol: string }>();
  const sym = decodeURIComponent(symbol ?? "");

  const { data, isLoading } = useQuery({
    queryKey: ["live-analysis", sym],
    queryFn: () => assetsApi.liveAnalysis(sym),
    enabled: Boolean(sym),
  });

  const addToWatchlist = async () => {
    try {
      await watchlistApi.add(sym);
    } catch {}
  };

  if (isLoading) {
    return (
      <View className="flex-1 bg-white dark:bg-neutral-950 items-center justify-center">
        <ActivityIndicator size="large" color="#2563eb" />
        <Text className="text-neutral-500 mt-3">Analisando {sym}...</Text>
      </View>
    );
  }

  if (!data) {
    return (
      <View className="flex-1 bg-white dark:bg-neutral-950 p-4 items-center justify-center">
        <Text className="text-neutral-900 dark:text-white">Não foi possível carregar dados de {sym}.</Text>
      </View>
    );
  }

  const score = data.score;
  const fund = data.fundamentals;
  const ind = data.indicators;

  const recoColor =
    data.recommendation_color === "green" ? "#16a34a" :
    data.recommendation_color === "lime" ? "#65a30d" :
    data.recommendation_color === "amber" ? "#d97706" :
    data.recommendation_color === "orange" ? "#ea580c" : "#dc2626";

  // Chart data from price_history
  const chartData = (data.price_history || []).filter((b) => b.close != null);
  const chartLabels = chartData.map((b, i) => {
    const d = new Date(b.trade_date);
    return i === 0 || i === chartData.length - 1 || i === Math.floor(chartData.length / 2)
      ? `${d.getDate()}/${d.getMonth() + 1}` : "";
  });
  const chartPrices = chartData.map((b) => b.close);

  // Score gauge (circular progress visual)
  const scoreColor = score.final_score >= 70 ? "#16a34a" : score.final_score >= 55 ? "#65a30d" : score.final_score >= 45 ? "#d97706" : score.final_score <= 30 ? "#dc2626" : "#737373";

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4">
      {/* Header */}
      <View className="flex-row justify-between items-start mb-2">
        <View className="flex-1">
          <Text className="text-2xl font-bold text-neutral-900 dark:text-white">{data.name}</Text>
          <Text className="text-neutral-500">{data.symbol} • {data.market}{data.sector ? ` • ${data.sector}` : ""}</Text>
        </View>
        {data.last_price ? (
          <View className="items-end">
            <Text className="text-2xl font-bold text-neutral-900 dark:text-white">
              {data.currency === "BRL" ? "R$" : "$"} {data.last_price.toFixed(2)}
            </Text>
            {ind.ema20 != null && data.last_price > ind.ema20 ? (
              <Text className="text-green-600 text-sm">▲ Acima EMA20</Text>
            ) : ind.ema20 != null ? (
              <Text className="text-red-500 text-sm">▼ Abaixo EMA20</Text>
            ) : null}
          </View>
        ) : null}
      </View>

      {/* Price Chart */}
      {chartPrices.length > 1 ? (
        <View className="my-3 rounded-xl overflow-hidden">
          <LineChart
            data={{ labels: chartLabels, datasets: [{ data: chartPrices, color: () => "#2563eb", strokeWidth: 2 }] }}
            width={screenWidth - 32}
            height={200}
            chartConfig={{
              backgroundColor: "#fff",
              backgroundGradientFrom: "#fff",
              backgroundGradientTo: "#f0f9ff",
              decimalCount: 2,
              color: (opacity) => `rgba(37, 99, 235, ${opacity})`,
              labelColor: (opacity) => `rgba(115, 115, 115, ${opacity})`,
              style: { borderRadius: 12 },
              propsForDots: { r: 2, strokeWidth: 1, stroke: "#2563eb" },
              fillShadowGradient: "#dbeafe",
              fillShadowGradientOpacity: 0.4,
            }}
            bezier
            style={{ marginVertical: 4, borderRadius: 12 }}
          />
        </View>
      ) : null}

      {/* Recommendation + Score Card */}
      <View className="flex-row gap-3 mb-4">
        {/* Score Circle */}
        <View className="items-center justify-center rounded-2xl px-4 py-4" style={{ backgroundColor: scoreColor + "15" }}>
          <Text style={{ color: scoreColor }} className="text-4xl font-bold">{score.final_score}</Text>
          <Text style={{ color: scoreColor }} className="text-xs font-medium">/ 100</Text>
        </View>
        <View className="flex-1 rounded-2xl px-4 py-4 justify-center" style={{ backgroundColor: recoColor }}>
          <Text className="text-white text-center font-bold text-lg">{data.recommendation}</Text>
          <Text className="text-white text-center text-sm mt-1">
            Confiança: {score.confidence}% • Tendência: {score.trend}
          </Text>
        </View>
      </View>

      {/* Sub-scores */}
      <View className="flex-row justify-between bg-neutral-100 dark:bg-neutral-900 rounded-xl p-3 mb-4">
        {[
          { label: "Técnica", value: score.subscores.technical, color: "#2563eb" },
          { label: "Valuation", value: score.subscores.valuation, color: "#16a34a" },
          { label: "Sentimento", value: score.subscores.sentiment, color: "#d97706" },
        ].map((s, i) => (
          <View key={i} className="items-center flex-1">
            <Text className="text-neutral-500 text-xs mb-1">{s.label}</Text>
            <Text style={{ color: s.color }} className="text-xl font-bold">{s.value}</Text>
            <View className="w-full bg-neutral-200 dark:bg-neutral-700 rounded-full h-2 mt-1">
              <View style={{ width: `${s.value}%`, backgroundColor: s.color, height: 8, borderRadius: 4 }} />
            </View>
          </View>
        ))}
      </View>

      {/* Forces */}
      <View className="flex-row justify-between mb-4">
        <View className="flex-1 bg-green-50 dark:bg-green-950 rounded-lg p-2 mr-1">
          <Text className="text-green-700 dark:text-green-400 text-center font-semibold">✓ Compradora</Text>
          <Text className="text-green-700 dark:text-green-400 text-center text-lg font-bold">{score.buyer_strength}</Text>
        </View>
        <View className="flex-1 bg-red-50 dark:bg-red-950 rounded-lg p-2 ml-1">
          <Text className="text-red-700 dark:text-red-400 text-center font-semibold">✗ Vendedora</Text>
          <Text className="text-red-700 dark:text-red-400 text-center text-lg font-bold">{score.seller_strength}</Text>
        </View>
      </View>

      {/* Technical Indicators */}
      <Text className="text-neutral-900 dark:text-white font-semibold mb-1">Indicadores Técnicos</Text>
      <View className="bg-neutral-50 dark:bg-neutral-900 rounded-xl p-3 mb-4 gap-1">
        {ind.rsi != null ? (
          <Text className="text-neutral-700 dark:text-neutral-300">
            RSI (14): <Text className="font-semibold">{ind.rsi.toFixed(1)}</Text>
            {"  "}({ind.rsi < 30 ? "🟢 sobrevendido" : ind.rsi > 70 ? "🔴 sobrecomprado" : "⚪ neutro"})
          </Text>
        ) : null}
        {ind.ema20 != null ? (
          <Text className="text-neutral-700 dark:text-neutral-300">EMA 20: <Text className="font-semibold">{ind.ema20.toFixed(2)}</Text></Text>
        ) : null}
        {ind.ema50 != null ? (
          <Text className="text-neutral-700 dark:text-neutral-300">
            EMA 50: <Text className="font-semibold">{ind.ema50.toFixed(2)}</Text>
            {ind.ema20 != null ? (ind.ema20 > ind.ema50 ? "  📈 cruzamento alcista" : "  📉 cruzamento baixista") : ""}
          </Text>
        ) : null}
        {ind.macd != null ? (
          <Text className="text-neutral-700 dark:text-neutral-300">
            MACD: <Text className="font-semibold">{ind.macd.toFixed(3)}</Text> (sinal {ind.macd_signal?.toFixed(3) ?? "—"})
          </Text>
        ) : null}
        {ind.rsi == null && ind.ema20 == null && ind.macd == null ? (
          <Text className="text-neutral-500">Indisponível (dados insuficientes).</Text>
        ) : null}
      </View>

      {/* Technical Votes */}
      {Object.keys(data.technical_votes).length > 0 ? (
        <View className="mb-4">
          <Text className="text-neutral-900 dark:text-white font-semibold mb-1">Votos dos Indicadores</Text>
          <View className="flex-row flex-wrap gap-2">
            {Object.entries(data.technical_votes).map(([k, v]) => (
              <View key={k} className="px-3 py-1 rounded-full" style={{ backgroundColor: v > 0 ? "#dcfce7" : v < 0 ? "#fee2e2" : "#f5f5f4" }}>
                <Text style={{ color: v > 0 ? "#16a34a" : v < 0 ? "#dc2626" : "#737373" }} className="text-xs font-semibold">
                  {k} {v > 0 ? "📈" : v < 0 ? "📉" : "➖"}
                </Text>
              </View>
            ))}
          </View>
        </View>
      ) : null}

      {/* Fundamentals */}
      <Text className="text-neutral-900 dark:text-white font-semibold mb-1">Fundamentos</Text>
      <View className="bg-neutral-50 dark:bg-neutral-900 rounded-xl p-3 mb-4 gap-1">
        {fund.pe_ratio != null ? <Text className="text-neutral-700 dark:text-neutral-300">📊 P/L: <Text className="font-semibold">{fund.pe_ratio.toFixed(2)}</Text></Text> : null}
        {fund.pb_ratio != null ? <Text className="text-neutral-700 dark:text-neutral-300">📊 P/VPA: <Text className="font-semibold">{fund.pb_ratio.toFixed(2)}</Text></Text> : null}
        {fund.dividend_yield != null ? <Text className="text-neutral-700 dark:text-neutral-300">💰 Div. Yield: <Text className="font-semibold">{(fund.dividend_yield * 100).toFixed(2)}%</Text></Text> : null}
        {fund.roe != null ? <Text className="text-neutral-700 dark:text-neutral-300">📈 ROE: <Text className="font-semibold">{(fund.roe * 100).toFixed(1)}%</Text></Text> : null}
        {fund.debt_to_equity != null ? <Text className="text-neutral-700 dark:text-neutral-300">🏦 Díq./Patrim.: <Text className="font-semibold">{fund.debt_to_equity.toFixed(2)}</Text></Text> : null}
        {fund.pe_ratio == null && fund.roe == null ? <Text className="text-neutral-500">Dados indisponíveis.</Text> : null}
      </View>

      {/* AI Explanation */}
      <Text className="text-neutral-900 dark:text-white font-semibold mb-1">🤖 Recomendação da IA</Text>
      <Text className="text-neutral-700 dark:text-neutral-300 mb-2 leading-6">{data.ai_explanation}</Text>
      <Text className="text-neutral-500 italic leading-5">{data.indicators_explanation}</Text>

      {/* News */}
      <Text className="text-neutral-900 dark:text-white font-semibold mt-3 mb-1">📰 Notícias Recentes</Text>
      <Text className="text-neutral-500 italic mb-2">{data.news_summary}</Text>
      {data.news_items && data.news_items.length > 0 ? (
        <View className="gap-2 mb-4">
          {data.news_items.map((n, i) => {
            const sColor = n.sentiment_label === "positive" ? "#16a34a" : n.sentiment_label === "negative" ? "#dc2626" : "#737373";
            const sEmoji = n.sentiment_label === "positive" ? "🟢" : n.sentiment_label === "negative" ? "🔴" : "⚪";
            return (
              <View key={i} className="border border-neutral-200 dark:border-neutral-800 rounded-xl p-3">
                <View className="flex-row justify-between items-start mb-1">
                  <Text className="text-neutral-500 text-xs">{n.source}</Text>
                  <Text style={{ color: sColor }} className="text-xs font-semibold">{sEmoji} {n.sentiment_label?.toUpperCase()}</Text>
                </View>
                <Text className="text-neutral-900 dark:text-white font-medium leading-5">{n.title}</Text>
                {n.summary ? <Text className="text-neutral-500 text-sm mt-1 leading-4" numberOfLines={3}>{n.summary}</Text> : null}
                {n.published_at ? <Text className="text-neutral-400 text-xs mt-1">{new Date(n.published_at).toLocaleDateString("pt-BR")}</Text> : null}
              </View>
            );
          })}
        </View>
      ) : (
        <Text className="text-neutral-500 mb-4">Sem notícias disponíveis.</Text>
      )}

      {/* Actions */}
      <View className="flex-row gap-3 mb-8">
        <Pressable className="flex-1 bg-blue-600 px-4 py-3 rounded-xl items-center" onPress={addToWatchlist}>
          <Text className="text-white font-semibold">＋ Watchlist</Text>
        </Pressable>
        <Pressable className="flex-1 bg-neutral-200 dark:bg-neutral-800 px-4 py-3 rounded-xl items-center" onPress={() => router.back()}>
          <Text className="text-neutral-900 dark:text-white font-semibold">← Voltar</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}