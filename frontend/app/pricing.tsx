import "../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";
import { useState } from "react";

import { plansApi, subscriptionsApi, useAuthStore, featuresApi } from "@/api/client";

const WHATSAPP = "https://wa.me/551152866453";
const DISCORD = "https://discord.com/invite/6X3MamvS5T";
const CURSOS = "https://handliv.kpages.online/cursos";

export default function PricingScreen() {
  const { data: plans, isLoading } = useQuery({ queryKey: ["plans"], queryFn: plansApi.list });
  const { data: features } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const token = useAuthStore((s) => s.accessToken);
  const [loadingCheckout, setLoadingCheckout] = useState<string | null>(null);

  const links = features?.links || { whatsapp: WHATSAPP, discord: DISCORD, cursos: CURSOS, copy_trading: WHATSAPP, robots_indicators: WHATSAPP, trading_panel: "", auto_robot: WHATSAPP };

  const open = (url: string) => {
    if (url && typeof window !== "undefined") window.open(url, "_blank");
  };

  const handleSubscribe = async (planCode: string) => {
    if (planCode === "free") {
      if (token) router.push("/(tabs)");
      else router.push("/auth/register");
      return;
    }
    if (!token) {
      router.push("/auth/register");
      return;
    }
    setLoadingCheckout(planCode);
    try {
      const res = await subscriptionsApi.checkout(planCode, "monthly");
      if (res.checkout_url) open(res.checkout_url);
    } catch {}
    setLoadingCheckout(null);
  };

  const planConfig: Record<string, { color: string; badge: string | null }> = {
    free: { color: "#737373", badge: null },
    start: { color: "#2563eb", badge: "MAIS POPULAR" },
    ultimate: { color: "#7c3aed", badge: "PREMIUM" },
  };

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950">
      <View className="bg-blue-600 px-6 py-12 items-center">
        <Text className="text-white text-3xl font-bold text-center">Handliv Trading</Text>
        <Text className="text-blue-100 text-lg text-center mt-2">
          Inteligência artificial para investir com confiança
        </Text>
      </View>

      <View className="px-6 py-8">
        {isLoading ? (
          <ActivityIndicator size="large" />
        ) : plans && plans.length > 0 ? (
          <View className="gap-4">
            {plans.map((plan) => {
              const config = planConfig[plan.code] || planConfig.free;
              const price = plan.price_monthly_cents / 100;
              const limits = plan.limits_json as Record<string, any>;
              const isFree = plan.code === "free";

              return (
                <View
                  key={plan.code}
                  className="rounded-2xl p-6"
                  style={{ backgroundColor: config.color + "10", borderWidth: 2, borderColor: config.color }}
                >
                  {config.badge ? (
                    <View className="self-start px-3 py-1 rounded-full mb-2" style={{ backgroundColor: config.color }}>
                      <Text className="text-white text-xs font-bold">{config.badge}</Text>
                    </View>
                  ) : null}

                  <Text style={{ color: config.color }} className="text-2xl font-bold">{plan.name}</Text>
                  <Text style={{ color: config.color }} className="text-4xl font-bold mt-2">
                    {price === 0 ? "Grátis" : `R$ ${price.toFixed(0)}`}
                    {price > 0 ? <Text style={{ color: config.color }} className="text-sm font-normal">/mês</Text> : null}
                  </Text>

                  {/* Features + Botões */}
                  <View className="mt-4 gap-3">
                    <RowItem text={`📊 ${isFree ? "3 ativos" : limits.assets_analyzed ? `${limits.assets_analyzed} ativos` : "Ativos ilimitados"}`} ok={true} />

                    <FeatureRow
                      text="🤖 Robôs e Indicadores"
                      ok={limits.robots_indicators}
                      btnLabel={limits.robots_indicators ? "Acessar →" : "WhatsApp →"}
                      btnUrl={limits.robots_indicators ? links.robots_indicators : links.whatsapp}
                      color={config.color}
                    />
                    <FeatureRow
                      text="📈 Copy Trading"
                      ok={limits.copy_trading}
                      btnLabel={limits.copy_trading ? "Acessar →" : "WhatsApp →"}
                      btnUrl={limits.copy_trading ? links.copy_trading : links.whatsapp}
                      color={config.color}
                    />
                    <FeatureRow
                      text="🎥 Sala de Trading ao Vivo"
                      ok={limits.live_trading_room}
                      btnLabel={limits.live_trading_room ? "Entrar no Discord →" : "WhatsApp →"}
                      btnUrl={limits.live_trading_room ? links.discord : links.whatsapp}
                      color={config.color}
                    />
                    <FeatureRow
                      text="🎓 Desconto de Curso"
                      ok={limits.course_discount}
                      btnLabel={limits.course_discount ? "Acessar Curso →" : "WhatsApp →"}
                      btnUrl={limits.course_discount ? links.cursos : links.whatsapp}
                      color={config.color}
                    />
                    <RowItem text={`📉 Painel de Trading${limits.trading_panel ? "" : " (bloqueado)"}`} ok={limits.trading_panel} />
                    <RowItem text={`🤖 Robô Automático${limits.auto_robot ? "" : " (bloqueado)"}`} ok={limits.auto_robot} />
                  </View>

                  <Pressable
                    className="mt-5 py-3 rounded-xl items-center"
                    style={{ backgroundColor: config.color }}
                    onPress={() => handleSubscribe(plan.code)}
                    disabled={loadingCheckout === plan.code}
                  >
                    <Text className="text-white font-bold">
                      {loadingCheckout === plan.code ? "Redirecionando..." : isFree ? "Começar Grátis" : "Assinar com Stripe"}
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

      <View className="px-6 pb-8 items-center">
        {!token ? (
          <Pressable onPress={() => router.push("/auth/login")}>
            <Text className="text-blue-600 font-semibold mt-2">Já tenho conta → Entrar</Text>
          </Pressable>
        ) : null}
      </View>
    </ScrollView>
  );
}

function RowItem({ text, ok }: { text: string; ok: boolean }) {
  return (
    <View className="flex-row items-center">
      <Text className={ok ? "text-neutral-900 dark:text-white text-sm" : "text-neutral-400 text-sm line-through"}>
        {ok ? "✓ " : "🔒 "}{text}
      </Text>
    </View>
  );
}

function FeatureRow({ text, ok, btnLabel, btnUrl, color }: { text: string; ok: boolean; btnLabel: string; btnUrl: string; color: string }) {
  const open = (url: string) => {
    if (url && typeof window !== "undefined") window.open(url, "_blank");
  };
  return (
    <View className="flex-row items-center justify-between">
      <Text className={ok ? "text-neutral-900 dark:text-white text-sm" : "text-neutral-400 text-sm line-through"}>
        {ok ? "✓ " : "🔒 "}{text}
      </Text>
      <Pressable onPress={() => open(btnUrl)} className="px-3 py-1 rounded-lg" style={{ backgroundColor: ok ? color : "#f59e0b" }}>
        <Text className="text-white text-xs font-bold">{btnLabel}</Text>
      </Pressable>
    </View>
  );
}