# Trading Intelligence Platform SaaS

Plataforma SaaS de inteligência financeira multiusuário combinando análise técnica, valuation e sentimento de notícias em um motor de decisão com IA, com integração nativa ao MetaTrader 5 (boleta, sincronização e auto-trading) e backtesting histórico.

## Documentação

- [`PRD_Trading_Intelligence_Platform.md`](./PRD_Trading_Intelligence_Platform.md) — especificação de produto
- [`docs/DATA_MODEL.md`](./docs/DATA_MODEL.md) — modelo de dados (DER completo, 18+ tabelas)
- [`docs/API_CONTRACTS.md`](./docs/API_CONTRACTS.md) — contratos REST + WebSocket (43 endpoints)
- Este README — setup, execução, variáveis de ambiente

## Status da implementação (Scaffold MVP)

| Módulo | Estado |
|---|---|
| Backend FastAPI (43 endpoints + OpenAPI) | ✅ carregando |
| Modelos SQLAlchemy (18 tabelas) | ✅ |
| Alembic migration inicial | ✅ |
| Auth (JWT, register, login, refresh, reset SMTP, RBAC) | ✅ |
| Stripe (checkout, portal, webhook placeholder) | ✅ |
| Assets + preço (yfinance) + indicadores | ✅ |
| Motor de decisão (RSI/MACD/EMA/ADX/Stoch/BB/SuperTrend/votação) | ✅ |
| IA local (explicação PT-BR determinística) | ✅ |
| Backtests (Celery + backtesting.py) | ✅ |
| Admin (usuários, logs, métricas, pesos, planos, cache) | ✅ |
| Uploads/Downloads (aba de robôs, presigned) | ✅ |
| WebSocket (notificação de cache, sem streaming tick) | ✅ |
| Tasks Celery (fetch prices 2x/dia, scores, RSS, backtest) | ✅ |
| Frontend Expo (4 tabs, auth, ativo, backtest, admin) | ✅ scaffold |
| Docker + docker-compose + EasyPanel | ✅ |

> Para validar localmente: `docker compose up -d --build` e acesse `http://localhost:8000/docs`.

---

## Stack

- **Front-end:** React Native (Expo) · TypeScript · React Navigation · React Query · Zustand · NativeWind
- **Back-end:** FastAPI · SQLAlchemy · Alembic · MySQL · Redis · Celery · JWT · WebSocket
- **Infra:** Docker · Docker Compose · EasyPanel · HTTPS · Rate Limiting

---

## Estrutura planejada

```
saas_mercado_financeiro/
├── backend/
│   ├── app/
│   │   ├── domain/          # Entidades e regras de negócio
│   │   ├── application/     # Casos de uso
│   │   ├── infrastructure/  # Providers, DB, cache, queues
│   │   └── presentation/    # Rotas API, schemas, middlewares
│   ├── alembic/
│   ├── tests/
│   ├── storage/uploads/     # arquivos enviados pelo Super Admin
│   ├── Dockerfile
│   ├── requirements.txt
│   └── pyproject.toml
├── frontend/
│   ├── app/                  # Expo Router (telas)
│   ├── src/                  # api, state, types, components
│   ├── Dockerfile
│   ├── nginx.conf
│   └── package.json
├── docs/                    # DATA_MODEL.md + API_CONTRACTS.md
├── ea_mt5/                   # Expert Advisor MQL5 (Fase 2)
├── docker-compose.yml
├── .env.example
├── PRD_Trading_Intelligence_Platform.md
└── README.md
```

---

## Pré-requisitos

- Node.js 20+
- Python 3.11+
- Docker + Docker Compose
- (opcional) EasyPanel para deploy
- Conta Stripe com Products/Prices criados
- MetaTrader 5 (para testes do EA)

> **Zero token pago obrigatório.** IA/NLP e market data usam libs Python free + `yfinance`. Stripe é o único serviço que requer credenciais pagas (mas opera em modo `test` sem custo).

---

## Como executar

### 1. Clone e prepare o ambiente

```bash
git clone <repo-url>
cd saas_mercado_financeiro
cp .env.example .env
# preencha as variáveis no .env (ver seção abaixo)
```

### 2. Suba os serviços com Docker (recomendado)

```bash
docker-compose up -d --build
```

Serviços disponíveis:
- Backend (FastAPI): `http://localhost:8000`
- Docs OpenAPI: `http://localhost:8000/docs`
- Frontend (Expo): `http://localhost:8081`
- MySQL: `localhost:3306`
- Redis: `localhost:6379`
- Celery Worker / Beat: rodam em background

