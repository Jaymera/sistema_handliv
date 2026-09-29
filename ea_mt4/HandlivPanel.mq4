//+------------------------------------------------------------------+
//|                                                 HandlivPanel.mq4 |
//|                                  Copyright 2026 - Handliv(R)     |
//|                                       https://handliv.com        |
//+------------------------------------------------------------------+
//| Painel de Trading Handliv (MetaTrader 4) - comunica com o site    |
//| app.handliv.com                                                  |
//|                                                                  |
//| Como funciona:                                                   |
//|  1. No site (aba Robo -> Painel de Execucao) o usuario           |
//|     clica em COMPRAR / VENDER / FECHAR.                          |
//|  2. Este EA consulta a API (1x por segundo) e recebe o comando.  |
//|  3. O EA executa a ordem no MT4 e devolve o resultado ao site.   |
//|                                                                  |
//| Este arquivo e a conversao do HandlivPanel.mq5 para MT4.         |
//| Mesma API, mesmas entradas, mesmo painel e mesmo token do MT5.   |
//|                                                                  |
//| Requisitos:                                                      |
//|  - Conta MT4 cadastrada no site (aba Robo -> Contas)             |
//|  - URL da API liberada em:                                       |
//|    Ferramentas -> Opcoes -> Expert Advisors -> Allow WebRequest  |
//|    adicionar: https://api.handliv.com  (ou o host da sua API)    |
//|                                                                  |
//| Diferencas inevitaveis do MT5 para o MT4 (mesmo comportamento     |
//| funcional, outra API):                                           |
//|  - SHA256 implementado no proprio EA (MT4 nao tem CryptEncode)   |
//|  - Ordens via OrderSend/OrderClose (MT4 nao tem a classe CTrade)  |
//|  - Estatisticas de P/L lidas em OrdersHistory (MT4 nao tem deals) |
//+------------------------------------------------------------------+
#property copyright "2026 - Handliv(R)"
#property link      "https://handliv.com"
#property version   "1.00"
#property description "Painel de Trading Handliv - executa no MT4 os comandos enviados pelo site (comprar/vender/fechar)"
#property strict

//== API Handliv ======================================================
extern string InpApiUrl       = "https://api.handliv.com/api/v1"; // API Base URL
extern string InpApiToken     = "6rsUNfHCWh0mj2nDEJG8OP3ZMlpbYXoR"; // Secret (API token do backend)
extern int    InpPollSeconds  = 1;    // Intervalo de consulta (segundos)
extern int    InpStatsSeconds = 30;   // Intervalo de envio de estatisticas (segundos)

//== Painel local =====================================================
extern double InpVolume        = 0.10;    // Volume padrao (lotes)
extern string InpSymbol        = "";      // Ativo (vazio = ativo do grafico)
extern int    InpMagic         = 20260817; // Magic Number
extern int    InpSlippage      = 10;      // Desvio maximo (points)
extern bool   InpCloseOnlyMagic = true;   // FECHAR apenas ordens deste EA (recomendado)

//== Estado interno ===================================================
string   g_symbol;
datetime g_lastPoll  = 0;
datetime g_lastStats = 0;
bool     g_apiOk    = false;
string   g_status   = "Conectando...";
double   g_peakEquity = 0.0; // pico de equity (para calculo do drawdown)
int      g_lastError  = 0;   // ultimo erro de trade (exibido no painel)

//== Painel ==========================================================
#define PNL_NAME   "HLVPNL"
#define BTN_BUY    "HLV_BTN_BUY"
#define BTN_SELL   "HLV_BTN_SELL"
#define BTN_CLOSE  "HLV_BTN_CLOSE"

//+------------------------------------------------------------------+
//| SHA256 (implementacao propria: MT4 nao possui CryptEncode)        |
//| O token do EA e SHA256(conta + secret) em hex, igual ao MT5.     |
//+------------------------------------------------------------------+
uint Ror32(uint x, int n)
{
   return (x >> n) | (x << (32 - n));
}

