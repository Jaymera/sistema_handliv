import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { Pressable, ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";

import { featuresApi, mt5Api, ordersApi, statsApi, type MT5Stats } from "@/api/client";
import { Badge, C, Card, Empty, GhostButton, Input, Loading, PrimaryButton, SectionTitle, UpsellCard, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";
const HANDLIV = "https://handliv.com";

function curSymbol(currency: string): string {
  return currency === "BRL" ? "R$" : currency === "EUR" ? "€" : currency === "GBP" ? "£" : "$";
}

function signMoney(v: number, currency: string): string {
  return `${v >= 0 ? "+" : "-"}${curSymbol(currency)} ${Math.abs(v).toFixed(2)}`;
}

/* ===== Cards do dashboard ===== */

function HeroResult({ stats }: { stats: MT5Stats }) {
  const pos = stats.profit_day >= 0;
  const color = pos ? C.up : C.down;
  return (
    <Card className="p-5 mb-3 items-center" style={{ borderColor: color + "40", backgroundColor: pos ? C.up + "0D" : C.down + "0D" }}>
      <Text className="text-ink-faint text-[11px] font-bold tracking-widest">RESULTADO DE HOJE</Text>
      <Text className="text-4xl font-bold mt-2" style={{ color }}>
        {signMoney(stats.profit_day, stats.currency)}
      </Text>
      <View className="flex-row gap-6 mt-4">
        <View className="items-center">
          <Text className="text-ink-faint text-[10px] font-bold">PATRIMÔNIO</Text>
          <Text className="text-ink font-bold mt-0.5">
            {curSymbol(stats.currency)} {stats.equity.toFixed(2)}
          </Text>
        </View>
        <View className="items-center">
          <Text className="text-ink-faint text-[10px] font-bold">SALDO</Text>
          <Text className="text-ink font-bold mt-0.5">
            {curSymbol(stats.currency)} {stats.balance.toFixed(2)}
          </Text>
        </View>
        <View className="items-center">
          <Text className="text-ink-faint text-[10px] font-bold">FLUTUANTE</Text>
          <Text className="font-bold mt-0.5" style={{ color: stats.floating_pl >= 0 ? C.up : C.down }}>
            {signMoney(stats.floating_pl, stats.currency)}
          </Text>
        </View>
      </View>
    </Card>
  );
}

function PeriodGrid({ stats }: { stats: MT5Stats }) {
  const rows: { label: string; value: number; icon: keyof typeof Ionicons.glyphMap }[] = [
    { label: "SEMANA", value: stats.profit_week, icon: "calendar-clear-outline" },
    { label: "MÊS", value: stats.profit_month, icon: "calendar-outline" },
    { label: "TOTAL", value: stats.profit_total, icon: "flag-outline" },
  ];
  return (
    <View className="gap-3 mb-3">
      {rows.map((r) => {
        const color = r.value >= 0 ? C.up : C.down;
        return (
          <Card key={r.label} className="px-4 py-3.5 flex-row items-center">
            <View className="w-9 h-9 rounded-xl items-center justify-center mr-3" style={{ backgroundColor: color + "18" }}>
              <Ionicons name={r.icon} size={17} color={color} />
            </View>
            <Text className="text-ink-faint text-[11px] font-bold tracking-widest flex-1">{r.label}</Text>
            <Text className="text-xl font-bold" style={{ color }}>
              {signMoney(r.value, stats.currency)}
            </Text>
          </Card>
        );
      })}
    </View>
  );
}

function RiskCard({ stats }: { stats: MT5Stats }) {
  const ddColor = stats.dd_percent >= 20 ? C.down : stats.dd_percent >= 10 ? C.amber : C.up;
  const winRate = stats.total_trades > 0 ? Math.round((stats.win_trades / stats.total_trades) * 100) : null;
  const wrColor = winRate === null ? C.soft : winRate >= 50 ? C.up : C.amber;

  return (
    <View className="flex-row gap-3 mb-3">
      {/* Drawdown */}
      <Card className="flex-1 p-4 items-center">
        <Ionicons name="trending-down" size={20} color={ddColor} />
        <Text className="text-2xl font-bold mt-1.5" style={{ color: ddColor }}>
          -{stats.dd_percent.toFixed(2)}%
        </Text>
        <Text className="text-ink-faint text-[10px] font-bold tracking-widest mt-0.5">DRAWDOWN</Text>
        {/* barra de DD */}
        <View className="w-full h-1.5 rounded-full mt-3 overflow-hidden" style={{ backgroundColor: C.surface2 }}>
          <View className="h-full rounded-full" style={{ width: `${Math.min(100, stats.dd_percent)}%`, backgroundColor: ddColor }} />
        </View>
      </Card>

      {/* Win rate */}
      <Card className="flex-1 p-4 items-center">
        <Ionicons name="trophy-outline" size={20} color={wrColor} />
        <Text className="text-2xl font-bold mt-1.5" style={{ color: wrColor }}>
          {winRate === null ? "—" : `${winRate}%`}
        </Text>
        <Text className="text-ink-faint text-[10px] font-bold tracking-widest mt-0.5">WIN RATE</Text>
        {/* barra de win rate */}
        <View className="w-full h-1.5 rounded-full mt-3 overflow-hidden flex-row" style={{ backgroundColor: C.down + "55" }}>
          {winRate !== null ? <View className="h-full" style={{ width: `${winRate}%`, backgroundColor: C.up }} /> : null}
        </View>
      </Card>
    </View>
  );
}

function TradesCard({ stats }: { stats: MT5Stats }) {
  return (
    <Card className="px-4 py-3.5 mb-3">
      <View className="flex-row items-center justify-between">
        <View className="items-center flex-1">
          <Text className="text-lg font-bold" style={{ color: C.up }}>
            {stats.win_trades}
          </Text>
          <Text className="text-ink-faint text-[10px] font-bold">GANHOS</Text>
        </View>
        <View className="w-px h-8" style={{ backgroundColor: C.line }} />
        <View className="items-center flex-1">
          <Text className="text-lg font-bold" style={{ color: C.down }}>
            {stats.loss_trades}
          </Text>
          <Text className="text-ink-faint text-[10px] font-bold">PERDAS</Text>
        </View>
        <View className="w-px h-8" style={{ backgroundColor: C.line }} />
        <View className="items-center flex-1">
          <Text className="text-lg font-bold" style={{ color: C.ink }}>
            {stats.total_trades}
          </Text>
          <Text className="text-ink-faint text-[10px] font-bold">TRADES</Text>
        </View>
        <View className="w-px h-8" style={{ backgroundColor: C.line }} />
        <View className="items-center flex-1">
          <Text className="text-lg font-bold" style={{ color: C.accent }}>
            {stats.open_positions}
          </Text>
          <Text className="text-ink-faint text-[10px] font-bold">ABERTAS</Text>
        </View>
      </View>
    </Card>
  );
}

function AccountMeta({ stats }: { stats: MT5Stats }) {
  const updated = stats.updated_at
    ? new Date(stats.updated_at).toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" })
    : null;
  return (
    <View className="flex-row items-center justify-center gap-2 mb-1">
      <View className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: C.up }} />
      <Text className="text-ink-faint text-[11px]">
        {updated ? `Atualizado pelo EA às ${updated}` : "Aguardando atualização do EA..."}
      </Text>
    </View>
  );
}

