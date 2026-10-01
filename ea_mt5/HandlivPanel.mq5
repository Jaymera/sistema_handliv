//+------------------------------------------------------------------+
//|                                                 HandlivPanel.mq5 |
//|                                  Copyright 2026 - Handliv(R)     |
//|                                       https://handliv.com        |
//+------------------------------------------------------------------+
//| Painel de Trading Handliv - comunica com o site app.handliv.com  |
//|                                                                  |
//| Como funciona:                                                   |
//|  1. No site (aba Robo -> Painel de Execucao MT5) o usuario       |
//|     clica em COMPRAR / VENDER / FECHAR.                          |
//|  2. Este EA consulta a API (1x por segundo) e recebe o comando.  |
//|  3. O EA executa a ordem no MT5 e devolve o resultado ao site.   |
//|                                                                  |
//| Requisitos:                                                      |
//|  - Conta MT5 cadastrada no site (aba Robo -> Contas MT5)         |
//|  - URL da API liberada em:                                       |
//|    Ferramentas -> Opcoes -> Expert Advisors -> Allow WebRequest  |
//|    adicionar: https://api.handliv.com  (ou o host da sua API)    |
//+------------------------------------------------------------------+
#property copyright   "2026 - Handliv(R)"
#property link        "https://handliv.com"
#property version     "1.00"
#property description "Painel de Trading Handliv - executa no MT5 os comandos enviados pelo site (comprar/vender/fechar)"
#property strict

#include <Trade/Trade.mqh>

input group "== API Handliv =="
 string InpApiUrl      = "https://api.handliv.com/api/v1"; // API Base URL
 string InpApiToken    = "6rsUNfHCWh0mj2nDEJG8OP3ZMlpbYXoR";                                // Secret (MT5_API_TOKEN do backend)
input int    InpPollSeconds = 1;                                 // Intervalo de consulta (segundos)
input int    InpStatsSeconds = 30;                               // Intervalo de envio de estatisticas (segundos)

input group "== Painel local =="
input double InpVolume      = 0.10;   // Volume padrao (lotes)
input string InpSymbol      = "";     // Ativo (vazio = ativo do grafico)
input ulong  InpMagic       = 20260817; // Magic Number
input int    InpSlippage    = 10;     // Desvio maximo (points)

CTrade   trade;
string   g_symbol;
datetime g_lastPoll = 0;
datetime g_lastStats = 0;
bool     g_apiOk    = false;
string   g_status   = "Conectando...";
double   g_peakEquity = 0.0;   // pico de equity (para calculo do drawdown)

// Painel
#define PNL_NAME   "HLVPNL"
#define BTN_BUY    "HLV_BTN_BUY"
#define BTN_SELL   "HLV_BTN_SELL"
#define BTN_CLOSE  "HLV_BTN_CLOSE"

//+------------------------------------------------------------------+
//| SHA256 hex (token do EA: SHA256(conta + secret))                 |
//+------------------------------------------------------------------+
string Sha256Hex(const string text)
{
   uchar src[], key[], dst[];
   StringToCharArray(text, src, 0, StringLen(text));
   StringToCharArray("", key, 0, 0);
   if(CryptEncode(CRYPT_HASH_SHA256, src, key, dst) <= 0) return "";
   string hex = "";
   for(int i = 0; i < ArraySize(dst); i++)
      hex += StringFormat("%02x", dst[i]);
   return hex;
}

string AccountToken()
{
   return Sha256Hex(IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + InpApiToken);
}

//+------------------------------------------------------------------+
//| HTTP                                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Traduz erros de WebRequest do terminal (sem ecoar o corpo da resposta) |
//+------------------------------------------------------------------+
string HttpErrorHelp(const int code)
{
   switch(code)
   {
      case 4014: return " | ERRO 4014: libere " + InpApiUrl + " em Ferramentas > Opcoes > Expert Advisors > Allow WebRequest";
      case 4060: return " | ERRO 4060: sem resposta da API. Verifique a URL, firewall/proxy e se a API esta online";
      case 4051: return " | ERRO 4051: WebRequest desabilitado nas opcoes do terminal";
      case 4063: return " | ERRO 4063: WebRequest nao permitido para este EA";
      case 4071: return " | ERRO 4071: nao foi possivel abrir a conexao com a API";
      default:   return " | erro WebRequest " + IntegerToString(code);
   }
}