void Sha256K(uint &k[])
{
   k[ 0]=0x428a2f98; k[ 1]=0x71374491; k[ 2]=0xb5c0fbcf; k[ 3]=0xe9b5dba5;
   k[ 4]=0x3956c25b; k[ 5]=0x59f111f1; k[ 6]=0x923f82a4; k[ 7]=0xab1c5ed5;
   k[ 8]=0xd807aa98; k[ 9]=0x12835b01; k[10]=0x243185be; k[11]=0x550c7dc3;
   k[12]=0x72be5d74; k[13]=0x80deb1fe; k[14]=0x9bdc06a7; k[15]=0xc19bf174;
   k[16]=0xe49b69c1; k[17]=0xefbe4786; k[18]=0x0fc19dc6; k[19]=0x240ca1cc;
   k[20]=0x2de92c6f; k[21]=0x4a7484aa; k[22]=0x5cb0a9dc; k[23]=0x76f988da;
   k[24]=0x983e5152; k[25]=0xa831c66d; k[26]=0xb00327c8; k[27]=0xbf597fc7;
   k[28]=0xc6e00bf3; k[29]=0xd5a79147; k[30]=0x06ca6351; k[31]=0x14292967;
   k[32]=0x27b70a85; k[33]=0x2e1b2138; k[34]=0x4d2c6dfc; k[35]=0x53380d13;
   k[36]=0x650a7354; k[37]=0x766a0abb; k[38]=0x81c2c92e; k[39]=0x92722c85;
   k[40]=0xa2bfe8a1; k[41]=0xa81a664b; k[42]=0xc24b8b70; k[43]=0xc76c51a3;
   k[44]=0xd192e819; k[45]=0xd6990624; k[46]=0xf40e3585; k[47]=0x106aa070;
   k[48]=0x19a4c116; k[49]=0x1e376c08; k[50]=0x2748774c; k[51]=0x34b0bcb5;
   k[52]=0x391c0cb3; k[53]=0x4ed8aa4a; k[54]=0x5b9cca4f; k[55]=0x682e6ff3;
   k[56]=0x748f82ee; k[57]=0x78a5636f; k[58]=0x84c87814; k[59]=0x8cc70208;
   k[60]=0x90befffa; k[61]=0xa4506ceb; k[62]=0xbef9a3f7; k[63]=0xc67178f2;
}

void Sha256Init(uint &h[])
{
   h[0]=0x6a09e667; h[1]=0xbb67ae85; h[2]=0x3c6ef372; h[3]=0xa54ff53a;
   h[4]=0x510e527f; h[5]=0x9b05688c; h[6]=0x1f83d9ab; h[7]=0x5be0cd19;
}

//--- SHA-256 (FIPS 180-4). Estado de 32 bits: 8 words.
void Sha256Block(uint &h[], const uchar &block[], int offset)
{
   uint k[64], w[64];
   uint a, b, c, d, e, f, g, hh, v, s0, s1, t1, t2;
   int i, j;
   Sha256K(k);
   for(i = 0; i < 64; i++) w[i] = 0;   // evita "possible use of uninitialized variable"
   for(i = 0; i < 16; i++)
   {
      v = 0;
      for(j = 0; j < 4; j++) v = (v << 8) | (uint)block[offset + i * 4 + j];
      w[i] = v;
   }
   for(i = 16; i < 64; i++)
   {
      s0 = Ror32(w[i-15], 7) ^ Ror32(w[i-15], 18) ^ (w[i-15] >> 3);
      s1 = Ror32(w[i-2], 17) ^ Ror32(w[i-2], 19)  ^ (w[i-2]  >> 10);
      w[i] = w[i-16] + s0 + w[i-7] + s1;
   }
   a=h[0]; b=h[1]; c=h[2]; d=h[3]; e=h[4]; f=h[5]; g=h[6]; hh=h[7];
   for(i = 0; i < 64; i++)
   {
      s1 = Ror32(e, 6) ^ Ror32(e, 11) ^ Ror32(e, 25);
      t1 = hh + s1 + ((e & f) ^ ((~e) & g)) + k[i] + w[i];
      s0 = Ror32(a, 2) ^ Ror32(a, 13) ^ Ror32(a, 22);
      t2 = s0 + ((a & b) ^ (a & c) ^ (b & c));
      hh = g; g = f; f = e; e = d + t1;
      d  = c; c = b; b = a; a = t1 + t2;
   }
   h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d; h[4]+=e; h[5]+=f; h[6]+=g; h[7]+=hh;
}

