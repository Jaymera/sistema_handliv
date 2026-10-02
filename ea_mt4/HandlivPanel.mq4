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
#property version   "1.02"
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

extern bool InpAllowAutomation = false; // Local opt-in; never enabled by installation

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

uint Sha256K[64];   // tabela K: global para evitar aviso de variavel nao inicializada
uint Sha256W[64];   // vetor de trabalho: global pelo mesmo motivo

void Sha256LoadK()
{
   Sha256K[ 0]=0x428a2f98; Sha256K[ 1]=0x71374491; Sha256K[ 2]=0xb5c0fbcf; Sha256K[ 3]=0xe9b5dba5;
   Sha256K[ 4]=0x3956c25b; Sha256K[ 5]=0x59f111f1; Sha256K[ 6]=0x923f82a4; Sha256K[ 7]=0xab1c5ed5;
   Sha256K[ 8]=0xd807aa98; Sha256K[ 9]=0x12835b01; Sha256K[10]=0x243185be; Sha256K[11]=0x550c7dc3;
   Sha256K[12]=0x72be5d74; Sha256K[13]=0x80deb1fe; Sha256K[14]=0x9bdc06a7; Sha256K[15]=0xc19bf174;
   Sha256K[16]=0xe49b69c1; Sha256K[17]=0xefbe4786; Sha256K[18]=0x0fc19dc6; Sha256K[19]=0x240ca1cc;
   Sha256K[20]=0x2de92c6f; Sha256K[21]=0x4a7484aa; Sha256K[22]=0x5cb0a9dc; Sha256K[23]=0x76f988da;
   Sha256K[24]=0x983e5152; Sha256K[25]=0xa831c66d; Sha256K[26]=0xb00327c8; Sha256K[27]=0xbf597fc7;
   Sha256K[28]=0xc6e00bf3; Sha256K[29]=0xd5a79147; Sha256K[30]=0x06ca6351; Sha256K[31]=0x14292967;
   Sha256K[32]=0x27b70a85; Sha256K[33]=0x2e1b2138; Sha256K[34]=0x4d2c6dfc; Sha256K[35]=0x53380d13;
   Sha256K[36]=0x650a7354; Sha256K[37]=0x766a0abb; Sha256K[38]=0x81c2c92e; Sha256K[39]=0x92722c85;
   Sha256K[40]=0xa2bfe8a1; Sha256K[41]=0xa81a664b; Sha256K[42]=0xc24b8b70; Sha256K[43]=0xc76c51a3;
   Sha256K[44]=0xd192e819; Sha256K[45]=0xd6990624; Sha256K[46]=0xf40e3585; Sha256K[47]=0x106aa070;
   Sha256K[48]=0x19a4c116; Sha256K[49]=0x1e376c08; Sha256K[50]=0x2748774c; Sha256K[51]=0x34b0bcb5;
   Sha256K[52]=0x391c0cb3; Sha256K[53]=0x4ed8aa4a; Sha256K[54]=0x5b9cca4f; Sha256K[55]=0x682e6ff3;
   Sha256K[56]=0x748f82ee; Sha256K[57]=0x78a5636f; Sha256K[58]=0x84c87814; Sha256K[59]=0x8cc70208;
   Sha256K[60]=0x90befffa; Sha256K[61]=0xa4506ceb; Sha256K[62]=0xbef9a3f7; Sha256K[63]=0xc67178f2;
}

void Sha256Init(uint &h[])
{
   h[0]=0x6a09e667; h[1]=0xbb67ae85; h[2]=0x3c6ef372; h[3]=0xa54ff53a;
   h[4]=0x510e527f; h[5]=0x9b05688c; h[6]=0x1f83d9ab; h[7]=0x5be0cd19;
}

