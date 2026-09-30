type ArticleEvidence = { source?: string | null; sentiment_score?: number | null };
type DailyBar = { trade_date?: string | null; close?: number | null };
type EvidenceInput = {
  price_history?: DailyBar[];
  news_items?: ArticleEvidence[];
  sentiment_sample_count?: number;
  indicators?: Record<string, number | null>;
  fundamentals?: Record<string, number | null>;
};

/** Describe the returned sample, never the provider's claimed refresh interval. */
export function analysisEvidence(data: EvidenceInput) {
  const datedBars = (data.price_history ?? []).filter(b =>
    /^\d{4}-\d{2}-\d{2}$/.test(b.trade_date ?? '') && typeof b.close === 'number' && Number.isFinite(b.close));
  const latestDate = datedBars.reduce<string | null>((latest, bar) =>
    !latest || bar.trade_date! > latest ? bar.trade_date! : latest, null);
  // Compare only distinct session dates, never treat duplicate/invalid rows as intraday ticks.
  const sessions = new Map(datedBars.map(bar => [bar.trade_date!, bar.close!]));
  const dates = Array.from(sessions.keys()).sort();
  const last = dates.length >= 2 ? sessions.get(dates[dates.length - 1])! : null;
  const previous = dates.length >= 2 ? sessions.get(dates[dates.length - 2])! : null;
  const validPair = last != null && previous != null && last > 0 && previous > 0;
  const dailyChange = validPair ? last - previous : null;
  const articles = data.news_items ?? [];
  const measurable = articles.filter(a => typeof a.sentiment_score === 'number' && Number.isFinite(a.sentiment_score));
  const sources = new Set(articles.map(a => a.source?.trim()).filter(Boolean));
  const present = (record?: Record<string, number | null>) => Object.values(record ?? {})
    .filter(v => typeof v === 'number' && Number.isFinite(v)).length;
  return {
    priceDate: latestDate ? latestDate.split('-').reverse().join('/') : null,
    priceBars: dates.length,
    dailyChange,
    dailyChangePct: dailyChange == null ? null : (dailyChange / previous!) * 100,
    newsCount: articles.length,
    measuredNews: measurable.length,
    scoredNews: Number.isSafeInteger(data.sentiment_sample_count) && (data.sentiment_sample_count ?? -1) >= 0
      ? data.sentiment_sample_count! : null,
    newsSources: sources.size,
    technicalCount: present(data.indicators),
    fundamentalsCount: present(data.fundamentals),
  };
}
