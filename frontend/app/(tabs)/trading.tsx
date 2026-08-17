import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { Pressable, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { featuresApi } from "@/api/client";
import { Badge, C, Card, Loading, PLAN_THEME, SectionTitle, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";

type Feature = { icon: string; title: string; desc: string; active: boolean; url: string; actionLabel: string; color: string };

export default function TradingPanelScreen() {
  const { data: features, isLoading } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });

  if (isLoading) return <Loading label="Carregando painel..." />;

  const f = features?.features;
  const links = features?.links;
  const plan = PLAN_THEME[features?.plan_code ?? "free"] ?? PLAN_THEME.free;

  const list: Feature[] = [
    {
      icon: "hardware-chip",
      title: "Robôs e Indicadores",
      desc: "Robôs e indicadores desvendados",
      active: !!f?.robots_indicators,
      url: f?.robots_indicators ? links?.robots_indicators || WHATSAPP : WHATSAPP,
      actionLabel: f?.robots_indicators ? "Acessar" : "WhatsApp",
      color: C.accent,
    },
    {
      icon: "copy",
      title: "Copy Trading",
      desc: "Copie as operações dos melhores",
      active: !!f?.copy_trading,
      url: f?.copy_trading ? links?.copy_trading || WHATSAPP : WHATSAPP,
      actionLabel: f?.copy_trading ? "Acessar" : "WhatsApp",
      color: C.up,
    },
    {
      icon: "videocam",
      title: "Sala de Trading ao Vivo",
      desc: "Sala exclusiva no Discord",
      active: !!f?.live_trading_room,
      url: f?.live_trading_room ? links?.discord || WHATSAPP : WHATSAPP,
      actionLabel: f?.live_trading_room ? "Discord" : "WhatsApp",
      color: "#5865F2",
    },
    {
      icon: "school",
      title: "Desconto de Curso",
      desc: "Cursos com desconto exclusivo",
      active: !!f?.course_discount,
      url: f?.course_discount ? links?.cursos || WHATSAPP : WHATSAPP,
      actionLabel: f?.course_discount ? "Cursos" : "WhatsApp",
      color: C.purple,
    },
    {
      icon: "stats-chart",
      title: "Painel de Trading",
      desc: "Cadastro de trades e resultados",
      active: !!f?.trading_panel,
      url: "",
      actionLabel: "Abrir aba",
      color: C.brand,
    },
    {
      icon: "hardware-chip",
      title: "Robô Automático",
      desc: "EA Livewell no MT5 · exclusivo Ultimate",
      active: !!f?.auto_robot,
      url: "",
      actionLabel: "Abrir aba",
      color: C.amber,
    },
  ];

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
      <Text className="text-ink text-2xl font-bold mb-4">Painel de Trading</Text>

      {/* Plan card */}
      <Card className="p-4 mb-5 flex-row items-center justify-between">
        <View>
          <Text className="text-ink-faint text-xs font-bold tracking-wider mb-1">SEU PLANO</Text>
          <View className="flex-row items-center gap-2">
            <Text className="text-ink text-lg font-bold">{plan.label}</Text>
            {features && !features.payment_ok && features.plan_code !== "free" ? (
              <Badge text="PAGAMENTO ATRASADO" color={C.down} />
            ) : (
              <Badge text="ATIVO" color={C.up} />
            )}
          </View>
          {features && !features.payment_ok && features.plan_code !== "free" ? (
            <Text className="text-down text-xs mt-1">⚠ Regularize sua assinatura para manter o acesso.</Text>
          ) : (
            <Text className="text-ink-soft text-xs mt-1">
              {f?.assets_analyzed_limit == null ? "Ativos analisados: ilimitados" : `Ativos analisados: ${f.assets_analyzed_limit}/dia`}
            </Text>
          )}
        </View>
        <Ionicons name="shield-checkmark" size={34} color={plan.color} />
      </Card>

      <SectionTitle>Recursos do seu plano</SectionTitle>
      <View className="gap-3">
        {list.map((item) => (
          <Card key={item.title} className="px-4 py-4 flex-row items-center gap-3">
            <View
              className="w-11 h-11 rounded-xl items-center justify-center"
              style={{ backgroundColor: item.active ? item.color + "22" : C.surface2 }}
            >
              <Ionicons name={item.icon as any} size={22} color={item.active ? item.color : C.faint} />
            </View>
            <View className="flex-1">
              <Text className={`font-bold ${item.active ? "text-ink" : "text-ink-faint"}`}>{item.title}</Text>
              <Text className="text-ink-soft text-xs mt-0.5">{item.active ? item.desc : "🔒 Bloqueado no seu plano"}</Text>
            </View>
            {item.actionLabel === "Abrir aba" ? (
              item.active ? (
                <Pressable
                  className="px-4 py-2 rounded-lg"
                  style={{ backgroundColor: item.color + "22", borderWidth: 1, borderColor: item.color + "55" }}
                  onPress={() => router.push(item.title === "Robô Automático" ? "/(tabs)/robot" : "/(tabs)/trades")}
                >
                  <Text className="text-xs font-bold" style={{ color: item.color }}>ABRIR</Text>
                </Pressable>
              ) : (
                <Pressable
                  className="px-4 py-2 rounded-lg"
                  style={{ backgroundColor: C.amber + "22", borderWidth: 1, borderColor: C.amber + "55" }}
                  onPress={() => router.push("/pricing")}
                >
                  <Text className="text-xs font-bold" style={{ color: C.amber }}>UPGRADE</Text>
                </Pressable>
              )
            ) : (
              <Pressable
                className="px-4 py-2 rounded-lg"
                style={{ backgroundColor: item.active ? item.color + "22" : C.amber + "22", borderWidth: 1, borderColor: item.active ? item.color + "55" : C.amber + "55" }}
                onPress={() => openUrl(item.url)}
              >
                <Text className="text-xs font-bold" style={{ color: item.active ? item.color : C.amber }}>
                  {item.actionLabel.toUpperCase()}
                </Text>
              </Pressable>
            )}
          </Card>
        ))}
      </View>
    </ScrollView>
  );
}
