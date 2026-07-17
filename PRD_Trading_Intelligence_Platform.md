# PRD — Trading Intelligence Platform SaaS

> Documentos relacionados:
> - [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) — DER completo (18+ tabelas) com índices, soft delete, seeds
> - [`docs/API_CONTRACTS.md`](docs/API_CONTRACTS.md) — contratos REST + WebSocket (43 endpoints), payloads e rate limits
> - [`README.md`](README.md) — setup, execução e variáveis de ambiente

## 1. Visão Geral

Plataforma SaaS de inteligência financeira multiusuário que combina análise técnica, valuation e sentimento de notícias em um motor de decisão com IA **100% local** (libs Python open-source, sem dependência de tokens pagos). Permite ao investidor visualizar, interpretar e executar operações em múltiplos mercados, com integração nativa ao MetaTrader 5 e arquitetura extensível para futuros conectores de corretoras e exchanges.

- **Público-alvo:** Traders e investidores individuais (Brasil e internacional).
- **Modelo de negócio:** Assinatura recorrente via Stripe (Free, Pro, Premium).
- **Entrega:** Front-end mobile (React Native/Expo) + Back-end API (FastAPI), implantado via Docker/EasyPanel.

---

## 2. Stack Técnica

### Front-end
- React Native (Expo)
- TypeScript
- React Navigation
- React Query
- Zustand
- NativeWind
- Reanimated / Skia (gráficos)

### Back-end
- FastAPI
- SQLAlchemy + Alembic
- MySQL (banco principal)
- Redis (cache + filas)
- Celery (tarefas assíncronas)
- JWT (access + refresh)
- WebSocket (notifica a UI quando cache de preços/score é atualizado; **não há streaming de preço em tempo real no MVP**)

### Infraestrutura
- Dockerfile para frontend e backend
- `docker-compose.yml` compatível com EasyPanel
- Variáveis de ambiente via `.env`
- HTTPS, CORS, Rate Limiting

---

## 3. Funcionalidades

### 3.1 Autenticação e Identidade
- Cadastro com **nome, email, celular e senha** (BCrypt cost >= 12)
- Sem confirmação de e-mail (double opt-in) no MVP
- Login com **email + senha** (sem OAuth social no MVP)
- Recuperação de senha via **e-mail SMTP (Gmail)** com link/token de reset
- JWT com Access Token (curta duração) + Refresh Token (rotação)
- Bloqueio após tentativas excessivas (Rate Limit)
- Controle de sessão (revogar refresh tokens)
- RBAC (papéis: `user`, `super_admin`)

### 3.2 Landing Page
- Tema dark/light, responsiva, **bilingue PT-BR + EN**
- Seções: Hero, Planos (Free / Pro / Premium), Comparativo, Demonstração, FAQ, CTA
- SEO (meta tags, Open Graph, sitemap)
- Landing servida como página estática (Expo Web route `/`)
- Fluxo de entrada: Landing → "Entrar/Cadastrar" → tela de auth → app

### 3.3 Pagamentos (Stripe)
- Checkout hospedado (Stripe Hosted Checkout)
- Assinaturas mensais e anuais
- Upgrade / downgrade / cancelamento
- Portal do cliente Stripe
- Webhooks (assinatura, fatura, pagamento, cancelamento)
- Histórico de pagamentos sincronizado
- Controle de acesso por plano (middleware de permissões)
- Sincronização imediata via webhook + reconciliação periódica via API Stripe
- **Free sem cartão** (cadastro direto do Free) — **sem trial** no MVP

**Variáveis de ambiente:**
```
STRIPE_SECRET_KEY=
STRIPE_PUBLISHABLE_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PRICE_FREE=
STRIPE_PRICE_PRO=
STRIPE_PRICE_PREMIUM=
```

