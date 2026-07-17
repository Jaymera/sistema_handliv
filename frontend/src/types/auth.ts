export interface Credentials {
  email: string;
  password: string;
}

export interface AuthResponse {
  user: {
    id: string;
    name: string;
    email: string;
    phone?: string | null;
    role: "user" | "super_admin";
    locale: string;
    theme: string;
    force_password_change: boolean;
    plan?: { code: string; name: string; limits: Record<string, unknown> } | null;
  };
  access_token: string;
  refresh_token: string;
}

export interface RegisterRequest {
  name: string;
  email: string;
  phone?: string;
  password: string;
}

export interface PasswordForgotRequest {
  email: string;
}

export interface PasswordResetRequest {
  token: string;
  new_password: string;
}

export interface AssetListItem {
  id: string;
  symbol: string;
  display_symbol: string;
  name: string;
  market: string;
  asset_type: string;
  currency: string;
  logo_url?: string | null;
}

export interface ScoreResponse {
  final_score: number | null;
  buyer_strength: number;
  seller_strength: number;
  confidence: number;
  trend: "up" | "down" | "sideways" | null;
  horizon: "short" | "medium" | "long" | null;
  subscores: { technical: number; valuation: number; sentiment: number };
  ai_explanation: string;
  indicators_explanation: string;
  news_summary: string;
  calculated_at: string;
}

export interface BacktestEnqueueResponse {
  id: string;
  status: "queued" | "running" | "completed" | "failed";
}

export interface UploadInfo {
  id: string;
  title: string;
  description?: string;
  version: string;
  category: string;
  size_bytes: number;
  min_plan: "free" | "pro" | "premium";
  created_at: string;
  allowed: boolean;
}