//--- SHA256 hex minusculo (mesmo formato do CryptEncode do MT5)
string Sha256Hex(const string text)
{
   uchar  src[];
   uchar  last[128];
   uint   h[8];
   ulong  bits;
   string hex = "";
   int    len, full, rest, total, off, i;

   Sha256Init(h);
   for(i = 0; i < 128; i++) last[i] = 0;   // padding sem lixo da pilha
   len  = StringToCharArray(text, src, 0, StringLen(text));
   full = len - (len % 64);
   for(off = 0; off < full; off += 64) Sha256Block(h, src, off);

   rest = len - full;
   for(i = 0; i < rest; i++)          last[i] = src[full + i];
   last[rest] = 0x80;                  // bit '1' do padding
   total = (rest < 56) ? 64 : 128;     // 56 = 64 - 8 (tamanho em bits)
   for(i = rest + 1; i < total; i++)  last[i] = 0;
   bits = ((ulong)len) * 8;            // tamanho do texto em bits (big endian)
   for(i = 0; i < 8; i++)             last[total - 1 - i] = (uchar)((bits >> (8 * i)) & 0xFF);
   Sha256Block(h, last, 0);
   if(total == 128) Sha256Block(h, last, 64);

   for(i = 0; i < 8; i++) hex += StringFormat("%08x", h[i]);
   return hex;
}

string AccountToken()
{
   return Sha256Hex(IntegerToString(AccountNumber()) + InpApiToken);
}

//+------------------------------------------------------------------+
//| HTTP                                                              |
//| Assinatura real do MQL4 (confirmada pelo compilador):              |
//|   int WebRequest(method, url, referer, headers, timeout,           |
//|                 data, data_size, result, result_headers)          |
//| Nao existe 'cookie' nem 'result_size'; 'result' e char& e a        |
//| funcao redimensiona o buffer internamente.                         |
//+------------------------------------------------------------------+
#define HTTP_TIMEOUT 5000

bool HttpGet(const string url, string &response)
{
   string headers  = "Content-Type: application/json\r\n";
   string referer  = InpApiUrl + "/";
   string resultHeaders = "";
   char   post[], result[];
   int    code;

   ResetLastError();
   ArrayResize(post, 0);                // GET sem corpo
   code = WebRequest("GET", url, referer, headers, HTTP_TIMEOUT,
                     post, 0, result, resultHeaders);
   if(code == -1)
   {
      g_status = "WebRequest bloqueado (erro " + IntegerToString(GetLastError()) + "). Libere a URL nas opcoes do MT4.";
      return false;
   }
   if(code != 200)
   {
      g_status = "HTTP " + IntegerToString(code);
      return false;
   }
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return true;
}

bool HttpPost(const string url, const string json, string &response)
{
   string headers  = "Content-Type: application/json\r\n";
   string referer  = InpApiUrl + "/";
   string resultHeaders = "";
   char   post[], result[];
   int    code, size;

   ResetLastError();
   size = StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   code = WebRequest("POST", url, referer, headers, HTTP_TIMEOUT,
                     post, size, result, resultHeaders);
   if(code == -1 || code >= 400)
   {
      Print("HandlivPanel POST falhou HTTP ", code, " url=", url);
      return false;
   }
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return true;
}

//+------------------------------------------------------------------+
//| Mini parser JSON (mesmo do MT5)                                  |
//+------------------------------------------------------------------+
string JsonGetString(const string json, const string key)
{
   string needle = "\"" + key + "\":";
   int p = StringFind(json, needle);
   if(p < 0) return "";
   p += StringLen(needle);
   while(p < StringLen(json) && StringGetCharacter(json, p) == ' ') p++;
   if(StringGetCharacter(json, p) == '"')
   {
      int e = StringFind(json, "\"", p + 1);
      if(e > p) return StringSubstr(json, p + 1, e - p - 1);
      return "";
   }
   int e = p;
   while(e < StringLen(json))
   {
      ushort c = StringGetCharacter(json, e);
      if(c == ',' || c == '}' || c == ']') break;
      e++;
   }
   return StringSubstr(json, p, e - p);
}

