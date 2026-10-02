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

input bool InpAllowAutomation = false; // Local opt-in; never enabled by installation

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
      string kind = JsonErrorField(response, "type");
      string reason = JsonErrorField(response, "msg");
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
// Automation v1: fail closed, opt-in, dedicated magic, no automatic closes.
#define AUTOMATION_MAGIC 20261002

bool JsonSpace(const int c) { return c == 32 || c == 9 || c == 10 || c == 13; }

bool JsonNumber(const string s)
{
   int n = StringLen(s), p = 0;
   if(n == 0) return false;
   if(StringGetCharacter(s, p) == 45) p++;
   if(p >= n) return false;
   if(StringGetCharacter(s, p) == 48) p++;
   else
   {
      int begin = p;
      while(p < n && StringGetCharacter(s,p) >= 48 && StringGetCharacter(s,p) <= 57) p++;
      if(begin == p) return false;
   }
   if(p < n && StringGetCharacter(s,p) == 46)
   {
      p++; int begin = p;
      while(p < n && StringGetCharacter(s,p) >= 48 && StringGetCharacter(s,p) <= 57) p++;
      if(begin == p) return false;
   }
   if(p < n && (StringGetCharacter(s,p) == 101 || StringGetCharacter(s,p) == 69))
   {
      p++;
      if(p < n && (StringGetCharacter(s,p) == 43 || StringGetCharacter(s,p) == 45)) p++;
      int begin = p;
      while(p < n && StringGetCharacter(s,p) >= 48 && StringGetCharacter(s,p) <= 57) p++;
      if(begin == p) return false;
   }
   return p == n;
}

// Parse a flat serializer-produced object, validate the WHOLE object, and reject
// duplicate keys/nested objects. Missing/invalid are distinct from JSON false.
string JsonRawField(const string json, const string wanted)
{
   int n = StringLen(json), p = 0;
   string result = "!MISSING", seen = "|";
   while(p < n && JsonSpace(StringGetCharacter(json,p))) p++;
   if(p >= n || StringGetCharacter(json,p++) != 123) return "!INVALID";
   while(true)
   {
      while(p < n && JsonSpace(StringGetCharacter(json,p))) p++;
      if(p >= n) return "!INVALID";
      if(StringGetCharacter(json,p) == 125)
      {
         p++;
         while(p < n && JsonSpace(StringGetCharacter(json,p))) p++;
         return p == n ? result : "!INVALID";
      }
      if(StringGetCharacter(json,p++) != 34) return "!INVALID";
      int begin = p;
      while(p < n && StringGetCharacter(json,p) != 34)
      {
         int c = StringGetCharacter(json,p);
         if(c < 32 || c == 92 || c == 124) return "!INVALID";
         p++;
      }
      if(p >= n) return "!INVALID";
      string key = StringSubstr(json,begin,p-begin); p++;
      if(StringFind(seen,"|" + key + "|") >= 0) return "!INVALID";
      seen += key + "|";
      while(p < n && JsonSpace(StringGetCharacter(json,p))) p++;
      if(p >= n || StringGetCharacter(json,p++) != 58) return "!INVALID";
      while(p < n && JsonSpace(StringGetCharacter(json,p))) p++;
      begin = p;
      if(p < n && StringGetCharacter(json,p) == 34)
      {
         p++;
         while(p < n && StringGetCharacter(json,p) != 34)
         {
            int c = StringGetCharacter(json,p++);
            if(c < 32) return "!INVALID";
            if(c == 92)
            {
               if(p >= n) return "!INVALID";
               c = StringGetCharacter(json,p++);
               if(c == 117)
               {
                  for(int j=0;j<4;j++)
                  {
                     if(p >= n) return "!INVALID";
                     c = StringGetCharacter(json,p++);
                     if(!((c>=48 && c<=57)||(c>=65 && c<=70)||(c>=97 && c<=102))) return "!INVALID";
                  }
               }
               else if(c!=34 && c!=92 && c!=47 && c!=98 && c!=102 && c!=110 && c!=114 && c!=116) return "!INVALID";
            }
         }
         if(p >= n) return "!INVALID";
         p++;
      }
      else
      {
         while(p < n && !JsonSpace(StringGetCharacter(json,p)) && StringGetCharacter(json,p)!=44 && StringGetCharacter(json,p)!=125) p++;
         string value = StringSubstr(json,begin,p-begin);
         if(value!="true" && value!="false" && value!="null" && !JsonNumber(value)) return "!INVALID";
      }
      if(key == wanted) result = StringSubstr(json,begin,p-begin);
      while(p < n && JsonSpace(StringGetCharacter(json,p))) p++;
      if(p >= n) return "!INVALID";
      if(StringGetCharacter(json,p)==125) continue;
      if(StringGetCharacter(json,p++)!=44) return "!INVALID";
      while(p < n && JsonSpace(StringGetCharacter(json,p))) p++;
      if(p >= n || StringGetCharacter(json,p)==125) return "!INVALID";
   }
   return "!INVALID";
}