#### 3.3.1 Limites por plano
| Recurso | Free | Pro | Premium |
|---|---|---|---|
| Watchlist | até 5 | até 50 | ilimitado |
| Alertas | até 5 | até 50 | ilimitado |
| IA (insights/sumarização) | Não | Sim | Sim |
| MT5 | Não | Sim | Sim |
| Mercados | B3 | B3 + EUA + Forex | Todos |
| Histórico de notas | 30 dias | 1 ano | ilimitado |
| Backtesting | 1/mês | 50/mês | ilimitado |
| Auto-Trading | Não | Não | Sim |

### 3.4 Dashboard
- Heatmap de setores/ativos
- Ranking (ganhadores/perdedores, customizável)
- Watchlist personalizável — **inicia vazia** + seção "Sugeridos" (top B3/EUA) com 1 toque para adicionar
- Favoritos
- Alertas configuráveis: **preço** (acima/abaixo de X) e **score do motor** (ex.: >= 70)
- Gráficos interativos: **linha + velas (candles)** com volume
- Pesquisa global de ativos
- WebSocket só notifica a UI quando o cache de preços/score é atualizado (não é preço tick-a-tick)
- **Onboarding** na 1ª vez: 4 telas (Boas-vindas → Tour dashboard → Planos → Sugestão de watchlist)
- **Tema dark + light** com toggle; **i18n PT-BR + EN**
- **Bottom tabs:** Dashboard · Mercados · Busca · Perfil

### 3.5 Mercados Suportados
- **Brasil:** B3 (ações, FIIs, ETFs, BDRs)
- **EUA:** NYSE, NASDAQ, ETFs, REITs
- **Forex**
- **Criptomoedas**
- **Commodities**

### 3.6 Página do Ativo
Ordem dos blocos (topo → baixo):
1. **Preço** (cotação cacheada das 2 fetches diárias, variação, volume)
2. **Gráfico** (linha + velas, com volume)
3. **Indicadores Técnicos** (tabela)
4. **Valuation completo**: P/L, P/VP, Div. Yield, ROE, margens, crescimento, dívida/patrimônio, setor + **DCF simplificado** (WACC e growth rate configuráveis) + **sub-score valuation 0-100**
5. **Notícias** (RSS PT-BR + EN, idioma selecionado pela origem do ativo; resumo via IA local sempre em **PT-BR**)
6. **Score consolidado** do motor de decisão + **IA explicação em PT-BR**

---

## 4. Motor de Decisão (AI Decision Engine)

Combina 3 pilares em um score final ponderado (0-100):

| Pilar | Peso padrão |
|---|---|
| Análise Técnica | 40% |
| Valuation | 35% |
| Notícias / Sentimento | 25% |

Cada pilar gera um sub-score 0-100. **Pesos configuráveis pelo Super Admin.**

### 4.1 Saída do motor
- Score Geral (0-100)
- Força Compradora (0-100)
- Força Vendedora (0-100)
- Grau de Confiança (0-100)
- Tendência (Alta / Baixa / Lateral)
- Horizonte sugerido (Curto / Médio / Longo prazo)

### 4.2 Requisitos do motor
- **Fonte de dados: `yfinance`** (free, sem API key)
- **Atualização 2x ao dia** via Celery beat (ex.: 10h e 18h horário de Brasília) para ativos populares
- Score recalculado **após cada um dos 2 fetches diários**
- Cache por `(ativo, timeframe)` em Redis com TTL configurável
- WebSocket notifica a UI quando score é atualizado (sem streaming de preço em tempo real)
- Log de insumos (rastreabilidade) por execução
- Backtesting incluído no MVP (seção 5)

---

## 5. Backtesting

Módulo de simulação histórica do Motor de Decisão e de estratégias dos indicadores, permitindo validar a performance antes de operar com capital real.

### 5.1 Funcionalidades
- Seleção de ativo, **período configurável** (data início e fim dentro do máximo disponível no yfinance) e timeframe
- Seleção de estratégia (pré-definidas) ou configuração customizada (indicadores + pesos)
- Simulação buy & hold vs. seguindo os sinais do motor
- Execução de ordens simuladas (entry, SL, TP)
- **Sem custos** (corretagem/emolumentos ignorados no MVP)
- Métricas: retorno total, retorno %, sharpe, sortino, max drawdown, win rate, profit factor, número de trades, média de ganho/perda
- Equity curve e curva de drawdown
- Exportação do relatório em PDF/CSV