bool HttpGet(const string url, string &response)
{
   string headers = "Content-Type: application/json\r\n";
   char   post[]; char result[]; string resultHeaders;
   ResetLastError();
   int code = WebRequest("GET", url, headers, 5000, post, result, resultHeaders);
   if(code == -1)
   {
      g_status = "WebRequest bloqueado (erro " + IntegerToString(GetLastError()) + "). Libere a URL nas opcoes do MT5.";
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
   string headers = "Content-Type: application/json\r\n";
   char   post[]; char result[]; string resultHeaders;
   ResetLastError();
   // Alguns builds incluem o terminador NUL no retorno; JSON com byte extra
   // e rejeitado pelo parser da API antes de validar o token.
   int size = StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   if(size > 0 && post[size - 1] == 0) size--;
   // O overload com headers envia ArraySize(post) bytes (nao aceita data_size).
   // Nunca enviar um corpo vazio: isso produz 422 missing antes da autenticacao.
   if(size <= 0 || ArrayResize(post, size) != size)
   {
      g_status = "POST local | corpo vazio ou conversao UTF-8 falhou";
      Print("HandlivPanel POST recusado localmente: ", g_status,
            " chars=", StringLen(json), " bytes=", size, " endpoint=", url);
      return false;
   }
   int code = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(code == -1 || code >= 400)
   {
      // FastAPI 422 retorna detail[].type/msg. Nao imprimir response inteiro:
      // erros de validacao podem conter o corpo original com token.
      string kind = JsonGetString(response, "type");
      string reason = JsonGetString(response, "msg");
      int err = (code == -1) ? GetLastError() : 0;
      g_status = "POST HTTP " + IntegerToString(code) +
                 (code == -1 ? HttpErrorHelp(err) :
                 (kind != "" ? " | " + kind : "") +
                 (reason != "" ? " | " + StringSubstr(reason, 0, 90) : ""));
      Print("HandlivPanel POST falhou: ", g_status, " endpoint=", url);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Mini parser JSON (valores simples de chave)                      |
//+------------------------------------------------------------------+
string JsonGetString(const string json, const string key)
{
   string needle = "\"" + key + "\":";
   int p = StringFind(json, needle);
   if(p < 0) return "";
   p += StringLen(needle);
   // pula espacos
   while(p < StringLen(json) && (StringGetCharacter(json, p) == ' ')) p++;
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
//| Execucao de ordens                                               |
//+------------------------------------------------------------------+
bool ExecuteBuy(const string symbol, double volume)
{
   trade.SetExpertMagicNumber(InpMagic);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(ask <= 0) { SymbolSelect(symbol, true); ask = SymbolInfoDouble(symbol, SYMBOL_ASK); }
   if(ask <= 0) return false;
   bool ok = trade.Buy(NormalizeVolume(symbol, volume), symbol, ask, 0, 0, "HandlivPanel");
   return ok && trade.ResultRetcode() == TRADE_RETCODE_DONE;
}

bool ExecuteSell(const string symbol, double volume)
{
   trade.SetExpertMagicNumber(InpMagic);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0) { SymbolSelect(symbol, true); bid = SymbolInfoDouble(symbol, SYMBOL_BID); }
   if(bid <= 0) return false;
   bool ok = trade.Sell(NormalizeVolume(symbol, volume), symbol, bid, 0, 0, "HandlivPanel");
   return ok && trade.ResultRetcode() == TRADE_RETCODE_DONE;
}

bool ExecuteClose(const string symbol)
{
   bool all = (symbol == "" || symbol == NULL);
   bool any = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(!all && posSymbol != symbol) continue;
      if(trade.PositionClose(ticket, InpSlippage)) any = true;
   }
   return any;
}

double NormalizeVolume(const string symbol, double volume)
{
   double min  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   volume = MathMax(min, MathMin(max, volume));
   volume = MathRound(volume / step) * step;
   return NormalizeDouble(volume, 2);
}

//+------------------------------------------------------------------+
//| Reporta resultado ao site                                        |
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
//| Estatisticas: P/L por periodo a partir do historico de trades    |
//+------------------------------------------------------------------+
double HistoryProfit(datetime from, datetime to)
{
   if(!HistorySelect(from, to)) return 0.0;
   double total = 0.0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      long t = HistoryDealGetInteger(ticket, DEAL_TIME);
      if(t < from || t >= to) continue;
      double p = HistoryDealGetDouble(ticket, DEAL_PROFIT)
               + HistoryDealGetDouble(ticket, DEAL_SWAP)
               + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      total += p;
   }
   return total;
}

void CountWinLoss(int &wins, int &losses)
{
   wins = 0; losses = 0;
   datetime from = 0;
   datetime to   = TimeCurrent() + 86400;
   if(!HistorySelect(from, to)) return;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      double p = HistoryDealGetDouble(ticket, DEAL_PROFIT)
               + HistoryDealGetDouble(ticket, DEAL_SWAP)
               + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      if(p >= 0) wins++; else losses++;
   }
}