string RawString(const string raw)
{
   int n = StringLen(raw);
   if(n < 2 || StringGetCharacter(raw,0)!=34 || StringGetCharacter(raw,n-1)!=34 || StringFind(raw,"\\")>=0) return "";
   return StringSubstr(raw,1,n-2);
}

bool ValidUuid(const string s)
{
   if(StringLen(s)!=36) return false;
   for(int i=0;i<36;i++)
   {
      int c=StringGetCharacter(s,i);
      if(i==8 || i==13 || i==18 || i==23) { if(c!=45) return false; }
      else if(!((c>=48 && c<=57)||(c>=65 && c<=70)||(c>=97 && c<=102))) return false;
   }
   return true;
}

// API ISO UTC: whole seconds or 1..6 fractional digits, Z or +00:00 only.
// Fraction is conservatively discarded (can expire less than a second early).
datetime UtcExpiry(const string s)
{
   int n=StringLen(s);
   if(n<20) return 0;
   for(int i=0;i<19;i++)
   {
      int c=StringGetCharacter(s,i);
      if(i==4 || i==7) { if(c!=45) return 0; }
      else if(i==10) { if(c!=84) return 0; }
      else if(i==13 || i==16) { if(c!=58) return 0; }
      else if(c<48 || c>57) return 0;
   }
   int p=19;
   if(StringGetCharacter(s,p)==46)
   {
      p++; int begin=p;
      while(p<n && StringGetCharacter(s,p)>=48 && StringGetCharacter(s,p)<=57) p++;
      if(p-begin<1 || p-begin>6) return 0;
   }
   string zone=StringSubstr(s,p);
   if(zone!="Z" && zone!="+00:00") return 0;
   string canonical=StringSubstr(s,0,19);
   StringReplace(canonical,"-","."); StringReplace(canonical,"T"," ");
   datetime t=StringToTime(canonical);
   if(t<=0 || TimeToString(t,TIME_DATE|TIME_SECONDS)!=canonical) return 0;
   return t;
}

bool ExactVolume(const double volume, const double minLot, const double maxLot, const double step)
{
   if(!MathIsValidNumber(volume) || !MathIsValidNumber(minLot) || !MathIsValidNumber(maxLot) || !MathIsValidNumber(step)) return false;
   if(minLot<=0 || maxLot<minLot || step<=0 || volume<minLot || volume>maxLot) return false;
   double units=volume/step;
   return MathAbs(units-MathRound(units))<=1e-8;
}

bool ExactBrokerSymbol(const string symbol)
{
   if(symbol=="") return false;
   for(int i=0;i<SymbolsTotal(false);i++)
      if(SymbolName(i,false)==symbol) return SymbolSelect(symbol,true);
   return false;
}

// ATR14/H1 protection is mandatory on the INITIAL automatic order.
bool ProtectionParameters(const string item)
{
   if(JsonRawField(item,"stop_mode")!="\"atr\"" || JsonRawField(item,"atr_period")!="14" || JsonRawField(item,"atr_timeframe")!="\"H1\"") return false;
   string sl=RawString(JsonRawField(item,"sl_atr_multiplier"));
   string tp=RawString(JsonRawField(item,"tp_atr_multiplier"));
   if(!JsonNumber(sl) || !JsonNumber(tp)) return false;
   double a=StringToDouble(sl), b=StringToDouble(tp);
   return MathIsValidNumber(a) && MathIsValidNumber(b) && a>=0.1 && a<=20 && b>=0.1 && b<=20;
}

// Round OUTWARD to the broker tick lattice, then digits; never move SL/TP
// through the entry or below required stop/freeze distance to force acceptance.
double ProtectionPrice(const string action, const bool stop, const double entry, const double atr, const double multiplier, const double tick, const int digits)
{
   if((action!="buy" && action!="sell") || !MathIsValidNumber(entry) || !MathIsValidNumber(atr) || !MathIsValidNumber(multiplier) || !MathIsValidNumber(tick)) return 0;
   if(entry<=0 || atr<=0 || multiplier<0.1 || multiplier>20 || tick<=0 || digits<0 || digits>8) return 0;
   bool above=(action=="buy" && !stop) || (action=="sell" && stop);
   double price=entry+(above ? 1 : -1)*atr*multiplier;
   if(!MathIsValidNumber(price) || price<=0) return 0;
   price=(above ? MathCeil(price/tick) : MathFloor(price/tick))*tick;
   return NormalizeDouble(price,digits);
}

