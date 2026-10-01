import { useState } from 'react';
import { ActivityIndicator, Linking, Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { assetsApi, watchlistApi } from '@/api/client';
import { FavoriteStar, MarketBadge } from '@/components/ui';
import { Meter, PriceChart, T } from './visuals';
import { analysisEvidence } from './evidence';
import { dailySessions, displayEvidence, factorEvidence, windowEvidence } from './workspace';

type Analysis = Awaited<ReturnType<typeof assetsApi.liveAnalysis>>;
type Props = { data: Analysis; inWatchlist: boolean; onToggle: () => void; onBack: () => void; onRefresh: () => void; refreshing: boolean };
const TABS = ['Visão geral', 'Gráfico', 'Técnica', 'Fundamentos', 'Notícias', 'Evidências'] as const;
const finite = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);
const fmt = (value: unknown, digits = 2) => finite(value) ? value.toFixed(digits) : 'Indisponível';
const states: Record<string, string> = { above: 'Acima', below: 'Abaixo', equal: 'Iguais', unavailable: 'Indisponível', overbought: 'Sobrecomprado', oversold: 'Sobrevendido', 'in-range': 'Entre 30 e 70' };

function Panel({ title, children, wide = false }: { title: string; children: React.ReactNode; wide?: boolean }) {
  return <View style={[s.panel, wide && { flexBasis: '100%' }]}><Text style={s.kicker}>{title}</Text>{children}</View>;
}
function Metric({ label, value, note, color = T.ink }: { label: string; value: string; note?: string; color?: string }) {
  return <View style={s.metric}><Text style={[s.muted, { flex: 1 }]}>{label}</Text><View style={{ flex: 1, alignItems: 'flex-end' }}>
    <Text style={[s.value, { color }]}>{value}</Text>{note ? <Text style={s.dim}>{note}</Text> : null}</View></View>;
}

// Original Expo component: OpenTerminal ticker workspace interaction + OpenStock compact header hierarchy.
function AssetPicker({ symbol }: { symbol: string }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const { data, isFetching, isError } = useQuery({ queryKey: ['asset-picker', query.trim()],
    queryFn: () => assetsApi.list({ q: query.trim(), limit: 12 }), enabled: open && query.trim().length >= 2 });
  const { data: watchlist } = useQuery({ queryKey: ['watchlist'], queryFn: watchlistApi.list, enabled: open });
  const items = query.trim().length >= 2 ? (data?.items ?? []) as {symbol: string; name: string; market?: string}[]
    : (watchlist ?? []).map(w => w.asset);
  return <View style={s.picker}>
    <Pressable accessibilityRole="button" accessibilityLabel="Selecionar outro ativo" onPress={() => setOpen(!open)} style={s.button}>
      <Ionicons name="search" color={T.cyan} size={16} /><Text style={s.buttonText}>Trocar ativo · {symbol}</Text><Ionicons name={open ? 'chevron-up' : 'chevron-down'} size={14} color={T.muted} />
    </Pressable>
    {open ? <View style={s.pickerBody}>
      <TextInput accessibilityLabel="Buscar ticker ou empresa" value={query} onChangeText={setQuery} placeholder="Ticker ou empresa · mínimo 2 letras" placeholderTextColor={T.dim} style={s.input} autoCapitalize="none" />
      <Text style={s.dim}>{query.trim().length >= 2 ? 'RESULTADOS DO CATÁLOGO' : 'SUA WATCHLIST · OU BUSQUE NO CATÁLOGO'}</Text>
      {isFetching ? <ActivityIndicator color={T.cyan} /> : isError ? <Text style={s.muted}>Busca indisponível. Tente novamente.</Text> : items.length ? items.map(a =>
        <Pressable key={a.symbol} accessibilityRole="button" accessibilityLabel={`Analisar ${a.symbol}`} onPress={() => { setOpen(false); router.push(`/asset/${encodeURIComponent(a.symbol)}`); }} style={s.pickerRow}>
          <Text style={s.value}>{a.symbol}</Text><Text style={[s.muted, { flex: 1 }]} numberOfLines={1}>{a.name}</Text><Ionicons name="arrow-forward" size={15} color={T.cyan} />
        </Pressable>) : <Text style={s.muted}>{query.trim().length >= 2 ? 'Nenhum ativo encontrado.' : 'Busque um ativo para iniciar a análise.'}</Text>}
    </View> : null}
  </View>;
}

