import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Pressable, Text, View } from "react-native";
import { mt5AutomationApi, watchlistApi, type MT5AutomationRule } from "@/api/client";
import { C, Card, Input, Loading, SectionTitle } from "@/components/ui";
import { validateAutomation, type AutomationDirection, type AutomationDraft } from "./model";

const directions: { value: AutomationDirection; label: string }[] = [
  { value: "buy", label: "Compra" }, { value: "sell", label: "Venda" }, { value: "both", label: "Compra e venda" },
];
function Button({ label, disabled = false, onPress }: { label: string; disabled?: boolean; onPress: () => void }) {
  return <Pressable accessibilityRole="button" accessibilityLabel={label} disabled={disabled} onPress={onPress}
    className="rounded-xl px-4 py-3 mb-2" style={{ backgroundColor: C.brand + "22", opacity: disabled ? 0.45 : 1 }}>
    <Text className="text-ink font-bold">{label}</Text>
  </Pressable>;
}

function FavoriteRule({ account, symbol, rule }: {
  account: { id: string; account_number: string }; symbol: string; rule?: MT5AutomationRule;
}) {
  const qc = useQueryClient();
  const [saved, setSaved] = useState(rule);
  const [draft, setDraft] = useState<AutomationDraft>(rule ?? { broker_symbol: "", direction: "buy", volume: "", sl_atr_multiplier: "2.00", tp_atr_multiplier: "3.00" });
  const [dirty, setDirty] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const lock = useRef(false);
  const mounted = useRef(true);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  useEffect(() => {
    if (!dirty && !lock.current) {
      setSaved(rule);
      setDraft(rule ?? { broker_symbol: "", direction: "buy", volume: "", sl_atr_multiplier: "2.00", tp_atr_multiplier: "3.00" });
    }
  }, [rule, dirty]);
  const invalid = validateAutomation(draft);
  const frozen = pending || confirm || !!saved?.enabled;
  function edit(change: Partial<AutomationDraft>) {
    if (frozen || lock.current) return;
    setDraft(d => ({ ...d, ...change })); setDirty(true); setError(null); setMessage(null);
  }
  async function save(enabled: boolean) {
    if (lock.current) return;
    const config = !enabled && saved?.enabled ? saved : draft;
    const validation = validateAutomation(config);
    if (validation) { setError(validation); return; }
    lock.current = true; setPending(true); setError(null); setMessage(null);
    try {
      const result = await mt5AutomationApi.save(symbol, { account_id: account.id, broker_symbol: config.broker_symbol,
        direction: config.direction, volume: config.volume, sl_atr_multiplier: config.sl_atr_multiplier, tp_atr_multiplier: config.tp_atr_multiplier, enabled });
      if (result.account_id !== account.id || result.symbol !== symbol) throw new Error("Resposta de outra conta/ativo rejeitada. Recarregue para verificar a configuração.");
      qc.setQueryData<{ items: MT5AutomationRule[] }>(["mt5-automation", account.id], previous => ({
        items: [...(previous?.items ?? []).filter(r => r.symbol !== symbol), result],
      }));
      if (mounted.current) {
        setSaved(result); setDraft(result); setDirty(false); setConfirm(false);
        setMessage(result.enabled ? "Ativada no servidor. Aguarde o próximo NOVO sinal forte." : "Configuração desativada salva.");
      }
    } catch (e) {
      if (mounted.current) { setError(e instanceof Error ? e.message : "Erro ao salvar. Verifique o estado no servidor antes de tentar novamente."); setConfirm(false); }
    } finally { lock.current = false; if (mounted.current) setPending(false); }
  }
  return <Card className="p-4 mb-3" testID={`automation-${symbol}`}>
    <Text className="text-ink font-bold mb-2">{symbol} · {saved?.enabled ? "ATIVADA" : "DESATIVADA"}</Text>
    <Text className="text-ink-soft text-xs mb-2">Conta {account.account_number} · ID {account.id}</Text>
    <Text className="text-ink-soft text-xs mb-1">Símbolo EXATO na corretora (inclua sufixos; não é inferido)</Text>
    <Input accessibilityLabel="Símbolo exato na corretora" editable={!frozen} autoCapitalize="none" value={draft.broker_symbol} onChangeText={broker_symbol => edit({ broker_symbol })} placeholder="Ex.: EURUSD.a" />
    <Text className="text-ink-soft text-xs mb-1">Volume em lotes · ponto decimal · máximo 2 casas</Text>
    <Input accessibilityLabel="Volume em lotes" editable={!frozen} keyboardType="decimal-pad" value={draft.volume} onChangeText={volume => edit({ volume })} placeholder="Ex.: 0.10" />
    <Text className="text-ink-soft text-xs mb-2">Proteção obrigatória: ATR14 H1, candle fechado da corretora. O EA calcula stop/alvo com ATR e cotação reais do broker, nunca preços Yahoo da análise. Sem ordem sem SL/TP.</Text>
    <Text className="text-ink-soft text-xs mb-1">Stop · multiplicador ATR (0.10–20.00)</Text>
    <Input accessibilityLabel="Stop ATR multiplicador" editable={!frozen} keyboardType="decimal-pad" value={draft.sl_atr_multiplier} onChangeText={sl_atr_multiplier => edit({ sl_atr_multiplier })} />
    <Text className="text-ink-soft text-xs mb-1">Alvo · multiplicador ATR (0.10–20.00)</Text>
    <Input accessibilityLabel="Alvo ATR multiplicador" editable={!frozen} keyboardType="decimal-pad" value={draft.tp_atr_multiplier} onChangeText={tp_atr_multiplier => edit({ tp_atr_multiplier })} />
    <View className="flex-row flex-wrap gap-2 mb-2">
      {directions.map(d => <Pressable key={d.value} accessibilityRole="button" accessibilityLabel={d.label}
        accessibilityState={{ selected: draft.direction === d.value, disabled: frozen }} disabled={frozen}
        onPress={() => edit({ direction: d.value })} className="px-3 py-2 rounded-xl" style={{ backgroundColor: draft.direction === d.value ? C.brand + "55" : C.surface2 }}>
        <Text className="text-ink">{d.label}</Text>
      </Pressable>)}
    </View>
    {invalid ? <Text className="text-amber text-xs mb-2">{invalid}</Text> : null}
    {error ? <Text accessibilityRole="alert" className="text-down text-sm mb-2">{error}</Text> : null}
    {message ? <Text className="text-up text-xs mb-2">{message}</Text> : null}
    <Text className="text-ink-soft text-xs mb-2">Último sinal: {saved?.last_signal ?? "—"} · Último status: {saved?.last_status ?? "—"}</Text>
    <Text className="text-ink-faint text-xs mb-3">pending / sent: aguardando ACK do EA; não confirma execução. Só ACK executado confirma execução, falhas devem ser verificadas.</Text>
    {pending ? <Text className="text-amber mb-2">Salvando… controles bloqueados</Text> : null}
    {saved?.enabled ? <Button label="Desativar" disabled={pending} onPress={() => void save(false)} /> : <>
      <Button label="Salvar desativada" disabled={!!invalid || pending || confirm} onPress={() => void save(false)} />
      <Button label="Ativar…" disabled={!!invalid || pending || confirm} onPress={() => setConfirm(true)} />
    </>}
    {confirm ? <View testID="automation-confirm" className="p-3 rounded-xl border border-amber">
      <Text className="text-amber font-bold">Risco: esta ativação autoriza ordens reais via HandlivPanel.</Text>
      <Text className="text-ink mt-2">Conta {account.account_number} (ID {account.id}) · Favorito {symbol} · Corretora {draft.broker_symbol} · {draft.volume} lotes · {directions.find(d => d.value === draft.direction)?.label}</Text>
      <Text className="text-ink mt-2">Stop {draft.sl_atr_multiplier}× ATR · Alvo {draft.tp_atr_multiplier}× ATR · ATR14 H1, candle fechado da corretora.</Text>
      <Text className="text-ink-soft text-xs my-2">Sem ordem imediata: o servidor registra o sinal atual como baseline e espera o próximo NOVO COMPRA FORTE/VENDA FORTE da análise ao vivo. Não repete o mesmo forte nem abre outra posição de automação no mesmo ativo. Erros não reiniciam o baseline.</Text>
      <Button label="Confirmar ativação" disabled={pending || !!invalid} onPress={() => void save(true)} />
      <Button label="Cancelar" disabled={pending} onPress={() => setConfirm(false)} />
    </View> : null}
  </Card>;
}