bool ProtectionPair(const string action, const double entry, const double bid, const double ask, const double sl, const double tp, const double minDistance, const double tick)
{
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(bid) || !MathIsValidNumber(ask) || !MathIsValidNumber(sl) || !MathIsValidNumber(tp) || !MathIsValidNumber(minDistance) || !MathIsValidNumber(tick)) return false;
   if(entry<=0 || bid<=0 || ask<bid || sl<=0 || tp<=0 || minDistance<0 || tick<=0) return false;
   if(MathAbs(sl/tick-MathRound(sl/tick))>1e-7 || MathAbs(tp/tick-MathRound(tp/tick))>1e-7) return false;
   if(action=="buy") return sl<entry && tp>entry && bid-sl>=minDistance && tp-bid>=minDistance;
   if(action=="sell") return sl>entry && tp<entry && sl-ask>=minDistance && ask-tp>=minDistance;
   return false;
}

bool g_automationProtectionFault=false;
int g_activeCommandClaim=-1;
string ProtectionFaultPath() { return "HandlivProtectionFault_"+CommandScope()+".lock"; }
bool ProtectionHealthy()
{
   return !g_automationProtectionFault && !FileIsExist(ProtectionFaultPath(),FILE_COMMON);
}

void ProtectionFault()
{
   // Never auto-clear this circuit breaker on restart. Operator reconciliation
   // is required if the broker reports success but protection cannot be verified.
   g_automationProtectionFault=true;
   if(g_activeCommandClaim>=0) { FileWriteString(g_activeCommandClaim,Sha256Hex("AUTOMATION_PROTECTION_HALT")+"\r\n"); FileFlush(g_activeCommandClaim); }
   int h=FileOpen(ProtectionFaultPath(),FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h!=INVALID_HANDLE) { FileWriteString(h,"protection verification failed\r\n"); FileFlush(h); FileClose(h); }
   g_status="automation protection missing/unverified; disabled for reconciliation";
}

string g_automationSymbols[];
int g_automationCounts[];
bool g_automationSnapshotComplete=true;
void ResetAutomationSnapshot()
{
   ArrayResize(g_automationSymbols,0); ArrayResize(g_automationCounts,0);
   g_automationSnapshotComplete=true;
}
void CollectAutomationSymbol(const string symbol)
{
   int n=ArraySize(g_automationSymbols);
   for(int i=0;i<n;i++) if(g_automationSymbols[i]==symbol) { g_automationCounts[i]++; return; }
   if(ArrayResize(g_automationSymbols,n+1)!=n+1 || ArrayResize(g_automationCounts,n+1)!=n+1) { g_automationSnapshotComplete=false; return; }
   g_automationSymbols[n]=symbol; g_automationCounts[n]=1;
}
string AutomationPositionsJson()
{
   if(!g_automationSnapshotComplete) return "null"; // never advertise incomplete data as flat
   string json="[";
   for(int i=0;i<ArraySize(g_automationSymbols);i++)
   {
      if(i>0) json+=",";
      string safe=g_automationSymbols[i];
      StringReplace(safe,"\\","\\\\"); StringReplace(safe,"\"","\\\"");
      json+="{\"symbol\":\""+safe+"\",\"open_positions\":"+IntegerToString(g_automationCounts[i])+"}";
   }
   return json+"]";
}

