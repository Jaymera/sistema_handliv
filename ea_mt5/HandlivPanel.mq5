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
input string InpApiUrl      = "https://api.handliv.com/api/v1"; // API Base URL
input string InpApiToken    = "";                                // Secret (MT5_API_TOKEN do backend)
input int    InpPollSeconds = 1;                                 // Intervalo de consulta (segundos)

input group "== Painel local =="
input double InpVolume      = 0.10;   // Volume padrao (lotes)
input string InpSymbol      = "";     // Ativo (vazio = ativo do grafico)
input ulong  InpMagic       = 20260817; // Magic Number
input int    InpSlippage    = 10;     // Desvio maximo (points)

CTrade   trade;
string   g_symbol;
datetime g_lastPoll = 0;
bool     g_apiOk    = false;
string   g_status   = "Conectando...";

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
   uchar src[], dst[];
   StringToCharArray(text, src, 0, StringLen(text));
   if(CryptEncode(CRYPT_SHA256, src, src, dst) <= 0) return "";
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
   StringToCharArray(json, post, 0, StringLen(json));
   int code = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);
   if(code == -1 || code >= 400)
   {
      Print("HandlivPanel POST falhou HTTP ", code, " url=", url);
      return false;
   }
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
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
//| Consulta comandos pendentes                                      |
//+------------------------------------------------------------------+
void PollCommands()
{
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
   if(TimeCurrent() - g_lastPoll < MathMax(1, InpPollSeconds)) return;
   g_lastPoll = TimeCurrent();
   PollCommands();
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
