import { useEffect } from 'react';
import { Modal, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Badge, C, Card } from '@/components/ui';
import { money } from './model';
import type { FloorStation } from './types';

const unknown = 'Não informado pelo MT5';
export default function StationDetails({ station, demo, onClose }: { station: FloorStation | null; demo: boolean; onClose: () => void }) {
  useEffect(() => {
    if (!station || Platform.OS !== 'web') return;
    const escape = (event: KeyboardEvent) => { if (event.key === 'Escape') onClose(); };
    window.addEventListener('keydown', escape);
    return () => window.removeEventListener('keydown', escape);
  }, [station, onClose]);
  if (!station) return null;
  const value = (n: number | null) => n == null ? unknown : String(n);
  const rows = [
    ['Magic', value(station.magic)], ['Ativo', station.symbol ?? unknown], ['Timeframe', station.timeframe ?? unknown],
    ['Lucro diário', money(station.profitDay, station.currency, true)], ['Lucro semanal', money(station.profitWeek, station.currency, true)],
    ['Lucro mensal', money(station.profitMonth, station.currency, true)], ['Trades', value(station.trades)],
    ['Vitórias', value(station.wins)], ['Derrotas', value(station.losses)],
    ['Drawdown', station.drawdown == null ? unknown : `${station.drawdown.toFixed(2)}%`],
    ['Posições abertas', value(station.openPositions)],
    ['Atualizado', station.updatedAt ? new Date(station.updatedAt).toLocaleString('pt-BR') : unknown],
  ];
  return <Modal transparent visible animationType="fade" onRequestClose={onClose}>
    <View style={styles.overlay}>
      <Pressable accessibilityRole="button" accessibilityLabel="Fechar detalhes" onPress={onClose} style={StyleSheet.absoluteFill} />
      <Card style={styles.panel} accessibilityViewIsModal>
        <View style={styles.header}>
          <View style={{ flex: 1 }}><Text accessibilityRole="header" style={styles.title}>{station.name}</Text><Text style={styles.muted}>{demo ? 'Robô simulado • sem operações reais' : 'HandlivPanel • resultado agregado da conta'}</Text></View>
          <Pressable accessibilityRole="button" accessibilityLabel="Fechar detalhes" onPress={onClose} style={styles.close}><Text style={styles.title}>×</Text></Pressable>
        </View>
        <View style={{ flexDirection: 'row', gap: 8, marginBottom: 16 }}><Badge text={demo ? 'DEMO' : 'REAL · CONTA'} color={demo ? C.amber : C.brand} /><Badge text={station.status} /></View>
        <ScrollView contentContainerStyle={{ paddingBottom: 16 }}>
          {rows.map(([label, text]) => <View key={label} style={styles.row}><Text style={styles.muted}>{label}</Text><Text style={styles.value}>{text}</Text></View>)}
          <Text style={[styles.title, { marginTop: 20, fontSize: 16 }]}>Posições</Text>
          {!station.positions.length ? <Text style={[styles.muted, { marginTop: 8 }]}>{demo ? 'Nenhuma posição aberta neste robô.' : 'Posições por robô: Não informado pelo MT5. O total acima pertence à conta, não a um Magic.'}</Text> : station.positions.map(p => <View key={p.id} style={styles.position}>
            <Text style={styles.title}>{p.side} · {p.symbol}</Text>
            <Text style={styles.muted}>Entrada {value(p.entry)} · Atual {value(p.current)}</Text>
            <Text style={styles.muted}>Stop {value(p.stop)} · Take {value(p.take)} · Lote {value(p.lot)}</Text>
            <Text style={{ color: p.pnl != null && p.pnl < 0 ? C.down : C.up }}>{money(p.pnl, station.currency, true)}</Text>
          </View>)}
          <Text style={[styles.muted, { marginTop: 20 }]}>Somente leitura. Nenhuma ordem pode ser enviada por esta tela.</Text>
        </ScrollView>
      </Card>
    </View>
  </Modal>;
}
const styles = StyleSheet.create({
  overlay: { flex: 1, backgroundColor: '#000B', alignItems: 'center', justifyContent: 'center', padding: 16 },
  panel: { width: '100%', maxWidth: 540, maxHeight: '90%', padding: 20, backgroundColor: C.surface },
  header: { flexDirection: 'row', gap: 12, alignItems: 'flex-start', marginBottom: 14 },
  close: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', backgroundColor: C.surface2, borderRadius: 10 },
  title: { color: C.ink, fontWeight: '700', fontSize: 19 }, muted: { color: C.soft, fontSize: 12, lineHeight: 19 },
  row: { flexDirection: 'row', gap: 16, justifyContent: 'space-between', paddingVertical: 10, borderBottomColor: C.line, borderBottomWidth: 1 },
  value: { color: C.ink, fontSize: 12, textAlign: 'right', flexShrink: 1 },
  position: { padding: 12, gap: 8, backgroundColor: C.surface2, borderRadius: 10, marginTop: 12 },
});
