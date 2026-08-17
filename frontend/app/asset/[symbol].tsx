import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useLocalSearchParams, router } from "expo-router";
import { ActivityIndicator, Dimensions, Pressable, ScrollView, Text, View } from "react-native";
import { LineChart } from "react-native-chart-kit";
import { Ionicons } from "@expo/vector-icons";

import { assetsApi, watchlistApi } from "@/api/client";
import { C, Card, FavoriteStar, MarketBadge, SectionTitle } from "@/components/ui";

const screenWidth = Dimensions.get("window").width;

export default function AssetScreen() {
  const { symbol } = useLocalSearchParams<{ symbol: string }>();
  const sym = decodeURIComponent(symbol ?? "");
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
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

  if (isLoading) {
    return (
      <View className="flex-1 bg-night items-center justify-center">
        <ActivityIndicator size="large" color={C.brand} />
        <Text className="text-ink-soft mt-3">Analisando {sym}...</Text>
      </View>
    );
  }

  if (!data) {
    return (
      <View className="flex-1 bg-night p-4 items-center justify-center">
        <Text className="text-ink">Não foi possível carregar dados de {sym}.</Text>
      </View>
    );
  }

  const score = data.score;
  const fund = data.fundamentals;
  const ind = data.indicators;

  const recoColor =
    data.recommendation_color === "green" ? C.up :
    data.recommendation_color === "lime" ? "#65a30d" :
    data.recommendation_color === "amber" ? "#d97706" :
    data.recommendation_color === "orange" ? "#ea580c" : C.down;

  const chartData = (data.price_history || []).filter((b) => b.close != null);
  const chartLabels = chartData.map((b, i) => {
    const d = new Date(b.trade_date);
    return i === 0 || i === chartData.length - 1 || i === Math.floor(chartData.length / 2)
      ? `${d.getDate()}/${d.getMonth() + 1}` : "";
  });
  const chartPrices = chartData.map((b) => b.close);

  const scoreColor = score.final_score >= 70 ? C.up : score.final_score >= 55 ? "#65a30d" : score.final_score >= 45 ? "#d97706" : score.final_score <= 30 ? C.down : "#a3a3a3";

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 40 }}>
      {/* Header */}
      <View className="flex-row justify-between items-start mb-2">
        <View className="flex-1 pr-2">
          <View className="flex-row items-center gap-2 mb-1">
            <MarketBadge market={data.market} />
            {data.sector ? <Text className="text-ink-faint text-xs" numberOfLines={1}>{data.sector}</Text> : null}
          </View>
          <Text className="text-ink text-2xl font-bold">{data.name}</Text>
          <Text className="text-ink-soft text-sm">{data.symbol}</Text>
        </View>
        <View className="items-end">
          <View className="flex-row items-center gap-2">
            {data.last_price ? (
              <Text className="text-ink text-2xl font-bold">
                {data.currency === "BRL" ? "R$" : "$"} {data.last_price.toFixed(2)}
              </Text>
            ) : null}
            <FavoriteStar active={inWatchlist} onPress={() => toggle.mutate()} size={28} />
          </View>
          {ind.ema20 != null && data.last_price ? (
            <Text className="text-xs font-semibold mt-1" style={{ color: data.last_price > ind.ema20 ? C.up : C.down }}>
              {data.last_price > ind.ema20 ? "▲ Acima EMA20" : "▼ Abaixo EMA20"}
            </Text>
          ) : null}
        </View>
      </View>

      {/* Price Chart */}
      {chartPrices.length > 1 ? (
        <View className="my-3 rounded-2xl overflow-hidden bg-night-800 border border-night-600">
          <LineChart
            data={{ labels: chartLabels, datasets: [{ data: chartPrices, color: () => C.brand, strokeWidth: 2 }] }}
            width={screenWidth - 32}
            height={200}
            chartConfig={{
              backgroundColor: "transparent",
              backgroundGradientFrom: "#0E1729",
              backgroundGradientTo: "#0E1729",
              decimalPlaces: 2,
              color: (opacity) => `rgba(22, 211, 154, ${opacity})`,
              labelColor: () => C.faint,
              style: { borderRadius: 16 },
              propsForDots: { r: 2, strokeWidth: 1, stroke: C.brand },
              fillShadowGradient: "#16D39A",
              fillShadowGradientOpacity: 0.18,
            }}
            bezier
            style={{ marginVertical: 4, borderRadius: 16 }}
          />
        </View>
      ) : null}

      {/* Recommendation + Score Card */}
      <View className="flex-row gap-3 mb-4">
        <View className="items-center justify-center rounded-2xl px-5 py-4" style={{ backgroundColor: scoreColor + "1F", borderWidth: 1, borderColor: scoreColor + "55" }}>
          <Text style={{ color: scoreColor }} className="text-4xl font-bold">{score.final_score}</Text>
          <Text style={{ color: scoreColor }} className="text-xs font-bold">/ 100</Text>
        </View>
        <View className="flex-1 rounded-2xl px-4 py-4 justify-center" style={{ backgroundColor: recoColor }}>
          <Text className="text-white text-center font-bold text-lg">{data.recommendation}</Text>
          <Text className="text-white text-center text-sm mt-1 opacity-90">
            Confiança: {score.confidence}% • {score.trend}
          </Text>
        </View>
      </View>

      {/* Sub-scores */}
      <Card className="flex-row justify-between p-4 mb-3">
        {[
          { label: "Técnica", value: score.subscores.technical, color: C.accent },
          { label: "Valuation", value: score.subscores.valuation, color: C.up },
          { label: "Sentimento", value: score.subscores.sentiment, color: C.amber },
        ].map((s, i) => (
          <View key={i} className="items-center flex-1">
            <Text className="text-ink-faint text-xs mb-1">{s.label}</Text>
            <Text style={{ color: s.color }} className="text-xl font-bold">{s.value}</Text>
            <View className="w-full bg-night-600 rounded-full h-1.5 mt-2 overflow-hidden">
              <View style={{ width: `${Math.min(Math.max(s.value, 0), 100)}%`, backgroundColor: s.color, height: 6, borderRadius: 4 }} />
            </View>
          </View>
        ))}
      </Card>

      {/* Forces */}
      <View className="flex-row gap-3 mb-4">
        <View className="flex-1 rounded-2xl p-3" style={{ backgroundColor: C.up + "14", borderWidth: 1, borderColor: C.up + "44" }}>
          <Text style={{ color: C.up }} className="text-center font-bold text-xs">✓ FORÇA COMPRADORA</Text>
          <Text style={{ color: C.up }} className="text-center text-2xl font-bold mt-1">{score.buyer_strength}</Text>
        </View>
        <View className="flex-1 rounded-2xl p-3" style={{ backgroundColor: C.down + "14", borderWidth: 1, borderColor: C.down + "44" }}>
          <Text style={{ color: C.down }} className="text-center font-bold text-xs">✗ FORÇA VENDEDORA</Text>
          <Text style={{ color: C.down }} className="text-center text-2xl font-bold mt-1">{score.seller_strength}</Text>
        </View>
      </View>

      {/* Technical Indicators */}
      <SectionTitle>Indicadores técnicos</SectionTitle>
      <Card className="p-4 mb-4 gap-2">
        {ind.rsi != null ? (
          <Text className="text-ink-soft">
            RSI (14): <Text className="text-ink font-bold">{ind.rsi.toFixed(1)}</Text>
            {"  "}({ind.rsi < 30 ? "🟢 sobrevendido" : ind.rsi > 70 ? "🔴 sobrecomprado" : "⚪ neutro"})
          </Text>
        ) : null}
        {ind.ema20 != null ? (
          <Text className="text-ink-soft">EMA 20: <Text className="text-ink font-bold">{ind.ema20.toFixed(2)}</Text></Text>
        ) : null}
        {ind.ema50 != null ? (
          <Text className="text-ink-soft">
            EMA 50: <Text className="text-ink font-bold">{ind.ema50.toFixed(2)}</Text>
            {ind.ema20 != null ? (ind.ema20 > ind.ema50 ? "  📈 cruzamento alcista" : "  📉 cruzamento baixista") : ""}
          </Text>
        ) : null}
        {ind.macd != null ? (
          <Text className="text-ink-soft">
            MACD: <Text className="text-ink font-bold">{ind.macd.toFixed(3)}</Text> (sinal {ind.macd_signal?.toFixed(3) ?? "—"})
          </Text>
        ) : null}
        {ind.rsi == null && ind.ema20 == null && ind.macd == null ? (
          <Text className="text-ink-faint">Indisponível (dados insuficientes).</Text>
        ) : null}
      </Card>

      {/* Technical Votes */}
      {Object.keys(data.technical_votes).length > 0 ? (
        <View className="mb-4">
          <SectionTitle>Votos dos indicadores</SectionTitle>
          <View className="flex-row flex-wrap gap-2">
            {Object.entries(data.technical_votes).map(([k, v]) => (
              <View key={k} className="px-3 py-1.5 rounded-full" style={{ backgroundColor: v > 0 ? C.up + "1F" : v < 0 ? C.down + "1F" : C.surface2 }}>
                <Text style={{ color: v > 0 ? C.up : v < 0 ? C.down : C.soft }} className="text-xs font-bold">
                  {k} {v > 0 ? "📈" : v < 0 ? "📉" : "➖"}
                </Text>
              </View>
            ))}
          </View>
        </View>
      ) : null}

      {/* Fundamentals */}
      <SectionTitle>Fundamentos</SectionTitle>
      <Card className="p-4 mb-4 gap-2">
        {fund.pe_ratio != null ? <Text className="text-ink-soft">📊 P/L: <Text className="text-ink font-bold">{fund.pe_ratio.toFixed(2)}</Text></Text> : null}
        {fund.pb_ratio != null ? <Text className="text-ink-soft">📊 P/VPA: <Text className="text-ink font-bold">{fund.pb_ratio.toFixed(2)}</Text></Text> : null}
        {fund.dividend_yield != null ? <Text className="text-ink-soft">💰 Div. Yield: <Text className="text-ink font-bold">{(fund.dividend_yield * 100).toFixed(2)}%</Text></Text> : null}
        {fund.roe != null ? <Text className="text-ink-soft">📈 ROE: <Text className="text-ink font-bold">{(fund.roe * 100).toFixed(1)}%</Text></Text> : null}
        {fund.debt_to_equity != null ? <Text className="text-ink-soft">🏦 Díq./Patrim.: <Text className="text-ink font-bold">{fund.debt_to_equity.toFixed(2)}</Text></Text> : null}
        {fund.pe_ratio == null && fund.roe == null ? <Text className="text-ink-faint">Dados indisponíveis.</Text> : null}
      </Card>

      {/* AI Explanation */}
      <SectionTitle>🤖 Recomendação da IA</SectionTitle>
      <Card className="p-4 mb-4">
        <Text className="text-ink leading-6">{data.ai_explanation}</Text>
        <Text className="text-ink-soft italic leading-5 mt-2">{data.indicators_explanation}</Text>
      </Card>

      {/* News */}
      <SectionTitle>📰 Notícias recentes</SectionTitle>
      <Text className="text-ink-soft italic mb-3">{data.news_summary}</Text>
      {data.news_items && data.news_items.length > 0 ? (
        <View className="gap-2 mb-4">
          {data.news_items.map((n, i) => {
            const sColor = n.sentiment_label === "positive" ? C.up : n.sentiment_label === "negative" ? C.down : C.faint;
            return (
              <Card key={i} className="p-4">
                <View className="flex-row justify-between items-start mb-1">
                  <Text className="text-ink-faint text-xs">{n.source}</Text>
                  <Text style={{ color: sColor }} className="text-xs font-bold">
                    {n.sentiment_label === "positive" ? "🟢 POSITIVO" : n.sentiment_label === "negative" ? "🔴 NEGATIVO" : "⚪ NEUTRO"}
                  </Text>
                </View>
                <Text className="text-ink font-medium leading-5" onPress={() => { if (typeof window !== "undefined") window.open(n.url, "_blank"); }}>
                  {n.title}
                </Text>
                {n.summary ? <Text className="text-ink-soft text-sm mt-1 leading-4" numberOfLines={3}>{n.summary}</Text> : null}
                {n.published_at ? <Text className="text-ink-faint text-[11px] mt-1">{new Date(n.published_at).toLocaleDateString("pt-BR")}</Text> : null}
              </Card>
            );
          })}
        </View>
      ) : (
        <Text className="text-ink-faint mb-4">Sem notícias disponíveis.</Text>
      )}

      {/* Actions */}
      <View className="flex-row gap-3 mb-8">
        <Pressable
          className="flex-1 rounded-xl items-center justify-center py-3 flex-row gap-2"
          style={{ backgroundColor: inWatchlist ? C.surface2 : C.amber, borderWidth: 1, borderColor: inWatchlist ? C.line : C.amber }}
          onPress={() => toggle.mutate()}
        >
          <Ionicons name={inWatchlist ? "star" : "star-outline"} size={18} color={inWatchlist ? C.amber : "#04110C"} />
          <Text className="font-bold" style={{ color: inWatchlist ? C.amber : "#04110C" }}>
            {inWatchlist ? "Na watchlist" : "Favoritar"}
          </Text>
        </Pressable>
        <Pressable
          className="flex-1 rounded-xl items-center justify-center py-3 border"
          style={{ borderColor: C.line, backgroundColor: C.surface }}
          onPress={() => router.back()}
        >
          <Text className="text-ink font-semibold">← Voltar</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}
