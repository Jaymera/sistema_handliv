# Data Model — Trading Intelligence Platform

Derivado da [`PRD_Trading_Intelligence_Platform.md`](../PRD_Trading_Intelligence_Platform.md).

Convenções:
- Engine: **MySQL 8** / utf8mb4
- snake_case em todas as colunas
- UUIDs como PK default (`CHAR(36)` / `BINARY(16)`)
- Timestamps `created_at` / `updated_at` em UTC
- **Soft delete** via `deleted_at` (nullable). Purge após 30 dias via job Celery
- Índices marcados com `IDX`

---

## 1. Users & Auth

### `users`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| name | VARCHAR(120) |  |
| email | VARCHAR(255) UNIQUE NOT NULL |  |
| phone | VARCHAR(32) | celular |
| password_hash | VARCHAR(255) | BCrypt cost ≥ 12 |
| role | ENUM('user','super_admin') DEFAULT 'user' | RBAC |
| is_active | BOOLEAN DEFAULT TRUE |  |
| force_password_change | BOOLEAN DEFAULT FALSE | true no bootstrap do Super Admin |
| locale | VARCHAR(8) DEFAULT 'pt-BR' | 'pt-BR' \| 'en' |
| theme | VARCHAR(8) DEFAULT 'dark' | 'dark' \| 'light' |
| deleted_at | DATETIME NULL | soft delete |
| created_at / updated_at | DATETIME |  |

IDX: `email`, `role`, `deleted_at`

### `refresh_tokens`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK → users.id |  |
| token_hash | CHAR(64) UNIQUE | SHA-256 do refresh token |
| device_info | VARCHAR(255) |  |
| expires_at | DATETIME |  |
| revoked_at | DATETIME NULL |  |
| created_at | DATETIME |  |

IDX: `user_id`, `token_hash`

### `password_resets`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK |  |
| token_hash | CHAR(64) UNIQUE |  |
| expires_at | DATETIME | 30 min |
| used_at | DATETIME NULL |  |
| created_at | DATETIME |  |

IDX: `user_id`, `token_hash`

---

## 2. Plano & Stripe

### `plans`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| code | VARCHAR(32) UNIQUE | 'free' \| 'pro' \| 'premium' |
| name | VARCHAR(64) |  |
| stripe_price_id | VARCHAR(128) NULL |  |
| price_monthly_cents | INT | 0 para free |
| price_yearly_cents | INT |  |
| limits_json | JSON | ver PRD §3.3.1 |
| is_active | BOOLEAN |  |
| created_at / updated_at | DATETIME |  |

### `subscriptions`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK UNIQUE | 1 subscription ativa por user |
| plan_id | UUID FK |  |
| stripe_customer_id | VARCHAR(128) NULL |  |
| stripe_subscription_id | VARCHAR(128) NULL |  |
| status | ENUM('active','past_due','canceled','trialing') |  |
| current_period_end | DATETIME |  |
| cancel_at_period_end | BOOLEAN |  |
| created_at / updated_at | DATETIME |  |

IDX: `user_id`, `stripe_subscription_id`

### `payment_events`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| subscription_id | UUID FK NULL |  |
| stripe_event_id | VARCHAR(255) UNIQUE | idempotência |
| event_type | VARCHAR(64) | checkout.session.completed, invoice.paid, etc. |
| payload_json | JSON |  |
| processed_at | DATETIME NULL |  |
| created_at | DATETIME |  |

IDX: `stripe_event_id`

---

## 3. Assets & Market Data

### `assets`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| symbol | VARCHAR(32) UNIQUE | 'PETR4.SA', 'AAPL', 'EURUSD=X', 'BTC-USD' |
| display_symbol | VARCHAR(32) | 'PETR4', 'AAPL' sem sufixo |
| name | VARCHAR(255) |  |
| market | VARCHAR(32) | 'B3' \| 'NYSE' \| 'NASDAQ' \| 'FOREX' \| 'CRYPTO' \| 'COMMODITY' |
| asset_type | VARCHAR(32) | 'stock' \| 'fii' \| 'etf' \| 'bdr' \| 'reit' \| 'forex' \| 'crypto' \| 'commodity' |
| sector | VARCHAR(64) NULL |  |
| industry | VARCHAR(64) NULL |  |
| currency | VARCHAR(8) | 'BRL' \| 'USD' \| 'EUR' |
| logo_url | VARCHAR(512) NULL |  |
| is_active | BOOLEAN |  |
| created_at / updated_at | DATETIME |  |

IDX: `symbol`, `market`, `(market, asset_type)`

### `asset_prices`
Cache das 2 fetches diárias do yfinance. Particionável por `trade_date`.