//--- SHA-256 (FIPS 180-4). Estado de 32 bits: 8 words.
void Sha256Block(uint &h[], const uchar &block[], int offset)
{
   uint a, b, c, d, e, f, g, hh, v, s0, s1, t1, t2;
   int i, j;
   for(i = 0; i < 64; i++) Sha256W[i] = 0;
   for(i = 0; i < 16; i++)
   {
      v = 0;
      for(j = 0; j < 4; j++) v = (v << 8) | (uint)block[offset + i * 4 + j];
      Sha256W[i] = v;
   }
   for(i = 16; i < 64; i++)
   {
      s0 = Ror32(Sha256W[i-15], 7) ^ Ror32(Sha256W[i-15], 18) ^ (Sha256W[i-15] >> 3);
      s1 = Ror32(Sha256W[i-2], 17) ^ Ror32(Sha256W[i-2], 19)  ^ (Sha256W[i-2]  >> 10);
      Sha256W[i] = Sha256W[i-16] + s0 + Sha256W[i-7] + s1;
   }
   a=h[0]; b=h[1]; c=h[2]; d=h[3]; e=h[4]; f=h[5]; g=h[6]; hh=h[7];
   for(i = 0; i < 64; i++)
   {
      s1 = Ror32(e, 6) ^ Ror32(e, 11) ^ Ror32(e, 25);
      t1 = hh + s1 + ((e & f) ^ ((~e) & g)) + Sha256K[i] + Sha256W[i];
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
   Sha256LoadK();
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
//| Overload de headers personalizados:                               |
//|   WebRequest(method, url, headers, timeout, data, result,          |
//|              result_headers)                                       |
//| O overload de 9 argumentos usa cookie e referer, NAO headers.     |
//| Para JSON, usar 7 argumentos e ajustar o array ao tamanho exato.  |
//+------------------------------------------------------------------+
#define HTTP_TIMEOUT 5000

//+------------------------------------------------------------------+
//| Traduz o erro do WebRequest em acao util.                       |
//| 4014 = URL nao esta na lista de Allow WebRequest                 |
//| 4060 = nenhuma resposta / conexao recusada                       |
//| 4051 = funcao desabilitada nas opcoes do terminal                 |
//+------------------------------------------------------------------+
string HttpErrorHelp(const int code)
{
   switch(code)
   {
      case 4014: return " | ERRO 4014: libere " + InpApiUrl + " em Ferramentas > Opcoes > Expert Advisors > Allow WebRequest";
      case 4060: return " | ERRO 4060: sem resposta da API. Verifique a URL, firewall/proxy e se a API esta online";
      case 4051: return " | ERRO 4051: WebRequest desabilitado nas opcoes do terminal";
      case 4063: return " | ERRO 4063: WebRequest nao permitido para este EA (marcar 'Permitir WebRequest para EAs de terceiros')";
      case 4071: return " | ERRO 4071: nao foi possivel abrir a conexao com a API";
      default:   return " | erro WebRequest " + IntegerToString(code);
   }
}

bool HttpGet(const string url, string &response)
{
   string headers  = "Content-Type: application/json\r\n";
   string resultHeaders = "";
   char   post[], result[];
   int    code;

   ResetLastError();
   ArrayResize(post, 0);                // GET sem corpo
   code = WebRequest("GET", url, headers, HTTP_TIMEOUT,
                     post, result, resultHeaders);
   if(code == -1)
   {
      int err = GetLastError();
      g_status = "WebRequest falhou" + HttpErrorHelp(err);
      Print("HandlivPanel GET falhou: ", g_status);
      return false;
   }
   if(code != 200)
   {
      g_status = "HTTP " + IntegerToString(code) +
                 (code == 401 ? " | token invalido: confira conta e API token" :
                  code == 404 ? " | conta nao cadastrada no site" : "");
      return false;
   }
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return true;
}

bool HttpPost(const string url, const string json, string &response)
{
   string headers  = "Content-Type: application/json\r\n";
   string resultHeaders = "";
   char   post[], result[];
   int    code, size;

   ResetLastError();
   size = StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   // Alguns builds incluem o terminador NUL no retorno; JSON com byte extra
   // e rejeitado pelo parser da API antes de validar o token.
   if(size > 0 && post[size - 1] == 0) size--;
   // O overload com headers envia ArraySize(post) bytes (nao aceita data_size).
   // Nunca enviar um corpo vazio: isso produz 422 missing antes da autenticacao.
   if(size <= 0 || ArrayResize(post, size) != size)
   {
      int chars = StringLen(json);
      g_status = "POST local | corpo vazio ou conversao UTF-8 falhou";
      Print("HandlivPanel POST recusado localmente: ", g_status,
            " chars=", chars, " bytes=", size, " endpoint=", url);
      return false;
   }
   code = WebRequest("POST", url, headers, HTTP_TIMEOUT,
                     post, result, resultHeaders);
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(code == -1 || code >= 400)
   {
      int err = (code == -1) ? GetLastError() : 0;
      // FastAPI 422 retorna detail[].type/msg. Nao imprimir response inteiro:
      // erros de validacao podem conter o corpo original com token.
      string kind = JsonErrorField(response, "type");
      string reason = JsonErrorField(response, "msg");
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
//| Mini parser JSON (mesmo do MT5)                                  |
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
   return Sha256Hex("mt4|"+AccountServer()+"|"+IntegerToString(AccountNumber()));
}

bool AutomationVolume(const string symbol, const double volume)
{
   return ExactVolume(volume,MarketInfo(symbol,MODE_MINLOT),MarketInfo(symbol,MODE_MAXLOT),MarketInfo(symbol,MODE_LOTSTEP));
}

bool AutomationOccupied(const string symbol)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) return true;
      if(OrderSymbol()==symbol && OrderMagicNumber()==AUTOMATION_MAGIC) return true;
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
   if(iBars(symbol,PERIOD_H1)<16) return 0;
   if(!FreshBrokerTimes(TimeCurrent(),(datetime)MarketInfo(symbol,MODE_TIME),iTime(symbol,PERIOD_H1,1))) return 0;
   double atr=iATR(symbol,PERIOD_H1,14,1);
   return MathIsValidNumber(atr) && atr>0 ? atr : 0;
}

bool AutomationExecute(const string item, const string action, const string symbol, const double volume)
{
   if(AutomationValidate(item,action,symbol,volume)!=1 || AutomationOccupied(symbol)) return false;
   if(MarketInfo(symbol,MODE_TRADEALLOWED)==0) return false;
   double atr=ClosedCandleAtr(symbol);
   RefreshRates();
   double ask=MarketInfo(symbol,MODE_ASK), bid=MarketInfo(symbol,MODE_BID);
   if(!BrokerClockFresh() || !FreshBrokerTimes(TimeCurrent(),(datetime)MarketInfo(symbol,MODE_TIME),iTime(symbol,PERIOD_H1,1))) return false;
   double price=action=="buy" ? ask : bid;
   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE), point=MarketInfo(symbol,MODE_POINT);
   double stops=MarketInfo(symbol,MODE_STOPLEVEL), freeze=MarketInfo(symbol,MODE_FREEZELEVEL);
   if(!MathIsValidNumber(point) || point<=0 || !MathIsValidNumber(stops) || stops<0 || !MathIsValidNumber(freeze) || freeze<0) return false;
   int digits=(int)MarketInfo(symbol,MODE_DIGITS);
   double sl=ProtectionPrice(action,true,price,atr,StringToDouble(RawString(JsonRawField(item,"sl_atr_multiplier"))),tick,digits);
   double tp=ProtectionPrice(action,false,price,atr,StringToDouble(RawString(JsonRawField(item,"tp_atr_multiplier"))),tick,digits);
   if(!ProtectionPair(action,price,bid,ask,sl,tp,MathMax(stops,freeze)*point,tick)) return false;
   if(!AutomationReady() || AutomationOccupied(symbol) || UtcExpiry(RawString(JsonRawField(item,"expires_at")))<=TimeGMT()) return false;
   ResetLastError();
   int ticket=OrderSend(symbol,action=="buy" ? OP_BUY : OP_SELL,volume,price,InpSlippage,sl,tp,
      "Handliv automation",AUTOMATION_MAGIC,0,clrNONE);
   g_lastError=GetLastError();
   if(ticket<=0) return false; // Never retry without SL/TP, including invalid stops.
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES) || OrderSymbol()!=symbol || OrderMagicNumber()!=AUTOMATION_MAGIC || OrderStopLoss()<=0 || OrderTakeProfit()<=0)
   {
      ProtectionFault(); return false;
   }
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
   SymbolSelect(symbol, true);
   ask = MarketInfo(symbol, MODE_ASK);
   if(ask <= 0)
   {
      g_status = "Sem cotacao de compra em " + symbol;
      return false;
   }
   lot = NormalizeVolume(symbol, volume);
   ResetLastError();
   ticket = OrderSend(symbol, OP_BUY, lot, ask, InpSlippage, 0, 0,
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
   SymbolSelect(symbol, true);
   bid = MarketInfo(symbol, MODE_BID);
   if(bid <= 0)
   {
      g_status = "Sem cotacao de venda em " + symbol;
      return false;
   }
   lot = NormalizeVolume(symbol, volume);
   ResetLastError();
   ticket = OrderSend(symbol, OP_SELL, lot, bid, InpSlippage, 0, 0,
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
      if(OrderMagicNumber()==AUTOMATION_MAGIC) continue;
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
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      datetime closed = OrderCloseTime();
      if(closed < from || closed >= to) continue;
      total += OrderProfit() + OrderCommission() + OrderSwap();
   }
   return total;
}

