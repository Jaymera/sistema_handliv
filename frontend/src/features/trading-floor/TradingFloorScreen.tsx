import { useCallback, useEffect, useState } from 'react';
import { AccessibilityInfo, FlatList, Modal, Platform, Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { router } from 'expo-router';
import { Badge, C, Card } from '@/components/ui';
import FloorScene from './FloorScene';
import StationDetails from './StationDetails';
import { useTradingFloor } from './useTradingFloor';
import { money } from './model';
import type { FloorSceneProps, FloorStatus } from './types';

const statusColors: Record<FloorStatus, string> = { OPERANDO: C.up, 'POSIÇÃO ABERTA': C.accent, AGUARDANDO: C.amber, OFFLINE: C.faint };
function Button({ label, onPress, disabled = false, selected = false }: { label: string; onPress: () => void; disabled?: boolean; selected?: boolean }) {
  return <Pressable accessibilityRole="button" accessibilityState={{ disabled, selected }} disabled={disabled} onPress={onPress} style={[styles.button, selected && { borderColor: C.brand, backgroundColor: '#16D39A18' }, disabled && { opacity: 0.45 }]}><Text style={{ color: selected ? C.brand : C.ink, fontSize: 12, fontWeight: '600' }}>{label}</Text></Pressable>;
}
export default function TradingFloorScreen() {
  const floor = useTradingFloor();
  const { width } = useWindowDimensions();
  const mobile = width < 720;
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [expanded, setExpanded] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [command, setCommand] = useState<FloorSceneProps['command']>({ type: 'fit', seq: 0 });
  const close = useCallback(() => setSelectedId(null), []);
  useEffect(() => { setSelectedId(null); }, [floor.demo, floor.user?.id]);
  useEffect(() => {
    let mounted = true;
    AccessibilityInfo.isReduceMotionEnabled().then(value => { if (mounted) setReducedMotion(value); });
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setReducedMotion);
    return () => { mounted = false; sub.remove(); };
  }, []);
  useEffect(() => {
    if (!expanded || Platform.OS !== 'web') return;
    const escape = (event: KeyboardEvent) => { if (event.key === 'Escape' && !selectedId) setExpanded(false); };
    window.addEventListener('keydown', escape);
    return () => window.removeEventListener('keydown', escape);
  }, [expanded, selectedId]);
  const send = (type: FloorSceneProps['command']['type']) => setCommand(previous => ({ type, seq: previous.seq + 1 }));
  const { summary } = floor;
  const metrics = [
    ['Saldo', money(summary.balance, summary.currency)], ['Equity', money(summary.equity, summary.currency)],
    ['Lucro diário', money(summary.profitDay, summary.currency, true)], ['Flutuante', money(summary.floating, summary.currency, true)],
    ['Drawdown', summary.drawdown == null ? '—' : `${summary.drawdown.toFixed(2)}%`],
    ['Posições abertas', summary.openPositions == null ? '—' : String(summary.openPositions)],
    [floor.demo ? 'Robôs online' : 'Estações online', summary.online == null ? '—' : String(summary.online)],
  ];
  const scene = (large: boolean) => <View style={[styles.sceneShell, large ? { flex: 1 } : { height: mobile ? 480 : 550 }]}>
    <View style={styles.toolbar}>
      <View style={{ flex: 1, minWidth: 130 }}><Text style={styles.eyebrow}>LIVE OPERATIONS</Text><Text style={styles.sceneTitle}>{floor.demo ? 'Pregão simulado' : 'Suas estações MT5'}</Text></View>
      <Button label="−" onPress={() => send('out')} /><Button label="+" onPress={() => send('in')} />
      <Button label="Fit Screen" onPress={() => send('fit')} />
      <Button label={large ? 'Fechar tela cheia' : 'Tela cheia'} onPress={() => { setExpanded(!large); send('fit'); }} />
    </View>
    <View style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}>
      <FloorScene stations={floor.stations} summary={summary} events={floor.events} selectedId={selectedId} onSelect={setSelectedId} command={command} reducedMotion={reducedMotion} demo={floor.demo} />
      {!floor.stations.length && <View pointerEvents="none" style={styles.emptyScene}><Text style={styles.sceneTitle}>Aguardando estações</Text><Text style={[styles.caption, { textAlign: 'center', maxWidth: 320 }]}>Conecte uma conta MT5 ou ative a demonstração para conhecer o Trading Floor.</Text></View>}
    </View>
    <View style={styles.sceneFooter}><Text style={styles.caption}>{floor.stations.length} estações · selecione uma mesa para detalhes</Text><Badge text={floor.demo ? 'DEMO' : 'REAL'} color={floor.demo ? C.amber : C.brand} /></View>
  </View>;
  return <View style={{ flex: 1, backgroundColor: C.bg }}>
    <ScrollView contentContainerStyle={[styles.content, { paddingHorizontal: mobile ? 12 : 28 }]}>
      <View style={styles.heading}>
        <View><Text style={styles.eyebrow}>HANDLIV / INTELLIGENCE</Text><Text accessibilityRole="header" style={[styles.title, { fontSize: mobile ? 26 : 34 }]}>TRADING FLOOR</Text><Text style={styles.caption}>Seu pregão digital. Uma visão de todas as estações.</Text></View>
        <View style={{ gap: 8 }}><Badge text={floor.demo ? 'DEMO · DADOS SIMULADOS' : 'REAL · CONTAS MT5'} color={floor.demo ? C.amber : C.brand} /><Text style={styles.caption}>{floor.demo ? 'Simulação local · a cada 6s' : floor.polling ? 'Atualização automática · 15s' : 'Atualização pausada'}</Text></View>
      </View>
      <View style={styles.modeRow}>
        <Button label="Dados reais" selected={!floor.demo} onPress={() => floor.setRequestedDemo(false)} />
        <Button label="Explorar demo" selected={floor.demo} disabled={floor.accounts.length > 0} onPress={() => floor.setRequestedDemo(true)} />
        {floor.accounts.length > 0 && <Text style={styles.caption}>Contas reais têm prioridade sobre a demo.</Text>}
        {floor.demo && <View style={styles.modeRow}>{[10, 20, 50, 100, 150].map(count => <Button key={count} label={`${count} robôs`} selected={floor.count === count} onPress={() => { floor.setCount(count); send('fit'); }} />)}</View>}
      </View>
      <Card style={styles.notice}><Text style={{ color: floor.demo ? C.amber : C.soft, fontSize: 12, lineHeight: 19 }}>{floor.demo ? 'DEMONSTRAÇÃO — robôs, posições e resultados fictícios. Não representa sua conta nem desempenho prometido.' : 'MT5 envia dados por conta; Magic/ativo e posições por robô ainda não disponíveis. Cada estação representa uma conta HandlivPanel, não um robô individual.'}</Text></Card>
      {!floor.demo && !floor.user && <Card style={styles.notice}><Text style={styles.body}>Entre para consultar suas contas reais. A demonstração é opcional e independente.</Text><Button label="Entrar" onPress={() => router.push('/auth/login')} /></Card>}
      {!floor.demo && floor.user && !floor.allowed && !floor.features.isLoading && <Card style={styles.notice}><Text style={styles.body}>{floor.features.isError ? 'Não foi possível verificar seu acesso. Nenhum dado simulado substituiu os dados reais.' : 'O painel MT5 precisa estar incluído no seu plano para visualizar contas reais.'}</Text><Button label={floor.features.isError ? 'Tentar novamente' : 'Ver planos'} onPress={() => { if (floor.features.isError) void floor.features.refetch(); else router.push('/pricing'); }} /></Card>}
      {!floor.demo && floor.allowed && floor.stats.isError && <Card style={styles.notice}><Text style={{ color: C.amber, fontSize: 13 }}>Falha ao atualizar o MT5. {floor.accounts.length ? 'Exibindo o último snapshot recebido; verifique o horário de cada conta.' : 'Nenhum dado real disponível. Não substituímos falhas por simulação.'}</Text><Button label="Tentar novamente" onPress={() => { void floor.stats.refetch(); }} /></Card>}
      {!floor.demo && (floor.features.isLoading || floor.stats.isLoading) && <Text style={styles.caption}>Consultando acesso e dados MT5…</Text>}
      {!floor.demo && floor.allowed && floor.stats.isSuccess && !floor.accounts.length && <Text style={styles.caption}>Nenhuma conta cadastrada. Cadastre sua conta na área MT5/Robô ou explore a demo.</Text>}
      {!floor.demo && floor.accounts.length > 0 && <View style={{ gap: 8 }}><Text style={styles.caption}>Indicadores da conta selecionada · não somamos moedas ou percentuais</Text><ScrollView horizontal showsHorizontalScrollIndicator>{floor.accounts.map(a => <View key={a.id} style={{ marginRight: 8 }}><Button label={`Conta ${a.account_number}`} selected={a.id === floor.selectedAccount?.id} onPress={() => floor.setAccountId(a.id)} /></View>)}</ScrollView></View>}
      <View style={styles.metrics}>{metrics.map(([label, value]) => <Card key={label} style={[styles.metric, { minWidth: mobile ? 130 : 140 }]}><Text style={styles.caption}>{label}</Text><Text style={[styles.metricValue, label === 'Lucro diário' && { color: summary.profitDay == null ? C.ink : summary.profitDay < 0 ? C.down : C.up }]}>{value}</Text></Card>)}</View>
      {!summary.equityHistory.length && <Text style={styles.caption}>Histórico de equity não disponível — sem curva estimada.</Text>}
      {!expanded && scene(false)}
      <View style={styles.legend}>{(Object.keys(statusColors) as FloorStatus[]).map(status => <View key={status} style={styles.legendItem}><View style={[styles.dot, { backgroundColor: statusColors[status] }]} /><Text style={styles.caption}>{status} · {floor.stations.filter(s => s.status === status).length}</Text></View>)}</View>
      <View style={styles.heading}><Text accessibilityRole="header" style={styles.sceneTitle}>Estações / acesso rápido</Text><Text style={styles.caption}>Visão somente leitura</Text></View>
      <FlatList horizontal data={floor.stations} keyExtractor={item => item.id} initialNumToRender={8} windowSize={3} style={{ flexGrow: 0 }} contentContainerStyle={{ gap: 10, paddingBottom: 10 }} renderItem={({ item }) => <Pressable accessibilityRole="button" accessibilityLabel={`Detalhes de ${item.name}, ${item.status}`} onPress={() => setSelectedId(item.id)} style={styles.station}><Text style={styles.stationName}>{item.name}</Text><Text style={{ color: statusColors[item.status], fontSize: 11 }}>{item.status}</Text><Text style={styles.body}>{money(item.profitDay, item.currency, true)}</Text><Text style={styles.caption}>{item.symbol ?? 'Ativo não informado'}</Text></Pressable>} />
      <Text style={[styles.caption, { textAlign: 'center', marginTop: 8 }]}>HANDLIV · Trading Floor · Sem execução de ordens</Text>
    </ScrollView>
    <Modal visible={expanded} animationType="fade" onRequestClose={() => setExpanded(false)}><View style={{ flex: 1, backgroundColor: C.bg, padding: mobile ? 8 : 20 }}>{scene(true)}{expanded && <StationDetails station={floor.stations.find(s => s.id === selectedId) ?? null} demo={floor.demo} onClose={close} />}</View></Modal>
    {!expanded && <StationDetails station={floor.stations.find(s => s.id === selectedId) ?? null} demo={floor.demo} onClose={close} />}
  </View>;
}
const styles = StyleSheet.create({
  content: { paddingTop: 24, paddingBottom: 36, gap: 16, width: '100%', maxWidth: 1680, alignSelf: 'center' },
  heading: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' },
  eyebrow: { color: C.brand, fontSize: 10, fontWeight: '700', letterSpacing: 2, marginBottom: 7 },
  title: { color: C.ink, fontWeight: '800', letterSpacing: 1, marginBottom: 6 },
  caption: { color: C.soft, fontSize: 11, lineHeight: 17 }, body: { color: C.ink, fontSize: 13, lineHeight: 20 },
  modeRow: { flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap' },
  button: { minHeight: 38, minWidth: 38, paddingHorizontal: 12, paddingVertical: 10, borderRadius: 8, borderWidth: 1, borderColor: C.line, backgroundColor: C.surface2, alignItems: 'center', justifyContent: 'center' },
  notice: { padding: 14, gap: 10, backgroundColor: C.surface, borderColor: C.line },
  metrics: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 }, metric: { flex: 1, padding: 15, gap: 10, backgroundColor: C.surface },
  metricValue: { fontSize: 21, color: C.ink, fontWeight: '700', fontVariant: ['tabular-nums'] },
  sceneShell: { backgroundColor: C.deep, borderRadius: 16, borderColor: C.line, borderWidth: 1, overflow: 'hidden' },
  toolbar: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: 6, padding: 12, borderBottomWidth: 1, borderBottomColor: C.line },
  sceneTitle: { color: C.ink, fontSize: 16, fontWeight: '700' },
  sceneFooter: { padding: 12, flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between', gap: 8, borderTopWidth: 1, borderTopColor: C.line },
  emptyScene: { ...StyleSheet.absoluteFillObject, alignItems: 'center', justifyContent: 'center', gap: 10, padding: 20 },
  legend: { flexDirection: 'row', flexWrap: 'wrap', gap: 16 }, legendItem: { flexDirection: 'row', alignItems: 'center', gap: 6 }, dot: { width: 7, height: 7, borderRadius: 4 },
  station: { width: 195, padding: 16, borderRadius: 12, gap: 8, backgroundColor: C.surface, borderWidth: 1, borderColor: C.line },
  stationName: { color: C.ink, fontSize: 13, fontWeight: '700' },
});