| Coluna | Tipo | Notas |
|---|---|---|
| id | BIGINT PK AUTO |  |
| asset_id | UUID FK |  |
| trade_date | DATE |  |
| timeframe | VARCHAR(8) | '1d' \| '1h' \| '15m' \| '5m' |
| open / high / low / close | DECIMAL(18,6) |  |
| volume | BIGINT |  |
| fetched_at | DATETIME |  |

IDX: `(asset_id, timeframe, trade_date)`, `fetched_at`
UNIQUE: `(asset_id, timeframe, trade_date)`

### `asset_fundamentals`
Valuation snapshot diário.

| Coluna | Tipo | Notas |
|---|---|---|
| id | BIGINT PK AUTO |  |
| asset_id | UUID FK |  |
| snapshot_date | DATE |  |
| pe_ratio | DECIMAL(12,4) NULL |  |
| pb_ratio | DECIMAL(12,4) NULL |  |
| dividend_yield | DECIMAL(8,4) NULL |  |
| roe | DECIMAL(8,4) NULL |  |
| margin | DECIMAL(8,4) NULL |  |
| revenue_growth | DECIMAL(8,4) NULL |  |
| debt_to_equity | DECIMAL(12,4) NULL |  |
| dcf_intrinsic_value | DECIMAL(18,6) NULL | calculado |
| sub_score_valuation | TINYINT | 0-100 |
| payload_json | JSON | outros campos |
| fetched_at | DATETIME |  |

IDX: `(asset_id, snapshot_date)`

---

## 4. Score & Decision Engine

### `scores`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| asset_id | UUID FK |  |
| timeframe | VARCHAR(8) |  |
| technical_score | TINYINT | 0-100 |
| valuation_score | TINYINT | 0-100 |
| sentiment_score | TINYINT | 0-100 |
| final_score | TINYINT | 0-100 ponderado |
| buyer_strength | TINYINT | 0-100 |
| seller_strength | TINYINT | 0-100 |
| confidence | TINYINT | 0-100 |
| trend | ENUM('up','down','sideways') |  |
| horizon | ENUM('short','medium','long') |  |
| weights_json | JSON | snapshot dos pesos usados |
| inputs_log_json | JSON | rastreabilidade |
| calculated_at | DATETIME |  |

IDX: `(asset_id, timeframe, calculated_at)`

### `score_weights` (configurável pelo Super Admin)
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| name | VARCHAR(64) | 'default' |
| technical_weight | DECIMAL(5,4) | 0.40 |
| valuation_weight | DECIMAL(5,4) | 0.35 |
| sentiment_weight | DECIMAL(5,4) | 0.25 |
| min_confidence | TINYINT |  |
| is_active | BOOLEAN |  |

---

## 5. News & Sentiment

### `news_articles`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| asset_id | UUID FK NULL | NULL se macro |
| source | VARCHAR(64) | 'infomoney' \| 'valor' \| 'reuters' ... |
| url | VARCHAR(512) UNIQUE |  |
| title | VARCHAR(512) |  |
| summary | TEXT | gerado pela IA local |
| language | VARCHAR(8) | 'pt-BR' \| 'en' |
| published_at | DATETIME |  |
| sentiment_label | ENUM('positive','neutral','negative') |  |
| sentiment_score | DECIMAL(6,4) | -1.0 a 1.0 |
| fetched_at | DATETIME |  |

IDX: `(asset_id, published_at)`, `url`

### `rss_sources`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| name | VARCHAR(64) |  |
| feed_url | VARCHAR(512) |  |
| language | VARCHAR(8) |  |
| market | VARCHAR(32) NULL | NULL se genérico |
| is_active | BOOLEAN |  |

---

## 6. Watchlist & Favorites & Alerts

### `watchlist_items`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK |  |
| asset_id | UUID FK |  |
| sort_order | INT |  |
| created_at | DATETIME |  |

UNIQUE: `(user_id, asset_id)`

### `favorites`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK |  |
| asset_id | UUID FK |  |
| created_at | DATETIME |  |

UNIQUE: `(user_id, asset_id)`

### `alerts`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK |  |
| asset_id | UUID FK |  |
| type | ENUM('price_above','price_below','score_above','score_below') |  |
| threshold | DECIMAL(12,4) | preço ou score |
| is_triggered | BOOLEAN DEFAULT FALSE |  |
| triggered_at | DATETIME NULL |  |
| is_active | BOOLEAN |  |
| created_at / updated_at | DATETIME |  |

IDX: `(asset_id, is_active)`, `(user_id)`

---

## 7. Backtesting

### `backtests`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK |  |
| asset_id | UUID FK |  |
| start_date / end_date | DATE |  |
| timeframe | VARCHAR(8) |  |
| strategy_config_json | JSON | indicadores + pesos |
| total_return_pct | DECIMAL(12,4) |  |
| sharpe | DECIMAL(10,4) |  |
| sortino | DECIMAL(10,4) |  |
| max_drawdown_pct | DECIMAL(12,4) |  |
| win_rate | DECIMAL(8,4) |  |
| profit_factor | DECIMAL(12,4) |  |
| num_trades | INT |  |
| equity_curve_json | JSON | array [date, equity] |
| drawdown_curve_json | JSON |  |
| status | ENUM('queued','running','completed','failed') |  |
| created_at / completed_at | DATETIME |  |

