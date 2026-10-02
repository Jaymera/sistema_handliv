export type AutomationDirection = "buy" | "sell" | "both";
export interface AutomationDraft {
  broker_symbol: string;
  direction: AutomationDirection;
  volume: string;
  sl_atr_multiplier: string;
  tp_atr_multiplier: string;
}

export function validateAutomation(draft: AutomationDraft): string | null {
  if (!draft.broker_symbol.trim() || draft.broker_symbol !== draft.broker_symbol.trim())
    return "Informe o símbolo EXATO da corretora, sem espaços nas extremidades (inclua sufixos).";
  if (!["buy", "sell", "both"].includes(draft.direction)) return "Selecione a direção.";
  // MT5Command uses Numeric(10, 2): keep strings to avoid floating-point rounding.
  if (!/^\d{1,8}(\.\d{1,2})?$/.test(draft.volume) || !Number.isFinite(Number(draft.volume)) || Number(draft.volume) <= 0)
    return "Lote deve ser decimal positivo, com ponto e no máximo 2 casas decimais (até 99999999.99).";
  for (const value of [draft.sl_atr_multiplier, draft.tp_atr_multiplier]) {
    if (!/^\d{1,2}(\.\d{1,2})?$/.test(value) || !Number.isFinite(Number(value)) || Number(value) < 0.1 || Number(value) > 20)
      return "SL e TP são obrigatórios: multiplicadores ATR entre 0.10 e 20.00, no máximo 2 casas decimais.";
  }
  return null;
}
