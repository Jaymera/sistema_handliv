import "../../src/global.css";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router } from "expo-router";
import { ScrollView, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useState } from "react";

import { featuresApi, mt5Api, ordersApi, statsApi, type MT5Stats } from "@/api/client";
import { Badge, C, Card, Empty, Input, Loading, PrimaryButton, SectionTitle, StatCard, UpsellCard, openUrl } from "@/components/ui";

const WHATSAPP = "https://wa.me/551152866453";
const HANDLIV = "https://handliv.com";

function money(v: number, currency: string): string {
  const symbol = currency === "BRL" ? "R$" : currency === "EUR" ? "€" : currency === "GBP" ? "£" : "$";
  return `${symbol} ${v.toFixed(2)}`;
}

function ProfitText({ value, currency }: { value: number; currency: string }) {
  return (
    <Text className="text-lg font-bold" style={{ color: value >= 0 ? C.up : C.down }}>
      {value >= 0 ? "+" : ""}
      {money(value, currency)}
    </Text>
  );
}

function AccountStats({ stats }: { stats: MT5Stats }) {
  const cur = stats.currency || "USD";
  const winRate = stats.total_trades > 0 ? Math.round((stats.win_trades / stats.total_trades) * 100) : null;
  const updated = stats.updated_at ? new Date(stats.updated_at).toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }) : null;

  return (
    <View className="gap-3">
      {/* Resultado por período */}
      <View className="flex-row gap-3">
        <View className="flex-1">
          <StatCard label="HOJE" value={`${stats.profit_day >= 0 ? "+" : ""}${money(stats.profit_day, cur)}`} color={stats.profit_day >= 0 ? C.up : C.down} />
        </View>
        <View className="flex-1">
          <StatCard label="SEMANA" value={`${stats.profit_week >= 0 ? "+" : ""}${money(stats.profit_week, cur)}`} color={stats.profit_week >= 0 ? C.up : C.down} />
        </View>
      </View>
      <View className="flex-row gap-3">
        <View className="flex-1">
          <StatCard label="MÊS" value={`${stats.profit_month >= 0 ? "+" : ""}${money(stats.profit_month, cur)}`} color={stats.profit_month >= 0 ? C.up : C.down} />
        </View>
        <View className="flex-1">
          <StatCard label="TOTAL" value={`${stats.profit_total >= 0 ? "+" : ""}${money(stats.profit_total, cur)}`} color={stats.profit_total >= 0 ? C.up : C.down} />
        </View>
      </View>

      {/* Conta */}
      <Card className="p-4">
        <View className="flex-row justify-between mb-3">
          <View>
            <Text className="text-ink-faint text-[10px] font-bold">SALDO</Text>
            <Text className="text-ink font-bold">{money(stats.balance, cur)}</Text>
          </View>
          <View className="items-end">
            <Text className="text-ink-faint text-[10px] font-bold">PATRIMÔNIO</Text>
            <Text className="text-ink font-bold">{money(stats.equity, cur)}</Text>
          </View>
        </View>
        <View className="flex-row justify-between">
          <View>
            <Text className="text-ink-faint text-[10px] font-bold">DRAWDOWN</Text>
            <Text className="font-bold" style={{ color: C.down }}>
              -{stats.dd_percent.toFixed(2)}%
            </Text>
          </View>
          <View>
            <Text className="text-ink-faint text-[10px] font-bold">FLUTUANTE</Text>
            <Text className="font-bold" style={{ color: stats.floating_pl >= 0 ? C.up : C.down }}>
              {stats.floating_pl >= 0 ? "+" : ""}
              {money(stats.floating_pl, cur)}
            </Text>
          </View>
          <View>
            <Text className="text-ink-faint text-[10px] font-bold">NÍVEL MARGEM</Text>
            <Text className="text-ink font-bold">{stats.margin_level > 0 ? stats.margin_level.toFixed(1) : "—"}%</Text>
          </View>
          <View className="items-end">
            <Text className="text-ink-faint text-[10px] font-bold">POSIÇÕES</Text>
            <Text className="text-ink font-bold">{stats.open_positions}</Text>
          </View>
        </View>
      </Card>

      {/* Win rate */}
      <Card className="p-4">
        <View className="flex-row items-center justify-between mb-2">
          <Text className="text-ink-faint text-[10px] font-bold">WIN RATE</Text>
          {winRate !== null ? (
            <Text className="font-bold" style={{ color: winRate >= 50 ? C.up : C.amber }}>
              {winRate}%
            </Text>
          ) : (
            <Text className="text-ink-faint">—</Text>
          )}
        </View>
        {winRate !== null ? (
          <View className="h-2 rounded-full overflow-hidden flex-row" style={{ backgroundColor: C.down + "55" }}>
            <View style={{ width: `${winRate}%`, backgroundColor: C.up }} />
          </View>
        ) : null}
        <View className="flex-row gap-4 mt-2">
          <Text className="text-xs" style={{ color: C.up }}>
            {stats.win_trades} ganhos
          </Text>
          <Text className="text-xs" style={{ color: C.down }}>
            {stats.loss_trades} perdas
          </Text>
          <Text className="text-ink-faint text-xs">{stats.total_trades} trades</Text>
        </View>
      </Card>

      {updated ? <Text className="text-ink-faint text-[10px] text-center">Atualizado pelo EA às {updated}</Text> : null}
    </View>
  );
}

