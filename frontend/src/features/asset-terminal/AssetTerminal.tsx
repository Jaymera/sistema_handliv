import { useEffect, useRef, useState } from 'react';
import { Animated, Linking, Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import { Ionicons } from '@expo/vector-icons';
import type { assetsApi } from '@/api/client';
import { FavoriteStar, MarketBadge } from '@/components/ui';
import { CountUp, Meter, PriceChart, Pulse, T } from './visuals';

type Analysis = Awaited<ReturnType<typeof assetsApi.liveAnalysis>>;
type Props = { data: Analysis; inWatchlist: boolean; onToggle: () => void; onBack: () => void; onRefresh: () => void; refreshing: boolean };
const mono = 'monospace';

function Panel({ title, children, width, accent }: { title: string; children: React.ReactNode; width?: number; accent?: string }) {
  return <View style={[styles.panel, width ? { width } : { flex: 1 }, accent ? { borderTopColor: accent, borderTopWidth: 2 } : null]}>
    <View style={styles.panelHead}><View style={[styles.headMark, { backgroundColor: accent ?? T.cyan }]} /><Text style={styles.panelTitle}>{title}</Text></View>
    {children}
  </View>;
}
function RowMetric({ label, value, color = T.ink, note }: { label: string; value: string; color?: string; note?: string }) {
  return <View style={styles.metricRow}><Text style={styles.muted}>{label}</Text><View style={{ alignItems: 'flex-end', maxWidth: '65%' }}>
    <Text style={[styles.metricValue, { color }]}>{value}</Text>{note ? <Text style={styles.dim}>{note}</Text> : null}</View></View>;
}
function SkeletonBlock({ width, height }: { width: string; height: number }) {
  return <View style={{ width: width as any, height, backgroundColor: T.track, borderRadius: 4, opacity: 0.7 }} />;
}
export function TerminalSkeleton({ symbol }: { symbol: string }) {
  const { width } = useWindowDimensions();
  return <ScrollView style={styles.root} contentContainerStyle={styles.content}>
    <View style={styles.shell}><Text style={styles.eyebrow}>HANDLIV / QUANT ANALYTICS</Text>
      <Text style={styles.title}>Processando {symbol}</Text>
      <Text style={styles.muted}>Consultando a análise existente do ativo...</Text>
      <View style={[styles.grid, { marginTop: 22 }]}>
        {[0, 1, 2, 3, 4, 5].map((key) => <View key={key} style={[styles.panel, { width: width >= 900 ? '32%' : '100%', minHeight: key === 1 ? 180 : 115, gap: 15 }]}>
          <SkeletonBlock width="38%" height={10} /><SkeletonBlock width="75%" height={18} /><SkeletonBlock width="57%" height={8} />
        </View>)}
      </View>
    </View>
  </ScrollView>;
}

export function AssetTerminal({ data, inWatchlist, onToggle, onBack, onRefresh, refreshing }: Props) {
  const { width: screen } = useWindowDimensions();
  const desktop = screen >= 980;
  const tablet = screen >= 640;
  const usable = Math.min(screen - (tablet ? 44 : 24), 1376);
  const gap = 10;
  const third = (usable - gap * 2) / 3;
  const half = (usable - gap) / 2;
  const quarter = (usable - gap * 3) / 4;
  const full = usable;
  const score = data.score;
  const ind = data.indicators;
  const fund = data.fundamentals;
  const color = data.recommendation_color === 'green' || data.recommendation_color === 'lime' ? T.green
    : data.recommendation_color === 'amber' ? T.amber : T.red;
  const priceFlash = useRef(new Animated.Value(0));
  const [flashColor, setFlashColor] = useState(T.green);
  const previousPrice = useRef<number | null>(null);
  useEffect(() => {
    if (data.last_price == null) return;
    if (previousPrice.current != null && previousPrice.current !== data.last_price) {
      setFlashColor(data.last_price > previousPrice.current ? T.green : T.red);
      priceFlash.current.setValue(0.28);
      Animated.timing(priceFlash.current, { toValue: 0, duration: 700, useNativeDriver: true }).start();
    }
    previousPrice.current = data.last_price;
  }, [data.last_price]);
  const money = (n: number) => `${data.currency} ${n.toFixed(2)}`;
  const trendColor = /up|bull|alta/i.test(score.trend) ? T.green : /down|bear|baixa/i.test(score.trend) ? T.red : T.amber;
  const scoreColor = score.final_score >= 55 ? T.green : score.final_score < 45 ? T.red : T.amber;
  const indicatorRows = [
    { label: 'RSI · 14', value: ind.rsi, digits: 1, note: ind.rsi == null ? undefined : ind.rsi < 30 ? 'sobrevendido' : ind.rsi > 70 ? 'sobrecomprado' : 'neutro' },
    { label: 'EMA · 20', value: ind.ema20, digits: 2 },
    { label: 'EMA · 50', value: ind.ema50, digits: 2, note: ind.ema20 != null && ind.ema50 != null ? ind.ema20 > ind.ema50 ? 'cruzamento alcista' : 'cruzamento baixista' : undefined },
    { label: 'MACD', value: ind.macd, digits: 3 },
    { label: 'MACD · sinal', value: ind.macd_signal, digits: 3 },
  ];
  const fundamentals = [
    { label: 'P/L', value: fund.pe_ratio, digits: 2 },
    { label: 'P/VPA', value: fund.pb_ratio, digits: 2 },
    { label: 'Dividend Yield', value: fund.dividend_yield, digits: 2, percent: true },
    { label: 'ROE', value: fund.roe, digits: 1, percent: true },
    { label: 'Dívida / Patrimônio', value: fund.debt_to_equity, digits: 2 },
    { label: 'Cresc. receita', value: fund.revenue_growth, digits: 1, percent: true },
  ];
  return <ScrollView style={styles.root} contentContainerStyle={[styles.content, { paddingHorizontal: tablet ? 22 : 12 }]}>
    <View style={[styles.shell, { width: usable }]}>
      <View style={styles.topline}><View style={styles.inline}><View style={styles.brandMark}><Text style={styles.brandLetter}>H</Text></View>
        <View><Text style={styles.eyebrow}>HANDLIV  /  QUANT ANALYTICS</Text><Text style={styles.muted}>TERMINAL DE ANÁLISE · DADOS DA PLATAFORMA</Text></View></View>
        <View style={styles.inline}><Pulse /><Text style={[styles.eyebrow, { color: T.green }]}>ANÁLISE ATIVA</Text>
          <Pressable accessibilityRole="button" accessibilityLabel="Atualizar análise" onPress={onRefresh} disabled={refreshing} style={styles.iconButton}>
            <Ionicons name="refresh" color={T.cyan} size={17} /></Pressable></View>
      </View>
      <View style={[styles.assetHead, !tablet && { alignItems: 'flex-start' }]}>
        <View style={{ flex: 1 }}><View style={styles.inline}><MarketBadge market={data.market} /><Text style={styles.eyebrow}>{data.symbol}</Text></View>
          <Text style={styles.title}>{data.name}</Text>
          <Text style={styles.muted}>{[data.sector, data.industry].filter(Boolean).join('  /  ') || 'Setor não informado'}</Text></View>
        <View style={{ alignItems: tablet ? 'flex-end' : 'flex-start', gap: 5 }}>
          <View style={styles.inline}><Text style={styles.eyebrow}>ÚLTIMO PREÇO</Text><FavoriteStar active={inWatchlist} onPress={onToggle} size={24} /></View>
          <View><Text style={styles.price}>{data.last_price == null ? '—' : money(data.last_price)}</Text>
            <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: flashColor, opacity: priceFlash.current }]} /></View>
          {data.last_price != null && ind.ema20 != null ? <Text style={[styles.muted, { color: data.last_price > ind.ema20 ? T.green : T.red }]}>
            {data.last_price > ind.ema20 ? '▲ Acima EMA20' : '▼ Abaixo EMA20'}</Text> : null}
        </View>
      </View>

      <View style={styles.grid}>
        <Panel title="COMPOSITE SCORE" width={desktop ? quarter : tablet ? half : full} accent={scoreColor}>
          <View style={styles.scoreCenter}><Svg width={142} height={142} viewBox="0 0 142 142">
            <Circle cx="71" cy="71" r="57" stroke={T.track} strokeWidth="9" fill="none" />
            <Circle cx="71" cy="71" r="57" stroke={scoreColor} strokeWidth="9" fill="none"
              strokeDasharray={`${Math.max(0, Math.min(100, score.final_score)) * 3.58} 358`} strokeLinecap="round" rotation={-90} origin="71,71" />
          </Svg><View style={styles.scoreText}><CountUp value={score.final_score} color={scoreColor} /><Text style={styles.dim}>/ 100</Text></View></View>
          <Meter value={score.final_score} color={scoreColor} /><View style={styles.metricRow}><Text style={styles.muted}>Confiança da análise</Text><Text style={styles.metricValue}>{score.confidence}%</Text></View>
        </Panel>
        <Panel title="PRICE HISTORY / 1D" width={desktop ? half : tablet ? half : full} accent={T.cyan}>
          <PriceChart history={data.price_history ?? []} currency={data.currency} />
        </Panel>
        <Panel title="SIGNAL ENGINE" width={desktop ? quarter : full} accent={color}>
          <Text style={[styles.signal, { color }]}>{data.recommendation}</Text>
          <Text style={styles.eyebrow}>RECOMENDAÇÃO DA ANÁLISE</Text>
          <View style={styles.divider} />
          <RowMetric label="Tendência" value={score.trend} color={trendColor} />
          <RowMetric label="Horizonte" value={score.horizon} />
          <RowMetric label="Confiança" value={`${score.confidence}%`} color={T.cyan} />
          <Text style={styles.dim}>Sinal obtido da análise existente; não é cotação em streaming.</Text>
        </Panel>

        <Panel title="FORÇA COMPRADORA" width={desktop ? quarter : tablet ? half : full} accent={T.green}>
          <Text style={[styles.big, { color: T.green }]}>{score.buyer_strength}</Text><Meter value={score.buyer_strength} color={T.green} />
        </Panel>
        <Panel title="FORÇA VENDEDORA" width={desktop ? quarter : tablet ? half : full} accent={T.red}>
          <Text style={[styles.big, { color: T.red }]}>{score.seller_strength}</Text><Meter value={score.seller_strength} color={T.red} />
        </Panel>
        <Panel title="TENDÊNCIA / HORIZONTE" width={desktop ? quarter : tablet ? half : full} accent={trendColor}>
          <Text style={[styles.big, { color: trendColor, fontSize: 20 }]}>{score.trend}</Text><Text style={styles.muted}>{score.horizon}</Text>
        </Panel>
        <Panel title="RSI · 14" width={desktop ? quarter : tablet ? half : full} accent={T.amber}>
          <Text style={[styles.big, { color: T.amber }]}>{ind.rsi == null ? '—' : ind.rsi.toFixed(1)}</Text>
          {ind.rsi != null ? <Meter value={ind.rsi} color={T.amber} /> : null}
          <Text style={styles.dim}>{ind.rsi == null ? 'Dado indisponível' : ind.rsi < 30 ? 'Sobrevendido' : ind.rsi > 70 ? 'Sobrecomprado' : 'Neutro'}</Text>
        </Panel>

        <Panel title="SCORE DE COMPONENTES" width={desktop ? half : full} accent={T.cyan}>
          {[{ label: 'TÉCNICA', value: score.subscores.technical, tint: T.cyan },
            { label: 'VALUATION', value: score.subscores.valuation, tint: T.green },
            { label: 'SENTIMENTO', value: score.subscores.sentiment, tint: T.amber }].map(item =>
            <View key={item.label} style={styles.barRow}><View style={styles.metricRow}><Text style={styles.eyebrow}>{item.label}</Text><Text style={[styles.metricValue, { color: item.tint }]}>{item.value}</Text></View>
              <Meter value={item.value} color={item.tint} height={6} /></View>)}
        </Panel>
        <Panel title="INDICATOR MATRIX · VALORES REAIS" width={desktop ? half : full} accent={T.green}>
          {indicatorRows.map(row => row.value != null ? <RowMetric key={row.label} label={row.label} value={row.value.toFixed(row.digits)} note={row.note} /> : null)}
          {ind.rsi == null && ind.ema20 == null && ind.macd == null ? <Text style={styles.dim}>Indisponível (dados insuficientes).</Text> : null}
        </Panel>
        {Object.keys(data.technical_votes ?? {}).length > 0 ? <Panel title="VOTOS DOS INDICADORES" width={full} accent={T.amber}>
          <View style={styles.voteGrid}>{Object.entries(data.technical_votes).map(([name, vote]) => <View key={name} style={styles.vote}>
            <Text style={styles.eyebrow}>{name}</Text><Text style={[styles.metricValue, { color: vote > 0 ? T.green : vote < 0 ? T.red : T.muted }]}>
              {vote > 0 ? '▲' : vote < 0 ? '▼' : '—'}  {vote}</Text></View>)}</View>
        </Panel> : null}
        <Panel title="FUNDAMENTOS" width={desktop ? half : full} accent={T.amber}>
          {fundamentals.map(row => row.value != null ? <RowMetric key={row.label} label={row.label}
            value={`${(row.percent ? row.value * 100 : row.value).toFixed(row.digits)}${row.percent ? '%' : ''}`} /> : null)}
          {fund.pe_ratio == null && fund.roe == null ? <Text style={styles.dim}>Dados indisponíveis.</Text> : null}
        </Panel>
        <Panel title="HANDLIV MARKET ANALYSIS" width={desktop ? half : full} accent={T.cyan}>
          <Text style={styles.body}>{data.ai_explanation}</Text>
          <View style={styles.divider} /><Text style={styles.eyebrow}>LEITURA DOS INDICADORES</Text>
          <Text style={[styles.body, { color: T.muted }]}>{data.indicators_explanation}</Text>
        </Panel>
        <Panel title="NOTÍCIAS E SENTIMENTO" width={full} accent={T.green}>
          <Text style={styles.body}>{data.news_summary}</Text>
          {(data.news_items ?? []).length ? <View style={[styles.grid, { marginTop: 12 }]}>{data.news_items.map((n, i) =>
            <Pressable key={`${n.url}-${i}`} onPress={() => { if (n.url) void Linking.openURL(n.url); }} accessibilityRole="link"
              style={[styles.news, { width: desktop ? third - 12 : tablet ? half - 12 : full - 24 }]}>
              <View style={styles.metricRow}><Text style={styles.eyebrow}>{n.source}</Text>
                <Text style={[styles.eyebrow, { color: n.sentiment_label === 'positive' ? T.green : n.sentiment_label === 'negative' ? T.red : T.amber }]}>
                  {n.sentiment_label ?? 'NEUTRO'}</Text></View>
              <Text style={styles.newsTitle}>{n.title}</Text>
              {n.summary ? <Text style={styles.muted}>{n.summary}</Text> : null}
              <View style={styles.metricRow}><Text style={styles.dim}>{n.published_at ? new Date(n.published_at).toLocaleDateString('pt-BR') : 'Data indisponível'}</Text>
                {n.sentiment_score != null ? <Text style={styles.dim}>Sentimento: {n.sentiment_score.toFixed(2)}</Text> : null}</View>
            </Pressable>)}</View> : <Text style={styles.dim}>Sem notícias disponíveis.</Text>}
        </Panel>
      </View>
      <View style={styles.footer}><Pressable onPress={onToggle} style={styles.action}><Ionicons name={inWatchlist ? 'star' : 'star-outline'} size={16} color={T.amber} /><Text style={styles.actionText}>{inWatchlist ? 'Na watchlist' : 'Favoritar'}</Text></Pressable>
        <Pressable onPress={onBack} style={styles.action}><Text style={styles.actionText}>← Voltar</Text></Pressable></View>
    </View>
  </ScrollView>;
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: T.bg }, content: { paddingBottom: 48, alignItems: 'center' }, shell: { maxWidth: 1376 },
  topline: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12, paddingTop: 19, paddingBottom: 14, borderBottomWidth: 1, borderBottomColor: T.line },
  inline: { flexDirection: 'row', alignItems: 'center', gap: 9 }, brandMark: { width: 31, height: 31, backgroundColor: T.green, alignItems: 'center', justifyContent: 'center', borderRadius: 4 }, brandLetter: { fontSize: 21, fontWeight: '900', color: T.bg },
  eyebrow: { fontSize: 10, fontWeight: '800', letterSpacing: 1.25, color: T.cyan, fontFamily: mono }, muted: { fontSize: 12, lineHeight: 19, color: T.muted }, dim: { fontSize: 11, lineHeight: 17, color: T.dim },
  iconButton: { borderWidth: 1, borderColor: T.line, padding: 7, borderRadius: 4, marginLeft: 6 },
  assetHead: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', alignItems: 'center', gap: 15, paddingVertical: 22 }, title: { fontSize: 29, fontWeight: '800', color: T.ink, marginVertical: 5 }, price: { fontSize: 27, fontWeight: '800', color: T.ink, fontFamily: mono },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 }, panel: { borderWidth: 1, borderColor: T.line, backgroundColor: T.panel, borderRadius: 5, padding: 15, minWidth: 0, overflow: 'hidden' }, panelHead: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 15 }, headMark: { width: 4, height: 12, borderRadius: 2 }, panelTitle: { fontSize: 10, fontWeight: '800', letterSpacing: 1.3, color: T.muted, fontFamily: mono },
  scoreCenter: { alignItems: 'center', justifyContent: 'center', height: 150 }, scoreText: { position: 'absolute', alignItems: 'center' },
  metricRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8, paddingVertical: 7 }, metricValue: { fontSize: 14, fontWeight: '700', fontFamily: mono, color: T.ink, textAlign: 'right' },
  signal: { fontSize: 24, fontWeight: '900', lineHeight: 30, marginVertical: 10 }, divider: { height: 1, backgroundColor: T.line, marginVertical: 12 }, big: { fontSize: 28, fontWeight: '800', fontFamily: mono, marginBottom: 9 }, barRow: { marginBottom: 9 },
  voteGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 }, vote: { minWidth: 115, flexGrow: 1, padding: 10, gap: 9, borderWidth: 1, borderColor: T.line, backgroundColor: T.bg, borderRadius: 4 },
  body: { color: T.ink, fontSize: 13, lineHeight: 21 }, news: { borderWidth: 1, borderColor: T.line, backgroundColor: T.bg, borderRadius: 4, padding: 12, gap: 6 }, newsTitle: { color: T.ink, fontSize: 14, lineHeight: 19, fontWeight: '700' },
  footer: { flexDirection: 'row', gap: 10, marginTop: 14 }, action: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7, borderWidth: 1, borderColor: T.line, borderRadius: 4, paddingVertical: 12, paddingHorizontal: 18 }, actionText: { color: T.ink, fontWeight: '700', fontSize: 12 },
});
