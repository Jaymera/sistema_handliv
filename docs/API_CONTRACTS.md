# API Contracts — Trading Intelligence Platform

Base URL: `/api/v1`
Auth header: `Authorization: Bearer <access_token>`
Content-Type: `application/json` (exceto uploads `multipart/form-data`)
Datasets: UTC ISO 8601 (`2026-07-08T13:00:00Z`)

> Endpoints marcados **[ADMIN]** exigem `role=super_admin`.

---

## 1. Auth

### `POST /auth/register` — Cadastro
Request:
```json
{ "name": "Jayme", "email": "jayme@example.com", "phone": "+5511999999999", "password": "Senha@123" }
```
Response `201`:
```json
{ "user": { "id", "name", "email", "phone", "role": "user", "locale": "pt-BR" }, "access_token": "...", "refresh_token": "..." }
```
Errors: `400` email já existe / `422` validação

### `POST /auth/login` — Login (email + senha)
Request:
```json
{ "email": "jayme@example.com", "password": "Senha@123" }
```
Response `200`:
```json
{ "user": {...}, "access_token": "...", "refresh_token": "...", "force_password_change": false }
```
Errors: `401` credenciais inválidas / `423` conta suspensa (`is_active=false`)

### `POST /auth/refresh` — Rotacionar access token
```json
{ "refresh_token": "..." }
```
Response `200`:
```json
{ "access_token": "...", "refresh_token": "..." }   // novo refresh, antigo revogado
```
Errors: `401` refresh inválido/expirado

### `POST /auth/logout` — Revogar refresh atual
Body: `{ "refresh_token": "..." }` → `204`

### `POST /auth/password/forgot` — Iniciar reset (envia email SMTP)
Body: `{ "email": "..." }` → `204` (sempre, mesmo se email não existir)
Gera `password_resets.token_hash` (30 min) e envia link `https://app.../reset?token=...`

### `POST /auth/password/reset` — Confirmar reset
Body: `{ "token": "...", "new_password": "..." }` → `204`
Errors: `400` token inválido/expirado/used

### `PATCH /auth/me` — Atualizar perfil (nome, phone, locale, theme)
```json
{ "name": "Jayme S.", "locale": "en", "theme": "light" }
```

### `DELETE /auth/me` — Soft delete da própria conta
`204` (define `deleted_at=now()`; purge após 30 dias)

### `GET /auth/me` — Dados do usuário logado
```json
{ "id", "name", "email", "phone", "role", "locale", "theme", "plan": {...} }
```

---

## 2. Plans & Subscriptions

### `GET /plans` — Lista planos públicos
```json
[{ "id", "code", "name", "price_monthly_cents", "price_yearly_cents", "limits_json" }]
```

### `POST /subscriptions/checkout` — Iniciar Stripe Checkout
Body: `{ "plan_code": "pro", "interval": "monthly" }`
Response `200`: `{ "checkout_url": "https://checkout.stripe.com/..." }`

### `POST /subscriptions/portal` — Stripe Customer Portal
Response `200`: `{ "portal_url": "https://billing.stripe.com/..." }`

### `GET /subscriptions/me` — Subscription atual
```json
{ "plan": {...}, "status", "current_period_end", "cancel_at_period_end" }
```

### `DELETE /subscriptions/me` — Cancelar no fim do período
`204`

### `POST /webhooks/stripe` — **[PÚBLICO]** (sem JWT; assinatura Stripe verificada)
Recebe evento Stripe; processa `checkout.session.completed`, `invoice.paid`, `customer.subscription.updated`, `customer.subscription.deleted`.

---

## 3. Assets & Market Data

### `GET /assets?q=petr&market=B3&type=stock`
Query: `q` (nome/símbolo), `market`, `type`, `sector`, `page`, `limit`
Response `200`:
```json
{ "items": [{ "id", "symbol", "display_symbol", "name", "market", "asset_type", "currency", "logo_url" }], "total", "page", "limit" }
```

### `GET /assets/{symbol}` — Detalhe
`symbol` = `PETR4.SA` ou `AAPL`. Response:
```json
{ "id", "symbol", "name", "market", "currency", "sector", "fundamentals": {...}, "last_price": {...}, "score": {...} }
```

### `GET /assets/{symbol}/price?timeframe=1d&from=2026-01-01&to=2026-07-08`
Retorna array de candles OHLCV cacheados. Response:
```json
{ "symbol", "timeframe", "bars": [{ "date": "2026-07-08", "open", "high", "low", "close", "volume" }] }
```

