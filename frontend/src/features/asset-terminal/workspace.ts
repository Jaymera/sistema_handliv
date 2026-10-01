// dailySessions adapts chartPointsToBars' finite-value / Map / sort pipeline.
// Copyright (c) 2026 OpenTerminalUI Contributors. MIT; see docs/asset-workspace-sources.md.
export type DailySession = { trade_date: string; close: number };
function validCalendarDate(date: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return false;
  const timestamp = Date.parse(`${date}T00:00:00Z`);
  return Number.isFinite(timestamp) && new Date(timestamp).toISOString().slice(0, 10) === date;
}
export function dailySessions(history: { trade_date?: string | null; close?: number | null }[] = []): DailySession[] {
  const byTime = new Map<string, DailySession>();
  for (const d of history) {
    const date = d.trade_date;
    const close = d.close;
    if (!date || !validCalendarDate(date) || typeof close !== 'number' || !Number.isFinite(close) || close <= 0) continue;
    byTime.set(date, { trade_date: date, close });
  }
  return Array.from(byTime.values()).sort((a, b) => a.trade_date.localeCompare(b.trade_date));
}

export type FactorRow = { label: string; available: boolean; state: string; detail: string };
const finite = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);
export function factorEvidence(data: { last_price?: number | null; indicators?: Record<string, number | null> }): FactorRow[] {
  const i = data.indicators ?? {};
  const pair = (label: string, a: unknown, b: unknown): FactorRow => {
    if (!finite(a) || !finite(b)) return { label, available: false, state: 'unavailable', detail: 'Par de valores indisponível' };
    return { label, available: true, state: a > b ? 'above' : a < b ? 'below' : 'equal', detail: `${a.toFixed(3)} / ${b.toFixed(3)}` };
  };
  const rsi = i.rsi;
  return [pair('Fechamento / EMA20', data.last_price, i.ema20), pair('EMA20 / EMA50', i.ema20, i.ema50),
    pair('MACD / sinal', i.macd, i.macd_signal),
    { label: 'RSI · 14', available: finite(rsi), state: !finite(rsi) ? 'unavailable' : rsi > 70 ? 'overbought' : rsi < 30 ? 'oversold' : 'in-range',
      detail: finite(rsi) ? `${rsi.toFixed(1)} · faixas 30 / 70` : 'Indicador indisponível' }];
}

export type ArticleSentiment = { sentiment_label?: string | null; sentiment_score?: number | null };
export function articleSentimentDisplay(article: ArticleSentiment) {
  const label: 'positive' | 'negative' | 'neutral' | null = article.sentiment_label === 'positive' || article.sentiment_label === 'negative' || article.sentiment_label === 'neutral'
    ? article.sentiment_label : null;
  const score = finite(article.sentiment_score) ? article.sentiment_score : null;
  return { label, score, text: `${label ?? 'Não classificado'} · ${score == null ? 'Pontuação indisponível' : score.toFixed(2)}` };
}

export function displayEvidence(data: {
  score?: { confidence?: number | null; subscores?: { sentiment?: number | null } };
  sentiment_sample_count?: number;
  news_items?: { published_at?: string | null }[];
}) {
  const confidence = data.score?.confidence;
  const sentiment = data.score?.subscores?.sentiment;
  const dates = (data.news_items ?? []).map(n => n.published_at)
    .filter((d): d is string => !!d && /^\d{4}-\d{2}-\d{2}(T|$)/.test(d) && Number.isFinite(Date.parse(d))
      && validCalendarDate(d.slice(0,10)))
    .sort((a, b) => Date.parse(b) - Date.parse(a));
  return {
    confidence: finite(confidence) && confidence >= 0 && confidence <= 100 ? confidence : null,
    sentiment: (data.sentiment_sample_count == null || (Number.isSafeInteger(data.sentiment_sample_count) && data.sentiment_sample_count > 0)) && finite(sentiment) ? sentiment : null,
    latestNewsDate: dates.length ? dates[0].slice(0,10).split('-').reverse().join('/') : null,
  };
}

export function windowEvidence(history: DailySession[], window: number) {
  const sessions = dailySessions(history).slice(-Math.max(1, window));
  const first = sessions[0], last = sessions[sessions.length - 1];
  const change = sessions.length > 1 ? last.close - first.close : null;
  return {
    sessions, count: sessions.length, firstDate: first?.trade_date ?? null, lastDate: last?.trade_date ?? null,
    change, changePct: change == null ? null : change / first.close * 100,
    minClose: sessions.length ? Math.min(...sessions.map(s => s.close)) : null,
    maxClose: sessions.length ? Math.max(...sessions.map(s => s.close)) : null,
  };
}