export function AutomationControls({ account }: { account: { id: string; account_number: string } }) {
  const favorites = useQuery({ queryKey: ["watchlist"], queryFn: watchlistApi.list });
  const rules = useQuery({ queryKey: ["mt5-automation", account.id], queryFn: async () => {
    const data = await mt5AutomationApi.list(account.id);
    if (data.items.some(r => r.account_id !== account.id)) throw new Error("Configuração de outra conta rejeitada.");
    return data;
  }, retry: false, staleTime: 0, refetchInterval: 15000 });
  return <View className="mb-5">
    <SectionTitle>Automação dos favoritos</SectionTitle>
    <Text className="text-ink-soft text-xs mb-3">Conta {account.account_number}. Configuração por conta, validada pelo servidor. Somente favoritos; o frontend não calcula sinais nem envia ordens automaticamente. O job durável usa exclusivamente os NOVOS sinais canônicos COMPRA FORTE/VENDA FORTE. Ativar não envia ordem imediata; erros não resetam o sinal. Sem repetição do mesmo forte ou outra posição de automação no mesmo ativo. Mantenha HandlivPanel conectado.</Text>
    {favorites.isPending || rules.isPending ? <Loading label="Carregando automações desta conta…" /> : favorites.isError || rules.isError ? <Card className="p-4">
      <Text className="text-down">Não foi possível carregar favoritos/configuração desta conta. Controles bloqueados.</Text>
      <Button label="Tentar novamente" onPress={() => { void favorites.refetch(); void rules.refetch(); }} />
    </Card> : favorites.data?.length ? favorites.data.map(f => <FavoriteRule key={`${account.id}:${f.asset.symbol}`}
      account={account} symbol={f.asset.symbol} rule={rules.data?.items.find(r => r.symbol === f.asset.symbol && r.account_id === account.id)} />)
      : <Text className="text-ink-soft">Adicione favoritos para configurar a automação (padrão desativado).</Text>}
  </View>;
}