### `GET /assets/{symbol}/fundamentals?date=2026-07-08`
```json
{ "pe_ratio", "pb_ratio", "dividend_yield", "roe", "margin", "revenue_growth", "debt_to_equity", "dcf_intrinsic_value", "sub_score_valuation" }
```

### `GET /assets/{symbol}/indicators?timeframe=1d`
Retorna últimos valores calculados para cada indicador:
```json
{ "rsi": 68.2, "macd": { "macd": 0.4, "signal": 0.2, "hist": 0.2 }, "ema20": 22.3, "ema50": 21.1, "vwap": 21.8, ... }
```

### `GET /assets/{symbol}/news?page=1&limit=20`
```json
{ "items": [{ "id", "title", "summary", "url", "source", "language", "sentiment": { "label": "positive", "score": 0.42 }, "published_at" }] }
```

### `GET /assets/{symbol}/score?timeframe=1d`
```json
{
  "final_score": 72, "buyer_strength": 80, "seller_strength": 28, "confidence": 65,
  "trend": "up", "horizon": "medium",
  "subscores": { "technical": 70, "valuation": 75, "sentiment": 68 },
  "ai_explanation": "Score composto elevado..., em PT-BR.",
  "calculated_at": "2026-07-08T18:00:00Z"
}
```

> `ai_explanation` é gerada deterministicamente a partir das regras/templates (sem LLM).

---

## 4. Watchlist & Favorites

### `GET /watchlist` — Itens do usuário logado
```json
[{ "asset": {...}, "sort_order": 1 }]
```

### `POST /watchlist` — Adicionar
Body: `{ "symbol": "PETR4.SA" }` → `201`
Errors: `409` já existe / `403` limite do plano atingido

### `DELETE /watchlist/{symbol}` → `204`

### `PATCH /watchlist/reorder`
Body: `{ "items": [{"symbol": "PETR4.SA", "sort_order": 1}, ...] }` → `204`

### `GET /watchlist/suggested` — Sugeridos para watchlist vazia
```json
[{ "symbol": "PETR4.SA", "name": "Petrobras PN", "market": "B3" }, ...]
```

### `GET /favorites` / `POST /favorites` / `DELETE /favorites/{symbol}`
Mesma estrutura da watchlist.

---

## 5. Alerts

### `GET /alerts` — Lista alertas do usuário
```json
[{ "id", "asset": {...}, "type": "price_above", "threshold": 38.5, "is_triggered": false, "is_active": true }]
```

### `POST /alerts`
Body:
```json
{ "symbol": "PETR4.SA", "type": "price_above", "threshold": 38.5 }
```
Response `201`. Errors: `403` limite do plano excedido

### `PATCH /alerts/{id}` — Ativar/desativar
Body: `{ "is_active": false }` → `204`

### `DELETE /alerts/{id}` → `204`

---

## 6. Backtesting

### `POST /backtests` — Enfileirar
Body:
```json
{
  "symbol": "PETR4.SA",
  "start_date": "2024-01-01",
  "end_date": "2026-06-30",
  "timeframe": "1d",
  "strategy_config": { "use_motor": true }
}
```
Response `202`:
```json
{ "id": "...", "status": "queued" }
```
Errors: `403` limite do plano excedido / `422` datas inválidas

### `GET /backtests` — Lista do usuário
```json
{ "items": [{ "id", "asset_symbol": "PETR4.SA", "status": "completed", "created_at", "total_return_pct" }] }
```

### `GET /backtests/{id}`
```json
{
  "id", "asset_symbol": "PETR4.SA", "start_date", "end_date",
  "strategy_config": {...},
  "metrics": { "total_return_pct", "sharpe", "sortino", "max_drawdown_pct", "win_rate", "profit_factor", "num_trades" },
  "equity_curve": [{ "date", "equity" }],
  "drawdown_curve": [{ "date", "drawdown" }],
  "trades": [{ "entry_date", "exit_date", "side", "entry_price", "exit_price", "quantity", "pnl" }],
  "status": "completed"
}
```

### `GET /backtests/{id}/export?format=pdf|csv`
`200` retorna arquivo binário (`Content-Disposition: attachment`).

### `DELETE /backtests/{id}` → `204`

---

## 7. Files / Downloads

### `GET /files?category=robo_mt5&min_plan=pro`
Retorna apenas os visíveis p/ plano do usuário logado.
```json
{ "items": [{ "id", "title", "description", "version", "category", "size_bytes", "min_plan", "is_new_version": true, "created_at" }] }
```