double JsonGetDouble(const string json, const string key)
{
   return StringToDouble(JsonGetString(json, key));
}

//+------------------------------------------------------------------+
//| Execucao de ordens (equivalente ao CTrade do MT5)                |
//+------------------------------------------------------------------+
string ErrorText(const int code)
{
   switch(code)
   {
      case 0:    return "sem erro";
      case 1:    return "sem mudanca de preco";
      case 4:    return "servidor ocupado";
      case 6:    return "conexao perdida";
      case 8:    return "requotes muito frequentes";
      case 64:   return "conta bloqueada";
      case 65:   return "login invalido";
      case 128:  return "tempo esgotado";
      case 129:  return "preco invalido";
      case 130:  return "stops invalidos";
      case 131:  return "volume invalido";
      case 132:  return "mercado fechado";
      case 133:  return "negociacao proibida neste ativo";
      case 134:  return "dinheiro insuficiente";
      case 135:  return "preco mudou";
      case 136:  return "sem cotacao";
      case 137:  return "broker ocupado";
      case 138:  return "requote";
      case 139:  return "ordem bloqueada";
      case 145:  return "modificacao negada (ordem muito proxima)";
      case 146:  return "ordem nao permitida";
      case 147:  return "prazo expirado";
      case 148:  return "ordens demais";
      case 4051: return "funcao nao permitida";
      case 4109: return "negociacao nao permitida";
      case 4110: return "ordem longa proibida";
      case 4111: return "ordem curta proibida";
      case 4756: return "ordem rejeitada pelo broker";
      case 4757: return "ordre rejeitada (sem dinheiro)";
      case 4758: return "ordem rejeitada (bloqueada)";
      case 4759: return "ordem rejeitada (somente expert/EA)";
      case 4760: return "ordem rejeitada (bloqueio de tempo)";
      case 4761: return "ordem rejeitada (bloqueio de volume)";
      case 4762: return "ordem rejeitada (bloqueio de preco)";
      case 4763: return "ordem rejeitada (bloqueio de stops)";
      case 4764: return "ordem rejeitada (trailing stop)";
      case 4765: return "ordem rejeitada (expiracao)";
      case 4766: return "ordem rejeitada (negociacao bloqueada)";
      case 4767: return "ordem rejeitada (mercado muito rapido)";
      case 4768: return "ordem rejeitada (sem preco)";
      case 4769: return "ordem rejeitada (sistema ocupado)";
      default:   return "erro " + IntegerToString(code);
   }
}

double NormalizeVolume(const string symbol, double volume)
{
   double minL  = MarketInfo(symbol, MODE_MINLOT);
   double maxL  = MarketInfo(symbol, MODE_MAXLOT);
   double step  = MarketInfo(symbol, MODE_LOTSTEP);
   int    digits = 2;
   if(step <= 0) step = 0.01;
   volume = MathMax(minL, MathMin(maxL, volume));
   volume = MathRound(volume / step) * step;
   if(step >= 1.0)      digits = 0;
   else if(step >= 0.1) digits = 1;
   else if(step < 0.01) digits = 3;
   return NormalizeDouble(volume, digits);
}

bool ExecuteBuy(const string symbol, double volume)
{
   double ask, lot;
   int    ticket;
   RefreshRates();
   ask = MarketInfo(symbol, MODE_ASK);
   if(ask <= 0)
   {
      g_status = "Sem cotacao de compra em " + symbol;
      return false;
   }
   lot = NormalizeVolume(symbol, volume);
   ResetLastError();
   ticket = OrderSend(Symbol(), OP_BUY, lot, ask, InpSlippage, 0, 0,
                      "HandlivPanel", InpMagic, 0, clrGreen);
   g_lastError = GetLastError();
   if(ticket < 0)
   {
      g_status = "Falha na compra: " + ErrorText(g_lastError);
      return false;
   }
   g_status = "Compra executada " + symbol + " " + DoubleToString(lot, 2);
   return true;
}