// Return 0 manual, 1 valid automation, -1 malformed/unsafe automation.
int AutomationValidate(const string item, const string action, const string symbol, const double volume)
{
   string mode=JsonRawField(item,"automation");
   if(mode=="!INVALID") return -1;
   if(mode=="!MISSING" || mode=="false")
   {
      string rule=JsonRawField(item,"rule_id"), magic=JsonRawField(item,"magic"), expiry=JsonRawField(item,"expires_at");
      if((rule!="!MISSING" && rule!="null") || (magic!="!MISSING" && magic!="null") || (expiry!="!MISSING" && expiry!="null")) return -1;
      string fields[5]; fields[0]="stop_mode"; fields[1]="atr_period"; fields[2]="atr_timeframe"; fields[3]="sl_atr_multiplier"; fields[4]="tp_atr_multiplier";
      for(int i=0;i<5;i++)
      {
         string raw=JsonRawField(item,fields[i]);
         if(raw!="!MISSING" && raw!="null") return -1;
      }
      return 0;
   }
   if(mode!="true" || !ProtectionParameters(item) || !AutomationReady() || (action!="buy" && action!="sell")) return -1;
   if(!ValidUuid(RawString(JsonRawField(item,"id"))) || !ValidUuid(RawString(JsonRawField(item,"rule_id")))) return -1;
   if(JsonRawField(item,"magic")!="\"20261002\"") return -1;
   datetime expiry=UtcExpiry(RawString(JsonRawField(item,"expires_at")));
   if(expiry==0 || expiry<=TimeGMT()) return -1;
   if(RawString(JsonRawField(item,"symbol"))!=symbol || !ExactBrokerSymbol(symbol)) return -1;
   if(!JsonNumber(JsonRawField(item,"volume")) || !AutomationVolume(symbol,volume)) return -1;
   return 1;
}

// Durable, account-scoped, exclusive FILE_COMMON append-only claim journal.
// No FILE_SHARE flags: hold this lock until trade execution finishes, including
// occupancy recheck. Consume BEFORE execution: crash/timeout is never retried.
// No expiring terminal globals (which would lose dedup after four idle weeks).
// A partial/corrupt record or unavailable file fails closed; never auto-truncate.
int CommandClaim(const string id)
{
   if(!ValidUuid(id)) return -1;
   string scope=CommandScope();
   string digest=Sha256Hex(id);
   if(StringLen(scope)!=64 || StringLen(digest)!=64) return -1;
   int handle=FileOpen("HandlivClaims_"+scope+".txt",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(handle==INVALID_HANDLE) return -1;
   if(FileSize(handle)%66!=0) { FileClose(handle); return -1; }
   while(!FileIsEnding(handle))
   {
      string line=FileReadString(handle);
      if(StringLen(line)!=64) { FileClose(handle); return -1; }
      for(int i=0;i<64;i++)
      {
         int c=StringGetCharacter(line,i);
         if(!((c>=48 && c<=57)||(c>=97 && c<=102))) { FileClose(handle); return -1; }
      }
      if(line==Sha256Hex("AUTOMATION_PROTECTION_HALT")) { FileClose(handle); return -1; }
      if(line==digest) { FileClose(handle); return -2; }
   }
   if(!FileSeek(handle,0,SEEK_END)) { FileClose(handle); return -1; }
   ResetLastError();
   uint written=FileWriteString(handle,digest+"\r\n");
   FileFlush(handle);
   if(written!=66 || GetLastError()!=0) { FileClose(handle); return -1; }
   return handle;
}

// Array scanner independent of key order/JSON spacing; braces in strings are safe.
string NextCommandItem(const string json, int &pos)
{
   if(pos==0)
   {
      int items=StringFind(json,"\"items\"");
      if(items<0) return "";
      pos=StringFind(json,"[",items);
      if(pos<0) return "";
      pos++;
   }
   int n=StringLen(json);
   while(pos<n && (JsonSpace(StringGetCharacter(json,pos)) || StringGetCharacter(json,pos)==44)) pos++;
   if(pos>=n || StringGetCharacter(json,pos)!=123) return "";
   int begin=pos, depth=0; bool quoted=false, escaped=false;
   for(;pos<n;pos++)
   {
      int c=StringGetCharacter(json,pos);
      if(quoted)
      {
         if(escaped) escaped=false;
         else if(c==92) escaped=true;
         else if(c==34) quoted=false;
         continue;
      }
      if(c==34) quoted=true;
      else if(c==123) depth++;
      else if(c==125)
      {
         depth--;
         if(depth==0) { pos++; return StringSubstr(json,begin,pos-begin); }
      }
   }
   return "";
}

string CommandScope()
{
   return Sha256Hex("mt5|"+AccountInfoString(ACCOUNT_SERVER)+"|"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
}

bool AutomationVolume(const string symbol, const double volume)
{
   return ExactVolume(volume,SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP));
}

bool AutomationOccupied(const string symbol)
{
   bool netting=AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetTicket(i)==0) return true;
      if(PositionGetString(POSITION_SYMBOL)==symbol && (netting || PositionGetInteger(POSITION_MAGIC)==AUTOMATION_MAGIC)) return true;
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(OrderGetTicket(i)==0) return true;
      if(OrderGetString(ORDER_SYMBOL)==symbol && (netting || OrderGetInteger(ORDER_MAGIC)==AUTOMATION_MAGIC)) return true;
   }
   return false;
}

