import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, Text, View } from "react-native";

import { featuresApi } from "@/api/client";

const WHATSAPP = "https://wa.me/551152866453";
const DISCORD = "https://discord.com/invite/6X3MamvS5T";
const CURSOS = "https://handliv.kpages.online/cursos";
const HANDLIV = "https://handliv.com";

const open = (url: string) => {
  if (url && typeof window !== "undefined") window.open(url, "_blank");
};

export default function RecursosScreen() {
  const { data: features, isLoading } = useQuery({
    queryKey: ["features"],
    queryFn: featuresApi.myFeatures,
  });

  const f = features?.features;
  const links = features?.links || {
    whatsapp: WHATSAPP,
    discord: DISCORD,
    cursos: CURSOS,
    copy_trading: WHATSAPP,
    robots_indicators: WHATSAPP,
    trading_panel: "",
    auto_robot: WHATSAPP,
  };
  const plan = features?.plan_code ?? "free";

  if (isLoading) {
    return (
      <View className="flex-1 bg-white dark:bg-neutral-950 items-center justify-center">
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  const cards: {
    icon: string;
    title: string;
    subtitle: string;
    active: boolean;
    actionUrl: string;
    actionLabel: string;
    color: string;
  }[] = [
    {
      icon: "🤖",
      title: "Robôs e Indicadores Desvendados",
      subtitle: f?.robots_indicators ? "Acesso liberado" : "Disponível nos planos Start e Ultimate",
      active: !!f?.robots_indicators,
      actionUrl: f?.robots_indicators ? links.robots_indicators : links.whatsapp,
      actionLabel: f?.robots_indicators ? "Acessar Robôs →" : "WhatsApp →",
      color: "#2563eb",
    },
    {
      icon: "📈",
      title: "Copy Trading",
      subtitle: f?.copy_trading ? "Acesso liberado" : "Disponível nos planos Start e Ultimate",
      active: !!f?.copy_trading,
      actionUrl: f?.copy_trading ? links.copy_trading : links.whatsapp,
      actionLabel: f?.copy_trading ? "Acessar Copy Trading →" : "WhatsApp →",
      color: "#16a34a",
    },
    {
      icon: "🎥",
      title: "Sala de Trading ao Vivo",
      subtitle: f?.live_trading_room ? "Entrar na sala agora" : "Disponível nos planos Start e Ultimate",
      active: !!f?.live_trading_room,
      actionUrl: f?.live_trading_room ? links.discord : links.whatsapp,
      actionLabel: f?.live_trading_room ? "Entrar no Discord →" : "WhatsApp →",
      color: "#5865F2",
    },
    {
      icon: "🎓",
      title: "Desconto de Curso",
      subtitle: f?.course_discount ? "Acesso liberado" : "Disponível nos planos Start e Ultimate",
      active: !!f?.course_discount,
      actionUrl: f?.course_discount ? links.cursos : links.whatsapp,
      actionLabel: f?.course_discount ? "Acessar Cursos →" : "WhatsApp →",
      color: "#7c3aed",
    },
    {
      icon: "⚙️",
      title: "Robô Automático",
      subtitle: f?.auto_robot ? "Baixar no site da Handliv" : "Disponível no plano Ultimate",
      active: !!f?.auto_robot,
      actionUrl: f?.auto_robot ? HANDLIV : links.whatsapp,
      actionLabel: f?.auto_robot ? "Baixar Robô →" : "WhatsApp →",
      color: "#dc2626",
    },
  ];

  return (
    <ScrollView className="flex-1 bg-white dark:bg-neutral-950 p-4">
      {/* Header */}
      <View className="mb-5">
        <Text className="text-neutral-900 dark:text-white text-2xl font-bold">
          Recursos da sua Assinatura
        </Text>
        <Text className="text-neutral-500 mt-1">
          Acesse rapidamente todos os benefícios do seu plano.
        </Text>
      </View>

      {/* Plan badge */}
      <View className="flex-row items-center justify-between bg-gradient-to-r from-blue-600 to-indigo-600 rounded-2xl px-4 py-3 mb-5">
        <View>
          <Text className="text-white font-bold text-lg">Plano {plan.toUpperCase()}</Text>
          {features && !features.payment_ok && plan !== "free" ? (
            <Text className="text-red-100 text-sm mt-1">
              ⚠ Pagamento atrasado. Regularize sua assinatura.
            </Text>
          ) : (
            <Text className="text-blue-100 text-sm mt-0.5">
              {plan === "free"
                ? "Assine o Start ou Ultimate para liberar todos os recursos"
                : "Todos os recursos do seu plano liberados"}
            </Text>
          )}
        </View>
      </View>

      {/* Feature cards */}
      <View className="gap-4">
        {cards.map((card) => (
          <Pressable
            key={card.title}
            className="rounded-2xl p-5"
            style={{
              backgroundColor: card.color + (card.active ? "12" : "08"),
              borderWidth: 2,
              borderColor: card.active ? card.color : card.color + "30",
            }}
            onPress={() => open(card.actionUrl)}
          >
            <View className="flex-row items-center">
              <Text className="text-4xl mr-4">{card.icon}</Text>
              <View className="flex-1">
                <Text
                  className={`text-lg font-bold ${card.active ? "text-neutral-900 dark:text-white" : "text-neutral-400"}`}
                >
                  {card.title}
                </Text>
                <Text className="text-neutral-500 text-sm mt-0.5">{card.subtitle}</Text>
              </View>
            </View>
            <View
              className="mt-4 px-4 py-2.5 rounded-xl items-center"
              style={{ backgroundColor: card.active ? card.color : "#f59e0b" }}
            >
              <Text className="text-white font-bold">{card.actionLabel}</Text>
            </View>
          </Pressable>
        ))}
      </View>

      {/* Trading panel shortcut */}
      <Pressable
        className="mt-6 bg-neutral-100 dark:bg-neutral-900 rounded-2xl p-4 flex-row items-center justify-between"
        onPress={() => router.push("/trading-panel")}
      >
        <View className="flex-row items-center">
          <Text className="text-3xl mr-3">📉</Text>
          <View>
            <Text className="text-neutral-900 dark:text-white font-bold">Painel de Trading & MT5</Text>
            <Text className="text-neutral-500 text-sm">Resultados de trades e contas MetaTrader</Text>
          </View>
        </View>
        <Text className="text-neutral-400 text-xl">›</Text>
      </Pressable>

      {/* Upgrade CTA */}
      {plan === "free" ? (
        <Pressable
          className="mt-4 bg-gradient-to-r from-amber-500 to-orange-500 rounded-2xl p-4 items-center"
          onPress={() => router.push("/pricing")}
        >
          <Text className="text-white font-bold text-lg">Ver Planos e Assinar →</Text>
          <Text className="text-amber-100 text-sm mt-1">Desbloqueie todos os recursos agora</Text>
        </Pressable>
      ) : null}
    </ScrollView>
  );
}