### 5.2 Requisitos
- Dados históricos OHLCV via `yfinance` (B3 com sufixo `.SA`, EUA, ETfs, REITs, Forex, Cripto) — 100% free, sem API key
- **Sem custos de corretagem/emolumentos** na simulação (MVP)
- Suporte a paper trading reutilizável pelo Auto-Trading
- Comparação de múltiplas estratégias lado a lado
- Permissão por plano: Free (1 backtest/mês), Pro (50/mês), Premium (ilimitado)

### 5.3 Interface
- Página dedicada "Backtesting" no app
- Formulário de configuração da simulação
- Cards de métricas principais
- Gráfico de equity curve + drawdown
- Tabela de trades executados

---

## 6. Indicadores Técnicos

Implementar cálculo e exibição:
EMA, SMA, VWAP, RSI, MACD, ADX, ATR, CCI, Stochastic, Ichimoku, Bollinger, SuperTrend, SAR, OBV, MFI, Fibonacci, Price Action (pinbar, engolfo, doji), suportes/resistências e padrões de candles clássicos.

Disponibilizados para consumo via API e renderizados no app.

---

## 7. IA / NLP (100% local, sem token pago)

Toda a camada de IA / NLP **funciona sem qualquer chave de API paga**. O backend utiliza bibliotecas Python open-source rodando localmente:

| Função | Biblioteca (free) | Observação |
|---|---|---|
| Sentimento de notícias (PT-BR) | `pysentimento` (HuggingFace) | Baseado em BERT.Redis multilingual, otimizado para PT-BR |
| Sentimento de notícias (EN) | `transformers` + `distilbert-base-uncased-finetuned-sst-2` | Cai em disco local após 1º download |
| Sentimento simples/fallback | `vaderSentiment` + `TextBlob` | Leve, sem GPU, determinístico |
| Sumarização de notícias | `transformers` + `ptt5` (PT) / `bart-large-cnn` (EN) | Sumarização abstrativa |
| Extração de texto de notícias | `newspaper3k` | Lê URL de qualquer portal sem API key |
| Captura de notícias | `feedparser` (RSS) + `gnews` (Google News RSS) | RSS é gratuito e não exige chave |
| Explicação do score / indicadores | Gerador determinístico baseado em regras/templates | Sem LLM — rápido, leve, gratuito, auditável |
| Insights / hipóteses de trade | Templates com regras sobre score, força compradora/vendedora, tendência, horizonte | Mesma abordagem determinística |

### 7.1 Princípios
- **Sem custo por requisição:** nada de OpenAI/Anthropic no caminho crítico
- **Sem dependência de internet para o motor** (após 1º download dos modelos HF, que são cacheados em disco)
- **Auditável:** as regras/templates são versionadas no código, permitindo explicar exatamente o motivo de cada insight
- **Pipelines em batch via Celery** (não bloqueiam a API)
- **Cache por ativo + período** das análises de sentimento/sumarização (TTL configurável)

### 7.2 LLM pago (OPCIONAL — não incluído no núcleo)
Se no futuro quiser aprimorar a linguagem natural dos insights, pode-se plugar (via provider pattern) um LLM pago (OpenAI/Anthropic) **apenas como camada de reescrita/enriquecimento**, mas isso **nunca será obrigatório** para validar operações. O motor de decisão e a verificação de operações funcionam 100% com as libs locais.

> Variável `LLM_PROVIDER=disabled` no `.env` por padrão. Só preencher se quiser o aprimoramento opcional.

### 7.3 Respeitar limites por plano
A IA está disponível conforme os limites da tabela de planos (seção 3.3.1).

---

## 8. MetaTrader 5

### 8.1 EA (Expert Advisor) em MQL5
- Publicado e copilado para o usuário baixar
- Conexão com backend via HTTPS + WebSocket
- Autenticação via API Key / Token
- Vincula automaticamente a conta MT5 ao usuário da plataforma