IDX: `(user_id, created_at)`

### `backtest_trades`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| backtest_id | UUID FK |  |
| entry_date | DATETIME |  |
| exit_date | DATETIME NULL |  |
| side | ENUM('buy','sell') |  |
| entry_price | DECIMAL(18,6) |  |
| exit_price | DECIMAL(18,6) NULL |  |
| quantity | DECIMAL(18,6) |  |
| pnl | DECIMAL(18,6) NULL |  |

IDX: `backtest_id`

---

## 8. Files / Downloads

### `files`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| title | VARCHAR(255) |  |
| description | TEXT NULL |  |
| version | VARCHAR(32) | semver |
| category | VARCHAR(32) | 'robo_mt5' \| 'indicador' \| 'manual' \| 'outros' |
| storage_key | VARCHAR(512) | caminho no storage |
| size_bytes | BIGINT |  |
| mime_type | VARCHAR(128) |  |
| min_plan | ENUM('free','pro','premium') DEFAULT 'free' | controle de acesso |
| is_active | BOOLEAN |  |
| uploaded_by | UUID FK → users.id |  |
| created_at / updated_at | DATETIME |  |

### `file_downloads`
| Coluna | Tipo | Notas |
|---|---|---|
| id | BIGINT PK AUTO |  |
| file_id | UUID FK |  |
| user_id | UUID FK |  |
| downloaded_at | DATETIME |  |

IDX: `(file_id, downloaded_at)`, `(user_id)`

---

## 9. Notifications & Audit

### `notifications`
| Coluna | Tipo | Notas |
|---|---|---|
| id | UUID PK |  |
| user_id | UUID FK |  |
| type | VARCHAR(64) | 'alert' \| 'new_file_version' \| 'subscription' |
| title | VARCHAR(255) |  |
| body | TEXT |  |
| payload_json | JSON |  |
| channel | ENUM('push','email') DEFAULT 'push' |  |
| status | ENUM('pending','sent','failed') |  |
| sent_at | DATETIME NULL |  |
| created_at | DATETIME |  |

IDX: `(user_id, status)`

### `audit_logs`
| Coluna | Tipo | Notas |
|---|---|---|
| id | BIGINT PK AUTO |  |
| actor_user_id | UUID NULL | NULL se sistema |
| action | VARCHAR(64) | 'login' \| 'execute_order' \| 'change_plan' \| 'upload_file' ... |
| target_type | VARCHAR(32) |  |
| target_id | UUID NULL |  |
| details_json | JSON |  |
| ip | VARCHAR(64) |  |
| created_at | DATETIME |  |

IDX: `(actor_user_id, created_at)`, `(action, created_at)`

### `app_logs`
Logs de aplicação e webhook (não auditoria). Pode também ser log estruturado fora do DB, mas uma tabela para facilitar visualização no admin MVP.

| Coluna | Tipo | Notas |
|---|---|---|
| id | BIGINT PK AUTO |  |
| level | ENUM('debug','info','warning','error') |  |
| source | VARCHAR(64) | 'app' \| 'webhook' \| 'celery' |
| message | TEXT |  |
| context_json | JSON |  |
| created_at | DATETIME |  |

IDX: `(level, created_at)`, `(source, created_at)`

---

## 10. Relacionamentos (DER simplificado)

```
users 1───* refresh_tokens
users 1───* password_resets
users 1───* subscriptions *───1 plans
users 1───* payment_events (via subscription)
users 1───* watchlist_items *───1 assets
users 1───* favorites *───1 assets
users 1───* alerts *───1 assets
users 1───* backtests *───1 assets
backtests 1───* backtest_trades
users 1───* notifications
users 1───* file_downloads *───1 files
assets 1───* asset_prices
assets 1───* asset_fundamentals
assets 1───* scores
assets 1───* news_articles
rss_sources ─── news_articles (indireto)
audit_logs / app_logs independentes
score_weights (singleton ativo)
```

## 11. Seeds iniciais

- `plans`: free / pro / premium com `limits_json` conforme PRD §3.3.1
- `score_weights`: 1 registro ativo com `technical=0.40, valuation=0.35, sentiment=0.25`
- `rss_sources`: InfoMoney, Valor, Exame, O Globo, Investing.com BR, Yahoo Finance, Reuters, MarketWatch
- `super_admin` user via `ADMIN_*` env vars
- Assets sugeridos para "Sugeridos" da watchlist: PETR4.SA, VALE3.SA, ITUB4.SA, AAPL, MSFT, BTC-USD