// All broker timestamps below are SERVER time, never mixed with UTC expiry.
// Observe a server tick AFTER attachment before accepting an automation order;
// TimeCurrent can freeze offline. Local elapsed time bounds that observation.
datetime g_observedServerClock=0;
datetime g_serverAdvanceLocal=0;
bool BrokerClockFresh()
{
   datetime serverNow=TimeCurrent(), localNow=TimeLocal();
   if(g_observedServerClock==0 || serverNow<g_observedServerClock)
   { g_observedServerClock=serverNow; g_serverAdvanceLocal=0; return false; }
   if(serverNow>g_observedServerClock) { g_observedServerClock=serverNow; g_serverAdvanceLocal=localNow; }
   return g_serverAdvanceLocal>0 && localNow>=g_serverAdvanceLocal && localNow-g_serverAdvanceLocal<=90;
}

bool FreshBrokerTimes(const datetime serverNow, const datetime quoteTime, const datetime closedBarTime)
{
   if(serverNow<=0 || quoteTime<=0 || closedBarTime<=0 || quoteTime>serverNow) return false;
   if(serverNow-quoteTime>90) return false;
   return serverNow-closedBarTime>=3600 && serverNow-closedBarTime<=7290;
}

double ClosedCandleAtr(const string symbol)
{
   if(Bars(symbol,PERIOD_H1)<16) return 0;
   MqlTick quote;
   if(!SymbolInfoTick(symbol,quote) || !FreshBrokerTimes(TimeCurrent(),quote.time,iTime(symbol,PERIOD_H1,1))) return 0;
   int h=iATR(symbol,PERIOD_H1,14);
   if(h==INVALID_HANDLE) return 0;
   double values[];
   int copied=CopyBuffer(h,0,1,1,values); // broker CLOSED candle, never forming bar
   IndicatorRelease(h);
   if(copied!=1 || ArraySize(values)!=1 || !MathIsValidNumber(values[0]) || values[0]<=0) return 0;
   return values[0];
}

bool VerifyAutomationProtection(const string symbol, const long positionId)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetTicket(i)==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==symbol && PositionGetInteger(POSITION_MAGIC)==AUTOMATION_MAGIC && PositionGetInteger(POSITION_IDENTIFIER)==positionId)
         return PositionGetDouble(POSITION_SL)>0 && PositionGetDouble(POSITION_TP)>0;
   }
   return false;
}

bool AutomationExecute(const string item, const string action, const string symbol, const double volume)
{
   if(AutomationValidate(item,action,symbol,volume)!=1 || AutomationOccupied(symbol)) return false;
   CTrade automatic;
   automatic.SetAsyncMode(false);
   automatic.SetExpertMagicNumber(AUTOMATION_MAGIC);
   automatic.SetDeviationInPoints(InpSlippage);
   if(!automatic.SetTypeFillingBySymbol(symbol)) return false;
   double atr=ClosedCandleAtr(symbol);
   MqlTick quote;
   if(!SymbolInfoTick(symbol,quote)) return false;
   if(!BrokerClockFresh() || !FreshBrokerTimes(TimeCurrent(),quote.time,iTime(symbol,PERIOD_H1,1))) return false;
   double price=action=="buy" ? quote.ask : quote.bid;
   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE), point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   long stops=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL), freeze=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   if(!MathIsValidNumber(point) || point<=0 || stops<0 || freeze<0) return false;
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double sl=ProtectionPrice(action,true,price,atr,StringToDouble(RawString(JsonRawField(item,"sl_atr_multiplier"))),tick,digits);
   double tp=ProtectionPrice(action,false,price,atr,StringToDouble(RawString(JsonRawField(item,"tp_atr_multiplier"))),tick,digits);
   if(!ProtectionPair(action,price,quote.bid,quote.ask,sl,tp,MathMax(stops,freeze)*point,tick)) return false;
   if(!AutomationReady() || AutomationOccupied(symbol) || UtcExpiry(RawString(JsonRawField(item,"expires_at")))<=TimeGMT()) return false;
   bool accepted=action=="buy" ? automatic.Buy(volume,symbol,price,sl,tp,"Handliv automation")
      : automatic.Sell(volume,symbol,price,sl,tp,"Handliv automation");
   uint code=automatic.ResultRetcode();
   if(!accepted || (code!=TRADE_RETCODE_DONE && code!=TRADE_RETCODE_DONE_PARTIAL)) return false;
   ulong deal=automatic.ResultDeal();
   if(deal==0 || !HistoryDealSelect(deal) || HistoryDealGetInteger(deal,DEAL_MAGIC)!=AUTOMATION_MAGIC || HistoryDealGetString(deal,DEAL_SYMBOL)!=symbol)
   { ProtectionFault(); return false; }
   long positionId=HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   if(positionId<=0 || !VerifyAutomationProtection(symbol,positionId)) { ProtectionFault(); return false; }
   return true;
}