### 8.2 Sincronização de estado
- Saldo
- Equity
- Margem (livre/used)
- Ordens abertas
- Histórico de ordens
- Posições abertas

### 8.3 Boleta (execução de ordens)
- Comprar / Vender a mercado
- Fechar posição individual
- Fechar todas as posições
- Buy Limit / Sell Limit
- Buy Stop / Sell Stop
- Alterar SL / TP
- Trailing Stop (configurável em pontos ou ATR)
- Breakeven automático
- Confirmação síncrona de cada operação (status, preço filled, ticket) devolvida pelo EA ao backend, registrada como trade executado
- Botão único "Comprar" / "Vender" no app que envia ordem ao EA via WebSocket (baixa latência, com feedback em tempo real na UI)

### 8.4 Auto-Trading (Execução Automática por Sinal)
Permitir que o usuário ative a execução automática de ordens a partir dos sinais gerados pelo Motor de Decisão.

Requisitos:
- Toggle "Operar Automaticamente" por ativo na Watchlist / página do ativo
- Configuração de regras de gatilho:
  - Score mínimo de compra (ex.: >= 70)
  - Score máximo de venda (ex.: <= 30)
  - Horizonte considerado (curto / médio / longo)
  - Grau de confiança mínimo
- Respeitar gestão de risco (lote automático, SL/TP, limites diários)
- Confirmação/Rejeição exibida em tempo real via WebSocket
- Log completo de cada decisão automática (insumos, score, ordem enviada, resultado)
- Modo "Paper Trading" (simulado) e modo "Real"
- Possível pausar / retomar / desativar a qualquer momento
- Notificação push ao executar ordem automática

### 8.5 Gestão de Risco
- Cálculo de lote automático por risco % da banca
- Stop-loss e Take-profit obrigatórios configuráveis
- Limites de drawdown diário / máximo
- Limites de perda diária e semanal
- Bloqueio de operação ao exceder limites

### 8.6 Extensibilidade (futuros conectores — arquitetura preparada)
- MT4
- cTrader
- TradingView Webhooks
- Binance
- Bybit

Construir abstração de `BrokerConnector` para permitir novos provedores sem alterar o núcleo de negócio.

---

## 9. Administração (Painel Super Admin)

**Onde roda:** rota web embutida no app Expo (`/admin`), acessível via navegador, visível só para `super_admin`.

Acesso total à plataforma. Inclui (escopo MVP destacado em **negrito**):
- **Gestão de usuários (listar, suspender, resetar senha, atribuir plano)**
- **Gestão de planos / preços Stripe** (criar/editar planos com Stripe Price ID)
- Gestão de integrações (MT5 tokens, market data APIs; LLM opcional) — Fase 2
- **Visualização de logs** (aplicação, webhook, auditoria)
- **Gestão de cache** (inspeção, invalidação)
- **Métricas / estatísticas** (MAU, MRR, churn, uso por recurso)
- **Parâmetros do motor** (editar pesos técnicos/valuation/sentimento)
- **Gestão de uploads** (enviar/manter `.zip`/`.rar`/`.pdf`/`.ex5`/`.mq5` — ver 9.2)

### 9.1 Super Admin (inicialização)

O sistema deverá possuir um Super Admin com acesso irrestrito, autenticado via JWT + RBAC.

Requisitos:
- Login administrativo isolado de usuários comuns (flag `is_admin` ou rota exclusiva)
- Não depende de assinatura Stripe
- Conta criada automaticamente na primeira inicialização caso não exista
- Credenciais definidas via `.env`

**Variáveis de ambiente:**
```
ADMIN_NAME=
ADMIN_EMAIL=
ADMIN_USERNAME=
ADMIN_PASSWORD=
```

**Credenciais iniciais (primeira execução):**
- Usuário: `Handliv`
- Senha: `samsung12`

