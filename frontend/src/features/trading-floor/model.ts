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
    online: stations.length ? stations.filter((station) => account?.id != null && station.accountId === account.id && station.status !== 'OFFLINE').length : null,
    equityHistory: [],
  };
}

/** Naive server timestamps are UTC (the existing SQLAlchemy DateTime columns). */
export function timestamp(value: string | null): number {
  if (!value) return NaN;
  return Date.parse(/(?:Z|[+-]\d\d:\d\d)$/i.test(value) ? value : `${value}Z`);
}

/** Compare server-written telemetry against the server clock, not a skewed browser clock.
 * Elapsed local time still expires a snapshot when polling pauses. */
export function snapshotNow(serverTime: string | null | undefined, receivedAt: number, localNow: number): number {
  const server = serverTime ? Date.parse(serverTime) : NaN;
  return Number.isFinite(server) && receivedAt > 0
    ? server + Math.max(0, localNow - receivedAt) : localNow;
}

export function accountsToStations(accounts: FloorAccount[], now = Date.now()): FloorStation[] {
  return accounts.flatMap((account) => {
    const stats = account.stats;
    return (account.robots ?? []).filter(robot => /^\d+$/.test(String(robot.magic)) && String(robot.magic) !== '0').map(robot => {
      const age = now - timestamp(robot.updated_at ?? null);
      const fresh = account.is_active && robot.is_present && Number.isFinite(age) && age >= -60_000 && age <= 90_000;
      return {
        id: `${account.id}:magic:${robot.magic}`, name: `Magic ${robot.magic}`,
        accountId: account.id, accountNumber: account.account_number,
        scope: 'robot' as const, symbol: robot.symbol ?? null, magic: robot.magic, timeframe: null,
        currency: stats?.currency || 'USD', updatedAt: robot.updated_at ?? null,
        status: (!fresh ? 'OFFLINE' : robot.open_positions > 0 ? 'POSIÇÃO ABERTA' : robot.heartbeat ? 'AGUARDANDO' : 'OFFLINE') as FloorStation['status'],
        // The API does not report period P/L or drawdown per Magic; never borrow account totals.
        profitDay: null, profitWeek: null, profitMonth: null,
        profitTotal: robot.profit_total ?? null, floatingPl: robot.floating_pl ?? null,
        trades: robot.total_trades ?? null, wins: robot.win_trades ?? null, losses: robot.loss_trades ?? null,
        historyScope: robot.history_scope ?? null, drawdown: null,
        openPositions: robot.open_positions ?? null, positions: [],
      };
    });
  });
}