export function TerminalSkeleton({ symbol }: { symbol: string }) {
  return <View style={[s.root, { padding: 24, gap: 18 }]}><Text style={s.kicker}>HANDLIV / ASSET WORKSPACE</Text><Text style={s.title}>{symbol}</Text>
    <ActivityIndicator color={T.cyan} /><Text style={s.muted}>Consultando fontes e a análise existente…</Text>
    {[0, 1, 2].map(i => <View key={i} style={{ backgroundColor: T.track, height: 100, borderRadius: 12 }} />)}</View>;
}

export function AssetTerminal({ data, inWatchlist, onToggle, onBack, onRefresh, refreshing }: Props) {
  const { width } = useWindowDimensions();
  const [tab, setTab] = useState<typeof TABS[number]>('Visão geral');
  const [window, setWindow] = useState(30);
  const [newsFilter, setNewsFilter] = useState('Todas');
  const evidence = analysisEvidence({ ...data, price_history: dailySessions(data.price_history) });
  const display = displayEvidence(data);
  const selected = windowEvidence(data.price_history ?? [], window);
  const factors = factorEvidence(data);
  const score = data.score;
  const tint = data.recommendation_color === 'green' || data.recommendation_color === 'lime' ? T.green : data.recommendation_color === 'amber' ? T.amber : T.red;
  const money = (v: unknown) => finite(v) ? `${data.currency} ${v.toFixed(2)}` : 'Indisponível';
  const overview = tab === 'Visão geral';
  const showChart = overview || tab === 'Gráfico';
  const showTechnical = overview || tab === 'Técnica';
  const sources = Array.from(new Set((data.news_items ?? []).map(n => n.source?.trim()).filter(Boolean)));
  const news = (data.news_items ?? []).filter(n => newsFilter === 'Todas' || n.source?.trim() === newsFilter);
  const indicatorRows = [['RSI · 14','rsi'],['EMA · 20','ema20'],['EMA · 50','ema50'],['MACD','macd'],['MACD · sinal','macd_signal']];
  const fundamentals = [ {label:'P/L',key:'pe_ratio'}, {label:'P/VPA',key:'pb_ratio'}, {label:'Dividend yield',key:'dividend_yield',percent:true},
    {label:'ROE',key:'roe',percent:true}, {label:'Dívida / patrimônio',key:'debt_to_equity'}, {label:'Crescimento de receita',key:'revenue_growth',percent:true} ];
  return <ScrollView style={s.root} contentContainerStyle={[s.content, width < 640 && { paddingHorizontal: 12 }]}>
    <View style={s.shell}>
      <View style={s.toolbar}><Pressable onPress={onBack} accessibilityRole="button" style={s.button}><Ionicons name="arrow-back" size={16} color={T.muted} /><Text style={s.buttonText}>Voltar</Text></Pressable>
        <Text style={s.kicker}>HANDLIV / ASSET WORKSPACE</Text>
        <Pressable onPress={onRefresh} disabled={refreshing} accessibilityRole="button" accessibilityLabel="Atualizar análise" style={[s.button, refreshing && { opacity: 0.5 }]}>
          <Ionicons name="refresh" size={16} color={T.cyan} /><Text style={s.buttonText}>{refreshing ? 'Consultando…' : 'Atualizar análise'}</Text></Pressable>
      </View>
      <AssetPicker symbol={data.symbol} />
      <View style={[s.assetHeader, width < 640 && { flexDirection: 'column', alignItems: 'stretch' }]}>
        <View style={{ flex: 1, minWidth: 0, gap: 8 }}><View style={s.inline}><MarketBadge market={data.market} /><Text style={s.symbol}>{data.symbol}</Text><FavoriteStar active={inWatchlist} onPress={onToggle} size={24} /></View>
          <Text style={s.title}>{data.name}</Text><Text style={s.muted}>{[data.sector, data.industry].filter(Boolean).join(' / ') || 'Classificação setorial não informada'}</Text>
          <Text style={s.dim}>Análise sob demanda · sem streaming de cotações</Text>
        </View>
        <View style={{ gap: 7, flex: 1, minWidth: 0 }}><Text style={s.kicker}>ÚLTIMO FECHAMENTO DIÁRIO</Text><Text style={s.price}>{money(data.last_price)}</Text>
          <Text style={s.muted}>{evidence.priceDate ? `Pregão de ${evidence.priceDate}` : 'Data do fechamento indisponível'} · não é cotação em tempo real</Text>
          <Text style={[s.value, { textAlign: 'left', color: evidence.dailyChangePct == null ? T.muted : evidence.dailyChangePct >= 0 ? T.green : T.red }]}>
            {evidence.dailyChangePct == null ? 'Variação diária indisponível' : `${evidence.dailyChangePct >= 0 ? '+' : ''}${evidence.dailyChangePct.toFixed(2)}% · entre os 2 últimos fechamentos`}</Text>
        </View>
      </View>
      <View style={s.provenance}><Ionicons name="information-circle-outline" size={17} color={T.cyan} /><Text style={[s.dim, { flex: 1 }]}>Fonte: API Handliv / análise do ativo. Provedor não informado nesta resposta · atraso intradiário não informado · data de cálculo não informada.</Text></View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={s.tabScroll}><View style={s.inline}>{TABS.map(name =>
        <Pressable key={name} accessibilityRole="tab" accessibilityState={{ selected: tab === name }} accessibilityLabel={name} onPress={() => setTab(name)} style={[s.tab, tab === name && s.activeTab]}>
          <Text style={[s.tabText, tab === name && { color: T.cyan }]}>{name}</Text>{name === 'Notícias' ? <Text style={s.dim}>{evidence.newsCount}</Text> : null}</Pressable>)}</View></ScrollView>

      <View style={s.grid}>
        {overview ? <>
          <Panel title="SÍNTESE DO MOTOR EXISTENTE"><Text style={[s.signal, { color: tint }]}>{data.recommendation || 'Recomendação indisponível'}</Text>
            <Metric label="Score composto / 100" value={fmt(score.final_score, 1)} />
            {finite(score.final_score) ? <Meter value={score.final_score} color={tint} /> : null}
            <Metric label="Confiança do motor" value={display.confidence == null ? 'Indisponível' : `${display.confidence}%`} />
            <Text style={s.dim}>Confiança do motor, não probabilidade de lucro. Não é recomendação criada por esta interface.</Text>
            <Metric label="Tendência / horizonte" value={`${score.trend || 'Indisponível'} / ${score.horizon || 'Indisponível'}`} />
            <Metric label="Força compradora / vendedora" value={`${fmt(score.buyer_strength,1)} / ${fmt(score.seller_strength,1)}`} />
          </Panel>
          <Panel title="COMPONENTES E COBERTURA">{[
            {label:'Técnica',value:score.subscores.technical,color:T.cyan,note:`${evidence.technicalCount} indicadores disponíveis`},
            {label:'Valuation',value:score.subscores.valuation,color:T.green,note:`${evidence.fundamentalsCount} fundamentos disponíveis`},
            {label:'Sentimento',value:display.sentiment,color:T.amber,note:evidence.scoredNews == null ? 'Amostra pontuada não informada' : `${evidence.scoredNews} notícias pontuadas na análise`},
          ].map(r => <View key={r.label} style={{ gap: 7, marginBottom: 12 }}><Metric label={r.label} value={fmt(r.value,1)} note={r.note} color={r.color} />
            {finite(r.value) ? <Meter value={r.value} color={r.color} height={5} /> : <Text style={s.dim}>Sem amostra verificável para apresentar uma medição.</Text>}</View>)}
          </Panel>
        </> : null}

        {showChart ? <Panel title="HISTÓRICO · FECHAMENTOS OBSERVADOS" wide>
          <View style={[s.inline, { justifyContent: 'space-between' }]}><Text style={[s.muted, { flex: 1 }]}>Janela de observação</Text><View style={s.inline}>{[5,10,30].map(n =>
            <Pressable key={n} accessibilityRole="button" accessibilityState={{ selected: window === n }} accessibilityLabel={`${n} pregões`} onPress={() => setWindow(n)} style={[s.window, window === n && s.activeTab]}><Text style={s.tabText}>{n}D</Text></Pressable>)}</View></View>
          <PriceChart history={selected.sessions} currency={data.currency} />
          <View style={s.stats}>{[
            ['Variação na janela',selected.changePct == null ? 'Indisponível' : `${selected.changePct >= 0 ? '+' : ''}${selected.changePct.toFixed(2)}%`],
            ['Menor fechamento',money(selected.minClose)],['Maior fechamento',money(selected.maxClose)],['Amostra retornada',`${selected.count} pregões`],
          ].map(([label,value]) => <View key={label} style={s.stat}><Text style={s.dim}>{label}</Text><Text style={s.value}>{value}</Text></View>)}</View>
          <Text style={s.dim}>5D / 10D / 30D selecionam até esse número de pregões retornados, não dias corridos. Mínimo e máximo são fechamentos, não a faixa intradiária. Não recalcula RSI ou EMA do motor.</Text>
        </Panel> : null}

        {showTechnical ? <>
          <Panel title="LEITURA COMPARADA · EVIDÊNCIAS TÉCNICAS">{factors.map(row => <Metric key={row.label} label={row.label} value={states[row.state]} note={row.detail}
            color={!row.available ? T.dim : row.state === 'above' ? T.green : row.state === 'below' ? T.red : T.amber} />)}
            <Text style={s.dim}>Compara valores recebidos no mesmo retrato. Ordem entre EMAs não prova cruzamento; este exige séries de indicadores que a API não retorna. RSI não é sinal de compra/venda isolado.</Text>
          </Panel>
          <Panel title="MATRIZ DE INDICADORES · SEM ESTIMATIVAS">{indicatorRows.map(([label,key]) => <Metric key={key} label={label} value={fmt(data.indicators[key], key.startsWith('macd') ? 3 : 2)} />)}
            <Text style={s.dim}>Calculados pelo backend a partir do histórico diário. O gráfico contém somente a janela devolvida, não toda a base de cálculo.</Text>
          </Panel>
          {tab === 'Técnica' ? <Panel title="VOTOS E EXPLICAÇÃO DO MOTOR" wide><View style={s.stats}>{Object.entries(data.technical_votes ?? {}).filter(([,v]) => finite(v)).map(([name,vote]) =>
            <View key={name} style={s.stat}><Text style={s.dim}>{name}</Text><Text style={[s.value,{color:vote > 0 ? T.green : vote < 0 ? T.red : T.muted}]}>{vote > 0 ? '+' : ''}{vote}</Text></View>)}</View>
            {!Object.keys(data.technical_votes ?? {}).length ? <Text style={s.dim}>Votos indisponíveis.</Text> : null}<Text style={s.body}>{data.indicators_explanation || 'Explicação indisponível.'}</Text>
          </Panel> : null}
        </> : null}

        {tab === 'Fundamentos' ? <>
          <Panel title="FUNDAMENTOS RETORNADOS">{fundamentals.map(row => { const value = data.fundamentals[row.key]; return <Metric key={row.key} label={row.label}
            value={finite(value) ? `${fmt(row.percent ? value * 100 : value)}${row.percent ? '%' : ''}` : 'Indisponível'} />; })}
            <Text style={s.dim}>Não se aplica igualmente a todas as classes de ativos. Campos ausentes permanecem indisponíveis; não são convertidos em zero.</Text>
          </Panel><Panel title="LIMITES DE COMPARAÇÃO"><Text style={s.body}>Sem período fiscal, timestamp ou comparáveis fornecidos nesta resposta. Não é possível classificar o ativo como caro ou barato apenas por esses múltiplos.</Text>
            <Metric label="Campos disponíveis" value={String(evidence.fundamentalsCount)} /><Text style={s.dim}>Setor e moeda aparecem no cabeçalho. Não misture múltiplos de empresas com métricas de cripto, forex ou commodities.</Text></Panel>
        </> : null}

        {overview ? <Panel title="EXPLICAÇÃO DA ANÁLISE" wide><Text style={s.body}>{data.ai_explanation || 'Explicação indisponível.'}</Text><Text style={s.dim}>Texto da análise existente da plataforma; dados ausentes não foram estimados pela interface.</Text></Panel> : null}

        {tab === 'Notícias' ? <>
          <Panel title="COBERTURA EDITORIAL / SENTIMENTO" wide><Text style={s.body}>{data.news_summary || 'Resumo indisponível.'}</Text>
            <View style={s.stats}>{[['Notícias exibidas',evidence.newsCount],['Com pontuação exibida',evidence.measuredNews],['Fontes identificadas',evidence.newsSources],['Amostra do motor',evidence.scoredNews ?? 'Não informada']].map(([label,value]) =>
              <View key={label} style={s.stat}><Text style={s.dim}>{label}</Text><Text style={s.value}>{value}</Text></View>)}</View>
            <Text style={s.dim}>Última data de publicação retornada: {display.latestNewsDate ?? 'indisponível'}. Notícia sem pontuação não é sentimento neutro. A amostra do motor pode incluir artigos não exibidos.</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}><View style={s.inline}>{['Todas',...sources].map(source => <Pressable key={source} accessibilityRole="button" accessibilityState={{selected:newsFilter === source}} onPress={() => setNewsFilter(source)} style={[s.window,newsFilter === source && s.activeTab]}><Text style={s.tabText}>{source}</Text></Pressable>)}</View></ScrollView>
          </Panel>
          {news.length ? news.map((n,index) => <Panel key={`${n.url}-${index}`} title={n.source || 'FONTE NÃO INFORMADA'}><Text style={s.newsTitle}>{n.title}</Text>{n.summary ? <Text style={s.muted}>{n.summary}</Text> : null}
            <Metric label="Publicação" value={displayEvidence({news_items:[n]}).latestNewsDate ?? 'Indisponível'} />
            <Metric label="Sentimento do texto" value={finite(n.sentiment_score) ? `${n.sentiment_label || 'Pontuado'} · ${n.sentiment_score.toFixed(2)}` : 'Não pontuado'} />
            {/^(https?):\/\//i.test(n.url) ? <Pressable accessibilityRole="link" onPress={() => { void Linking.openURL(n.url); }} style={s.button}><Text style={[s.buttonText,{color:T.cyan}]}>Ler na fonte</Text><Ionicons name="open-outline" size={14} color={T.cyan} /></Pressable> : <Text style={s.dim}>Link indisponível.</Text>}
          </Panel>) : <Panel title="SEM ARTIGOS NESTA SELEÇÃO" wide><Text style={s.muted}>Nenhuma notícia retornada para este filtro. Não implica sentimento neutro.</Text></Panel>}
        </> : null}

        {tab === 'Evidências' ? <>
          <Panel title="TRILHA DE EVIDÊNCIAS / DADOS"><Metric label="Preço" value="Fechamento diário" note={evidence.priceDate ?? 'Sem data verificável'} />
            <Metric label="Histórico retornado" value={`${evidence.priceBars} pregões válidos`} />
            <Metric label="Indicadores disponíveis" value={`${evidence.technicalCount}`} />
            <Metric label="Fundamentos disponíveis" value={`${evidence.fundamentalsCount}`} />
            <Metric label="Amostra de sentimento" value={evidence.scoredNews == null ? 'Não informada' : `${evidence.scoredNews} pontuadas`} />
            <Metric label="Confiança do motor" value={display.confidence == null ? 'Indisponível' : `${display.confidence}%`} />
            <Text style={s.dim}>Confiança do motor, não probabilidade de lucro. Cobertura indica valores presentes, não qualidade garantida ou sucesso da estratégia.</Text>
          </Panel>
          <Panel title="O QUE ESTA RESPOSTA NÃO INFORMA"><Text style={s.body}>Provedor não informado · timestamp de cálculo não informado · atraso de cotação não informado · período fiscal não informado.</Text>
            <Text style={s.muted}>A atualização consulta novamente o backend; não comprova que o fornecedor tem uma observação nova. Não inferimos mercado aberto ou fechado a partir do relógio do dispositivo.</Text>
            <Text style={s.muted}>Comparações técnicas são relações entre valores, não detecção de eventos de cruzamento. Mudanças na janela do gráfico não alteram scores do backend.</Text>
            <Text style={s.dim}>Fonte contratual: /assets/{data.symbol}/live-analysis. Notícias têm fontes próprias exibidas em cada artigo.</Text>
          </Panel>
        </> : null}
      </View>
      <Text style={[s.dim,{marginTop:20}]}>HANDLIV · Decisões exigem contexto e gestão de risco. Este workspace não envia ordens.</Text>
    </View>
  </ScrollView>;
}