void CountWinLoss(int &countWins, int &countLosses)
{
   countWins = 0; countLosses = 0;
   int n = OrdersHistoryTotal();
   for(int i = 0; i < n; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      double p = OrderProfit() + OrderCommission() + OrderSwap();
      if(p >= 0) countWins++; else countLosses++;
   }
}

int OpenPositionsCount()
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL) count++;
   }
   return count;
}

// Magic 0 is manual trading. History is limited to what this terminal has loaded.
// Global buffers avoid MT4's false uninitialized-index warnings on local arrays.
int magics[256], opened[256], wins[256], losses[256];
double floating[256], realized[256];
string symbols[256];
int FindRobotMagic(const int magic, const int &lookupMagics[], const int count)
{
   for(int i = 0; i < count; i++) if(lookupMagics[i] == magic) return i;
   return -1;
}

string RobotStatsJson()
{
   ResetAutomationSnapshot();
   int count = 0;
   if(InpMagic > 0)
   {
      magics[0] = InpMagic; opened[0] = 0; wins[0] = 0; losses[0] = 0;
      floating[0] = 0; realized[0] = 0; symbols[0] = ""; count = 1;
   }
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { g_automationSnapshotComplete=false; continue; }
      if(OrderMagicNumber()==AUTOMATION_MAGIC) CollectAutomationSymbol(OrderSymbol());
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      int magic = OrderMagicNumber(); if(magic <= 0) continue;
      int at = FindRobotMagic(magic, magics, count);
      if(at < 0 && count < 256)
      {
         at = count++; magics[at] = magic; opened[at] = 0; wins[at] = 0;
         losses[at] = 0; floating[at] = 0; realized[at] = 0; symbols[at] = "";
      }
      if(at < 0) continue;
      opened[at]++;
      floating[at] += OrderProfit() + OrderCommission() + OrderSwap();
      if(symbols[at] == "") symbols[at] = OrderSymbol();
      else if(symbols[at] != OrderSymbol()) symbols[at] = "*";
   }
   for(int j = 0; j < OrdersHistoryTotal(); j++)
   {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      int magic = OrderMagicNumber(); if(magic <= 0) continue;
      int at = FindRobotMagic(magic, magics, count);
      if(at < 0 && count < 256)
      {
         at = count++; magics[at] = magic; opened[at] = 0; wins[at] = 0;
         losses[at] = 0; floating[at] = 0; realized[at] = 0; symbols[at] = "";
      }
      if(at < 0) continue;
      double profit = OrderProfit() + OrderCommission() + OrderSwap();
      realized[at] += profit;
      if(profit >= 0) wins[at]++; else losses[at]++;
      if(symbols[at] == "") symbols[at] = OrderSymbol();
      else if(symbols[at] != OrderSymbol()) symbols[at] = "*";
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
      result += StringFormat("{\"magic\":\"%d\",\"symbol\":%s,\"open_positions\":%d,"
         "\"floating_pl\":%.2f,\"profit_total\":%.2f,\"total_trades\":%d,"
         "\"win_trades\":%d,\"loss_trades\":%d,\"history_scope\":\"terminal_loaded\",\"heartbeat\":%s}",
         magics[k], symbol, opened[k], floating[k], realized[k], wins[k]+losses[k],
         wins[k], losses[k], magics[k] == InpMagic ? "true" : "false");
   }
   return result + "]";
}

