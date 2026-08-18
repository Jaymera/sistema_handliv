import "../../src/global.css";

import { useQuery } from "@tanstack/react-query";
import { router } from "expo-router";
import { ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { featuresApi } from "@/api/client";
import { Badge, C, Card, Loading, PrimaryButton, SectionTitle, UpsellCard, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";
const HANDLIV = "https://handliv.com";

export default function RobotScreen() {
  const { data: features, isLoading } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });

  if (isLoading) return <Loading label="Carregando..." />;

  const f = features?.features;
  const links = features?.links;

  if (!f?.auto_robot) {
    return (
      <View className="flex-1 bg-night px-4 pt-4">
        <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
        <Text className="text-ink text-2xl font-bold mb-4">Robô Automático</Text>
        <UpsellCard
          title="Robô Automático (EA Livewell)"
          message="Operações 100% automáticas no MT5, 24h por dia, sem emoção. Exclusivo do plano Ultimate."
          planLabel="ULTIMATE · R$297/MÊS"
          onWhatsapp={() => openUrl(links?.whatsapp || WHATSAPP)}
          onPlans={() => router.push("/pricing")}
        />
      </View>
    );
  }

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
      <Text className="text-ink text-2xl font-bold mb-1">Robô Automático</Text>
      <View className="flex-row items-center gap-2 mb-4">
        <Badge text="ULTIMATE" color={C.purple} />
        <Text className="text-ink-soft text-xs">Liberado no seu plano</Text>
      </View>

      <Card className="p-4 mb-5 flex-row items-center gap-3" style={{ borderColor: C.brand + "44" }}>
        <View className="w-12 h-12 rounded-xl items-center justify-center" style={{ backgroundColor: C.brand + "22" }}>
          <Ionicons name="hardware-chip" size={24} color={C.brand} />
        </View>
        <View className="flex-1">
          <Text className="text-ink font-bold">Download do Robô</Text>
          <Text className="text-ink-soft text-xs mt-0.5">Baixe o EA Livewell no site oficial</Text>
        </View>
        <PrimaryButton label="Baixar" small onPress={() => openUrl(HANDLIV)} />
      </Card>

      <SectionTitle>Como funciona</SectionTitle>
      <Card className="p-4 mb-5">
        <Text className="text-ink-soft text-sm leading-6">
          1. Baixe o EA Livewell no site da Handliv{"\n"}
          2. Anexe ao gráfico do ativo desejado no MT5{"\n"}
          3. O robô opera de forma automática, seguindo a estratégia Handliv{"\n"}
          4. Acompanhe o resultado na aba MT5
        </Text>
      </Card>

      <Card className="p-4">
        <Text className="text-ink-soft text-sm leading-6">
          Precisa de ajuda para configurar? Fale com nossa equipe no WhatsApp ou junte-se à sala ao vivo dos assinantes Ultimate.
        </Text>
        <View className="flex-row gap-3 mt-3">
          <View className="flex-1">
            <PrimaryButton label="Suporte WhatsApp" small onPress={() => openUrl(links?.whatsapp || WHATSAPP)} />
          </View>
          <View className="flex-1">
            <PrimaryButton label="Sala ao vivo" small color={C.accent} onPress={() => openUrl(HANDLIV)} />
          </View>
        </View>
      </Card>
    </ScrollView>
  );
}