> A senha deve ser trocada após o primeiro login. O sistema deve forçar essa troca caso ainda esteja utilizando a senha padrão.

O acesso administrativo é protegido por autenticação JWT e RBAC.

### 9.2 Gestão de Arquivos (Aba de Downloads)

O Super Admin poderá enviar e gerenciar arquivos compactados (`.zip`, `.rar`, `.ex5`, `.mq5`) que ficarão disponíveis para download pelos usuários no app, em uma aba "Downloads / robôs".

#### 9.2.1 Upload (Super Admin)
- Formulário de upload com:
  - Arquivo (`.zip`, `.rar`, `.ex5`, `.mq5`, `.pdf`)
  - Título (ex.: "Robô MT5 — v1.2")
  - Descrição / instruções de instalação
  - Versão (semver obrigatório)
  - Categoria (ex.: `robo_mt5`, `indicador`, `manual`, `outros`)
  - Plano mínimo exigido (Free / Pro / Premium — controle de acesso)
  - Flag `ativo` (publicar/ocultar)
  - Changelog da versão
- Validação de tipo MIME e tamanho máximo (padrão 100 MB, configurável)
- Armazenamento em bucket S3/MinIO ou diretório persistente no servidor
- Versionamento: cada upload de versão substitui o anterior ou cria histórico
- Scan de vírus em uploads (opcional, integração com ClamAV)

#### 9.2.2 Listagem / Download (Cliente)
- Aba "Downloads" no app (acessível via menu)
- Lista apenas arquivos compatíveis com o plano do usuário
- Card por arquivo: título, versão, descrição, tamanho, data, botão "Baixar"
- Indicador de "nova versão" quando há release mais recente que o último baixado
- Registro de cada download (quem, quando, versão) para auditoria
- Link assinado (presigned URL) com expiração curta — nunca expõe caminho direto do servidor

#### 9.2.3 Controle de acesso
- Arquivo marcado como `Premium` só é visível/baixável por usuários Premium
- Arquivo marcado como `Pro` é visível para Pro e Premium
- Arquivo marcado como `Free` é visível para todos
- Se a assinatura do usuário expirar, downloads do nível superior ficam bloqueados, mas os já baixados permanecem no dispositivo do cliente

#### 9.2.4 Notificações
- Push notification ao publicar nova versão para usuários do plano elegível (opt-in)
- Banner "Novo" no card por X dias após publicação

#### 9.2.5 Variáveis de ambiente
```
UPLOADS_DRIVER=local          # local | s3 | minio
UPLOADS_BASE_DIR=./storage/uploads
UPLOADS_MAX_SIZE_MB=100
UPLOADS_ALLOWED_EXT=zip,rar,ex5,mq5,pdf
S3_ENDPOINT=
S3_BUCKET=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_REGION=
```

---

## 10. Segurança

- Senhas com BCrypt (cost >= 12)
- JWT assinado (HS256 ou RS256), expiração curta no access token
- Refresh tokens hashed at rest
- HTTPS obrigatório em produção
- Rate Limiting por IP e por usuário
- Validação de entrada com Pydantic
- Proteção XSS / SQL Injection (ORM parametrizado, OWASP)
- Auditoria de ações sensíveis (login, execução de ordem, alteração de plano)
- Rotação de chaves (Stripe, MT5, market data APIs); LLM pago opcional
- Segredos nunca expostos ao front-end
- **Soft delete de usuário**: conta excluída fica 30 dias (janela de auditoria), depois apagada permanentemente. Logs mantidos 90 dias
- **Reset de senha via Gmail SMTP** (link/token de uso único, expira em 30 min)

---

## 11. Arquitetura / Estrutura

- **Clean Architecture** e **SOLID**
- Tipagem forte (TypeScript + Python type hints + mypy)
- Providers abstraídos para APIs externas (market data, Stripe, MT5); IA via libs Python locais (sem token)
- Separação em camadas: `domain`, `application`, `infrastructure`, `presentation`
- Documentação OpenAPI gerada automaticamente pelo FastAPI
- **Testes (MVP): unitários no backend** com pytest (motor, valuation, indicadores, cálculos de score). Frontend sem testes no MVP
- **CI/CD: adiado** para a Fase 2 (sem pipeline no MVP — dev roda lint/testes local)
- **i18n: PT-BR + EN** no app (frontend) — IA local sempre em PT-BR
- **Tema: dark + light** com toggle persistente (NativeWind)