export default function MT5Screen() {
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

  if (fLoading) return <Loading label="Carregando..." />;

  const f = features?.features;
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
  const activeAccountId = selectedAccount ?? items[0]?.id;
  const orders = ordersData?.items ?? [];

  return (
    <ScrollView className="flex-1 bg-night" contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 18, paddingBottom: 32 }}>
      <Text className="text-ink-faint text-xs font-bold tracking-widest mb-1">HANDLIV</Text>
      <Text className="text-ink text-2xl font-bold mb-1">Minha Conta MT5</Text>
      <View className="flex-row items-center gap-2 mb-4">
        <Badge text={isUltimate ? "ULTIMATE" : "START"} color={isUltimate ? C.purple : C.accent} />
        <Text className="text-ink-soft text-xs">Estatísticas em tempo real do seu trading</Text>
      </View>

      {/* Download EA */}
      <Card className="p-4 mb-5 flex-row items-center gap-3" style={{ borderColor: C.brand + "44" }}>
        <View className="w-12 h-12 rounded-xl items-center justify-center" style={{ backgroundColor: C.brand + "22" }}>
          <Ionicons name="speedometer" size={24} color={C.brand} />
        </View>
        <View className="flex-1">
          <Text className="text-ink font-bold">EA HandlivPanel</Text>
          <Text className="text-ink-soft text-xs mt-0.5">Baixe e rode no seu MT5 para enviar as estatísticas e receber comandos</Text>
        </View>
        <PrimaryButton label="Baixar" small onPress={() => openUrl(HANDLIV)} />
      </Card>

      {/* Contas */}
      <SectionTitle
        action={<Text className="text-ink-faint text-xs">{f?.mt5_accounts_used ?? items.length}/{f?.mt5_accounts_max ?? 2} contas</Text>}
      >
        Contas MT5
      </SectionTitle>
      {sLoading ? (
        <Loading />
      ) : items.length > 0 ? (
        <View className="gap-2 mb-5">
          {items.map((a) => {
            const active = a.id === activeAccountId;
            const st = a.stats;
            return (
              <Card key={a.id} className="p-4 mb-3" style={{ borderColor: active ? C.brand + "55" : C.line }}>
                <View className="flex-row items-center justify-between mb-3">
                  <PressableRow onPress={() => setSelectedAccount(a.id)} accountNumber={a.account_number} broker={a.broker} isActive={a.is_active} selected={active} />
                  <Text className="text-down text-[10px] font-bold px-2 py-1" onPress={() => removeAccount.mutate(a.id)}>
                    REMOVER
                  </Text>
                </View>
                {st ? <AccountStats stats={st} /> : (
                  <Text className="text-ink-soft text-xs leading-4">
                    Aguardando o EA HandlivPanel se conectar a esta conta... Rode o EA no MT5 com o secret correto e as estatísticas aparecerão aqui.
                  </Text>
                )}
              </Card>
            );
          })}
        </View>
      ) : (
        <View className="mb-5">
          <Empty text="Nenhuma conta MT5 cadastrada. Cadastre abaixo para ver suas estatísticas." />
        </View>
      )}

      {/* Cadastro de contas */}
      <Card className="p-4 mb-5">
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
      </Card>

      {/* Painel de Execução */}
      {items.length > 0 ? (
        <View className="mb-5">
          <SectionTitle>Painel de Execução</SectionTitle>
          <Card className="p-4">
            <Text className="text-ink-faint text-xs font-bold mb-2">CONTA SELECIONADA: {items.find((a) => a.id === activeAccountId)?.account_number}</Text>
            <Input value={symbol} onChangeText={setSymbol} placeholder="Ativo (ex: EURUSD, WIN$N, PETR4)" autoCapitalize="characters" />
            <Input value={volume} onChangeText={setVolume} placeholder="Volume (lotes, ex: 0.10)" keyboardType="decimal-pad" />
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
              Os botões enviam comandos ao EA HandlivPanel conectado na conta selecionada. Mantenha o EA rodando no MT5.
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
                      <Text className="text-ink font-bold text-sm">
                        {o.action === "buy" ? "COMPRA" : o.action === "sell" ? "VENDA" : "FECHAR"}
                      </Text>
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
    </ScrollView>
  );
}

function PressableRow({ onPress, accountNumber, broker, isActive, selected }: { onPress: () => void; accountNumber: string; broker: string | null; isActive: boolean; selected: boolean }) {
  return (
    <View className="flex-1">
      <Text onPress={onPress} className="text-ink font-bold text-base">
        Conta {accountNumber} {selected ? "·" : ""}
      </Text>
      <Text onPress={onPress} className="text-ink-soft text-xs">
        {broker ? `${broker} · ` : ""}
        {isActive ? "ativa" : "inativa"}
      </Text>
    </View>
  );
}