string JsonGetString(const string json, const string key)
{
   string raw=JsonRawField(json,key);
   if(raw=="!INVALID" || raw=="!MISSING" || raw=="null") return "";
   if(StringLen(raw)>0 && StringGetCharacter(raw,0)==34) return RawString(raw);
   return raw;
}

string JsonErrorField(const string json, const string key)
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
      if(PositionGetInteger(POSITION_MAGIC)==AUTOMATION_MAGIC) continue;
      if(trade.PositionClose(ticket, InpSlippage) && trade.ResultRetcode()==TRADE_RETCODE_DONE) any = true;
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
   ResetAutomationSnapshot();
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
      ulong ticket = PositionGetTicket(i); if(ticket == 0) { g_automationSnapshotComplete=false; continue; }
      if(PositionGetInteger(POSITION_MAGIC)==AUTOMATION_MAGIC) CollectAutomationSymbol(PositionGetString(POSITION_SYMBOL));
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
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderGetTicket(i)==0) { g_automationSnapshotComplete=false; continue; }
      if(OrderGetInteger(ORDER_MAGIC)==AUTOMATION_MAGIC) CollectAutomationSymbol(OrderGetString(ORDER_SYMBOL));
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

bool AutomationReady()
{
   return InpAllowAutomation && ProtectionHealthy() && g_automationSnapshotComplete && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
      TerminalInfoInteger(TERMINAL_CONNECTED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
      AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT) && !IsStopped();
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
   string robots=RobotStatsJson();
   string automationPositions=AutomationPositionsJson();
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
      ",\"robots\":" + robots + ",\"automation_v1\":true,\"automation_protection_v1\":true,\"automation_positions\":" +
      automationPositions + ",\"automation_ready\":" +
      (AutomationReady() ? "true" : "false") + "}";
   string resp;
   if(HttpPost(InpApiUrl + "/mt5/ea/stats", json, resp))
      g_status = "Stats OK " + TimeToString(now, TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Consulta comandos pendentes                                      |
//+------------------------------------------------------------------+
string AutomationPollCapabilities()
{
   return "&automation_v1=1&automation_protection_v1=1&automation_ready=" + (AutomationReady() ? "1" : "0");
}

void PollCommands(){
   string url = InpApiUrl + "/mt5/ea/commands?account=" +
                IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) +
                "&token=" + AccountToken();
   url += AutomationPollCapabilities();
   string resp;
   if(!HttpGet(url, resp)) { g_apiOk = false; UpdatePanel(); return; }
   g_apiOk = true;

   // Flat command objects from the actual API JSON serializer.
   int cursor = 0;
   while(true)
   {
      string item = NextCommandItem(resp,cursor);
      if(item == "") break;

      string id     = JsonGetString(item, "id");
      string action = JsonGetString(item, "action");
      string symbol = JsonGetString(item, "symbol");
      double volume = JsonGetDouble(item, "volume");
      if(id == "" || action == "") continue;

      int claim=CommandClaim(id);
      if(claim==-2) continue; // Never overwrite an earlier result on replay.
      if(claim<0)
      {
         ReportResult(id,false,"command claim unavailable; execution refused");
         continue;
      }
      g_activeCommandClaim=claim;
      int mode=AutomationValidate(item,action,symbol,volume);
      bool ok=false;
      string msg="";
      if(mode!=0)
      {
         ok=mode==1 && AutomationExecute(item,action,symbol,volume);
         msg=ok ? "automation executed" : "automation rejected by local safety guards";
         FileClose(claim); g_activeCommandClaim=-1;
         ReportResult(id,ok,msg);
         g_status=msg;
         continue;
      }
      // Preserve legacy manual defaults and normalization.
      if(symbol=="") symbol=g_symbol;
      else SymbolSelect(symbol,true);

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
      FileClose(claim); g_activeCommandClaim=-1;
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
   BrokerClockFresh();
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
   BrokerClockFresh();
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
