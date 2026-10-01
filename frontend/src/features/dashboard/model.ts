export type DashboardAsset = { symbol: string; name: string; market?: string };
export type Catalogue = { items: unknown[]; total: number };
export function dashboardOverview(watchlist?: { asset: DashboardAsset }[], catalogue?: Catalogue) {
  const counts = new Map<string, number>();
  for (const item of catalogue?.items ?? []) {
    const market = (item as DashboardAsset)?.market;
    if (typeof market === "string" && market.trim()) counts.set(market, (counts.get(market) ?? 0) + 1);
  }
  const markets = [...counts].map(([market, count]) => ({ market, count })).sort((a, b) => b.count - a.count || a.market.localeCompare(b.market));
  return {
    watchCount: watchlist?.length ?? null,
    catalogueTotal: catalogue?.total ?? null,
    loadedCount: catalogue?.items.length ?? null,
    marketCount: catalogue ? markets.length : null,
    markets,
  };
}
