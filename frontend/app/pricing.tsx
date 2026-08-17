import "../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { Pressable, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";

import { plansApi, subscriptionsApi, featuresApi } from "@/api/client";
import { useAuthStore } from "@/state/authStore";
import { C, Loading } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";

const PLAN_STYLE: Record<string, { color: string; badge: string | null; sub: string }> = {
  free: { color: "#95A6C3", badge: null, sub: "Para começar a explorar" },
  start: { color: "#16D39A", badge: "MAIS POPULAR", sub: "Para quem leva trading a sério" },
  ultimate: { color: "#8B5CF6", badge: "PREMIUM", sub: "Para traders profissionais" },
};

export default function PricingScreen() {
  const { data: plans, isLoading } = useQuery({ queryKey: ["plans"], queryFn: plansApi.list });
  const { data: features } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const token = useAuthStore((s) => s.accessToken);
  const [loadingCheckout, setLoadingCheckout] = useState<string | null>(null);

  const links = features?.links;

  const handleSubscribe = async (planCode: string) => {
    if (planCode === "free") {
      router.push(token ? "/(tabs)" : "/auth/register");
      return;
    }
    if (!token) {
      router.push("/auth/register");
      return;
    }
    setLoadingCheckout(planCode);
    try {
      const res = await subscriptionsApi.checkout(planCode, "monthly");
      if (res.checkout_url && typeof window !== "undefined") window.open(res.checkout_url, "_blank");
    } catch {}
    setLoadingCheckout(null);
  };

  const planFeatures = (limits: Record<string, any>, color: string): { text: string; ok: boolean }[] => [
    { text: limits.assets_analyzed ? `${limits.assets_analyzed} ativos analisados` : "Ativos analisados ilimitados", ok: true },
    { text: "Robôs e indicadores desvendados", ok: !!limits.robots_indicators },
    { text: "Copy trading", ok: !!limits.copy_trading },
    { text: "Sala de trading ao vivo", ok: !!limits.live_trading_room },
    { text: "Desconto de curso", ok: !!limits.course_discount },
    { text: "Painel de trading", ok: !!limits.trading_panel },
    { text: "Robô automático", ok: !!limits.auto_robot },
  ];

  return (
    <ScrollView className="flex-1 bg-night">
      {/* Hero */}
      <View className="px-6 pt-14 pb-10 items-center" style={{ backgroundColor: C.deep }}>
        <View className="w-14 h-14 rounded-2xl items-center justify-center mb-4" style={{ backgroundColor: C.brand + "22" }}>
          <Ionicons name="trending-up" size={28} color={C.brand} />
        </View>
        <Text className="text-ink text-3xl font-bold text-center">Handliv Trading</Text>
        <Text className="text-ink-soft text-base text-center mt-2 px-4">
          Inteligência artificial para investir com confiança
        </Text>
        <View className="flex-row gap-2 mt-4">
          <Text className="text-ink-faint text-xs">500+ clientes</Text>
          <Text className="text-ink-faint text-xs">•</Text>
          <Text className="text-ink-faint text-xs">★ 4,9 avaliação</Text>
          <Text className="text-ink-faint text-xs">•</Text>
          <Text className="text-ink-faint text-xs">7 dias de garantia</Text>
        </View>
      </View>

      <View className="px-4 py-8">
        <Text className="text-ink text-2xl font-bold text-center mb-1">Escolha seu plano</Text>
        <Text className="text-ink-soft text-sm text-center mb-6 px-6">
          3 planos para todos os perfis. Cancele quando quiser.
        </Text>

        {isLoading ? (
          <Loading />
        ) : plans && plans.length > 0 ? (
          <View className="gap-4">
            {plans.map((plan: any) => {
              const style = PLAN_STYLE[plan.code] ?? PLAN_STYLE.free;
              const price = plan.price_monthly_cents / 100;
              const isFree = plan.code === "free";
              const isCurrent = features?.plan_code === plan.code;
              const limits = plan.limits_json ?? {};

              return (
                <View
                  key={plan.code}
                  className="rounded-2xl p-5 relative overflow-hidden"
                  style={{ backgroundColor: C.surface, borderWidth: 2, borderColor: isCurrent ? style.color : C.line }}
                >
                  {style.badge ? (
                    <View className="self-start px-3 py-1 rounded-full mb-3" style={{ backgroundColor: style.color }}>
                      <Text className="text-[#04110C] text-[10px] font-bold tracking-wider">{style.badge}</Text>
                    </View>
                  ) : null}

                  {isCurrent ? (
                    <View className="self-start px-3 py-1 rounded-full mb-3 border" style={{ borderColor: style.color + "88", backgroundColor: style.color + "22" }}>
                      <Text className="text-[10px] font-bold tracking-wider" style={{ color: style.color }}>SEU PLANO ATUAL</Text>
                    </View>
                  ) : null}

                  <Text style={{ color: style.color }} className="text-sm font-bold tracking-widest">{plan.code.toUpperCase()}</Text>
                  <View className="flex-row items-end mt-1 mb-1">
                    <Text className="text-ink text-4xl font-bold">
                      {price === 0 ? "R$ 0" : `R$ ${price.toFixed(0)}`}
                    </Text>
                    {price > 0 ? <Text className="text-ink-faint text-sm mb-1"> /mês</Text> : null}
                  </View>
                  <Text className="text-ink-soft text-xs mb-4">{style.sub}</Text>

                  <View className="gap-2.5 mb-5">
                    {planFeatures(limits, style.color).map((f) => (
                      <View key={f.text} className="flex-row items-center gap-2">
                        <Ionicons
                          name={f.ok ? "checkmark-circle" : "close-circle"}
                          size={16}
                          color={f.ok ? style.color : "#3D4E71"}
                        />
                        <Text className={`text-sm ${f.ok ? "text-ink" : "text-ink-faint"}`} style={!f.ok ? { textDecorationLine: "line-through" } : undefined}>
                          {f.text}
                        </Text>
                      </View>
                    ))}
                  </View>

                  <Pressable
                    className={`rounded-xl py-3.5 items-center flex-row justify-center gap-2 ${isFree ? "border" : ""}`}
                    style={{
                      backgroundColor: isFree ? "transparent" : style.color,
                      borderColor: isFree ? style.color : undefined,
                    }}
                    onPress={() => handleSubscribe(plan.code)}
                    disabled={loadingCheckout === plan.code}
                  >
                    <Ionicons name="arrow-down-circle" size={18} color={isFree ? style.color : "#04110C"} />
                    <Text className="font-bold" style={{ color: isFree ? style.color : "#04110C" }}>
                      {loadingCheckout === plan.code
                        ? "Redirecionando..."
                        : isCurrent
                          ? "Plano atual"
                          : isFree
                            ? "Começar grátis"
                            : "Assinar agora"}
                    </Text>
                  </Pressable>
                </View>
              );
            })}
          </View>
        ) : (
          <Text className="text-ink-soft text-center">Não foi possível carregar os planos.</Text>
        )}

        <View className="items-center gap-4 mt-8">
          <Text className="text-ink-soft text-sm text-center px-6">
            Não tem certeza de qual plano combina com você? Fale com a nossa equipe.
          </Text>
          <Pressable
            className="flex-row items-center gap-2 rounded-xl px-6 py-3"
            style={{ backgroundColor: "#25D366" + "22", borderWidth: 1, borderColor: "#25D366" + "55" }}
            onPress={() => { if (typeof window !== "undefined") window.open(WHATSAPP, "_blank"); }}
          >
            <Ionicons name="logo-whatsapp" size={18} color="#25D366" />
            <Text className="font-bold" style={{ color: "#25D366" }}>Contato</Text>
          </Pressable>
          {!token ? (
            <Pressable onPress={() => router.push("/auth/login")}>
              <Text className="text-accent font-semibold">Já tenho conta → Entrar</Text>
            </Pressable>
          ) : (
            <Pressable onPress={() => router.push("/(tabs)/trading")}>
              <Text className="text-accent font-semibold">← Voltar ao painel</Text>
            </Pressable>
          )}
        </View>
      </View>
    </ScrollView>
  );
}