//+------------------------------------------------------------------+
//| Coleta e envia estatisticas da conta para o site                 |
//+------------------------------------------------------------------+
bool AutomationReady()
{
   return InpAllowAutomation && ProtectionHealthy() && g_automationSnapshotComplete && IsTradeAllowed() && IsConnected() && !IsStopped();
}

void SendStats()
{
   datetime now  = TimeCurrent();
   datetime day0   = DayStart(now);
   datetime week0  = WeekStart(now);
   datetime month0 = MonthStart(now);

   double equity  = AccountEquity();
   double balance = AccountBalance();
   double margin  = AccountMargin();
   double accountFloating = AccountProfit();
   double mlevel  = (margin > 0) ? equity / margin * 100.0 : 0.0;

   // Drawdown: acompanha o pico de equity desde o inicio do EA
   if(equity > g_peakEquity) g_peakEquity = equity;
   double dd = 0.0;
   if(g_peakEquity > 0) dd = (g_peakEquity - equity) / g_peakEquity * 100.0;

   int accountWins = 0, accountLosses = 0;
   CountWinLoss(accountWins, accountLosses);

   // Mesmo contrato do MT5, sem formatador variadico para o objeto completo.
   // Conversoes explicitas deixam o corpo verificavel antes do WebRequest.
   string robots=RobotStatsJson();
   string automationPositions=AutomationPositionsJson();
   string json = "{\"account\":\"" + IntegerToString(AccountNumber()) +
      "\",\"login\":\"" + IntegerToString(AccountNumber()) +
      "\",\"token\":\"" + AccountToken() +
      "\",\"currency\":\"" + AccountCurrency() + "\"," +
      "\"equity\":" + DoubleToString(equity, 2) +
      ",\"balance\":" + DoubleToString(balance, 2) +
      ",\"margin\":" + DoubleToString(margin, 2) +
      ",\"margin_level\":" + DoubleToString(mlevel, 2) +
      ",\"floating_pl\":" + DoubleToString(accountFloating, 2) +
      ",\"dd_percent\":" + DoubleToString(dd, 2) +
      ",\"profit_day\":" + DoubleToString(HistoryProfit(day0, now + 60), 2) +
      ",\"profit_week\":" + DoubleToString(HistoryProfit(week0, now + 60), 2) +
      ",\"profit_month\":" + DoubleToString(HistoryProfit(month0, now + 60), 2) +
      ",\"profit_total\":" + DoubleToString(HistoryProfit(0, now + 60), 2) +
      ",\"win_trades\":" + IntegerToString(accountWins) +
      ",\"loss_trades\":" + IntegerToString(accountLosses) +
      ",\"total_trades\":" + IntegerToString(accountWins + accountLosses) +
      ",\"open_positions\":" + IntegerToString(OpenPositionsCount()) +
      ",\"robots\":" + robots + ",\"automation_v1\":true,\"automation_protection_v1\":true,\"automation_positions\":" +
      automationPositions + ",\"automation_ready\":" +
      (AutomationReady() ? "true" : "false") + "}";
   string resp;
   if(HttpPost(InpApiUrl + "/mt5/ea/stats", json, resp))
      g_status = "Stats OK " + TimeToStr(now, TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Consulta comandos pendentes (1x por segundo)                     |
//+------------------------------------------------------------------+
string AutomationPollCapabilities()
{
   return "&automation_v1=1&automation_protection_v1=1&automation_ready=" + (AutomationReady() ? "1" : "0");
}

void PollCommands()
{
   string url = InpApiUrl + "/mt5/ea/commands?account=" +
                IntegerToString(AccountNumber()) +
                "&token=" + AccountToken();
   url += AutomationPollCapabilities();
   string resp;

   if(!HttpGet(url, resp)) { g_apiOk = false; UpdatePanel(); return; }
   if(!g_apiOk || g_status == "Conectando...") g_status = "Conectado";
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
      FileClose(claim); g_activeCommandClaim=-1;
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
   // Recria o objeto se nao existir (o status inicial "Conectando..." e
   // escrito em CreatePanel e nunca e redesenhado sem ChartRedraw).
   if(ObjectFind("HLV_STATUS") < 0)
   {
      CreatePanel();
      return;
   }
   PanelText("HLV_STATUS", 20, 68,
             (g_apiOk ? "API OK" : "API OFF") + " | " + g_status,
             g_apiOk ? C'149,166,195' : C'234,57,67', 8);
   ChartRedraw();
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
      Alert("Informe o API token (secret) nas configuracoes do EA. Contate a Handliv.");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_symbol = (InpSymbol == "" ? Symbol() : InpSymbol);
   SymbolSelect(g_symbol, true);
   RefreshRates();
   g_peakEquity = MathMax(AccountEquity(), AccountBalance());

   CreatePanel();
   EventSetTimer(MathMax(1, InpPollSeconds));
   Print("HandlivPanel MT4 iniciado. Conta=", AccountNumber(), " API=", InpApiUrl);

   // Verifica a conexao logo ao iniciar e exibe o resultado antes do timer.
   // O timer continua ativo mesmo quando WebRequest falha.
   PollCommands();
   SendStats();
   UpdatePanel();
   ChartRedraw();
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
   ChartRedraw();
}

void OnTimer()
{
   BrokerClockFresh();
   datetime now = TimeLocal(); // TimeCurrent pode congelar sem ticks; polling HTTP nao deve parar
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
   UpdatePanel();
   ChartRedraw();
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
