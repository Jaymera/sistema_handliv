import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router, Redirect } from "expo-router";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useAuthStore } from "@/state/authStore";
import { assetsApi, featuresApi, watchlistApi } from "@/api/client";
import { Badge, C, MarketBadge, PLAN_THEME, openUrl } from "@/components/ui";
import { dashboardOverview, DashboardAsset } from "./model";

// Original Expo implementation. Design references: OpenTerminal dashboard's 2:1
// workspace and OpenStock's search-first hierarchy / compact watchlist. No source,
// branded assets, widgets or quote data from either project are incorporated.
export default function DashboardScreen() {
  const { width } = useWindowDimensions();
  const desktop = width >= 1000;
  const compact = width < 600;
  const hydrated = useAuthStore(s => s.hydrated);
  const token = useAuthStore(s => s.accessToken);
  const user = useAuthStore(s => s.user);
  const enabled = hydrated && !!token;
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [query, setQuery] = useState("");
  useEffect(() => { const timer = setTimeout(() => setQuery(search.trim()), 250); return () => clearTimeout(timer); }, [search]);
  const watch = useQuery({ queryKey: ["watchlist"], queryFn: watchlistApi.list, enabled });
  const suggestions = useQuery({ queryKey: ["suggested"], queryFn: watchlistApi.suggested, enabled });
  const catalogue = useQuery({ queryKey: ["assets", { limit: 100 }], queryFn: () => assetsApi.list({ limit: 100 }), enabled });
  const results = useQuery({ queryKey: ["assets", { q: query, limit: 6 }], queryFn: () => assetsApi.list({ q: query, limit: 6 }), enabled: enabled && !!query });
  const features = useQuery({ queryKey: ["features"], queryFn: featuresApi.myFeatures, enabled });
  const toggle = useMutation({
    mutationFn: async ({ symbol, active }: { symbol: string; active: boolean }) => active ? watchlistApi.remove(symbol) : watchlistApi.add(symbol),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["watchlist"] }),
  });
  if (!hydrated) return null;
  if (!token) return <Redirect href="/auth/login" />;
  const overview = dashboardOverview(watch.data, catalogue.data);
  const watchSymbols = new Set(watch.data?.map(w => w.asset.symbol));
  const plan = features.data ? (PLAN_THEME[features.data.plan_code] ?? PLAN_THEME.free) : null;
  const openAsset = (symbol: string) => router.push(`/asset/${encodeURIComponent(symbol)}`);
  const row = (asset: DashboardAsset, favorite = true) => <View key={asset.symbol} style={s.assetRow}>
    <Pressable accessibilityRole="button" accessibilityLabel={`Analisar ${asset.symbol}`} onPress={() => openAsset(asset.symbol)} style={s.assetLink}>
      <View style={s.symbolTile}><Text style={s.symbolInitial}>{asset.symbol.slice(0, 2)}</Text></View>
      <View style={{ flex: 1, minWidth: 0 }}><View style={s.inline}><Text style={s.symbol}>{asset.symbol}</Text>{asset.market ? <MarketBadge market={asset.market} /> : null}</View><Text numberOfLines={1} style={s.small}>{asset.name}</Text></View>
      {!compact && <Text style={s.analysisLink}>Analisar ↗</Text>}
    </Pressable>
    {favorite && <Pressable accessibilityRole="button" accessibilityLabel={`${watchSymbols.has(asset.symbol) ? "Remover" : "Adicionar"} ${asset.symbol} ${watchSymbols.has(asset.symbol) ? "da" : "à"} watchlist`} disabled={toggle.isPending || !watch.data} onPress={() => toggle.mutate({symbol: asset.symbol, active: watchSymbols.has(asset.symbol)})} style={[s.star, {opacity: toggle.isPending || !watch.data ? 0.4 : 1}]}><Ionicons name={watchSymbols.has(asset.symbol) ? "star" : "star-outline"} color={watchSymbols.has(asset.symbol) ? C.amber : C.soft} size={19} /></Pressable>}
  </View>;
  return <ScrollView style={s.screen} contentContainerStyle={{padding: compact ? 16 : 28, paddingBottom: 40}} keyboardShouldPersistTaps="handled">
    <View testID="dashboard-workspace" style={s.container}>
      <View style={[s.header, {alignItems: compact ? "flex-start" : "center"}]}>
        <View style={{flex: 1}}><Text style={s.eyebrow}>HANDLIV / WORKSPACE</Text><Text accessibilityRole="header" style={s.greeting}>Olá, {user?.name?.split(" ")[0] || "Investidor"}.</Text><Text style={s.body}>Seu ponto de partida para decisões mais informadas.</Text></View>
        {plan ? <Badge text={plan.label} color={plan.color} /> : <Text style={s.small}>{features.isError ? "Plano indisponível" : "Carregando plano…"}</Text>}
      </View>
      <View style={[s.hero, {flexDirection: desktop ? "row" : "column"}]}>
        <View style={{flex: 1, gap: 14}}><Text style={[s.eyebrow,{color:C.brand}]}>PESQUISE. ANALISE. ACOMPANHE.</Text><Text style={[s.heroTitle,{fontSize:compact ? 29 : 36}]}>Encontre sua próxima\noportunidade.</Text><Text style={[s.body,{maxWidth:520}]}>Abra a análise de um ativo, organize sua watchlist e acompanhe seu ambiente de trading.</Text>
          <View style={s.search}><Ionicons name="search-outline" size={20} color={C.brand}/><TextInput accessibilityLabel="Buscar ativo por símbolo ou nome" placeholder="Buscar símbolo ou nome do ativo" placeholderTextColor={C.soft} value={search} onChangeText={setSearch} style={s.input} autoCapitalize="none" returnKeyType="search" onSubmitEditing={() => { if (query && search.trim() === query && results.data?.items.length === 1) openAsset((results.data.items[0] as DashboardAsset).symbol); }}/>{!!search && <Pressable accessibilityLabel="Limpar busca" onPress={() => setSearch("")} style={{padding:8}}><Ionicons name="close" size={18} color={C.soft}/></Pressable>}</View>
          {!!search.trim() && <View style={s.searchResults}>{search.trim() !== query || results.isLoading ? <Notice loading text="Buscando no catálogo…"/> : results.isError ? <Notice text="Não foi possível buscar ativos." retry={() => results.refetch()}/> : results.data?.items.length ? results.data.items.map(a => row(a as DashboardAsset, false)) : <Notice text="Nenhum ativo encontrado. Tente outro símbolo ou nome."/>}</View>}
        </View>
        <View style={[s.heroAside,{width:desktop ? 280 : undefined}]}><Ionicons name="layers-outline" size={30} color={C.brand}/><Text style={s.heroAsideTitle}>Da descoberta à análise</Text><Text style={s.small}>Catálogo e favoritos da sua conta. Preços e indicadores ficam na análise de cada ativo.</Text><Pressable accessibilityRole="button" style={s.primary} onPress={() => router.push("/(tabs)/markets")}><Text style={s.primaryText}>Explorar mercados</Text><Ionicons name="arrow-forward" size={18} color={C.deep}/></Pressable></View>
      </View>
      <View style={s.metrics}>
        {([{label:"SUA WATCHLIST",value:overview.watchCount,sub:"Ativos que você acompanha",color:C.amber},{label:"CATÁLOGO",value:overview.catalogueTotal,sub:"Total informado pela plataforma",color:C.brand},{label:"MERCADOS NA AMOSTRA",value:overview.marketCount,sub:overview.loadedCount === null ? "Aguardando catálogo" : `${overview.loadedCount} ativos carregados`,color:C.accent}]).map(metric => <View key={metric.label} style={[s.metric,{minWidth:compact ? 130 : 180}]}><Text style={s.eyebrow}>{metric.label}</Text><Text style={[s.metricValue,{color:metric.color}]}>{metric.value === null ? "—" : metric.value.toLocaleString("pt-BR")}</Text><Text style={s.small}>{metric.sub}</Text></View>)}
      </View>
      <View style={[s.workspace,{flexDirection:desktop ? "row" : "column"}]}>
        <View style={{flex:desktop ? 2 : undefined, minWidth:0, gap:20}}>
          <View style={s.panel}><Heading title="Minha watchlist" subtitle="Sua seleção, sempre à mão" icon="star-outline" detail={overview.watchCount === null ? "—" : `${overview.watchCount} ativos`}/>
            {watch.isError && <Notice text="Não foi possível atualizar sua watchlist." retry={() => watch.refetch()}/>}
            {watch.isLoading ? <Notice loading text="Carregando seus favoritos…"/> : watch.data?.length ? watch.data.map(w => row(w.asset)) : !watch.isError && <View style={s.empty}><Ionicons name="star-outline" color={C.amber} size={30}/><Text style={s.emptyTitle}>Comece sua seleção</Text><Text style={s.body}>Favorite um ativo sugerido ou explore o catálogo para criar sua watchlist.</Text><Pressable accessibilityRole="button" onPress={() => router.push("/(tabs)/markets")}><Text style={s.analysisLink}>Encontrar ativos →</Text></Pressable></View>}
            {toggle.isError && <Notice text="Não foi possível salvar a alteração. Tente novamente na estrela do ativo."/>}
          </View>
          <View style={s.panel}><Heading title="Descobrir ativos" subtitle="Sugestões do catálogo Handliv" icon="compass-outline"/>
            {suggestions.isError && <Notice text="Sugestões indisponíveis no momento." retry={() => suggestions.refetch()}/>}
            {suggestions.isLoading ? <Notice loading text="Carregando sugestões…"/> : suggestions.data?.length ? suggestions.data.slice(0,6).map(a => row(a)) : !suggestions.isError && <Notice text="Ainda não há sugestões disponíveis. Explore os mercados."/>}
            <Pressable accessibilityRole="button" style={s.panelFooter} onPress={() => router.push("/(tabs)/markets")}><Text style={s.analysisLink}>Ver catálogo completo</Text><Ionicons name="arrow-forward" color={C.brand} size={16}/></Pressable>
          </View>
        </View>
        <View style={{flex:desktop ? 1 : undefined, minWidth:0, gap:20}}>
          <View style={s.panel}><Heading title="Visão do catálogo" subtitle="Distribuição da amostra carregada" icon="pie-chart-outline"/>
            {catalogue.isError && <Notice text="Catálogo indisponível." retry={() => catalogue.refetch()}/>}
            {catalogue.isLoading ? <Notice loading text="Carregando mercados…"/> : overview.markets.length ? <View style={{padding:20,gap:16}}>{overview.markets.map((m,i) => <Pressable key={m.market} accessibilityRole="button" onPress={() => router.push("/(tabs)/markets")}><View style={[s.inline,{justifyContent:"space-between",marginBottom:8}]}><MarketBadge market={m.market}/><Text style={s.small}>{m.count} ativos</Text></View><View style={s.barTrack}><View style={{height:5,width:`${m.count / (overview.loadedCount || 1) * 100}%`,backgroundColor:[C.brand,C.accent,C.purple,C.amber][i % 4],borderRadius:3}}/></View></Pressable>)}<Text style={s.disclaimer}>Contagens do catálogo, não cotações nem desempenho. A amostra não representa todo o mercado.</Text></View> : !catalogue.isError && <Notice text="Nenhum mercado identificado na amostra."/>}
          </View>
          <Pressable accessibilityRole="button" style={s.floorCard} onPress={() => router.push("/(tabs)/trading-floor")}><View style={s.inline}><View style={s.floorIcon}><Ionicons name="business-outline" size={22} color={C.accent}/></View><Text style={s.eyebrow}>AMBIENTE OPERACIONAL</Text></View><Text style={s.heroAsideTitle}>Seu Trading Floor</Text><Text style={s.body}>Abra a visão do escritório para acompanhar suas estações e operações.</Text><View style={[s.inline,{justifyContent:"space-between",marginTop:8}]}><Text style={s.analysisLink}>Entrar no floor</Text><Ionicons name="arrow-forward" color={C.brand} size={19}/></View></Pressable>
          <View style={s.planCard}><Ionicons name="diamond-outline" size={22} color={plan?.color ?? C.soft}/><Text style={s.emptyTitle}>{plan ? `Plano ${plan.label}` : "Seu plano"}</Text><Text style={s.small}>Consulte os recursos e limites disponíveis para sua conta.</Text><Pressable accessibilityRole="button" onPress={() => openUrl("https://handliv.com")} style={{marginTop:8}}><Text style={s.analysisLink}>Conhecer planos ↗</Text></Pressable></View>
        </View>
      </View>
      <Text style={[s.disclaimer,{marginTop:24}]}>WORKSPACE HANDLIV · Dados da sua conta e do catálogo da plataforma. Acesse a análise para consultar fontes e indicadores; este resumo não é recomendação de investimento.</Text>
    </View>
  </ScrollView>;
}
function Heading({title,subtitle,icon,detail}:{title:string;subtitle:string;icon:React.ComponentProps<typeof Ionicons>["name"];detail?:string}) { return <View style={s.panelHeader}><View style={s.inline}><Ionicons name={icon} size={19} color={C.brand}/><View style={{flex:1}}><Text accessibilityRole="header" style={s.sectionTitle}>{title}</Text><Text style={s.small}>{subtitle}</Text></View></View>{detail && <Text style={s.small}>{detail}</Text>}</View>; }
function Notice({text,loading,retry}:{text:string;loading?:boolean;retry?:()=>void}) { return <View style={s.notice}>{loading && <ActivityIndicator color={C.brand}/>}<Text accessibilityRole="text" style={[s.small,{flex:1}]}>{text}</Text>{retry && <Pressable accessibilityRole="button" onPress={retry} style={{padding:8}}><Text style={s.analysisLink}>Tentar novamente</Text></Pressable>}</View>; }
const s = StyleSheet.create({
  screen:{flex:1,backgroundColor:C.bg},container:{width:"100%",maxWidth:1440,alignSelf:"center",gap:22},header:{flexDirection:"row",justifyContent:"space-between",gap:16},eyebrow:{fontSize:10,fontWeight:"700",letterSpacing:1.6,color:C.soft},greeting:{fontSize:27,fontWeight:"700",color:C.ink,marginTop:8,marginBottom:4},body:{fontSize:14,lineHeight:22,color:C.soft},small:{fontSize:12,lineHeight:18,color:C.soft},hero:{backgroundColor:"#0C2026",borderWidth:1,borderColor:"#20413F",borderRadius:20,padding:24,gap:28,overflow:"hidden"},heroTitle:{fontWeight:"700",letterSpacing:-1,color:C.ink,lineHeight:42},heroAside:{gap:14,padding:20,backgroundColor:"#102D30",borderRadius:14,justifyContent:"center"},heroAsideTitle:{color:C.ink,fontSize:20,fontWeight:"700"},primary:{backgroundColor:C.brand,padding:13,borderRadius:10,flexDirection:"row",alignItems:"center",justifyContent:"space-between",gap:12},primaryText:{color:C.deep,fontWeight:"700",fontSize:13},search:{flexDirection:"row",alignItems:"center",gap:12,backgroundColor:C.deep,borderWidth:1,borderColor:"#2B4B48",borderRadius:12,paddingLeft:16,minHeight:52},input:{flex:1,minWidth:0,color:C.ink,fontSize:14,paddingVertical:14},searchResults:{backgroundColor:C.deep,borderRadius:12,overflow:"hidden"},metrics:{flexDirection:"row",flexWrap:"wrap",gap:12},metric:{flex:1,padding:18,backgroundColor:C.surface,borderRadius:14,borderWidth:1,borderColor:C.line,gap:8},metricValue:{fontSize:30,fontWeight:"700",fontVariant:["tabular-nums"]},workspace:{gap:20,alignItems:"stretch"},panel:{backgroundColor:C.surface,borderWidth:1,borderColor:C.line,borderRadius:16,overflow:"hidden"},panelHeader:{padding:20,borderBottomWidth:1,borderBottomColor:C.line,gap:8},inline:{flexDirection:"row",alignItems:"center",gap:10},sectionTitle:{color:C.ink,fontSize:17,fontWeight:"700",marginBottom:3},assetRow:{flexDirection:"row",alignItems:"center",paddingHorizontal:16,borderBottomWidth:1,borderBottomColor:C.line,minHeight:74},assetLink:{flex:1,minWidth:0,flexDirection:"row",alignItems:"center",gap:12,paddingVertical:14},symbolTile:{height:38,width:38,backgroundColor:C.surface2,borderRadius:10,alignItems:"center",justifyContent:"center"},symbolInitial:{fontSize:12,fontWeight:"700",color:C.soft},symbol:{fontSize:14,fontWeight:"700",color:C.ink},analysisLink:{fontSize:12,color:C.brand,fontWeight:"600"},star:{padding:12,marginLeft:4},notice:{padding:20,flexDirection:"row",flexWrap:"wrap",alignItems:"center",gap:12},empty:{padding:28,alignItems:"flex-start",gap:12},emptyTitle:{color:C.ink,fontSize:16,fontWeight:"700"},panelFooter:{padding:17,flexDirection:"row",justifyContent:"space-between",alignItems:"center"},barTrack:{height:5,backgroundColor:C.surface2,borderRadius:3},disclaimer:{fontSize:11,lineHeight:18,color:C.soft},floorCard:{padding:22,backgroundColor:"#101F36",borderColor:"#263D60",borderWidth:1,borderRadius:16,gap:14},floorIcon:{padding:9,backgroundColor:"#1A3153",borderRadius:10},planCard:{padding:20,borderRadius:16,borderWidth:1,borderColor:C.line,gap:10},
});
