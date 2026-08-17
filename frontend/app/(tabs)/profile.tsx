import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { Pressable, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { useAuthStore } from "@/state/authStore";
import { featuresApi, subscriptionsApi } from "@/api/client";
import { Badge, C, Card, GhostButton, PLAN_THEME, SectionTitle, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";

export default function ProfileScreen() {
  const { user, logout } = useAuthStore();
  const { data: features } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const { data: sub } = useQuery({ queryKey: ["subscription"], queryFn: subscriptionsApi.mySubscription });

  const plan = PLAN_THEME[features?.plan_code ?? "free"] ?? PLAN_THEME.free;
  const f = features?.features;

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
