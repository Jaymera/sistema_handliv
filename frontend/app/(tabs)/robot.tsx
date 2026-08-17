import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";

import { featuresApi, mt5Api, ordersApi } from "@/api/client";
import { Badge, C, Card, Empty, Input, Loading, PrimaryButton, SectionTitle, UpsellCard, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";
const HANDLIV = "https://handliv.com";

export default function RobotScreen() {
  const qc = useQueryClient();
  const [accounts, setAccounts] = useState("");
  const [broker, setBroker] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Painel de execução
  const [symbol, setSymbol] = useState("");
  const [volume, setVolume] = useState("0.10");
  const [selectedAccount, setSelectedAccount] = useState<string | null>(null);
  const [orderMsg, setOrderMsg] = useState<string | null>(null);
  const [orderError, setOrderError] = useState<string | null>(null);

  const { data: features, isLoading: fLoading } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const { data: mt5Data, isLoading } = useQuery({
    queryKey: ["mt5"],
    queryFn: mt5Api.list,
    enabled: !!features?.features.auto_robot,
  });
  const { data: ordersData } = useQuery({
    queryKey: ["orders"],
    queryFn: ordersApi.list,
    enabled: !!features?.features.auto_robot,
    refetchInterval: 5000,
  });

  const addAccounts = useMutation({
    mutationFn: () => mt5Api.add(accounts.trim(), broker.trim() || undefined),
    onSuccess: (res) => {
      setMsg(`${res.count} conta(s) MT5 cadastrada(s)`);
      setError(null);
      setAccounts("");
      setBroker("");
      qc.invalidateQueries({ queryKey: ["mt5"] });
      qc.invalidateQueries({ queryKey: ["features"] });
    },
    onError: (e: any) => setError(e?.message ?? "Erro ao cadastrar contas"),
  });

  const removeAccount = useMutation({
    mutationFn: (id: string) => mt5Api.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["mt5"] });
      qc.invalidateQueries({ queryKey: ["features"] });
    },
  });

  const sendOrder = useMutation({
    mutationFn: (action: "buy" | "sell" | "close") => {
      const acc = mt5Data?.items.find((a) => a.id === (selectedAccount ?? mt5Data?.items[0]?.id));
      if (!acc) throw new Error("Cadastre uma conta MT5 primeiro");
      return ordersApi.create({
        account_id: acc.id,
        action,
        symbol: symbol.trim().toUpperCase() || undefined,
        volume: action === "close" ? undefined : parseFloat(volume.replace(",", ".")),
      });
    },
    onSuccess: (_d, action) => {
      setOrderMsg(`Comando ${action === "buy" ? "COMPRA" : action === "sell" ? "VENDA" : "FECHAR"} enviado ao MT5!`);
      setOrderError(null);
      qc.invalidateQueries({ queryKey: ["orders"] });
    },
    onError: (e: any) => {
      setOrderError(e?.message ?? "Erro ao enviar comando");
      setOrderMsg(null);
    },
  });

  if (fLoading) return <Loading label="Carregando..." />;

  const f = features?.features;
  const links = features?.links;

  if (!f?.auto_robot) {
    return (
      <View className="flex-1 bg-night px-4 pt-4">
        <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
        <Text className="text-ink text-2xl font-bold mb-4">Robô Automático</Text>
        <UpsellCard
          title="Robô Automático (EA Livewell)"
          message="Operações 100% automáticas no MT5 + painel de execução remoto. Exclusivo do plano Ultimate."
          planLabel="ULTIMATE · R$297/MÊS"
          onWhatsapp={() => openUrl(links?.whatsapp || WHATSAPP)}
          onPlans={() => router.push("/pricing")}
        />
      </View>
    );
  }

  const accList = mt5Data?.items ?? [];
  const activeAccountId = selectedAccount ?? accList[0]?.id;
  const orders = ordersData?.items ?? [];

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
      <Text className="text-ink text-2xl font-bold mb-1">Robô Automático</Text>
      <View className="flex-row items-center gap-2 mb-4">
        <Badge text="ULTIMATE" color={C.purple} />
        <Text className="text-ink-soft text-xs">Liberado no seu plano</Text>
      </View>

      {/* Download */}
      <Card className="p-4 mb-5 flex-row items-center gap-3" style={{ borderColor: C.brand + "44" }}>
        <View className="w-12 h-12 rounded-xl items-center justify-center" style={{ backgroundColor: C.brand + "22" }}>
          <Ionicons name="download" size={24} color={C.brand} />
        </View>
        <View className="flex-1">
          <Text className="text-ink font-bold">Download do Robô</Text>
          <Text className="text-ink-soft text-xs mt-0.5">Baixe o EA Livewell no site oficial</Text>
        </View>
        <PrimaryButton label="Baixar" small onPress={() => openUrl(HANDLIV)} />
      </Card>

      {/* Painel de Execução MT5 */}
      <SectionTitle>Painel de Execução MT5</SectionTitle>
      {accList.length > 0 ? (
        <Card className="p-4 mb-5">
          {/* Account selector */}
          <Text className="text-ink-faint text-xs font-bold mb-2">CONTA MT5</Text>
          <View className="flex-row gap-2 flex-wrap mb-3">
            {accList.map((a) => {
              const active = a.id === activeAccountId;
              return (
                <Text
                  key={a.id}
                  onPress={() => setSelectedAccount(a.id)}
                  className="px-3 py-2 rounded-lg text-xs font-bold"
                  style={{
                    backgroundColor: active ? C.brand + "22" : C.surface2,
                    color: active ? C.brand : C.soft,
                    borderWidth: 1,
                    borderColor: active ? C.brand + "55" : C.line,
                  }}
                >
                  {a.account_number}
                </Text>
              );
            })}
          </View>

          <Input value={symbol} onChangeText={setSymbol} placeholder="Ativo (ex: EURUSD, WIN$N, PETR4)" autoCapitalize="characters" />
          <Input value={volume} onChangeText={setVolume} placeholder="Volume (lotes, ex: 0.10)" keyboardType="decimal-pad" />

          {/* Action buttons */}
          <View className="flex-row gap-2 mb-3">
            <View className="flex-1">
              <PrimaryButton
                label="▲ COMPRAR"
                color={C.up}
                loading={sendOrder.isPending && sendOrder.variables === "buy"}
                onPress={() => sendOrder.mutate("buy")}
              />
            </View>
            <View className="flex-1">
              <PrimaryButton
                label="▼ VENDER"
                color={C.down}
                loading={sendOrder.isPending && sendOrder.variables === "sell"}
                onPress={() => sendOrder.mutate("sell")}
              />
            </View>
            <View className="flex-1">
              <PrimaryButton
                label="✕ FECHAR"
                color={C.amber}
                loading={sendOrder.isPending && sendOrder.variables === "close"}
                onPress={() => sendOrder.mutate("close")}
              />
            </View>
          </View>

          {orderMsg ? <Text className="text-up text-sm mb-2">{orderMsg}</Text> : null}
          {orderError ? <Text className="text-down text-sm mb-2">{orderError}</Text> : null}

          <Text className="text-ink-faint text-[11px] leading-4">
            Os botões enviam comandos ao EA conectado na conta selecionada. Mantenha o EA Handliv rodando no MT5.
          </Text>
        </Card>
      ) : (
        <View className="mb-5">
          <Empty text="Cadastre uma conta MT5 abaixo para usar o painel de execução." />
        </View>
      )}

      {/* Últimos comandos */}
      {orders.length > 0 ? (
        <View className="mb-5">
          <SectionTitle>Últimos comandos</SectionTitle>
          <View className="gap-2">
            {orders.slice(0, 6).map((o) => {
              const statusColor =
                o.status === "executed" ? C.up : o.status === "failed" ? C.down : o.status === "sent" ? C.accent : C.amber;
              return (
                <Card key={o.id} className="px-4 py-3 flex-row items-center justify-between">
                  <View className="flex-1">
                    <View className="flex-row items-center gap-2">
                      <Text className="text-ink font-bold text-sm">
                        {o.action === "buy" ? "COMPRA" : o.action === "sell" ? "VENDA" : "FECHAR"}
                      </Text>
                      {o.symbol ? <Text className="text-ink-soft text-xs">{o.symbol} {o.volume ?? ""}</Text> : null}
                    </View>
                    <Text className="text-ink-faint text-[11px] mt-0.5">
                      {o.account_number}{o.created_at ? ` · ${new Date(o.created_at).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}` : ""}
                      {o.result_message ? ` · ${o.result_message}` : ""}
                    </Text>
                  </View>
                  <Badge
                    text={o.status === "executed" ? "OK" : o.status === "failed" ? "FALHOU" : o.status === "sent" ? "ENVIADO" : "PENDENTE"}
                    color={statusColor}
                  />
                </Card>
              );
            })}
          </View>
        </View>
      ) : null}

      {/* MT5 accounts */}
      <SectionTitle action={<Text className="text-ink-faint text-xs">{f.mt5_accounts_used}/{f.mt5_accounts_max} contas</Text>}>
        Contas MT5
      </SectionTitle>
      <Card className="p-4 mb-5">
        <Text className="text-ink-soft text-xs mb-3">
          Cadastre suas contas MT5 (máximo {f.mt5_accounts_max}). O robô só opera em contas cadastradas e ativas.
        </Text>
        <Input value={accounts} onChangeText={setAccounts} placeholder="ex: 216546,15616165" keyboardType="numeric" />
        <Input value={broker} onChangeText={setBroker} placeholder="Corretora (opcional)" />
        {error ? <Text className="text-down text-sm mb-2">{error}</Text> : null}
        {msg ? <Text className="text-up text-sm mb-2">{msg}</Text> : null}
        <PrimaryButton
          label="Cadastrar contas"
          loading={addAccounts.isPending}
          disabled={!accounts.trim() || f.mt5_accounts_used >= f.mt5_accounts_max}
          onPress={() => addAccounts.mutate()}
        />
        {f.mt5_accounts_used >= f.mt5_accounts_max ? (
          <Text className="text-amber text-xs mt-2 text-center">Limite de {f.mt5_accounts_max} contas atingido. Remova uma para cadastrar outra.</Text>
        ) : null}
      </Card>

      <SectionTitle>Contas cadastradas</SectionTitle>
      {isLoading ? (
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
        </View>
      ) : (
        <Empty text="Nenhuma conta MT5 cadastrada ainda." />
      )}
    </ScrollView>
  );
}
