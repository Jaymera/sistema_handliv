export type FloorStatus = "OPERANDO" | "POSIÇÃO ABERTA" | "AGUARDANDO" | "OFFLINE";

export interface FloorPosition {
  id: string;
  side: "BUY" | "SELL";
  symbol: string;
  entry: number | null;
  current: number | null;
  stop: number | null;
  take: number | null;
  lot: number | null;
  pnl: number | null;
}

export interface FloorStation {
  id: string;
  name: string;
  symbol: string | null;
  currency: string;
  profitDay: number | null;
  status: FloorStatus;
  scope: "account" | "robot";
  accountId?: string;
  accountNumber?: string;
  updatedAt: string | null;
  magic: number | string | null;
  floatingPl?: number | null;
  profitTotal?: number | null;
  historyScope?: string | null;
  timeframe: string | null;
  profitWeek: number | null;
  profitMonth: number | null;
  trades: number | null;
  wins: number | null;
  losses: number | null;
  drawdown: number | null;
  positions: FloorPosition[];
  openPositions: number | null;
}

export interface FloorEvent {
  id: string;
  stationId: string;
  pnl: number;
  currency: string;
  at: number;
}

export interface FloorSummary {
  currency: string;
  balance: number | null;
  equity: number | null;
  profitDay: number | null;
  floating: number | null;
  drawdown: number | null;
  openPositions: number | null;
  online: number | null;
  equityHistory: number[];
}

export interface FloorSceneProps {
  stations: FloorStation[];
  summary: FloorSummary;
  events: FloorEvent[];
  selectedId: string | null;
  onSelect: (id: string) => void;
  command: { type: "in" | "out" | "fit"; seq: number };
  reducedMotion: boolean;
  demo: boolean;
}

/** Mirrors GET /mt5/stats, not a new backend contract. */
export interface FloorAccount {
  id: string;
  account_number: string;
  broker: string | null;
  is_active: boolean;
  robots?: {
    magic: string;
    symbol: string | null;
    open_positions: number;
    floating_pl: number;
    profit_total: number | null;
    total_trades: number | null;
    win_trades: number | null;
    loss_trades: number | null;
    history_scope: string | null;
    heartbeat: boolean;
    is_present: boolean;
    updated_at: string | null;
  }[];
  stats: {
    currency: string;
    balance: number;
    equity: number;
    floating_pl: number;
    dd_percent: number;
    profit_day: number;
    profit_week: number;
    profit_month: number;
    total_trades: number;
    win_trades: number;
    loss_trades: number;
    open_positions: number;
    updated_at: string | null;
  } | null;
}
