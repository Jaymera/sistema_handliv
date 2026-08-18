import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";

import { featuresApi, mt5Api } from "@/api/client";
import { Badge, C, Card, Empty, Input, Loading, PrimaryButton, SectionTitle, UpsellCard, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";
const HANDLIV = "https://handliv.com";

export default function RobotScreen() {
  const qc = useQueryClient();
  const [accounts, setAccounts] = useState("");
  const [broker, setBroker] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const { data: features, isLoading } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const canMT5 = !!features?.features.trading_panel;
  const isUltimate = !!features?.features.auto_robot;

  const { data: mt5Data, isLoading: mt5Loading } = useQuery({
    queryKey: ["mt5-stats"],
    queryFn: mt5Api.list,
    enabled: canMT5,
  });

  const addAccounts = useMutation({
    mutationFn: () => mt5Api.add(accounts.trim(), broker.trim() || undefined),
    onSuccess: (res) => {
      setMsg(`${res.count} conta(s) MT5 cadastrada(s)`);
      setError(null);
      setAccounts("");
      setBroker("");
      qc.invalidateQueries({ queryKey: ["mt5-stats"] });
      qc.invalidateQueries({ queryKey: ["features"] });
    },
    onError: (e: any) => setError(e?.message ?? "Erro ao cadastrar contas"),
  });

  const removeAccount = useMutation({
    mutationFn: (id: string) => mt5Api.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["mt5-stats"] });
      qc.invalidateQueries({ queryKey: ["features"] });
    },
  });

  if (isLoading) return <Loading label="Carregando..." />;

  const f = features?.features;
  const links = features?.links;

  if (!isUltimate) {
    return (
      <View className="flex-1 bg-night px-4 pt-4">
        <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
        <Text className="text-ink text-2xl font-bold mb-4">Robô & Contas MT5</Text>
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

  const accList = mt5Data?.items ?? [];

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
      <Text className="text-ink text-2xl font-bold mb-1">Robô & Contas MT5</Text>
      <View className="flex-row items-center gap-2 mb-4">
        <Badge text="ULTIMATE" color={C.purple} />
        <Text className="text-ink-soft text-xs">Robô Automático liberado no seu plano</Text>
      </View>

      {/* ===== Robô Automático ===== */}
      <View className="mb-5">
        <SectionTitle>Robô Automático</SectionTitle>
        <Card className="p-4 mb-3 flex-row items-center gap-3" style={{ borderColor: C.brand + "44" }}>
          <View className="w-12 h-12 rounded-xl items-center justify-center" style={{ backgroundColor: C.brand + "22" }}>
            <Ionicons name="hardware-chip" size={24} color={C.brand} />
          </View>
          <View className="flex-1">
            <Text className="text-ink font-bold">Download do Robô</Text>
            <Text className="text-ink-soft text-xs mt-0.5">Baixe o EA Livewell no site oficial</Text>
          </View>
          <PrimaryButton label="Baixar" small onPress={() => openUrl(HANDLIV)} />
        </Card>
        <Card className="p-4">
          <Text className="text-ink-soft text-sm leading-6">
            1. Baixe o EA Livewell no site da Handliv{"\n"}
            2. Anexe ao gráfico do ativo desejado no MT5{"\n"}
            3. O robô opera de forma automática, seguindo a estratégia Handliv{"\n"}
            4. Acompanhe o resultado na aba MT5
          </Text>
        </Card>
      </View>

      {/* ===== Cadastro de contas MT5 ===== */}
      <SectionTitle
        action={<Text className="text-ink-faint text-xs">{f?.mt5_accounts_used ?? accList.length}/{f?.mt5_accounts_max ?? 2} contas</Text>}
      >
        Contas MT5
      </SectionTitle>
      <Card className="p-4 mb-4">
        <Text className="text-ink-soft text-xs mb-3">
          Cadastre suas contas MT5 (máximo {f?.mt5_accounts_max ?? 2}). O EA HandlivPanel só envia dados de contas cadastradas.
        </Text>
        <Input value={accounts} onChangeText={setAccounts} placeholder="ex: 216546,15616165" keyboardType="numeric" />
        <Input value={broker} onChangeText={setBroker} placeholder="Corretora (opcional)" />
        {error ? <Text className="text-down text-sm mb-2">{error}</Text> : null}
        {msg ? <Text className="text-up text-sm mb-2">{msg}</Text> : null}
        <PrimaryButton
          label="Cadastrar contas"
          loading={addAccounts.isPending}
          disabled={!accounts.trim() || (f?.mt5_accounts_used ?? 0) >= (f?.mt5_accounts_max ?? 2)}
          onPress={() => addAccounts.mutate()}
        />
        {(f?.mt5_accounts_used ?? 0) >= (f?.mt5_accounts_max ?? 2) ? (
          <Text className="text-amber text-xs mt-2 text-center">Limite de {f?.mt5_accounts_max ?? 2} contas atingido. Remova uma para cadastrar outra.</Text>
        ) : null}
      </Card>

      {/* Contas cadastradas */}
      <SectionTitle>Contas cadastradas</SectionTitle>
      {mt5Loading ? (
        <Loading />
      ) : accList.length > 0 ? (
        <View className="gap-2">
          {accList.map((a) => (
            <Card key={a.id} className="px-4 py-3 flex-row items-center justify-between">
              <View className="flex-1">
                <View className="flex-row items-center gap-2">
                  <Text className="text-ink font-bold">{a.account_number}</Text>
                  <Badge text={a.is_active ? "ATIVA" : "INATIVA"} color={a.is_active ? C.up : C.faint} />
                </View>
                {a.broker ? <Text className="text-ink-soft text-xs mt-0.5">{a.broker}</Text> : null}
              </View>
              <Text className="text-down text-xs font-bold px-3 py-2" onPress={() => removeAccount.mutate(a.id)}>
                REMOVER
              </Text>
            </Card>
          ))}
          <Text className="text-ink-faint text-[11px] text-center mt-1">
            As estatísticas destas contas aparecem na aba MT5.
          </Text>
        </View>
      ) : (
        <Empty text="Nenhuma conta MT5 cadastrada ainda." />
      )}
    </ScrollView>
  );
}