---

## 12. Escopo de Entregas (MVP — Fase 1)

1. **Autenticação** — email/senha (BCrypt), JWT access+refresh, RBAC `user`/`super_admin`, reset via Gmail SMTP. **Sem** OAuth social, **sem** double opt-in
2. **Landing page** bilingue (PT-BR + EN), dark+light, com fluxo: Landing → auth → app
3. **Stripe** — checkout hospedado, Free sem cartão, **sem trial**, webhooks + controle por plano
4. **Dashboard** (4 tabs: Dashboard / Mercados / Busca / Perfil) com heatmap, ranking, watchlist vazia + sugeridos, favoritos, alertas de preço e de score, gráficos linha+velas, onboarding 4 telas, i18n, tema dark+light
5. **Página do ativo** (B3 + EUA) na ordem: Preço → Gráfico → Indicadores → Valuation (com DCF simplificado) → Notícias (RSS PT-BR + EN) → Score + IA local em PT-BR
6. **Motor de decisão v1** — técnico + valuation + sentimento (libs Python locais, **sem token**). Atualizado **2x/dia** via Celery + cache Redis. WebSocket só notifica UI quando cache muda
7. **IA local** — resumir notícias, explicar score, explicar indicadores, insights em PT-BR (regras/templates + transformers/pysentimento)
8. **Backtesting v1** — período configurável, sem custos, métricas + curves + export PDF/CSV
9. **Painel admin** (Expo Web `/admin`) — usuários, planos Stripe, logs, cache, métricas, pesos do motor, uploads
10. **Downloads** — upload (Super Admin, 100 MB) + aba de downloads (cliente) com presigned URL, controle por plano, notificação push
11. **Notificações push** via Expo Notifications (alertas + nova versão de arquivo)
12. **Testes unitários backend** (pytest no domínio/motor)

**Fora do MVP (Fase 2):**
- MT5 completo (EA + boleta + gestão de risco + Auto-Trading)
- Forex / Cripto / Commodities
- Conectores adicionais (MT4, cTrader, TradingView, Binance, Bybit)
- LLM pago opcional para enriquecimento de texto
- CI/CD (GitHub Actions)
- Testes de integração e E2E

---

## 13. Variáveis de Ambiente (.env)

```
# App
APP_ENV=development|production
APP_SECRET=

# Database
DATABASE_URL=
REDIS_URL=

# JWT
JWT_SECRET=
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30

# Stripe
STRIPE_SECRET_KEY=
STRIPE_PUBLISHABLE_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PRICE_FREE=
STRIPE_PRICE_PRO=
STRIPE_PRICE_PREMIUM=

# Admin (bootstrap)
ADMIN_NAME=
ADMIN_EMAIL=
ADMIN_USERNAME=
ADMIN_PASSWORD=

# SMTP (reset de senha via Gmail)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=seu_email@gmail.com
SMTP_PASSWORD=app_password_16_chars
SMTP_FROM=no-reply@handliv.com

# Push (Expo Notifications)
EXPO_ACCESS_TOKEN=

# Market Data
MARKET_DATA_PROVIDER=yfinance   # yfinance (free, sem key) | brapi | alpha_vantage | polygon | finnhub | twelve_data

# IA / NLP (libs Python locais — sem token)
# Nenhuma variável obrigatória. LLM pago é OPCIONAL:
LLM_PROVIDER=disabled            # disabled | openai | anthropic (não obrigatório)
LLM_API_KEY=

# MT5
MT5_API_BASE_URL=
MT5_API_TOKEN=

# Uploads / Downloads (aba de robôs e manuais)
UPLOADS_DRIVER=local               # local | s3 | minio
UPLOADS_BASE_DIR=./storage/uploads
UPLOADS_MAX_SIZE_MB=100
UPLOADS_ALLOWED_EXT=zip,rar,ex5,mq5,pdf
```

