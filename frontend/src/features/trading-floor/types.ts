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
  updatedAt: string | null;
  magic: number | null;
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
