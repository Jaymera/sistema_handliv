import "../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";
import { useState } from "react";

import { plansApi, subscriptionsApi, useAuthStore } from "@/api/client";

const WHATSAPP_URL = "https://wa.me/551152866453";
const DISCORD_URL = "https://discord.com/invite/6X3MamvS5T";
const CURSOS_URL = "https://handliv.kpages.online/cursos";

const PLAN_INFO: Record<string, { color: string; badge: string | null; features: { icon: string; text: string; link?: string; locked?: boolean }[] }> = {
  free: {
    color: "#737373",
    badge: null,
    features: [
      { icon: "📊", text: "Analisar até 3 ativos" },
      { icon: "🤖", text: "Robôs e Indicadores", locked: true, link: WHATSAPP_URL },
      { icon: "📈", text: "Copy Trading", locked: true, link: WHATSAPP_URL },
    ],
  },
  start: {
    color: "#2563eb",
    badge: "MAIS POPULAR",
    features: [
      { icon: "📊", text: "Analisar até 10 ativos" },
      { icon: "🤖", text: "Robôs e Indicadores" },
      { icon: "📈", text: "Copy Trading" },
      { icon: "🎥", text: "Sala de Trading ao Vivo", link: DISCORD_URL },
      { icon: "🎓", text: "Desconto de Curso", link: CURSOS_URL },
      { icon: "📉", text: "Painel de Trading" },
    ],
  },
  ultimate: {
    color: "#7c3aed",
    badge: "PREMIUM",
    features: [
      { icon: "∞", text: "Ativos Ilimitados" },
      { icon: "🤖", text: "Robôs e Indicadores" },
      { icon: "📈", text: "Copy Trading" },
      { icon: "🎥", text: "Sala de Trading ao Vivo", link: DISCORD_URL },
      { icon: "🎓", text: "Desconto de Curso", link: CURSOS_URL },
      { icon: "📉", text: "Painel de Trading" },
      { icon: "🤖", text: "Robô Automático" },
    ],
  },
};

export default function PricingScreen() {
  const { data: plans, isLoading } = useQuery({ queryKey: ["plans"], queryFn: plansApi.list });
  const token = useAuthStore((s) => s.accessToken);
  const [loadingCheckout, setLoadingCheckout] = useState<string | null>(null);

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
      if (res.checkout_url) {
        window.open(res.checkout_url, "_blank");
      }
    } catch {}
    setLoadingCheckout(null);
  };

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950">
      {/* Hero */}
      <View className="bg-blue-600 px-6 py-12 items-center">
        <Text className="text-white text-3xl font-bold text-center">Handliv Trading</Text>
        <Text className="text-blue-100 text-lg text-center mt-2">
          Inteligência artificial para investir com confiança
        </Text>
      </View>

      {/* Plans */}
      <View className="px-6 py-8">
        {isLoading ? (
          <ActivityIndicator size="large" />
        ) : plans && plans.length > 0 ? (
          <View className="gap-4">
            {plans.map((plan) => {
              const info = PLAN_INFO[plan.code] || PLAN_INFO.free;
              const price = plan.price_monthly_cents / 100;

              return (
                <View
                  key={plan.code}
                  className="rounded-2xl p-6"
                  style={{ backgroundColor: info.color + "10", borderWidth: 2, borderColor: info.color }}
                >
                  {info.badge ? (
                    <View className="self-start px-3 py-1 rounded-full mb-2" style={{ backgroundColor: info.color }}>
                      <Text className="text-white text-xs font-bold">{info.badge}</Text>
                    </View>
                  ) : null}

                  <Text style={{ color: info.color }} className="text-2xl font-bold">{plan.name}</Text>
                  <Text style={{ color: info.color }} className="text-4xl font-bold mt-2">
                    {price === 0 ? "Grátis" : `R$ ${price.toFixed(0)}`}
                    {price > 0 ? <Text style={{ color: info.color }} className="text-sm font-normal">/mês</Text> : null}
                  </Text>

                  {/* Features */}
                  <View className="mt-4 gap-2">
                    {info.features.map((f, i) => (
                      <View key={i} className="flex-row items-center">
                        <Text className="text-xl mr-2">{f.icon}</Text>
                        <Text
                          className={f.locked ? "text-neutral-400 line-through" : "text-neutral-900 dark:text-white"}
                          style={!f.locked ? { color: info.color } : {}}
                        >
                          {f.text}
                        </Text>
                        {f.link ? (
                          <Pressable onPress={() => window.open(f.link, "_blank")} className="ml-auto">
                            <Text style={{ color: info.color }} className="text-xs font-bold">
                              {f.link === WHATSAPP_URL ? "WhatsApp →" : f.link === DISCORD_URL ? "Entrar →" : "Acessar →"}
                            </Text>
                          </Pressable>
                        ) : null}
                        {f.locked ? (
                          <Pressable onPress={() => window.open(WHATSAPP_URL, "_blank")} className="ml-auto">
                            <Text className="text-blue-600 text-xs font-bold">WhatsApp →</Text>
                          </Pressable>
                        ) : null}
                      </View>
                    ))}
                  </View>

                  {/* CTA */}
                  <Pressable
                    className="mt-5 py-3 rounded-xl items-center"
                    style={{ backgroundColor: info.color }}
                    onPress={() => handleSubscribe(plan.code)}
                    disabled={loadingCheckout === plan.code}
                  >
                    <Text className="text-white font-bold">
                      {loadingCheckout === plan.code ? "Redirecionando..." : plan.code === "free" ? "Começar Grátis" : "Assinar Agora"}
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
        {!token ? (
          <Pressable onPress={() => router.push("/auth/login")}>
            <Text className="text-blue-600 font-semibold mt-2">Já tenho conta → Entrar</Text>
          </Pressable>
        ) : null}
      </View>
    </ScrollView>
  );
}