### `POST /files/{id}/download-url` — Gera presigned URL
Response `200`:
```json
{ "url": "https://...", "expires_in": 300 }
```
Errors: `403` plano insuficiente / `404` arquivo inativo

### `POST /files` [ADMIN] — Upload (multipart/form-data)
Form fields: `file`, `title`, `description?`, `version`, `category`, `min_plan`, `is_active`
Response `201`: `{ "id", ... }`. Errors: `413` arquivo > 100 MB / `415` extensão não permitida

### `PATCH /files/{id}` [ADMIN] — Editar metadados
Body: `{ "title", "is_active", "min_plan", ... }` → `204`

### `DELETE /files/{id}` [ADMIN] — Remover
`204`

---

## 8. Admin

### `GET /admin/users?q=&page=&limit=` [ADMIN]
```json
{ "items": [{ "id", "name", "email", "plan_code", "is_active", "created_at", "last_login_at" }] }
```

### `PATCH /admin/users/{id}` [ADMIN] — Suspender / resetar / mudar plano
Body: `{ "is_active": false }` OU `{ "plan_code": "premium" }` OU `{ "reset_password": true }` → `204`

### `GET /admin/logs?source=app&level=error&page=&limit=` [ADMIN]
```json
{ "items": [{ "id", "level", "source", "message", "context_json", "created_at" }] }
```

### `POST /admin/cache/invalidate` [ADMIN]
Body: `{ "pattern": "asset_price:*" }` → `204`

### `GET /admin/metrics?from=&to=` [ADMIN]
```json
{ "mau": 320, "mrr_cents": 1240000, "churn_rate": 0.04, "by_resource": { "backtests_used": 1820, "files_downloaded": 450 } }
```

### `GET /admin/score-weights` [ADMIN]
```json
{ "id", "technical_weight": 0.40, "valuation_weight": 0.35, "sentiment_weight": 0.25, "min_confidence": 50 }
```

### `PUT /admin/score-weights` [ADMIN]
Body como acima. Invalida cache de scores ao salvar.

### `GET /admin/plans` [ADMIN] / `POST /admin/plans` [ADMIN] / `PATCH /admin/plans/{id}` [ADMIN]
CRUD dos planos (sincroniza `stripe_price_id`).

---

## 9. Notifications

### `GET /notifications?page=`
```json
{ "items": [{ "id", "type", "title", "body", "payload_json", "sent_at", "read": false }] }
```

### `POST /notifications/{id}/read` → `204`

### `POST /notifications/read-all` → `204`

### `POST /notifications/push-token` — Registra Expo Push Token
Body: `{ "token": "ExponentPushToken[...]" }` → `204`

---

## 10. WebSocket

URL: `wss://api.../ws` (header `Authorization: Bearer <access_token>`)

Eventos servidor → cliente:

### `score.updated`
Payload: `{ "symbol": "PETR4.SA", "timeframe": "1d", "final_score": 74, "calculated_at": "..." }`

### `price.cache_updated`
Payload: `{ "symbol": "PETR4.SA", "last_close": 38.42, "fetched_at": "..." }`

### `alert.triggered`
Payload: `{ "alert_id": "...", "symbol": "...", "type": "price_above", "threshold": 38.5, "value": 38.8 }`

### `file.new_version`
Payload: `{ "file_id": "...", "title": "Robô MT5 v1.2", "version": "1.2.0" }`

### `backtest.completed`
Payload: `{ "backtest_id": "...", "status": "completed" }`

Cliente → servidor: apenas `ping` (manter vivo). Nada de price tick-a-tick no MVP.

---

## 11. Erros padronizados

Qualquer erro segue:
```json
{
  "error": { "code": "PLAN_LIMIT_EXCEEDED", "message": "Limite do plano atingido.", "field": "watchlist" }
}
```

Códigos comuns: `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION_ERROR`, `PLAN_LIMIT_EXCEEDED`, `RATE_LIMITED`, `CONFLICT`, `INTERNAL`.

HTTP status: `400, 401, 403, 404, 409, 413, 415, 422, 423, 429, 500`.

---

## 12. Rate limits (MVP)

| Endpoint | Limite |
|---|---|
| `POST /auth/login` | 5 / min / IP |
| `POST /auth/password/forgot` | 3 / min / IP |
| `POST /auth/register` | 3 / min / IP |
| Outros endpoints autenticados | 120 / min / user |
| `POST /backtests` | 5 / min / user (free) \ 30 (pro) \ 100 (premium) |
| `POST /files` (admin) | 10 / min |
| `GET /webhooks/stripe` (outras) | 100 / min / IP |

Implementação: middleware FastAPI + Redis (sliding window).