/* ===== Tela ===== */

export default function MT5Screen() {
  const qc = useQueryClient();
  const [symbol, setSymbol] = useState("");
  const [volume, setVolume] = useState("0.10");
  const [selectedAccount, setSelectedAccount] = useState<string | null>(null);
  const [orderMsg, setOrderMsg] = useState<string | null>(null);
  const [orderError, setOrderError] = useState<string | null>(null);
  const [accounts, setAccounts] = useState("");
  const [broker, setBroker] = useState("");
  const [accMsg, setAccMsg] = useState<string | null>(null);
  const [accError, setAccError] = useState<string | null>(null);

  const { data: features, isLoading: fLoading } = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures });
  const canMT5 = !!features?.features.trading_panel;
  const isUltimate = !!features?.features.auto_robot;

  const { data: statsData, isLoading: sLoading } = useQuery({
    queryKey: ["mt5-stats"],
    queryFn: statsApi.list,
    enabled: canMT5,
    refetchInterval: 15000,
  });
  const { data: ordersData } = useQuery({
    queryKey: ["orders"],
    queryFn: ordersApi.list,
    enabled: canMT5,
    refetchInterval: 5000,
  });

  const sendOrder = useMutation({
    mutationFn: (action: "buy" | "sell" | "close") => {
      const acc = statsData?.items.find((a) => a.id === (selectedAccount ?? statsData?.items[0]?.id));
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

  const addAccounts = useMutation({
    mutationFn: () => mt5Api.add(accounts.trim(), broker.trim() || undefined),
    onSuccess: (res) => {
      setAccMsg(`${res.count} conta(s) MT5 cadastrada(s)`);
      setAccError(null);
      setAccounts("");
      setBroker("");
      qc.invalidateQueries({ queryKey: ["mt5-stats"] });
      qc.invalidateQueries({ queryKey: ["features"] });
    },
    onError: (e: any) => setAccError(e?.message ?? "Erro ao cadastrar contas"),
  });

  const removeAccount = useMutation({
    mutationFn: (id: string) => mt5Api.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["mt5-stats"] });
      qc.invalidateQueries({ queryKey: ["features"] });
    },
  });

  if (fLoading) return <Loading label="Carregando..." />;

  const links = features?.links;

  if (!canMT5) {
    return (
      <View className="flex-1 bg-night px-4 pt-4">
        <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
        <Text className="text-ink text-2xl font-bold mb-4">Minha Conta MT5</Text>
        <UpsellCard
          title="Estatísticas do seu trading no MT5"
          message="Drawdown, lucro/prejuízo do dia, semana, mês e total, win rate e painel de execução remoto. Disponível nos planos Start e Ultimate."
          planLabel="START · R$97/MÊS"
          onWhatsapp={() => openUrl(links?.whatsapp || WHATSAPP)}
          onPlans={() => router.push("/pricing")}
        />
      </View>
    );
  }

  const items = statsData?.items ?? [];
  const active = items.find((a) => a.id === (selectedAccount ?? items[0]?.id));
  const st = active?.stats ?? null;
  const orders = ordersData?.items ?? [];
  const f = features?.features;

  const registrationCard = (
    <Card className="p-4">
      <Text className="text-ink-soft text-xs mb-3">
        Cadastre suas contas MT5 (máximo {f?.mt5_accounts_max ?? 2}). O EA HandlivPanel só envia dados de contas cadastradas.
      </Text>
      <Input value={accounts} onChangeText={setAccounts} placeholder="ex: 216546,15616165" keyboardType="numeric" />
      <Input value={broker} onChangeText={setBroker} placeholder="Corretora (opcional)" />
      {accError ? <Text className="text-down text-sm mb-2">{accError}</Text> : null}
      {accMsg ? <Text className="text-up text-sm mb-2">{accMsg}</Text> : null}
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
  );

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
      <Text className="text-ink text-2xl font-bold mb-1">Minha Conta MT5</Text>
      <View className="flex-row items-center gap-2 mb-4">
        <Badge text={isUltimate ? "ULTIMATE" : "START"} color={isUltimate ? C.purple : C.accent} />
        <Text className="text-ink-soft text-xs">Desempenho do seu trading em tempo real</Text>
      </View>

      {/* Download EA HandlivPanel (Start e Ultimate) */}
      <Card className="p-4 mb-5 flex-row items-center gap-3" style={{ borderColor: C.brand + "44" }}>
        <View className="w-12 h-12 rounded-xl items-center justify-center" style={{ backgroundColor: C.brand + "22" }}>
          <Ionicons name="speedometer" size={24} color={C.brand} />
        </View>
        <View className="flex-1">
          <Text className="text-ink font-bold">EA HandlivPanel</Text>
          <Text className="text-ink-soft text-xs mt-0.5">Rode no MT5 para enviar estatísticas e receber comandos do site</Text>
        </View>
        <PrimaryButton label="Baixar" small onPress={() => openUrl(HANDLIV)} />
      </Card>

      {/* Seletor de contas */}
      {items.length > 1 ? (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} className="mb-4" contentContainerStyle={{ gap: 8, paddingRight: 8 }}>
          {items.map((a) => {
            const on = a.id === active?.id;
            return (
              <Pressable
                key={a.id}
                onPress={() => setSelectedAccount(a.id)}
                className="px-4 py-2.5 rounded-xl"
                style={{
                  backgroundColor: on ? C.brand + "1F" : C.surface,
                  borderWidth: 1,
                  borderColor: on ? C.brand + "66" : C.line,
                }}
              >
                <Text className="text-xs font-bold" style={{ color: on ? C.brand : C.soft }}>
                  {a.account_number}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>
      ) : null}

      {/* Dashboard */}
      {sLoading ? (
        <Loading label="Carregando estatísticas..." />
      ) : items.length === 0 ? (
        <View className="mb-5">
          <Empty text="Nenhuma conta MT5 cadastrada ainda." />
          {isUltimate ? (
            <PrimaryButton label="Cadastrar na aba Robô" onPress={() => router.push("/(tabs)/robot")} />
          ) : (
            registrationCard
          )}
        </View>
      ) : st ? (
        <View className="mb-5">
          {/* Header da conta */}
          <Card className="px-4 py-3 mb-3 flex-row items-center justify-between">
            <View className="flex-row items-center gap-2.5">
              <View className="w-9 h-9 rounded-xl items-center justify-center" style={{ backgroundColor: C.brand + "18" }}>
                <Ionicons name="speedometer" size={18} color={C.brand} />
              </View>
              <View>
                <Text className="text-ink font-bold">Conta {active?.account_number}</Text>
                <Text className="text-ink-faint text-[11px]">
                  {active?.broker ? `${active.broker} · ` : ""}
                  {st.currency}
                </Text>
              </View>
            </View>
            <Badge text={st.open_positions > 0 ? `${st.open_positions} ABERTAS` : "SEM POSIÇÕES"} color={st.open_positions > 0 ? C.accent : C.faint} />
          </Card>

          <HeroResult stats={st} />
          <PeriodGrid stats={st} />
          <RiskCard stats={st} />
          <TradesCard stats={st} />
          <AccountMeta stats={st} />
        </View>
      ) : (
        <View className="mb-5">
          <Card className="p-5 items-center">
            <View className="w-14 h-14 rounded-2xl items-center justify-center mb-3" style={{ backgroundColor: C.accent + "18" }}>
              <Ionicons name="pulse" size={26} color={C.accent} />
            </View>
            <Text className="text-ink font-bold text-center">Conta {active?.account_number} aguardando o EA</Text>
            <Text className="text-ink-soft text-sm text-center mt-1">
              Baixe o EA HandlivPanel acima, anexe a um gráfico no MT5 com o secret correto e as estatísticas aparecerão aqui automaticamente.
            </Text>
          </Card>
        </View>
      )}

      {/* Painel de Execução */}
      {items.length > 0 ? (
        <View className="mb-5">
          <SectionTitle>Painel de Execução</SectionTitle>
          <Card className="p-4">
            <Text className="text-ink-faint text-xs font-bold mb-2">CONTA: {active?.account_number}</Text>
            <Input value={symbol} onChangeText={setSymbol} placeholder="Ativo (ex: EURUSD, WIN$N, PETR4)" autoCapitalize="characters" />
            <Input value={volume} onChangeText={setVolume} placeholder="Volume (lotes, ex: 0.10)" keyboardType="decimal-pad" />
            <View className="flex-row gap-2 mb-3">
              <View className="flex-1">
                <PrimaryButton label="▲ COMPRAR" color={C.up} loading={sendOrder.isPending && sendOrder.variables === "buy"} onPress={() => sendOrder.mutate("buy")} />
              </View>
              <View className="flex-1">
                <PrimaryButton label="▼ VENDER" color={C.down} loading={sendOrder.isPending && sendOrder.variables === "sell"} onPress={() => sendOrder.mutate("sell")} />
              </View>
              <View className="flex-1">
                <PrimaryButton label="✕ FECHAR" color={C.amber} loading={sendOrder.isPending && sendOrder.variables === "close"} onPress={() => sendOrder.mutate("close")} />
              </View>
            </View>
            {orderMsg ? <Text className="text-up text-sm mb-2">{orderMsg}</Text> : null}
            {orderError ? <Text className="text-down text-sm mb-2">{orderError}</Text> : null}
            <Text className="text-ink-faint text-[11px] leading-4">
              Os comandos são executados pelo EA HandlivPanel conectado na conta. Mantenha o EA rodando no MT5.
            </Text>
          </Card>
        </View>
      ) : null}

      {/* Últimos comandos */}
      {orders.length > 0 ? (
        <View className="mb-5">
          <SectionTitle>Últimos comandos</SectionTitle>
          <View className="gap-2">
            {orders.slice(0, 6).map((o) => {
              const statusColor = o.status === "executed" ? C.up : o.status === "failed" ? C.down : o.status === "sent" ? C.accent : C.amber;
              return (
                <Card key={o.id} className="px-4 py-3 flex-row items-center justify-between">
                  <View className="flex-1">
                    <View className="flex-row items-center gap-2">
                      <Text className="text-ink font-bold text-sm">{o.action === "buy" ? "COMPRA" : o.action === "sell" ? "VENDA" : "FECHAR"}</Text>
                      {o.symbol ? (
                        <Text className="text-ink-soft text-xs">
                          {o.symbol} {o.volume ?? ""}
                        </Text>
                      ) : null}
                    </View>
                    <Text className="text-ink-faint text-[11px] mt-0.5">
                      {o.account_number}
                      {o.created_at ? ` · ${new Date(o.created_at).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}` : ""}
                      {o.result_message ? ` · ${o.result_message}` : ""}
                    </Text>
                  </View>
                  <Badge text={o.status === "executed" ? "OK" : o.status === "failed" ? "FALHOU" : o.status === "sent" ? "ENVIADO" : "PENDENTE"} color={statusColor} />
                </Card>
              );
            })}
          </View>
        </View>
      ) : null}
      {/* Gerenciar contas (Start gerencia aqui; Ultimate na aba Robô) */}
      {!isUltimate ? (
        <View className="mb-5">
          <SectionTitle
            action={<Text className="text-ink-faint text-xs">{f?.mt5_accounts_used ?? items.length}/{f?.mt5_accounts_max ?? 2} contas</Text>}
          >
            Gerenciar contas
          </SectionTitle>
          <View className="gap-2 mb-3">
            {items.map((a) => (
              <Card key={a.id} className="px-4 py-3 flex-row items-center justify-between">
                <View className="flex-1">
                  <Text className="text-ink font-bold">{a.account_number}</Text>
                  {a.broker ? <Text className="text-ink-soft text-xs mt-0.5">{a.broker}</Text> : null}
                </View>
                <Text className="text-down text-xs font-bold px-3 py-2" onPress={() => removeAccount.mutate(a.id)}>
                  REMOVER
                </Text>
              </Card>
            ))}
          </View>
          {registrationCard}
        </View>
      ) : null}
    </ScrollView>
  );
}