### 3. Rodando em modo desenvolvimento (separado)

**Backend:**
```bash
cd backend
python -m venv .venv
.venv\Scripts\activate           # Windows
# source .venv/bin/activate     # Linux/Mac
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# em outro terminal
celery -A app.worker worker -l info
celery -A app.worker beat -l info
```

**Frontend:**
```bash
cd frontend
npm install
npx expo start
```

### 4. Deploy no EasyPanel

> Setup validado em produção (EasyPanel v2.26+). O repositório usa um único `docker-compose.yml` (tipo **Compose**) com os serviços `frontend`, `backend`, `celery_worker`, `celery_beat` e `redis`. O EasyPanel injeta automaticamente um `docker-compose.override.yml` que conecta os serviços à rede `easypanel`, então **não use `ports` no compose** — use apenas `expose` (o traefik roteia por DNS interno).

1. **Crie o projeto** no EasyPanel e escolha **Compose** (não "Runtime"/"Buildpack").
2. **Conecte o repositório GitHub** (`https://github.com/Jaymera/sistema_handliv.git`) e informe o caminho do compose (`docker-compose.yml`).
3. **Variáveis de ambiente**: preencha no painel do serviço `saas_handliv` todas as variáveis do `.env` (Stripe, MySQL, JWT, Redis, ADMIN_*, URLs dos links de Recursos).
4. **MySQL**: rode um serviço MySQL separado no EasyPanel (ou use externo) e aponte `DATABASE_URL` para ele. As migrations rodam no startup do backend (`alembic upgrade head`).
5. **Redis**: o compose já sobe o serviço `redis` interno.
6. **Domínios** (importante — foi a causa do erro 502 em produção):
   - `app.handliv.com` → serviço **frontend**, porta **80**
   - `api.handliv.com` → serviço **backend**, porta **8000**
   - No painel do domínio, o `composeService` deve apontar exatamente para o nome do serviço (frontend/backend). Se ficar `null`, o traefik roteia para `..._undefined` e retorna 502.