//+------------------------------------------------------------------+
//| Coleta e envia estatisticas da conta para o site                 |
//+------------------------------------------------------------------+
int FindRobotMagic(const ulong magic, const ulong &robotMagics[], const int count)
{
   for(int i = 0; i < count; i++) if(robotMagics[i] == magic) return i;
   return -1;
}

string RobotStatsJson()
{
   ulong magics[256];
   int opened[256], wins[256], losses[256], count = 0;
   double floating[256], realized[256];
   string symbols[256];
   if(InpMagic > 0)
   {
      magics[0] = InpMagic; opened[0] = 0; wins[0] = 0; losses[0] = 0;
      floating[0] = 0; realized[0] = 0; symbols[0] = ""; count = 1;
   }
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i); if(ticket == 0) continue;
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC); if(magic == 0) continue;
      int at = FindRobotMagic(magic, magics, count);
      if(at < 0 && count < 256)
      {
         at = count++; magics[at] = magic; opened[at] = 0; wins[at] = 0;
         losses[at] = 0; floating[at] = 0; realized[at] = 0; symbols[at] = "";
      }
      if(at < 0) continue;
      opened[at]++;
      floating[at] += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbols[at] == "") symbols[at] = symbol;
      else if(symbols[at] != symbol) symbols[at] = "*";
   }
   if(HistorySelect(0, TimeCurrent() + 86400))
   {
      for(int j = 0; j < HistoryDealsTotal(); j++)
      {
         ulong ticket = HistoryDealGetTicket(j); if(ticket == 0) continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         ulong magic = (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC); if(magic == 0) continue;
         int at = FindRobotMagic(magic, magics, count);
         if(at < 0 && count < 256)
         {
            at = count++; magics[at] = magic; opened[at] = 0; wins[at] = 0;
            losses[at] = 0; floating[at] = 0; realized[at] = 0; symbols[at] = "";
         }
         if(at < 0) continue;
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         realized[at] += profit;
         if(profit >= 0) wins[at]++; else losses[at]++;
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         if(symbols[at] == "") symbols[at] = symbol;
         else if(symbols[at] != symbol) symbols[at] = "*";
      }
   }
   string result = "[";
   for(int k = 0; k < count; k++)
   {
      if(k > 0) result += ",";
      string symbol = "null";
      if(symbols[k] != "" && symbols[k] != "*")
      {
         string safe = symbols[k];
         StringReplace(safe, "\\", "\\\\"); StringReplace(safe, "\"", "\\\"");
         symbol = "\"" + safe + "\"";
      }
      result += StringFormat("{\"magic\":\"%I64u\",\"symbol\":%s,\"open_positions\":%d,"
         "\"floating_pl\":%.2f,\"profit_total\":%.2f,\"total_trades\":%d,"
         "\"win_trades\":%d,\"loss_trades\":%d,\"history_scope\":\"account_history\",\"heartbeat\":%s}",
         magics[k], symbol, opened[k], floating[k], realized[k], wins[k]+losses[k],
         wins[k], losses[k], magics[k] == InpMagic ? "true" : "false");
   }
   return result + "]";
}

