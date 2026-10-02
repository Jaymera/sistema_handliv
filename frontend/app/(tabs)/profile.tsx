import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { Pressable, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { useAuthStore } from "@/state/authStore";
import { featuresApi, subscriptionsApi } from "@/api/client";
import { Badge, C, Card, GhostButton, PLAN_THEME, SectionTitle, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";

type Feature = { icon: string; title: string; desc: string; active: boolean; url: string; actionLabel: string; color: string };

export default function ProfileScreen() {
  const { user, logout } = useAuthStore();
  const { data: features } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const { data: sub } = useQuery({ queryKey: ["subscription"], queryFn: subscriptionsApi.mySubscription });

  const plan = PLAN_THEME[features?.plan_code ?? "free"] ?? PLAN_THEME.free;
  const f = features?.features;
  const links = features?.links;

  const rows: { icon: string; label: string; sub?: string; onPress: () => void; color: string }[] = [
    {
      icon: "diamond",
      label: "Planos & Assinatura",
      sub: "Comparar planos e assinar",
      onPress: () => router.push("/pricing"),
      color: C.brand,
    },
    {
      icon: "card",
      label: "Gerenciar cobrança",
      sub: "Portal de pagamento Stripe",
      onPress: async () => {
        try {
          const res = await subscriptionsApi.portal();
          openUrl(res.portal_url);
        } catch {
          openUrl("https://billing.stripe.com/p/login");
        }
      },
      color: C.accent,
    },
    {
      icon: "flask",
      label: "Novo backtest",
      sub: "Testar estratégias",
      onPress: () => router.push("/backtest/new"),
      color: C.purple,
    },
    {
      icon: "logo-whatsapp",
      label: "Suporte Handliv",
      sub: "Fale com a equipe",
      onPress: () => openUrl(WHATSAPP),
      color: "#25D366",
    },
  ];
  if (user?.role === "super_admin") {
    rows.push({
      icon: "shield",
      label: "Painel Admin",
      sub: "Usuários e configurações",
      onPress: () => router.push("/admin"),
      color: C.amber,
    });
  }

  const resources: Feature[] = [
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
      <Text className="text-ink text-2xl font-bold mb-5">Perfil</Text>

      {/* User card */}
      <Card className="p-5 mb-4 flex-row items-center gap-4">
        <View className="w-16 h-16 rounded-2xl items-center justify-center" style={{ backgroundColor: C.brand + "22" }}>
          <Text className="text-2xl font-bold text-brand">{user?.name?.[0]?.toUpperCase() ?? "?"}</Text>
        </View>
        <View className="flex-1">
          <Text className="text-ink text-lg font-bold">{user?.name}</Text>
          <Text className="text-ink-soft text-sm">{user?.email}</Text>
          <View className="mt-2">
            <Badge text={plan.label} color={plan.color} />
          </View>
        </View>
      </Card>

      {/* Plan summary */}
      <Card className="p-4 mb-6">
        <View className="flex-row items-center justify-between mb-3">
          <Text className="text-ink font-bold">Seu plano</Text>
          {sub?.current_period_end ? (
            <Text className="text-ink-faint text-xs">Renova em {new Date(sub.current_period_end).toLocaleDateString("pt-BR")}</Text>
          ) : null}
        </View>
        <View className="flex-row flex-wrap gap-2">
          <Badge text={f?.assets_analyzed_limit == null ? "ATIVOS ∞" : `${f.assets_analyzed_limit} ATIVOS`} color={C.accent} />
          <Badge text="ROBÔS" color={f?.robots_indicators ? C.up : C.faint} />
          <Badge text="COPY" color={f?.copy_trading ? C.up : C.faint} />
          <Badge text="SALA AO VIVO" color={f?.live_trading_room ? C.up : C.faint} />
          <Badge text="CURSO -%" color={f?.course_discount ? C.up : C.faint} />
          <Badge text="PAINEL" color={f?.trading_panel ? C.up : C.faint} />
          <Badge text="ROBÔ AUTO" color={f?.auto_robot ? C.purple : C.faint} />
        </View>
      </Card>

      {/* Resources of the plan (moved from the removed Painel tab) */}
      <SectionTitle>Recursos do seu plano</SectionTitle>
      <View className="gap-3 mb-6">
        {resources.map((item) => (
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

      {/* Menu */}
      <SectionTitle>Conta</SectionTitle>
      <View className="gap-2 mb-6">
        {rows.map((r) => (
          <Card key={r.label} className="px-4 py-3 flex-row items-center gap-3">
            <PressableRow onPress={r.onPress} color={r.color} icon={r.icon} label={r.label} sub={r.sub} />
          </Card>
        ))}
      </View>

      <GhostButton label="Sair da conta" color={C.down} onPress={() => { logout(); router.replace("/auth/login"); }} />
      <Text className="text-ink-faint text-[11px] text-center mt-6">Handliv Trading Intelligence · v1.0</Text>
    </ScrollView>
  );
}

function PressableRow({ onPress, color, icon, label, sub }: { onPress: () => void; color: string; icon: string; label: string; sub?: string }) {
  return (
    <Pressable className="flex-1 flex-row items-center gap-3" onPress={onPress}>
      <View className="w-10 h-10 rounded-xl items-center justify-center" style={{ backgroundColor: color + "22" }}>
        <Ionicons name={icon as any} size={20} color={color} />
      </View>
      <View className="flex-1">
        <Text className="text-ink font-semibold">{label}</Text>
        {sub ? <Text className="text-ink-faint text-xs">{sub}</Text> : null}
      </View>
      <Ionicons name="chevron-forward" size={16} color={C.faint} />
    </Pressable>
  );
}
