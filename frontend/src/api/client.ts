import Constants from "expo-constants";
import { Platform } from "react-native";

import { useAuthStore } from "@/state/authStore";
import type { AuthResponse, RegisterRequest, Credentials } from "@/types/auth";

function envOrDefault(key: string, fallback: string): string {
  const expoExtra = (Constants.expoConfig?.extra ?? {}) as Record<string, unknown>;
  return (expoExtra[key] as string) || fallback;
}

const API_BASE = envOrDefault("API_BASE_URL", Platform.select({
  web: typeof window !== "undefined" && window.location && window.location.hostname === "localhost" && window.location.port === "8081"
    ? "http://localhost:8000/api/v1"
    : "/api/v1",
  default: "http://localhost:8000/api/v1",
})) as string;

export class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

async function request<T>(path: string, init: RequestInit = {}, autoRefresh = true): Promise<T> {
  const accessToken = useAuthStore.getState().accessToken;
  if (accessToken) useAuthStore.getState().touchActivity();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...((init.headers as Record<string, string>) ?? {}),
  };
  if (accessToken) headers["Authorization"] = `Bearer ${accessToken}`;

  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  if (res.status === 401 && autoRefresh && accessToken) {
    try {
      await useAuthStore.getState().refresh();
    } catch {
      await useAuthStore.getState().logout();
      throw new ApiError("UNAUTHENTICATED", "sessão expirou", 401);
    }
    return request<T>(path, init, false);
  }
  if (!res.ok) {
    let code = "INTERNAL";
    let message = res.statusText;
    try {
      const data = await res.json();
      code = data?.error?.code ?? code;
      message = data?.error?.message ?? message;
    } catch {}
    throw new ApiError(code, message, res.status);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export const authApi = {
  login: (c: Credentials) =>
    request<AuthResponse>("/auth/login", { method: "POST", body: JSON.stringify(c) }, false),
  register: (body: RegisterRequest) =>
    request<AuthResponse>("/auth/register", { method: "POST", body: JSON.stringify(body) }, false),
  refresh: (refresh_token: string) =>
    request<AuthResponse>("/auth/refresh", { method: "POST", body: JSON.stringify({ refresh_token }) }, false),
  logout: (refresh_token: string) =>
    request<void>("/auth/logout", { method: "POST", body: JSON.stringify({ refresh_token }) }, false),
  forgot: (email: string) =>
    request<void>("/auth/password/forgot", { method: "POST", body: JSON.stringify({ email }) }, false),
  reset: (token: string, new_password: string) =>
    request<void>("/auth/password/reset", { method: "POST", body: JSON.stringify({ token, new_password }) }, false),
  me: () => request<{ id: string; name: string; email: string; role: string; plan: unknown }>("/auth/me"),
};

export const plansApi = {
  list: () => request<{ code: string; name: string; price_monthly_cents: number }[]>("/plans"),
};

export const assetsApi = {
  list: (params: { q?: string; market?: string; type?: string; page?: number; limit?: number }) => {
    const qp = new URLSearchParams();
    Object.entries(params).forEach(([k, v]) => {
      if (v !== undefined && v !== null) qp.set(k, String(v));
    });
    return request<{ items: unknown[]; total: number; page: number; limit: number }>(`/assets?${qp.toString()}`);
  },
  get: (symbol: string) => request<unknown>(`/assets/${encodeURIComponent(symbol)}`),
  score: (symbol: string) =>
    request<{
      final_score: number;
      ai_explanation: string;
      indicators_explanation: string;
      news_summary: string;
      subscores: { technical: number; valuation: number; sentiment: number };
    }>(`/assets/${encodeURIComponent(symbol)}/score`),
  liveAnalysis: (symbol: string) =>
    request<{
      symbol: string;
      name: string;
      market: string;
      currency: string;
      sector: string | null;
      industry: string | null;
      last_price: number | null;
      fundamentals: Record<string, number | null>;
      indicators: Record<string, number | null>;
      score: {
        final_score: number;
        buyer_strength: number;
        seller_strength: number;
        confidence: number;
        trend: string;
        horizon: string;
        subscores: { technical: number; valuation: number; sentiment: number };
      };
      recommendation: string;
      recommendation_color: string;
      ai_explanation: string;
      indicators_explanation: string;
      news_summary: string;
      news_items: {
        title: string;
        summary: string | null;
        url: string;
        source: string;
        published_at: string;
        sentiment_label: string | null;
        sentiment_score: number | null;
      }[];
      technical_votes: Record<string, number>;
      price_history: { trade_date: string; close: number }[];
    }>(`/assets/${encodeURIComponent(symbol)}/live-analysis`),
  news: (symbol: string) => request<{ items: unknown[] }>(`/assets/${encodeURIComponent(symbol)}/news`),
  price: (symbol: string, timeframe = "1d", period = "1mo") =>
    request<{ symbol: string; timeframe: string; bars: Record<string, unknown>[] }>(
      `/assets/${encodeURIComponent(symbol)}/price?timeframe=${timeframe}&period=${period}`,
    ),
};

export const watchlistApi = {
  list: () => request<{ asset: { symbol: string; name: string }; sort_order: number }[]>("/watchlist"),
  add: (symbol: string) => request<{ id: string; symbol: string }>(`/watchlist?symbol=${encodeURIComponent(symbol)}`, { method: "POST" }),
  remove: (symbol: string) => request<void>(`/watchlist/${encodeURIComponent(symbol)}`, { method: "DELETE" }),
  suggested: () => request<{ id: string; symbol: string; name: string; market: string }[]>("/watchlist/suggested"),
};

export const alertsApi = {
  list: () =>
    request<{ id: string; asset: { symbol: string }; type: string; threshold: number; is_triggered: boolean; is_active: boolean }[]>("/alerts"),
  create: (body: { symbol: string; type: string; threshold: number }) =>
    request<{ id: string }>("/alerts", { method: "POST", body: JSON.stringify(body) }),
  remove: (id: string) => request<void>(`/alerts/${id}`, { method: "DELETE" }),
};

export const backtestsApi = {
  enqueue: (body: { symbol: string; start_date: string; end_date: string; timeframe?: string }) =>
    request<{ id: string; status: string }>("/backtests", { method: "POST", body: JSON.stringify(body) }),
  list: () => request<{ items: unknown[] }>("/backtests"),
  get: (id: string) => request<unknown>(`/backtests/${id}`),
  remove: (id: string) => request<void>(`/backtests/${id}`, { method: "DELETE" }),
};

export const filesApi = {
  list: (category?: string) =>
    request<{
      items: {
        id: string;
        title: string;
        description?: string;
        version: string;
        category: string;
        size_bytes: number;
        min_plan: "free" | "pro" | "premium";
        created_at: string;
        allowed: boolean;
      }[];
    }>(`/files${category ? `?category=${category}` : ""}`),
  downloadUrl: (id: string) => request<{ url: string; expires_in: number }>(`/files/${id}/download-url`, { method: "POST" }),
};

export const adminApi = {
  users: () => request<{
    items: {
      id: string; name: string; email: string; is_active: boolean; role: string;
      plan_code: string; plan_name: string; subscription_status: string;
      created_at: string | null; last_login_at: string | null;
    }[];
  }>("/admin/users"),
  logs: () => request<{ items: unknown[] }>("/admin/logs"),
  weights: () => request<{ technical_weight: number; valuation_weight: number; sentiment_weight: number; min_confidence: number }>(
    "/admin/score-weights",
  ),
  updateWeights: (body: Record<string, unknown>) =>
    request<void>("/admin/score-weights", { method: "PUT", body: JSON.stringify(body) }),
  patchUser: (userId: string, body: { is_active?: boolean; plan_code?: string }) =>
    request<void>(`/admin/users/${userId}`, { method: "PATCH", body: JSON.stringify(body) }),
};

export const subscriptionsApi = {
  checkout: (planCode: string, interval?: string) =>
    request<{ checkout_url: string | null }>(`/subscriptions/checkout?plan_code=${planCode}&interval=${interval || "monthly"}`, { method: "POST" }),
  mySubscription: () =>
    request<{ plan: { code: string; name: string; limits: Record<string, unknown> }; status: string; current_period_end: string | null; cancel_at_period_end: boolean }>(
      "/subscriptions/me",
    ),
  cancel: () => request<void>("/subscriptions/me", { method: "DELETE" }),
  portal: () => request<{ portal_url: string }>("/subscriptions/portal", { method: "POST" }),
};

export const featuresApi = {
  myFeatures: () =>
    request<{
      plan_code: string;
      plan_status: string;
      payment_ok: boolean;
      features: {
        assets_analyzed_limit: number | null;
        assets_analyzed_used: number | null;
        mt5_accounts_used: number;
        mt5_accounts_max: number;
        robots_indicators: boolean;
        copy_trading: boolean;
        live_trading_room: boolean;
        course_discount: boolean;
        trading_panel: boolean;
        auto_robot: boolean;
      };
      links: { whatsapp: string; discord: string; cursos: string; copy_trading: string; robots_indicators: string; trading_panel: string; auto_robot: string };
    }>("/me/features"),
};

export const mt5Api = {
  list: () => request<{ items: { id: string; account_number: string; broker: string | null; is_active: boolean }[] }>("/mt5/accounts"),
  add: (accounts: string, broker?: string) =>
    request<{ created: string[]; count: number; max: number }>("/mt5/accounts", { method: "POST", body: JSON.stringify({ accounts, broker }) }),
  remove: (id: string) => request<void>(`/mt5/accounts/${id}`, { method: "DELETE" }),
};

export interface MT5Stats {
  login: string;
  currency: string;
  equity: number;
  balance: number;
  margin: number;
  margin_level: number;
  floating_pl: number;
  dd_percent: number;
  profit_day: number;
  profit_week: number;
  profit_month: number;
  profit_total: number;
  win_trades: number;
  loss_trades: number;
  total_trades: number;
  open_positions: number;
  updated_at: string | null;
}

export const statsApi = {
  list: () =>
    request<{ items: { id: string; account_number: string; broker: string | null; is_active: boolean; stats: MT5Stats | null }[] }>("/mt5/stats"),
};

export const ordersApi = {
  list: () =>
    request<{
      items: {
        id: string;
        account_number: string;
        action: "buy" | "sell" | "close";
        symbol: string | null;
        volume: number | null;
        status: "pending" | "sent" | "executed" | "failed";
        result_message: string | null;
        created_at: string | null;
        executed_at: string | null;
      }[];
    }>("/mt5/orders"),
  create: (body: { account_id?: string; account?: string; action: "buy" | "sell" | "close"; symbol?: string; volume?: number }) =>
    request<{ id: string; status: string }>("/mt5/orders", { method: "POST", body: JSON.stringify(body) }),
};

export const tradesApi = {
  list: () => request<{ items: { id: string; asset_symbol: string; result_pct: number; note: string | null; created_at: string | null }[] }>("/trades"),
  add: (body: { asset_symbol: string; result_pct: number; note?: string }) =>
    request<{ id: string; status: string }>("/trades", { method: "POST", body: JSON.stringify(body) }),
  remove: (id: string) => request<void>(`/trades/${id}`, { method: "DELETE" }),
};