bool ExecuteSell(const string symbol, double volume)
{
   double bid, lot;
   int    ticket;
   RefreshRates();
   bid = MarketInfo(symbol, MODE_BID);
   if(bid <= 0)
   {
      g_status = "Sem cotacao de venda em " + symbol;
      return false;
   }
   lot = NormalizeVolume(symbol, volume);
   ResetLastError();
   ticket = OrderSend(Symbol(), OP_SELL, lot, bid, InpSlippage, 0, 0,
                      "HandlivPanel", InpMagic, 0, clrRed);
   g_lastError = GetLastError();
   if(ticket < 0)
   {
      g_status = "Falha na venda: " + ErrorText(g_lastError);
      return false;
   }
   g_status = "Venda executada " + symbol + " " + DoubleToString(lot, 2);
   return true;
}

//--- Fecha as ordens do simbolo. Por padrao apenas as deste EA:
//--- no MT4, contas FIFO nao permitem escolher qual ordem fechar, entao
//--- filtrar pelo Magic evita fechar ordens de outros EAs.
bool ExecuteClose(const string symbol)
{
   bool all   = (symbol == "");
   bool any   = false;
   int  total = OrdersTotal();
   RefreshRates();
   g_lastError = 0;

   for(int i = total - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!all && OrderSymbol() != symbol) continue;
      if(InpCloseOnlyMagic && OrderMagicNumber() != InpMagic) continue;
      double price = (OrderType() == OP_BUY) ? MarketInfo(OrderSymbol(), MODE_BID)
                                             : MarketInfo(OrderSymbol(), MODE_ASK);
      ResetLastError();
      if(OrderClose(OrderTicket(), OrderLots(), price, InpSlippage, clrYellow))
         any = true;
      else
         g_lastError = GetLastError();
   }
   if(any) g_status = "Posicoes fechadas" + (all ? "" : " " + symbol);
   else     g_status = (g_lastError > 0 ? "Falha ao fechar: " + ErrorText(g_lastError)
                                        : "Nenhuma posicao para fechar");
   return any;
}

//+------------------------------------------------------------------+
//| Reporta resultado ao site (mesmo endpoint do MT5)                |
//+------------------------------------------------------------------+
void ReportResult(const string id, bool success, const string message)
{
   string json = StringFormat(
      "{\"id\":\"%s\",\"token\":\"%s\",\"success\":%s,\"message\":\"%s\"}",
      id, AccountToken(), success ? "true" : "false", message);
   string resp;
   HttpPost(InpApiUrl + "/mt5/ea/results", json, resp);
}

//+------------------------------------------------------------------+
//| Estatisticas: P/L por periodo a partir do historico de ordens    |
//| MT4 nao possui historico de deals (deals e so MT5), portanto o   |
//| P/L fechado e lido das ordens fechadas (OrderProfit).            |
//+------------------------------------------------------------------+
datetime DayStart(const datetime t)  { return StringToTime(TimeToStr(t, TIME_DATE) + " 00:00"); }

datetime WeekStart(const datetime t)
{
   // segunda-feira 00:00 da semana corrente
   int dow = TimeDayOfWeek(t); // 0 domingo .. 6 sabado
   if(dow == 0) dow = 7;
   return DayStart(t) - (dow - 1) * 86400;
}

datetime MonthStart(const datetime t)
{
   return StringToTime(IntegerToString(TimeYear(t)) + "." +
                       (TimeMonth(t) < 10 ? "0" : "") + IntegerToString(TimeMonth(t)) + ".01 00:00");
}

double HistoryProfit(const datetime from, const datetime to)
{
   double total = 0.0;
   int    n = OrdersHistoryTotal();
   for(int i = 0; i < n; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      datetime closed = OrderCloseTime();
      if(closed < from || closed >= to) continue;
      total += OrderProfit() + OrderCommission() + OrderSwap();
   }
   return total;
}