7. **Habilite HTTPS automático** (Let's Encrypt).
8. **Deploy** e verifique:
   - `https://api.handliv.com/api/v1/health` → `{"status":"ok"}`
   - `https://app.handliv.com/` → SPA carregando (login OK)
9. **Webhooks Stripe**: configure `https://api.handliv.com/api/v1/subscriptions/webhook` no dashboard da Stripe com o `whsec_*` real.

**Troubleshooting EasyPanel**
- `502 Bad Gateway`: domínio com `composeService` nulo → edite o domínio no painel e redeploy. Também garanta que os containers estejam na rede `easypanel`.
- `ModuleNotFoundError` no celery: arquivos novos precisam estar commitados e pushados no GitHub antes do deploy (o painel puxa o branch `main`).
- Alterou o compose? Use "Redeploy" (força regeração do override).

---

## Variáveis de ambiente (.env)

Copie `.env.example` para `.env` e preencha. **Nunca commit o `.env`.**

### App
```env
APP_ENV=development                # development | production
APP_SECRET=troque_por_uma_chave_longa_aleatoria
CORS_ORIGINS=http://localhost:8081,https://app.dominio.com
```

### Banco de dados / Cache
```env
DATABASE_URL=mysql+pymysql://user:pass@localhost:3306/handliv
REDIS_URL=redis://localhost:6379/0
```

### JWT
```env
JWT_SECRET=troque_por_uma_chave_longa_aleatoria
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30
```

### Stripe (pagamentos)
> Obter em: https://dashboard.stripe.com/apikeys e https://dashboard.stripe.com/products

```env
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
STRIPE_PRICE_FREE=price_xxx
STRIPE_PRICE_PRO=price_xxx
STRIPE_PRICE_PREMIUM=price_xxx
```

**Free sem cartão** (qualquer um se cadastra e usa o Free) — **sem trial** no MVP.

Para testar webhooks localmente:
```bash
stripe listen --forward-to localhost:8000/api/webhooks/stripe
```

### SMTP (reset de senha via Gmail)
> Criar App Password em https://myaccount.google.com/apppasswords

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=seu_email@gmail.com
SMTP_PASSWORD=app_password_16_chars
SMTP_FROM=no-reply@handliv.com
```

### Push (Expo Notifications)
```env
EXPO_ACCESS_TOKEN=                # opcional em dev (Expo só precisa em prod)
```

### Super Admin (bootstrap automático na primeira execução)
```env
ADMIN_NAME=Handliv
ADMIN_EMAIL=admin@handliv.com
ADMIN_USERNAME=Handliv
ADMIN_PASSWORD=samsung12
```
> A senha deve ser trocada após o primeiro login.

### Market Data (padrão free, sem API key)
> Default: `yfinance` (Python lib) — cobre B3 (sufixo `.SA`), NYSE, NASDAQ, ETFs, REITs, Forex, Cripto. 100% free, sem cadastro.

```env
MARKET_DATA_PROVIDER=yfinance     # yfinance (free, sem key) | brapi | alpha_vantage | polygon | finnhub | twelve_data
# Só preencher as chaves abaixo se usar provider diferente de yfinance:
BRAPI_API_KEY=
ALPHA_VANTAGE_API_KEY=
POLYGON_API_KEY=
FINNHUB_API_KEY=
TWELVE_DATA_API_KEY=
```

### News / Sentimento (padrão free, via RSS)
> Default: `rss` — captura notícias via RSS de portais (InfoMoney, Valor, Exame, Reuters, Yahoo Finance) usando `feedparser`. 100% free, sem API key.

```env
NEWS_PROVIDER=rss                 # rss (free) | newsapi | gnews | marketaux
NEWSAPI_KEY=
GNEWS_KEY=
MARKETAUX_KEY=
```

### IA / NLP (100% local, sem token pago)
> As libs Python abaixo rodam localmente no backend. **Nenhuma chave obrigatória.**

```env
LLM_PROVIDER=disabled             # disabled (padrão, usa libs locais) | openai | anthropic (OPCIONAL)
# Só preencher se quiser aprimoramento opcional com LLM pago:
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
LLM_MODEL=gpt-4o-mini
```

**Libs Python locais (instaladas via `requirements.txt`):**
- `transformers` (HuggingFace) — sentiment + summarization
- `pysentimento` — sentimento PT-BR
- `vaderSentiment` / `TextBlob` — sentimento leve/fallback
- `newspaper3k` — extração de texto de URLs de notícias
- `feedparser` — leitura de RSS
- `yfinance` — market data grátis
- `pandas-ta` / `ta` — indicadores técnicos
- `backtesting` / `backtrader` — backtesting

### MT5 (Integração com o Expert Advisor)
```env
MT5_API_BASE_URL=https://mt5.dominio.com
MT5_API_TOKEN=gerar_token_aleatorio
MT5_WEBHOOK_SECRET=whsec_mt5
```

### Uploads / Downloads (aba de robôs e manuais)
> Plataforma S3 (ex.: AWS S3, Cloudflare R2, MinIO local)

```env
UPLOADS_DRIVER=local               # local | s3 | minio
UPLOADS_BASE_DIR=./storage/uploads
UPLOADS_MAX_SIZE_MB=100
UPLOADS_ALLOWED_EXT=zip,rar,ex5,mq5,pdf
S3_ENDPOINT=
S3_BUCKET=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_REGION=
```

O Super Admin envia arquivos `.zip`/`.rar`/`.ex5` (robôs, indicadores, manuais) e o cliente acessa pela aba "Downloads" no app, respeitando o plano. Downloads via presigned URL com expiração.

---

## Onde obter cada API Key

### Obrigatórias
| Serviço | URL | Observação |
|---|---|---|
| Stripe | https://dashboard.stripe.com/apikeys | Modo teste (`sk_test_` / `pk_test_`) — sem custo em dev |
| Stripe Products | https://dashboard.stripe.com/products | Criar 3 preços (Free, Pro, Premium) |

### Opcionais (apenas se quiser trocar os defaults free)
| Serviço | URL | Observação |
|---|---|---|
| Brapi | https://brapi.dev | Dados B3 (free tier limitado) |
| Alpha Vantage | https://www.alphavantage.co | Free tier 25 calls/dia |
| Polygon.io | https://polygon.io | EUA / Forex / Cripto |
| Finnhub | https://finnhub.io | Notícias + fundamentos |
| Twelve Data | https://twelvedata.com | Multimercado |
| NewsAPI | https://newsapi.org | Notícias globais |
| GNews | https://gnews.io | Notícias multi-idioma |
| MarketAux | https://marketaux.com | Notícias financeiras com sentimento |
| OpenAI | https://platform.openai.com/api-keys | Apenas se ativar LLM opcional |
| Anthropic | https://console.anthropic.com | Apenas se ativar LLM opcional |

> **Padrão:** market data via `yfinance`, notícias via `rss` (`feedparser`), IA via libs locais (`transformers`/`pysentimento`/`vaderSentiment`). Tudo free, sem key.

---

## Super Admin (acesso inicial)

Após subir o backend pela primeira vez com as variáveis `ADMIN_*` preenchidas, o sistema cria automaticamente o Super Admin:

- **Usuário:** `Handliv`
- **Senha:** `samsung12` (definida no `.env`)

> Faça login e altere a senha imediatamente. O sistema exigirá a troca se ainda estiver com a senha padrão.

Login administrativo é isolado dos usuários comuns (rota exclusiva ou flag `is_admin`) e protegido por JWT + RBAC.

---

## Roadmap

### MVP (Fase 1)
- Autenticação email/senha + RBAC + reset via Gmail SMTP (sem OAuth social, sem double opt-in)
- Landing page bilingue PT-BR + EN (dark + light) com fluxo: Landing → auth → app
- Stripe (checkout, webhooks, controle por plano, **Free sem cartão, sem trial**)
- Dashboard 4 tabs (Dashboard / Mercados / Busca / Perfil): heatmap, ranking, watchlist vazia + sugeridos, favoritos, alertas (preço + score), gráficos linha+velas, onboarding 4 telas, i18n, tema dark+light
- Página do ativo (B3 + EUA): Preço → Gráfico → Indicadores → Valuation (DCF) → Notícias (RSS) → Score + IA local
- Motor de decisão v1 (técnico + valuation + sentimento local, libs Python free, **sem token**) atualizado 2x/dia via Celery + cache Redis; WebSocket só notifica UI quando cache muda
- IA local PT-BR: resumos, explicação do score e indicadores, insights
- Backtesting v1 (período configurável, sem custos, métricas + curves + export PDF/CSV)
- Painel admin (Expo Web `/admin`): usuários, planos Stripe, logs, cache, métricas, pesos do motor, uploads
- Downloads: upload Super Admin (100 MB) + aba cliente com presigned URL e controle por plano
- Push notifications (Expo)
- Testes unitários backend (pytest)

### Fase 2
- MT5 completo (EA + boleta + gestão de risco + Auto-Trading)
- Forex / Cripto / Commodities
- Conectores adicionais (MT4, cTrader, TradingView, Binance, Bybit)
- LLM opcional para enriquecimento de texto (OpenAI/Anthropic)
- CI/CD (GitHub Actions) + testes de integração/E2E

---

## Funcionalidades em destaque

### Motor de Decisão
Combina Análise Técnica (40%) + Valuation (35%) + Notícias/Sentimento (25%) em um score 0-100, com força compradora/vendedora, grau de confiança, tendência e horizonte. Pesos configuráveis pelo Super Admin.

### Backtesting
Simulação histórica do motor e de estratégias de indicadores. Métricas: retorno, sharpe, sortino, max drawdown, win rate, profit factor. Equity curve, curva de drawdown e export PDF/CSV. Limites por plano: 1/mês (Free), 50/mês (Pro), ilimitado (Premium).

### MetaTrader 5
- Sincronização de saldo, equity, margem, ordens, histórico e posições via WebSocket
- Boleta: market, limit, stop, SL/TP, trailing, breakeven, fechar tudo
- **Auto-Trading (Premium):** toggle "Operar Automaticamente" que executa ordens a partir dos sinais do motor, com regras de gatilho configuráveis (score, horizonte, confiança) e gestão de risco aplicada — em modo Paper ou Real
- Arquitetura `BrokerConnector` preparada para MT4, cTrader, TradingView, Binance, Bybit

### Downloads (robôs / manuais)
- Super Admin sobe arquivos `.zip`/`.rar`/`.ex5`/`.mq5`/`.pdf` (robô MT5, indicadores, manuais) via painel administrativo
- Cliente acessa pela aba "Downloads" no app
- Controle de acesso por plano (Free/Pro/Premium), notificação de nova versão, download via presigned URL

### Segurança
JWT + Refresh, BCrypt cost ≥ 12, HTTPS, Rate Limiting, auditoria, OWASP, segredos nunca expostos ao front-end, rotação de chaves.

---

## Documentação da API

Após subir o backend, acesse:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

---

## Licença

Proprietária © Handliv. Uso interno.