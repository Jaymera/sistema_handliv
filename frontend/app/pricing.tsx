import "../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";
import { useState } from "react";

import { plansApi } from "@/api/client";
import { useAuthStore } from "@/state/authStore";

export default function PricingScreen() {
  const { data: plans, isLoading } = useQuery({ queryKey: ["plans"], queryFn: plansApi.list });
  const token = useAuthStore((s) => s.accessToken);
  const [annual, setAnnual] = useState(false);

  const planStyles: Record<string, { bg: string; border: string; text: string; badge: string | null }> = {
    free: { bg: "#f5f5f4", border: "#d6d3d1", text: "#44403c", badge: null },
    pro: { bg: "#2563eb", border: "#2563eb", text: "#fff", badge: "MAIS POPULAR" },
    premium: { bg: "#1c1917", border: "#1c1917", text: "#fff", badge: "PREMIUM" },
  };

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950">
      {/* Hero */}
      <View className="bg-gradient-to-b from-blue-600 to-blue-800 px-6 py-12 items-center">
        <Text className="text-white text-3xl font-bold text-center">Handliv Trading</Text>
        <Text className="text-blue-100 text-lg text-center mt-2">
          Inteligência artificial para investir com confiança
        </Text>
        <Text className="text-blue-200 text-sm text-center mt-1">
          Análise técnica, fundamentalista e de sentimento em tempo real
        </Text>
      </View>

      {/* Features */}
      <View className="px-6 py-8">
        <Text className="text-neutral-900 dark:text-white text-xl font-bold mb-4 text-center">
          Recursos incluídos
        </Text>
        <View className="gap-3">
          {[
            { icon: "📊", title: "Análise Técnica Completa", desc: "RSI, MACD, EMA, Bollinger, ADX, Stochastic e Supertrend" },
            { icon: "💰", title: "Fundamentos Atualizados", desc: "P/L, P/VPA, Dividend Yield, ROE e Dívida/Patrimônio" },
            { icon: "📰", title: "Notícias com Sentimento", desc: "Últimas notícias analisadas por IA com peso no score" },
            { icon: "🤖", title: "Score de Recomendação", desc: "COMPRA, VENDA ou NEUTRO com confiança e tendência" },
            { icon: "📈", title: "Gráficos de Preço", desc: "Histórico de cotações em tempo real" },
            { icon: "⭐", title: "Watchlist Personalizada", desc: "Acompanhe seus ativos favoritos" },
          ].map((f, i) => (
            <View key={i} className="flex-row items-center bg-neutral-50 dark:bg-neutral-900 rounded-xl p-4">
              <Text className="text-2xl mr-3">{f.icon}</Text>
              <View className="flex-1">
                <Text className="text-neutral-900 dark:text-white font-semibold">{f.title}</Text>
                <Text className="text-neutral-500 text-sm">{f.desc}</Text>
              </View>
            </View>
          ))}
        </View>
      </View>

      {/* Billing Toggle */}
      <View className="flex-row justify-center items-center gap-3 mb-4">
        <Pressable onPress={() => setAnnual(false)}>
          <Text className={!annual ? "text-blue-600 font-bold text-lg" : "text-neutral-400 text-lg"}>Mensal</Text>
        </Pressable>
        <Text className="text-neutral-400">|</Text>
        <Pressable onPress={() => setAnnual(true)}>
          <Text className={annual ? "text-blue-600 font-bold text-lg" : "text-neutral-400 text-lg"}>
            Anual <Text className="text-green-600 text-sm">-17%</Text>
          </Text>
        </Pressable>
      </View>

      {/* Plans */}
      <View className="px-6 pb-8">
        {isLoading ? (
          <ActivityIndicator size="large" />
        ) : plans && plans.length > 0 ? (
          <View className="gap-4">
            {plans.map((plan) => {
              const style = planStyles[plan.code] || planStyles.free;
              const monthly = plan.price_monthly_cents / 100;
              const yearly = plan.price_yearly_cents / 100;
              const price = annual ? (yearly / 12) : monthly;
              const limits = plan.limits_json as Record<string, any>;

              return (
                <View
                  key={plan.code}
                  className="rounded-2xl p-6"
                  style={{ backgroundColor: style.bg, borderWidth: 2, borderColor: style.border }}
                >
                  {style.badge ? (
                    <View className="self-start bg-yellow-400 px-3 py-1 rounded-full mb-2">
                      <Text className="text-black text-xs font-bold">{style.badge}</Text>
                    </View>
                  ) : null}

                  <Text style={{ color: style.text }} className="text-2xl font-bold">{plan.name}</Text>
                  <Text style={{ color: style.text }} className="text-4xl font-bold mt-2">
                    {price === 0 ? "Grátis" : `R$ ${price.toFixed(2)}`}
                    {price > 0 ? <Text style={{ color: style.text }} className="text-sm font-normal">/mês</Text> : null}
                  </Text>
                  {annual && price > 0 ? (
                    <Text style={{ color: style.text, opacity: 0.7 }} className="text-sm">Cobrado anualmente R$ {yearly.toFixed(0)}</Text>
                  ) : null}

                  {/* Limits */}
                  <View className="mt-4 gap-2">
                    {limits.watchlist ? (
                      <Text style={{ color: style.text }}>
                        {limits.watchlist === "null" || limits.watchlist === null ? "∞" : limits.watchlist}
                        {"  ativos na watchlist"}
                      </Text>
                    ) : null}
                    {limits.alerts ? (
                      <Text style={{ color: style.text }}>
                        {limits.alerts === "null" || limits.alerts === null ? "∞" : limits.alerts}{"  alertas"}
                      </Text>
                    ) : null}
                    {limits.ai ? (
                      <Text style={{ color: style.text }}>✓ Análise com IA</Text>
                    ) : (
                      <Text style={{ color: style.text, opacity: 0.5 }}>✗ Sem IA</Text>
                    )}
                    {limits.history_days ? (
                      <Text style={{ color: style.text }}>
                        {limits.history_days === "null" || limits.history_days === null ? "∞" : `${limits.history_days} dias`}
                        {"  de histórico"}
                      </Text>
                    ) : null}
                    {Array.isArray(limits.markets) ? (
                      <Text style={{ color: style.text }}>📊 {limits.markets.join(", ")}</Text>
                    ) : limits.markets === "all" ? (
                      <Text style={{ color: style.text }}>📊 Todos os mercados</Text>
                    ) : null}
                  </View>

                  {/* CTA */}
                  <Pressable
                    className="mt-5 py-3 rounded-xl items-center"
                    style={{ backgroundColor: style.text === "#fff" ? "#fff" : "#2563eb" }}
                    onPress={() => router.push(token ? "/(tabs)" : "/auth/register")}
                  >
                    <Text style={{ color: style.text === "#fff" ? "#000" : "#fff" }} className="font-bold">
                      {plan.code === "free" ? "Começar Grátis" : "Assinar Agora"}
                    </Text>
                  </Pressable>
                </View>
              );
            })}
          </View>
        ) : (
          <Text className="text-neutral-500 text-center">Não foi possível carregar os planos.</Text>
        )}
      </View>

      {/* Footer */}
      <View className="px-6 pb-8 items-center">
        <Text className="text-neutral-400 text-sm text-center">
          {token ? "Já está logado. " : ""}Acesso completo a ações US, BR e Europeias + Cripto e Forex.
        </Text>
        {!token ? (
          <Pressable onPress={() => router.push("/auth/login")}>
            <Text className="text-blue-600 font-semibold mt-2">Já tenho conta → Entrar</Text>
          </Pressable>
        ) : null}
      </View>
    </ScrollView>
  );
}