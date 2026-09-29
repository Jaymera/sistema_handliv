import type { FloorAccount, FloorStation, FloorSummary } from './types';

export function money(value: number | null, currency: string, signed = false): string {
  if (value === null || !Number.isFinite(value)) return '—';
  const symbols: Record<string, string> = { USD: 'US$', BRL: 'R$', EUR: '€', GBP: '£' };
  const prefix = value < 0 ? '-' : signed ? '+' : '';
  const formatted = Math.abs(value).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return `${prefix}${symbols[currency] || currency} ${formatted}`;
}

export function chooseSource(accounts: FloorAccount[], requestedDemo: boolean): 'real' | 'demo' {
  return accounts.length === 0 && requestedDemo ? 'demo' : 'real';
}

export function accountSummary(account: FloorAccount | undefined, stations: FloorStation[]): FloorSummary {
  const stats = account?.stats;
  return {
    currency: stats?.currency || 'USD', balance: stats?.balance ?? null,
    equity: stats?.equity ?? null, profitDay: stats?.profit_day ?? null,
    floating: stats?.floating_pl ?? null, drawdown: stats?.dd_percent ?? null,
    openPositions: stats?.open_positions ?? null,
    online: stations.length ? stations.filter((station) => station.status !== 'OFFLINE').length : null,
    equityHistory: [],
  };
}

/** Naive server timestamps are UTC (the existing SQLAlchemy DateTime columns). */
export function timestamp(value: string | null): number {
  if (!value) return NaN;
  return Date.parse(/(?:Z|[+-]\d\d:\d\d)$/i.test(value) ? value : `${value}Z`);
}

export function accountsToStations(accounts: FloorAccount[], now = Date.now()): FloorStation[] {
  return accounts.map((account) => {
    const stats = account.stats;
    const age = now - timestamp(stats?.updated_at ?? null);
    const online = account.is_active && Number.isFinite(age) && age >= -60_000 && age <= 90_000;
    return {
      id: account.id, name: `HandlivPanel · ${account.account_number}`,
      scope: 'account', symbol: null, magic: null, timeframe: null,
      currency: stats?.currency || 'USD', updatedAt: stats?.updated_at ?? null,
      status: !online ? 'OFFLINE' : (stats?.open_positions ?? 0) > 0 ? 'POSIÇÃO ABERTA' : 'AGUARDANDO',
      profitDay: stats?.profit_day ?? null, profitWeek: stats?.profit_week ?? null,
      profitMonth: stats?.profit_month ?? null, trades: stats?.total_trades ?? null,
      wins: stats?.win_trades ?? null, losses: stats?.loss_trades ?? null,
      drawdown: stats?.dd_percent ?? null, openPositions: stats?.open_positions ?? null,
      // An account aggregate is not a list of positions, nor a robot heartbeat.
      positions: [],
    };
  });
}