void SendStats()
{
   datetime now  = TimeCurrent();
   datetime day0 = StringToTime(TimeToString(now, TIME_DATE));           // 00:00 de hoje
   MqlDateTime mq;
   TimeToStruct(now, mq);
   mq.hour = 0; mq.min = 0; mq.sec = 0;
   datetime week0 = StructToTime(mq) - ((mq.day_of_week + 6) % 7) * 86400; // segunda-feira 00:00
   mq.day = 1;
   datetime month0 = StructToTime(mq);                                    // dia 1 do mes 00:00

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Drawdown: acompanha o pico de equity desde o inicio do EA
   if(equity > g_peakEquity) g_peakEquity = equity;
   double dd = 0.0;
   if(g_peakEquity > 0) dd = (g_peakEquity - equity) / g_peakEquity * 100.0;

   int wins = 0, losses = 0;
   CountWinLoss(wins, losses);

   // Mesmo contrato do MT4, sem formatador variadico para o objeto completo.
   // Um unico StringFormat aninhado pode devolver corpo vazio e derrubar o envio.
   string json = "{\"account\":\"" + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) +
      "\",\"login\":\"" + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) +
      "\",\"token\":\"" + AccountToken() +
      "\",\"currency\":\"" + AccountInfoString(ACCOUNT_CURRENCY) + "\"," +
      "\"equity\":" + DoubleToString(equity, 2) +
      ",\"balance\":" + DoubleToString(balance, 2) +
      ",\"margin\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) +
      ",\"margin_level\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2) +
      ",\"floating_pl\":" + DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2) +
      ",\"dd_percent\":" + DoubleToString(dd, 2) +
      ",\"profit_day\":" + DoubleToString(HistoryProfit(day0, now + 60), 2) +
      ",\"profit_week\":" + DoubleToString(HistoryProfit(week0, now + 60), 2) +
      ",\"profit_month\":" + DoubleToString(HistoryProfit(month0, now + 60), 2) +
      ",\"profit_total\":" + DoubleToString(HistoryProfit(0, now + 60), 2) +
      ",\"win_trades\":" + IntegerToString(wins) +
      ",\"loss_trades\":" + IntegerToString(losses) +
      ",\"total_trades\":" + IntegerToString(wins + losses) +
      ",\"open_positions\":" + IntegerToString(PositionsTotal()) +
      ",\"robots\":" + RobotStatsJson() + "}";
   string resp;
   if(HttpPost(InpApiUrl + "/mt5/ea/stats", json, resp))
      g_status = "Stats OK " + TimeToString(now, TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Consulta comandos pendentes                                      |
//+------------------------------------------------------------------+
void PollCommands(){
   string url = InpApiUrl + "/mt5/ea/commands?account=" +
                IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) +
                "&token=" + AccountToken();
   string resp;
   if(!HttpGet(url, resp)) { g_apiOk = false; UpdatePanel(); return; }
   g_apiOk = true;

   // Percorre cada objeto do array "items"
   int pos = 0;
   while(true)
   {
      int start = StringFind(resp, "{\"id\":", pos);
      if(start < 0) break;
      int end = StringFind(resp, "}", start);
      if(end < 0) break;
      string item = StringSubstr(resp, start, end - start + 1);
      pos = end + 1;

      string id     = JsonGetString(item, "id");
      string action = JsonGetString(item, "action");
      string symbol = JsonGetString(item, "symbol");
      double volume = JsonGetDouble(item, "volume");
      if(id == "" || action == "") continue;

      // symbol vazio -> ativo do painel
      if(symbol == "" || symbol == NULL) symbol = g_symbol;
      else SymbolSelect(symbol, true);

      Print("HandlivPanel: comando do site -> ", action, " ", symbol, " ", volume);

      bool   ok = false;
      string msg = "";
      if(action == "buy")
      {
         ok = ExecuteBuy(symbol, volume <= 0 ? InpVolume : volume);
         msg = ok ? "compra executada " + symbol + " " + DoubleToString(volume, 2)
                  : "falha na compra: " + IntegerToString((int)trade.ResultRetcode());
      }
      else if(action == "sell")
      {
         ok = ExecuteSell(symbol, volume <= 0 ? InpVolume : volume);
         msg = ok ? "venda executada " + symbol + " " + DoubleToString(volume, 2)
                  : "falha na venda: " + IntegerToString((int)trade.ResultRetcode());
      }
      else if(action == "close")
      {
         ok = ExecuteClose(symbol);
         msg = ok ? "posicoes fechadas" + (symbol != "" ? " " + symbol : "")
                  : "nenhuma posicao para fechar";
      }
      ReportResult(id, ok, msg);
      g_status = (action == "buy" ? "COMPRA" : action == "sell" ? "VENDA" : "FECHAR") +
                 (ok ? " OK " : " FALHOU ") + TimeToString(TimeCurrent(), TIME_SECONDS);
   }
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| Painel visual                                                    |
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

void PanelText(const string name, int x, int y, const string text, color clr, int size = 10)
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
   PanelText("HLV_TITLE", 20, 28, "HANDLIV PAINEL", C'22,211,154', 10);
   PanelText("HLV_ACC",   20, 50, "Conta: " + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)), C'233,239,249', 9);
   PanelText("HLV_STATUS",20, 68, g_status, C'149,166,195', 8);
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
      Alert("Informe o MT5_API_TOKEN (secret) nas configuracoes do EA. Contate a Handliv.");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_symbol = (InpSymbol == "" ? _Symbol : InpSymbol);
   SymbolSelect(g_symbol, true);

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(g_symbol);

   g_peakEquity = MathMax(AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoDouble(ACCOUNT_BALANCE));

   CreatePanel();
   EventSetTimer(MathMax(1, InpPollSeconds));
   Print("HandlivPanel iniciado. Conta=", AccountInfoInteger(ACCOUNT_LOGIN), " API=", InpApiUrl);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
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
      // Reset visual do botao
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      bool ok = false;
      if(sparam == BTN_BUY)        ok = ExecuteBuy(g_symbol, InpVolume);
      else if(sparam == BTN_SELL)  ok = ExecuteSell(g_symbol, InpVolume);
      else                         ok = ExecuteClose(g_symbol);
      g_status = (sparam == BTN_BUY ? "COMPRA" : sparam == BTN_SELL ? "VENDA" : "FECHAR") +
                 (ok ? " OK" : " FALHOU") + " " + TimeToString(TimeCurrent(), TIME_SECONDS);
      UpdatePanel();
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+