---

## 14. Estado da implementação (Scaffold MVP)

Implementação inicial já disponível no repositório:

| Componente | Arquivos principais | Status |
|---|---|---|
| Backend FastAPI | `backend/app/main.py`, `presentation/routers/*` | ✅ 43 endpoints expostos via OpenAPI |
| Config + Settings | `app/config.py` | ✅ Pydantic Settings, lê `.env` |
| Database | `infrastructure/database/{base,session,bootstrap,models/*}` | ✅ 18 tabelas mapeadas |
| Alembic | `alembic/versions/0001_initial_schema.py` | ✅ migration inicial |
| Auth | `presentation/routers/auth.py`, `domain/security.py` | ✅ JWT, refresh, RBAC, reset via SMTP |
| Stripe | `presentation/routers/subscriptions.py` | ✅ checkout + portal + webhook |
| Assets | `presentation/routers/assets.py` | ✅ lista, detalhe, preço, indicators, news, score |
| Motor de decisão | `domain/decision_engine.py` | ✅ votação de RSI/MACD/EMA/ADX/Stoch/BB/SuperTrend |
| IA local | `domain/local_ai.py` | ✅ explicação determinística em PT-BR |
| Watchlist / Alerts | `presentation/routers/{watchlist,alerts}.py` | ✅ completo + sugeridos |
| Backtests | `presentation/routers/backtests.py` + `tasks/run_backtest.py` | ✅ enfileira via Celery usando backtesting.py |
| Files / Downloads | `presentation/routers/files.py` | ✅ upload 100MB + presigned + controle por plano |
| Admin | `presentation/routers/admin.py` | ✅ usuários, logs, cache, métricas, pesos, planos |
| Notifications | `presentation/routers/notifications.py` | ✅ listagem, marcação, push token |
| WebSocket | `presentation/routers/ws.py` | ✅ notificação de cache/score (sem tick) |
| Celery | `infrastructure/queue/{celery_app,tasks/*}` | ✅ fetch prices 2x/dia + scores + RSS + backtest |
| Provider yfinance | `infrastructure/providers/market_data/yfinance_provider.py` | ✅ OHLCV + info + quote |
| Email SMTP | `infrastructure/providers/email/smtp_gmail.py` | ✅ async aiosmtplib |
| Frontend Expo | `frontend/app/**`, `frontend/src/**` | ✅ scaffold com 4 tabs + auth + ativo + admin |
| Docker | `docker-compose.yml`, `backend/Dockerfile`, `frontend/Dockerfile` | ✅ MySQL + Redis + backend + worker + beat + web |

### Como validar
```bash
cp .env.example .env                 # ajustar STRIPE/SMTP conforme necessário
docker compose up -d --build
# backend: http://localhost:8000/docs
# frontend: http://localhost:8080
```

Mesmo sem DB/Redis disponíveis, o backend sobe e responde em `/api/v1/health` (bootstrap do Super Admin falha graciosamente e tenta novamente via job imprevisível).

### Próximos passos sugeridos
- Conectar a um MySQL real, rodar `alembic upgrade head`, e validar o bootstrap do Super Admin `Handliv / samsung12` (trocar senha no 1º login)
- Configurar chaves Stripe em modo `test` e validar fluxo checkout → webhook → ativação de plano
- Implementar tasks de sentimento (`pysentimento`, `transformers`) sobre as `news_articles` cadastradas (pipeline está pronto, falta o step de NLP)
- Preencher `assets` com ativos da B3/EUSA viaCelery seed task (a partir de `SUGGESTED_ASSETS`)
- Frontend: completar telas (Dashboard com watchlist, gráficos linha+velas com React Native Skia, onboarding 4 telas, i18n PT-BR/EN)
- Testes unitários dos casos críticos (motor, valuation, hash token, RBAC)