void CountWinLoss(int &wins, int &losses)
{
   wins = 0; losses = 0;
   int n = OrdersHistoryTotal();
   for(int i = 0; i < n; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      double p = OrderProfit() + OrderCommission() + OrderSwap();
      if(p >= 0) wins++; else losses++;
   }
}

//+------------------------------------------------------------------+
//| Coleta e envia estatisticas da conta para o site                 |
//+------------------------------------------------------------------+
void SendStats()
{
   datetime now  = TimeCurrent();
   datetime day0   = DayStart(now);
   datetime week0  = WeekStart(now);
   datetime month0 = MonthStart(now);

   double equity  = AccountEquity();
   double balance = AccountBalance();
   double margin  = AccountMargin();
   double floating = AccountProfit();
   double mlevel  = (margin > 0) ? equity / margin * 100.0 : 0.0;

   // Drawdown: acompanha o pico de equity desde o inicio do EA
   if(equity > g_peakEquity) g_peakEquity = equity;
   double dd = 0.0;
   if(g_peakEquity > 0) dd = (g_peakEquity - equity) / g_peakEquity * 100.0;

   int wins = 0, losses = 0;
   CountWinLoss(wins, losses);

   string json = StringFormat(
      "{\"account\":\"%s\",\"login\":\"%s\",\"token\":\"%s\","
      "\"currency\":\"%s\","
      "\"equity\":%.2f,\"balance\":%.2f,"
      "\"margin\":%.2f,\"margin_level\":%.2f,\"floating_pl\":%.2f,"
      "\"dd_percent\":%.2f,"
      "\"profit_day\":%.2f,\"profit_week\":%.2f,\"profit_month\":%.2f,\"profit_total\":%.2f,"
      "\"win_trades\":%d,\"loss_trades\":%d,\"total_trades\":%d,\"open_positions\":%d}",
      IntegerToString(AccountNumber()),
      IntegerToString(AccountNumber()),
      AccountToken(),
      AccountCurrency(),
      equity, balance,
      margin, mlevel, floating,
      dd,
      HistoryProfit(day0, now + 60),
      HistoryProfit(week0, now + 60),
      HistoryProfit(month0, now + 60),
      HistoryProfit(0, now + 60),
      wins, losses, wins + losses,
      OrdersTotal());
   string resp;
   if(HttpPost(InpApiUrl + "/mt5/ea/stats", json, resp))
      g_status = "Stats OK " + TimeToStr(now, TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Consulta comandos pendentes (1x por segundo)                     |
//+------------------------------------------------------------------+
void PollCommands()
{
   string url = InpApiUrl + "/mt5/ea/commands?account=" +
                IntegerToString(AccountNumber()) +
                "&token=" + AccountToken();
   string resp;
   int    pos, start, end;

   if(!HttpGet(url, resp)) { g_apiOk = false; UpdatePanel(); return; }
   g_apiOk = true;

   // Percorre cada objeto do array "items" (mesmo parser do MT5)
   pos = 0;
   while(true)
   {
      start = StringFind(resp, "{\"id\":", pos);
      if(start < 0) break;
      end = StringFind(resp, "}", start);
      if(end < 0) break;
      string item = StringSubstr(resp, start, end - start + 1);
      pos = end + 1;

      string id     = JsonGetString(item, "id");
      string action = JsonGetString(item, "action");
      string symbol = JsonGetString(item, "symbol");
      double volume = JsonGetDouble(item, "volume");
      if(id == "" || action == "") continue;

      // symbol vazio -> ativo do painel
      if(symbol == "") symbol = g_symbol;

      Print("HandlivPanel: comando do site -> ", action, " ", symbol, " ", volume);

      bool   ok = false;
      string msg = "";
      if(action == "buy")
      {
         ok = ExecuteBuy(symbol, volume <= 0 ? InpVolume : volume);
         msg = ok ? "compra executada " + symbol : "falha na compra: " + IntegerToString(g_lastError);
      }
      else if(action == "sell")
      {
         ok = ExecuteSell(symbol, volume <= 0 ? InpVolume : volume);
         msg = ok ? "venda executada " + symbol : "falha na venda: " + IntegerToString(g_lastError);
      }
      else if(action == "close")
      {
         ok = ExecuteClose(symbol);
         msg = ok ? "posicoes fechadas" + (symbol != "" ? " " + symbol : "")
                  : "nenhuma posicao para fechar";
      }
      ReportResult(id, ok, msg);
      g_status = (action == "buy" ? "COMPRA" : action == "sell" ? "VENDA" : "FECHAR") +
                 (ok ? " OK " : " FALHOU ") + TimeToStr(TimeCurrent(), TIME_SECONDS);
   }
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| Painel visual (identico ao MT5)                                  |
//+------------------------------------------------------------------+
void PanelRect(const string name, int x, int y, int w, int h, color bg)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void PanelText(const string name, int x, int y, const string text, color clr, int size)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void PanelButton(const string name, int x, int y, int w, int h, const string text, color bg)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreatePanel()
{
   PanelRect(PNL_NAME, 10, 20, 240, 120, C'10,17,32');
   PanelText("HLV_TITLE",  20, 28, "HANDLIV PAINEL", C'22,211,154', 10);
   PanelText("HLV_ACC",    20, 50, "Conta: " + IntegerToString(AccountNumber()), C'233,239,249', 9);
   PanelText("HLV_STATUS", 20, 68, g_status, C'149,166,195', 8);
   PanelButton(BTN_BUY,   20, 88, 66, 36, "COMPRAR", C'22,199,132');
   PanelButton(BTN_SELL,  92, 88, 66, 36, "VENDER",  C'234,57,67');
   PanelButton(BTN_CLOSE, 164, 88, 76, 36, "FECHAR", C'245,166,35');
}

void UpdatePanel()
{
   PanelText("HLV_STATUS", 20, 68,
             (g_apiOk ? "API OK" : "API OFF") + " | " + g_status,
             g_apiOk ? C'149,166,195' : C'234,57,67', 8);
}

void DeletePanel()
{
   ObjectDelete(0, PNL_NAME);
   ObjectDelete(0, "HLV_TITLE");
   ObjectDelete(0, "HLV_ACC");
   ObjectDelete(0, "HLV_STATUS");
   ObjectDelete(0, BTN_BUY);
   ObjectDelete(0, BTN_SELL);
   ObjectDelete(0, BTN_CLOSE);
}

//+------------------------------------------------------------------+
//| Eventos                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpApiToken == "")
   {
      Alert("Informe o API token (secret) nas configuracoes do EA. Contate a Handliv.");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_symbol = (InpSymbol == "" ? Symbol() : InpSymbol);
   RefreshRates();
   g_peakEquity = MathMax(AccountEquity(), AccountBalance());

   CreatePanel();
   EventSetTimer(MathMax(1, InpPollSeconds));
   Print("HandlivPanel MT4 iniciado. Conta=", AccountNumber(), " API=", InpApiUrl);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
}

void OnTick()
{
   // Mantem o painel vivo mesmo sem timer rodando
   UpdatePanel();
}

void OnTimer()
{
   datetime now = TimeCurrent();
   if(now - g_lastPoll >= MathMax(1, InpPollSeconds))
   {
      g_lastPoll = now;
      PollCommands();
   }
   if(now - g_lastStats >= MathMax(5, InpStatsSeconds))
   {
      g_lastStats = now;
      SendStats();
   }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam == BTN_BUY || sparam == BTN_SELL || sparam == BTN_CLOSE)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      bool ok = false;
      if(sparam == BTN_BUY)        ok = ExecuteBuy(g_symbol, InpVolume);
      else if(sparam == BTN_SELL)  ok = ExecuteSell(g_symbol, InpVolume);
      else                         ok = ExecuteClose(g_symbol);
      g_status = (sparam == BTN_BUY ? "COMPRA" : sparam == BTN_SELL ? "VENDA" : "FECHAR") +
                 (ok ? " OK" : " FALHOU") + " " + TimeToStr(TimeCurrent(), TIME_SECONDS);
      UpdatePanel();
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+