const s = StyleSheet.create({
  root:{flex:1,backgroundColor:T.bg}, content:{paddingHorizontal:24,paddingBottom:40,alignItems:'center'}, shell:{width:'100%',maxWidth:1376},
  toolbar:{flexDirection:'row',alignItems:'center',justifyContent:'space-between',flexWrap:'wrap',gap:12,paddingVertical:18,borderBottomWidth:1,borderColor:T.line},
  inline:{flexDirection:'row',alignItems:'center',gap:8,flexWrap:'wrap'}, button:{flexDirection:'row',gap:8,alignItems:'center',padding:10,borderRadius:7,borderWidth:1,borderColor:T.line}, buttonText:{color:T.ink,fontSize:12,fontWeight:'600'},
  picker:{marginTop:16}, pickerBody:{backgroundColor:T.panel,borderWidth:1,borderColor:T.line,borderRadius:10,padding:14,gap:12,marginTop:8}, input:{color:T.ink,fontSize:14,borderWidth:1,borderColor:T.line,borderRadius:7,padding:12}, pickerRow:{flexDirection:'row',gap:12,alignItems:'center',paddingVertical:9,borderBottomWidth:1,borderColor:T.line},
  assetHeader:{flexDirection:'row',alignItems:'center',gap:24,paddingVertical:24}, symbol:{color:T.cyan,fontFamily:'monospace',fontWeight:'700',fontSize:17}, title:{color:T.ink,fontSize:28,fontWeight:'800'}, price:{color:T.ink,fontFamily:'monospace',fontSize:32,fontWeight:'800'},
  kicker:{color:T.cyan,fontFamily:'monospace',fontSize:11,fontWeight:'700',letterSpacing:1.1}, muted:{color:T.muted,fontSize:13,lineHeight:20}, dim:{color:T.dim,fontSize:12,lineHeight:19}, value:{color:T.ink,fontFamily:'monospace',fontSize:14,fontWeight:'700',textAlign:'right'},
  provenance:{flexDirection:'row',gap:10,backgroundColor:T.panel,borderRadius:8,padding:12,borderWidth:1,borderColor:T.line}, tabScroll:{marginVertical:18,flexGrow:0}, tab:{flexDirection:'row',alignItems:'center',gap:8,paddingHorizontal:14,paddingVertical:12,borderBottomWidth:2,borderBottomColor:'transparent'}, activeTab:{backgroundColor:T.track,borderColor:T.cyan,borderBottomColor:T.cyan}, tabText:{color:T.muted,fontSize:13,fontWeight:'600'},
  grid:{flexDirection:'row',flexWrap:'wrap',gap:14,alignItems:'stretch'}, panel:{flexGrow:1,flexShrink:1,flexBasis:410,minWidth:0,borderWidth:1,borderColor:T.line,borderRadius:11,backgroundColor:T.panel,padding:18,gap:12},
  metric:{flexDirection:'row',justifyContent:'space-between',alignItems:'center',gap:12,paddingVertical:8,borderBottomWidth:1,borderColor:T.line}, signal:{fontSize:25,lineHeight:32,fontWeight:'800'}, body:{color:T.ink,fontSize:14,lineHeight:23}, newsTitle:{color:T.ink,fontWeight:'700',fontSize:18,lineHeight:25},
  window:{paddingHorizontal:12,paddingVertical:10,borderRadius:6,borderWidth:1,borderColor:T.line}, stats:{flexDirection:'row',flexWrap:'wrap',gap:10}, stat:{flexGrow:1,flexBasis:160,minWidth:0,padding:12,backgroundColor:T.bg,borderWidth:1,borderColor:T.line,borderRadius:7,gap:7},
});
