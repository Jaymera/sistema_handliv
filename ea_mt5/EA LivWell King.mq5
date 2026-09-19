//+------------------------------------------------------------------ß
//|                                                            JAson |
//|    This software is licensed under the MIT https://goo.gl/eyJgHe |
//+------------------------------------------------------------------+
//------------------------------------------------------------------	enum enJAType
enum enJAType { jtUNDEF, jtNULL, jtBOOL, jtINT, jtDBL, jtSTR, jtARRAY, jtOBJ };

//------------------------------------------------------------------	class CJAVal
class CJAVal
{
public:
	virtual void Clear(enJAType jt=jtUNDEF, bool savekey=false) { m_parent=NULL; if (!savekey) m_key=""; m_type=jt; m_bv=false; m_iv=0; m_dv=0; m_prec=8; m_sv=""; ArrayResize(m_e, 0, 100); }
	virtual bool Copy(const CJAVal &a) { m_key=a.m_key; CopyData(a); return true; }
	virtual void CopyData(const CJAVal& a) { m_type=a.m_type; m_bv=a.m_bv; m_iv=a.m_iv; m_dv=a.m_dv; m_prec=a.m_prec; m_sv=a.m_sv; CopyArr(a); }
	virtual void CopyArr(const CJAVal& a) { int n=ArrayResize(m_e, ArraySize(a.m_e)); for (int i=0; i<n; i++) { m_e[i]=a.m_e[i]; m_e[i].m_parent=GetPointer(this); } }
	
public:
	CJAVal m_e[];
	string m_key;
	string m_lkey;
	CJAVal* m_parent;
	enJAType m_type;
	bool m_bv;
	long m_iv;
	double m_dv; int m_prec;
	string m_sv;
	static int code_page;
	
public:
	CJAVal() { Clear(); }
	CJAVal(CJAVal* aparent, enJAType atype) { Clear(); m_type=atype; m_parent=aparent; }
	CJAVal(enJAType t, string a) { Clear(); FromStr(t, a); }
	CJAVal(const int a) { Clear(); m_type=jtINT; m_iv=a; m_dv=(double)m_iv; m_sv=IntegerToString(m_iv); m_bv=m_iv!=0; }
	CJAVal(const long a) { Clear(); m_type=jtINT; m_iv=a; m_dv=(double)m_iv; m_sv=IntegerToString(m_iv); m_bv=m_iv!=0; }
	CJAVal(const double a, int aprec=-100) { Clear(); m_type=jtDBL; m_dv=a; if (aprec>-100) m_prec=aprec; m_iv=(long)m_dv; m_sv=DoubleToString(m_dv, m_prec); m_bv=m_iv!=0; }
	CJAVal(const bool a) { Clear(); m_type=jtBOOL; m_bv=a; m_iv=m_bv; m_dv=m_bv; m_sv=IntegerToString(m_iv); }
	CJAVal(const CJAVal& a) { Clear(); Copy(a); }
	~CJAVal() { Clear(); }
	
public:
	int Size() { return ArraySize(m_e); }
	virtual bool IsNumeric() { return m_type==jtDBL || m_type==jtINT; }
	virtual CJAVal* FindKey(string akey) { for (int i=Size()-1; i>=0; --i) if (m_e[i].m_key==akey) return GetPointer(m_e[i]); return NULL; }
	virtual CJAVal* HasKey(string akey, enJAType atype=jtUNDEF) { CJAVal* e=FindKey(akey); if (CheckPointer(e)!=POINTER_INVALID) { if (atype==jtUNDEF || atype==e.m_type) return GetPointer(e); } return NULL; }
	virtual CJAVal* operator[](string akey);
	virtual CJAVal* operator[](int i);
	void operator=(const CJAVal &a) { Copy(a); }
	void operator=(const int a) { m_type=jtINT; m_iv=a; m_dv=(double)m_iv; m_bv=m_iv!=0; }
	void operator=(const long a) { m_type=jtINT; m_iv=a; m_dv=(double)m_iv; m_bv=m_iv!=0; }
	void operator=(const double a) { m_type=jtDBL; m_dv=a; m_iv=(long)m_dv; m_bv=m_iv!=0; }
	void operator=(const bool a) { m_type=jtBOOL; m_bv=a; m_iv=(long)m_bv; m_dv=(double)m_bv; }
	void operator=(string a) { m_type=(a!=NULL)?jtSTR:jtNULL; m_sv=a; m_iv=StringToInteger(m_sv); m_dv=StringToDouble(m_sv); m_bv=a!=NULL; }

	bool operator==(const int a) { return m_iv==a; }
	bool operator==(const long a) { return m_iv==a; }
	bool operator==(const double a) { return m_dv==a; }
	bool operator==(const bool a) { return m_bv==a; }
	bool operator==(string a) { return m_sv==a; }
	
	bool operator!=(const int a) { return m_iv!=a; }
	bool operator!=(const long a) { return m_iv!=a; }
	bool operator!=(const double a) { return m_dv!=a; }
	bool operator!=(const bool a) { return m_bv!=a; }
	bool operator!=(string a) { return m_sv!=a; }

	long ToInt() const { return m_iv; }
	double ToDbl() const { return m_dv; }
	bool ToBool() const { return m_bv; }
	string ToStr() { return m_sv; }

	virtual void FromStr(enJAType t, string a)
	{
		m_type=t;
		switch (m_type)
		{
		case jtBOOL: m_bv=(StringToInteger(a)!=0); m_iv=(long)m_bv; m_dv=(double)m_bv; m_sv=a; break;
		case jtINT: m_iv=StringToInteger(a); m_dv=(double)m_iv; m_sv=a; m_bv=m_iv!=0; break;
		case jtDBL: m_dv=StringToDouble(a); m_iv=(long)m_dv; m_sv=a; m_bv=m_iv!=0; break;
		case jtSTR: m_sv=Unescape(a); m_type=(m_sv!=NULL)?jtSTR:jtNULL; m_iv=StringToInteger(m_sv); m_dv=StringToDouble(m_sv); m_bv=m_sv!=NULL; break;
		}
	}
	virtual string GetStr(char& js[], int i, int slen) { if (slen==0) return ""; char cc[]; ArrayCopy(cc, js, 0, i, slen); return CharArrayToString(cc, 0, WHOLE_ARRAY, CJAVal::code_page); }

	virtual void Set(const CJAVal& a) { if (m_type==jtUNDEF) m_type=jtOBJ; CopyData(a); }
	virtual void Set(const CJAVal& list[]);
	virtual CJAVal* Add(const CJAVal& item) { if (m_type==jtUNDEF) m_type=jtARRAY; /*ASSERT(m_type==jtOBJ || m_type==jtARRAY);*/ return AddBase(item); } // добавление
	virtual CJAVal* Add(const int a) { CJAVal item(a); return Add(item); }
	virtual CJAVal* Add(const long a) { CJAVal item(a); return Add(item); }
	virtual CJAVal* Add(const double a, int aprec=-2) { CJAVal item(a, aprec); return Add(item); }
	virtual CJAVal* Add(const bool a) { CJAVal item(a); return Add(item); }
	virtual CJAVal* Add(string a) { CJAVal item(jtSTR, a); return Add(item); }
	virtual CJAVal* AddBase(const CJAVal &item) { int c=Size(); ArrayResize(m_e, c+1, 100); m_e[c]=item; m_e[c].m_parent=GetPointer(this); return GetPointer(m_e[c]); } // добавление
	virtual CJAVal* New() { if (m_type==jtUNDEF) m_type=jtARRAY; /*ASSERT(m_type==jtOBJ || m_type==jtARRAY);*/ return NewBase(); } // добавление
	virtual CJAVal* NewBase() { int c=Size(); ArrayResize(m_e, c+1, 100); return GetPointer(m_e[c]); } // добавление

	virtual string Escape(string a);
	virtual string Unescape(string a);
public:
	virtual void Serialize(string &js, bool bf=false, bool bcoma=false);
	virtual string Serialize() { string js; Serialize(js); return js; }
	virtual bool Deserialize(char& js[], int slen, int &i);
	virtual bool ExtrStr(char& js[], int slen, int &i);
	virtual bool Deserialize(string js, int acp=CP_ACP) { int i=0; Clear(); CJAVal::code_page=acp; char arr[]; int slen=StringToCharArray(js, arr, 0, WHOLE_ARRAY, CJAVal::code_page); return Deserialize(arr, slen, i); }
	virtual bool Deserialize(char& js[], int acp=CP_ACP) { int i=0; Clear(); CJAVal::code_page=acp; return Deserialize(js, ArraySize(js), i); }
};

int CJAVal::code_page=CP_ACP;

//------------------------------------------------------------------	operator[]
CJAVal* CJAVal::operator[](string akey) { if (m_type==jtUNDEF) m_type=jtOBJ; CJAVal* v=FindKey(akey); if (v) return v; CJAVal b(GetPointer(this), jtUNDEF); b.m_key=akey; v=Add(b); return v; }
//------------------------------------------------------------------	operator[]
CJAVal* CJAVal::operator[](int i)
{
	if (m_type==jtUNDEF) m_type=jtARRAY;
	while (i>=Size()) { CJAVal b(GetPointer(this), jtUNDEF); if (CheckPointer(Add(b))==POINTER_INVALID) return NULL; }
	return GetPointer(m_e[i]);
}
//------------------------------------------------------------------	Set
void CJAVal::Set(const CJAVal& list[])
{
	if (m_type==jtUNDEF) m_type=jtARRAY;
	int n=ArrayResize(m_e, ArraySize(list), 100); for (int i=0; i<n; ++i) { m_e[i]=list[i]; m_e[i].m_parent=GetPointer(this); }
}

//------------------------------------------------------------------	Serialize
void CJAVal::Serialize(string& js, bool bkey/*=false*/, bool coma/*=false*/)
{
	if (m_type==jtUNDEF) return;
	if (coma) js+=",";
	if (bkey) js+=StringFormat("\"%s\":", m_key);
	int _n=Size();
	switch (m_type)
	{
	case jtNULL: js+="null"; break;
	case jtBOOL: js+=(m_bv?"true":"false"); break;
	case jtINT: js+=IntegerToString(m_iv); break;
	case jtDBL: js+=DoubleToString(m_dv, m_prec); break;
	case jtSTR: { string ss=Escape(m_sv); if (StringLen(ss)>0) js+=StringFormat("\"%s\"", ss); else js+="null"; } break;
	case jtARRAY: js+="["; for (int i=0; i<_n; i++) m_e[i].Serialize(js, false, i>0); js+="]"; break;
	case jtOBJ: js+="{"; for (int i=0; i<_n; i++) m_e[i].Serialize(js, true, i>0); js+="}"; break;
	}
}

//------------------------------------------------------------------	Deserialize
bool CJAVal::Deserialize(char& js[], int slen, int &i)
{
	string num="0123456789+-.eE";
	int i0=i;
	for (; i<slen; i++)
	{
		char c=js[i]; if (c==0) break;
		switch (c)
		{
		case '\t': case '\r': case '\n': case ' ': // пропускаем из имени пробелы
			i0=i+1; break;

		case '[': // начало массива. создаём объекты и забираем из js
		{
			i0=i+1;
			if (m_type!=jtUNDEF) { Print(m_key+" "+string(__LINE__)); return false; } // если значение уже имеет тип, то это ошибка
			m_type=jtARRAY; // задали тип значения
			i++; CJAVal val(GetPointer(this), jtUNDEF);
			while (val.Deserialize(js, slen, i))
			{
				if (val.m_type!=jtUNDEF) Add(val);
				if (val.m_type==jtINT || val.m_type==jtDBL || val.m_type==jtARRAY) i++;
				val.Clear(); val.m_parent=GetPointer(this);
				if (js[i]==']') break;
				i++; if (i>=slen) { Print(m_key+" "+string(__LINE__)); return false; }
			}
			return js[i]==']' || js[i]==0;
		}
		break;
		case ']': if (!m_parent) return false; return m_parent.m_type==jtARRAY; // конец массива, текущее значение должны быть массивом

		case ':':
		{
			if (m_lkey=="") { Print(m_key+" "+string(__LINE__)); return false; }
			CJAVal val(GetPointer(this), jtUNDEF);
			CJAVal *oc=Add(val); // тип объекта пока не определён
			oc.m_key=m_lkey; m_lkey=""; // задали имя ключа
			i++; if (!oc.Deserialize(js, slen, i)) { Print(m_key+" "+string(__LINE__)); return false; }
			break;
		}
		case ',': // разделитель значений // тип значения уже должен быть определён
			i0=i+1;
			if (!m_parent && m_type!=jtOBJ) { Print(m_key+" "+string(__LINE__)); return false; }
			else if (m_parent)
			{
				if (m_parent.m_type!=jtARRAY && m_parent.m_type!=jtOBJ) { Print(m_key+" "+string(__LINE__)); return false; }
				if (m_parent.m_type==jtARRAY && m_type==jtUNDEF) return true;
			}
			break;

			// примитивы могут быть ТОЛЬКО в массиве / либо самостоятельно
		case '{': // начало объекта. создаем объект и забираем его из js
			i0=i+1;
			if (m_type!=jtUNDEF) { Print(m_key+" "+string(__LINE__)); return false; }// ошибка типа
			m_type=jtOBJ; // задали тип значения
			i++; if (!Deserialize(js, slen, i)) { Print(m_key+" "+string(__LINE__)); return false; } // вытягиваем его
			return js[i]=='}' || js[i]==0;
			break;
		case '}': return m_type==jtOBJ; // конец объекта, текущее значение должно быть объектом

		case 't': case 'T': // начало true
		case 'f': case 'F': // начало false
			if (m_type!=jtUNDEF) { Print(m_key+" "+string(__LINE__)); return false; } // ошибка типа
			m_type=jtBOOL; // задали тип значения
			if (i+3<slen) { if (StringCompare(GetStr(js, i, 4), "true", false)==0) { m_bv=true; i+=3; return true; } }
			if (i+4<slen) { if (StringCompare(GetStr(js, i, 5), "false", false)==0) { m_bv=false; i+=4; return true; } }
			Print(m_key+" "+string(__LINE__)); return false; // не тот тип или конец строки
			break;
		case 'n': case 'N': // начало null
			if (m_type!=jtUNDEF) { Print(m_key+" "+string(__LINE__)); return false; } // ошибка типа
			m_type=jtNULL; // задали тип значения
			if (i+3<slen) if (StringCompare(GetStr(js, i, 4), "null", false)==0) { i+=3; return true; }
			Print(m_key+" "+string(__LINE__)); return false; // не NULL или конец строки
			break;

		case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9': case '-': case '+': case '.': // начало числа
		{
			if (m_type!=jtUNDEF) { Print(m_key+" "+string(__LINE__)); return false; } // ошибка типа
			bool dbl=false;// задали тип значения
			int is=i; while (js[i]!=0 && i<slen) { i++; if (StringFind(num, GetStr(js, i, 1))<0) break; if (!dbl) dbl=(js[i]=='.' || js[i]=='e' || js[i]=='E'); }
			m_sv=GetStr(js, is, i-is);
			if (dbl) { m_type=jtDBL; m_dv=StringToDouble(m_sv); m_iv=(long)m_dv; m_bv=m_iv!=0; }
			else { m_type=jtINT; m_iv=StringToInteger(m_sv); m_dv=(double)m_iv; m_bv=m_iv!=0; } // уточнии тип значения
			i--; return true; // отодвинулись на 1 символ назад и вышли
			break;
		}
		case '\"': // начало или конец строки
			if (m_type==jtOBJ) // если тип еще неопределён и ключ не задан
			{
				i++; int is=i; if (!ExtrStr(js, slen, i)) { Print(m_key+" "+string(__LINE__)); return false; } // это ключ, идём до конца строки
				m_lkey=GetStr(js, is, i-is);
			}
			else
			{
				if (m_type!=jtUNDEF) { Print(m_key+" "+string(__LINE__)); return false; } // ошибка типа
				m_type=jtSTR; // задали тип значения
				i++; int is=i;
				if (!ExtrStr(js, slen, i)) { Print(m_key+" "+string(__LINE__)); return false; }
				FromStr(jtSTR, GetStr(js, is, i-is));
				return true;
			}
			break;
		}
	}
	return true;
}

//------------------------------------------------------------------	ExtrStr
bool CJAVal::ExtrStr(char& js[], int slen, int &i)
{
	for (; js[i]!=0 && i<slen; i++)
	{
		char c=js[i];
		if (c=='\"') break; // конец строки
		if (c=='\\' && i+1<slen)
		{
			i++; c=js[i];
			switch (c)
			{
			case '/': case '\\': case '\"': case 'b': case 'f': case 'r': case 'n': case 't': break; // это разрешенные
			case 'u': // \uXXXX
			{
				i++;
				for (int j=0; j<4 && i<slen && js[i]!=0; j++, i++)
				{
					if (!((js[i]>='0' && js[i]<='9') || (js[i]>='A' && js[i]<='F') || (js[i]>='a' && js[i]<='f'))) { Print(m_key+" "+CharToString(js[i])+" "+string(__LINE__)); return false; } // не hex
				}
				i--;
				break;
			}
			default: break; /*{ return false; } // неразрешенный символ с экранированием */
			}
		}
	}
	return true;
}
//------------------------------------------------------------------	Escape
string CJAVal::Escape(string a)
{
	ushort as[], s[]; int n=StringToShortArray(a, as); if (ArrayResize(s, 2*n)!=2*n) return NULL;
	int j=0;
	for (int i=0; i<n; i++)
	{
		switch (as[i])
		{
		case '\\': s[j]='\\'; j++; s[j]='\\'; j++; break;
		case '"': s[j]='\\'; j++; s[j]='"'; j++; break;
		case '/': s[j]='\\'; j++; s[j]='/'; j++; break;
		case 8: s[j]='\\'; j++; s[j]='b'; j++; break;
		case 12: s[j]='\\'; j++; s[j]='f'; j++; break;
		case '\n': s[j]='\\'; j++; s[j]='n'; j++; break;
		case '\r': s[j]='\\'; j++; s[j]='r'; j++; break;
		case '\t': s[j]='\\'; j++; s[j]='t'; j++; break;
		default: s[j]=as[i]; j++; break;
		}
	}
	a=ShortArrayToString(s, 0, j);
	return a;
}
//------------------------------------------------------------------	Unescape
string CJAVal::Unescape(string a)
{
	ushort as[], s[]; int n=StringToShortArray(a, as); if (ArrayResize(s, n)!=n) return NULL;
	int j=0, i=0;
	while (i<n)
	{
		ushort c=as[i];
		if (c=='\\' && i<n-1)
		{
			switch (as[i+1])
			{
			case '\\': c='\\'; i++; break;
			case '"': c='"'; i++; break;
			case '/': c='/'; i++; break;
			case 'b': c=8; /*08='\b'*/; i++; break;
			case 'f': c=12;/*0c=\f*/ i++; break;
			case 'n': c='\n'; i++; break;
			case 'r': c='\r'; i++; break;
			case 't': c='\t'; i++; break;
			case 'u': // \uXXXX
			{
				i+=2; ushort k=0;
				for (int jj=0; jj<4 && i<n; jj++, i++)
				{
					c=as[i]; ushort h=0;
					if (c>='0' && c<='9') h=c-'0';
					else if (c>='A' && c<='F') h=c-'A'+10;
					else if (c>='a' && c<='f') h=c-'a'+10;
					else break; // не hex
					k+=h*(ushort)pow(16, (3-jj));
				}
				i--;
				c=k;
				break;
			}
			}
		}
		s[j]=c; j++; i++;
	}
	a=ShortArrayToString(s, 0, j);
	return a;
}

//+------------------------------------------------------------------+
//|                                       Quantum Queen MT5 V3.52.mq5 |
//|                          Copyright 2026, Quantum Trading Systems |
//|                                             https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright   "2023 - Handliv®️"
#property link        "https://handliv.com/index.html"
#property version     "3.52"
#property description "Attention"
#property description "Handliv is not responsible for any losses that may occur due to the incorrect use of the program,"
#property description "by using this program you agree that you are aware of all risks associated with financial market and automatic trading,"
#property description "assuming full responsibility for the operations performed by the program."
#property strict
#property description ""
#property description "Contact: faleconosco.handliv@gmail.com | +55 1152866453"
#property icon        "logo_robo.ico"

//--- INCLUDES ---
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Canvas\Canvas.mqh>

//--- ENUMS ---
enum ENUM_LOT_METHOD { 
   LOT_AUTO = 0,    // Automatic
   LOT_FIXED = 1,   // Fixed Lots
   LOT_BALANCE = 2  // Fixed per Balance
};
enum ENUM_RISK_LEVEL { 
   RISK_VERY_LOW,   // Very Low
   RISK_LOW,        // Low
   RISK_MEDIUM,     // Medium
   RISK_LOW_MEDIUM, // Low-Medium
   RISK_MEDIUM_HIGH,// Medium-High
   RISK_HIGH,       // High
   RISK_VERY_HIGH   // Very High
};
enum ENUM_DD_MODE { 
   DD_OFF = 0,                     // OFF
   DD_PCT_CLOSE_CONTINUE = 1,      // [Pct.] Close all EA trades & CONTINUE
   DD_PCT_CLOSE_REMOVE = 2,        // [Pct.] Close all EA trades & REMOVE
   DD_PCT_ALERT = 3,               // [Pct.] Alert on Terminal
   DD_MONEY_CLOSE_CONTINUE = 4,    // [Money] Close all EA trades & CONTINUE
   DD_MONEY_CLOSE_REMOVE = 5,      // [Money] Close all EA trades & REMOVE
   DD_MONEY_ALERT = 6              // [Money] Alert on Terminal
};
enum ENUM_ON_OFF { 
   SWITCH_OFF = 0, // OFF
   SWITCH_ON = 1   // ON
};
bool IsOn(const ENUM_ON_OFF value) { return (value == SWITCH_ON); }
enum ENUM_PRESET_SETS { 
   SET_IC_LOW = 0,  // IC Markets/VT Markets (RAW)- Medium Risk
   SET_IC_HIGH = 1, // IC Markets/VT Markets (RAW)- High Risk
   SET_ROBO_ECN = 2,// RoboForex- ECN
   SET_FUSION = 3   // Fusion Markets (Zero)
};

//--- SMC Strategy Constants ---
enum ENUM_SMC_STRATEGY {
   SMC_LIQUIDITY_SWEEP,
   SMC_ORDER_BLOCK,
   SMC_MSS,
   SMC_CHOCH,
   SMC_BOS,
   SMC_FVG,
   SMC_INDUCEMENT,
   SMC_BREAKER_BLOCK,
   SMC_REJECTION_BLOCK,
   SMC_VOLUME_IMBALANCE,
   SMC_SESSION_LIQUIDITY,
   SMC_DAILY_PROFILES
};

struct SMC_Signal {
   ENUM_SMC_STRATEGY strategy;
   ENUM_ORDER_TYPE   type;
   double            price;
   double            sl;
   double            tp;
   bool              isValid;
   string            comment;
};

//--- CONFIG CONSTANTS (v4.3 Boosted) ---
const double CFG_RECOVERY_LOSS_USD = 5.0; // Increased from $4.00
const double CFG_CYCLE_TARGET_USD = 3.0; // Increased from $2.00
const int    CFG_COOLDOWN_MIN = 60;      // 60-minute strategy cooldown
const double CFG_RECOVERY_MULT = 1.0;
const int    CFG_LOT_BOOST_STEPS = 1;
const double CFG_SINGLE_TRAIL_USD = 20.0;
const double CFG_GOLD_ATR_REF = 6.0;     // ATR de referencia do XAUUSD da calibracao original (0.01 lote = $6/ATR)

//+------------------------------------------------------------------+
//| MULTI-ASSET: valor monetario de 1 ATR com o lote atual           |
//| Converte os alvos em USD (calibrados p/ XAUUSD) para qualquer    |
//| simbolo: XAUUSD, US100, BTCUSD, Forex, acoes e indices B3.        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| MULTI-ASSET: True Range medio (replica global do metodo          |
//| GetAverageRange da classe, que nao e visivel no escopo global)   |
//+------------------------------------------------------------------+
double KingAvgRange(ENUM_TIMEFRAMES tf, int period, int index) {
   double sum = 0;
   for(int i = 0; i < period; i++) {
      double high = iHigh(_Symbol, tf, index + i);
      double low  = iLow(_Symbol, tf, index + i);
      double prev_close = iClose(_Symbol, tf, index + i + 1);
      double tr = MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));
      sum += tr;
   }
   return (period > 0) ? sum / period : 0.0;
}

double KingAtrUsd(double lot) {
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0.0 || tv <= 0.0 || lot <= 0.0) return 0.0;
   double atr = KingAvgRange(PERIOD_H1, 14, 1);   // H1 fixo: independe do timeframe do grafico
   if(atr <= 0.0) return 0.0;
   return (atr / ts) * tv * lot;
}

double KingScaleUsd(double usd_ref, double lot) {
   double atr_usd = KingAtrUsd(lot);
   if(atr_usd <= 0.0) return usd_ref;              // fallback: valor original
   return (usd_ref / CFG_GOLD_ATR_REF) * atr_usd;  // mesma proporcao por ATR do XAUUSD
}

bool IsStrategyEnabled(const int index)
{
   switch(index) {
      case 0: return true;   // S1 ON
      case 1: return true;   // S2 ON
      case 2: return true;   // S3 ON
      case 3: return true;   // S4 ON
      case 4: return true;   // S5 ON
      case 5: return true;   // S6 ON
      case 6: return true;   // S7 ON
      case 7: return true;   // S8 ON
      case 8: return true;   // S9 ON
      case 9: return true;   // S10 ON
      case 10: return true;  // S11 ON
      case 11: return true;  // S12 ON
   }
   return false;
}

//+------------------------------------------------------------------+
//| CMarketStructure Class - Deep Algorithmic Mapping                |
//+------------------------------------------------------------------+
class CMarketStructure
{
public:
   struct Swing {
      double price;
      int    index;
      datetime time;
      bool   isHigh;
      bool   isBroken;
   };

   Swing m_swings[];
   int   m_swing_max;
   datetime m_last_update_bar;

   CMarketStructure() : m_swing_max(100), m_last_update_bar(0) { ArraySetAsSeries(m_swings, true); }

   void Update(string symbol, ENUM_TIMEFRAMES period) {
      datetime bar_time = iTime(symbol, period, 0);
      if(bar_time == 0) return;
      if(bar_time == m_last_update_bar && ArraySize(m_swings) > 0) return;
      m_last_update_bar = bar_time;

      ArrayResize(m_swings, 0);
      int lookback = 300;
      for(int i = 5; i < lookback; i++) {
         if(IsPivotHigh(symbol, period, i)) AddSwing(iHigh(symbol, period, i), i, iTime(symbol, period, i), true);
         if(IsPivotLow(symbol, period, i))  AddSwing(iLow(symbol, period, i), i, iTime(symbol, period, i), false);
      }
   }

   bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES period, int i) {
      return (iHigh(symbol, period, i) > iHigh(symbol, period, i+1) && 
              iHigh(symbol, period, i) > iHigh(symbol, period, i+2) &&
              iHigh(symbol, period, i) > iHigh(symbol, period, i-1) && 
              iHigh(symbol, period, i) > iHigh(symbol, period, i-2));
   }

   bool IsPivotLow(string symbol, ENUM_TIMEFRAMES period, int i) {
      return (iLow(symbol, period, i) < iLow(symbol, period, i+1) && 
              iLow(symbol, period, i) < iLow(symbol, period, i+2) &&
              iLow(symbol, period, i) < iLow(symbol, period, i-1) && 
              iLow(symbol, period, i) < iLow(symbol, period, i-2));
   }

   void AddSwing(double p, int idx, datetime t, bool high) {
      int size = ArraySize(m_swings);
      ArrayResize(m_swings, size + 1);
      m_swings[size].price = p;
      m_swings[size].index = idx;
      m_swings[size].time = t;
      m_swings[size].isHigh = high;
      m_swings[size].isBroken = false;
   }

   double GetRecentExtremum(bool high, int rank=0) {
      int found = 0;
      for(int i=0; i<ArraySize(m_swings); i++) {
         if(m_swings[i].isHigh == high) {
            if(found == rank) return m_swings[i].price;
            found++;
         }
      }
      return 0;
   }
};

//+------------------------------------------------------------------+
//| CQuantumDashboard Class - Advanced UI Replica                    |
//+------------------------------------------------------------------+
class CQuantumDashboard
{
private:
   CCanvas m_canvas;
   string  m_name;
   int     m_w, m_h;
   int     m_x, m_y;
   bool    m_paused;
   ulong   m_last_profit_calc_ms;
   datetime m_last_profit_day;
   double  m_cached_daily_profit;

public:
   CQuantumDashboard() : m_name("QQ_Dashboard"), m_w(460), m_h(560), m_x(40), m_y(20), m_paused(false), m_last_profit_calc_ms(0), m_last_profit_day(0), m_cached_daily_profit(0.0) {}
   
   bool Init() {
      if(!m_canvas.CreateBitmapLabel(m_name, m_x, m_y, m_w, m_h, COLOR_FORMAT_ARGB_NORMALIZE))
         return false;
      Update();
      return true;
   }
   
   void Deinit() {
      m_canvas.Destroy();
   }
   
   void OnPaused(bool state) { m_paused = state; Update(); }

   void Update() {
      static ulong last_update = 0;
      if(GetTickCount64() - last_update < 300) return; 
      last_update = GetTickCount64();

      const uint col_bg = ARGB(255, 0, 0, 0);
      const uint col_header = ARGB(255, 23, 28, 126);
      const uint col_border = ARGB(255, 70, 90, 255);
      const uint col_text = ARGB(255, 255, 255, 255);
      const uint col_text_dim = ARGB(255, 220, 220, 220);
      const uint col_text_off = ARGB(255, 165, 165, 165);
      int fs_body = MathMax(11, InpFontSize + 4);
      int fs_head = fs_body + 1;
      int fs_title = fs_body + 2;

      int startX = 8;
      m_canvas.Erase(col_bg);
      m_canvas.FillRectangle(0, 0, m_w, m_h, col_bg);
      m_canvas.Rectangle(0, 0, m_w-1, m_h-1, col_border);
      m_canvas.Rectangle(1, 1, m_w-2, m_h-2, col_border);

      // 1. HEADER
      m_canvas.FillRectangle(4, 4, m_w-4, 34, col_header);
      m_canvas.FontSet(InpFont, fs_title, FW_BOLD);
      string symbol_upper = _Symbol;
      StringToUpper(symbol_upper);
      m_canvas.TextOut(8, 10, StringFormat("Quantum Queen MT5 v3.52 (%s) [%s]", "17/03/2026", symbol_upper), col_text);
      m_canvas.TextOut(m_w - 40, 10, "-  x", col_text);
      
      // 2. TOP BUTTONS (kept aligned with click zones in OnChartEvent)
      int btnW = (m_w - 15) / 2;
      int btnH = 32;
      DrawButton(5, 40, btnW, btnH, m_paused ? "RESUME EA" : "PAUSE EA", col_header);
      DrawButton(m_w - btnW - 5, 40, btnW, btnH, "CLOSE ALL TRADES", col_header);
      
      // 3. INFORMATION BAR
      m_canvas.FillRectangle(5, 75, m_w-5, 95, col_header);
      m_canvas.FontSet(InpFont, fs_head, FW_BOLD);
      m_canvas.TextOut(startX + (m_w/2) - 60, 78, "INFORMATION", col_text);
      
      // 4. DATA FIELDS
      int startY = 105;
      int lineH = 18;
      int strategyX = 265;
      int strategyLineH = 36;
      m_canvas.FontSet(InpFont, fs_body);
      
      string lotMode = (InpLotsCalc == LOT_FIXED) ? "Fixed" : (InpLotsCalc == LOT_BALANCE ? "Fixed per Balance" : "Automatic");
      string fixedTxt = (InpLotsCalc == LOT_FIXED) ? StringFormat("%.2f", InpLotsFixed) : "---";
      string fixedBalTxt = (InpLotsCalc == LOT_BALANCE) ? StringFormat("%.1f", InpLotsFixedBalance) : "---";

      string riskLevel = "Medium";
      switch(InpAutoLotsValue) {
         case RISK_VERY_LOW: riskLevel = "Very Low"; break;
         case RISK_LOW: riskLevel = "Low"; break;
         case RISK_MEDIUM: riskLevel = "Medium"; break;
         case RISK_LOW_MEDIUM: riskLevel = "Low-Medium"; break;
         case RISK_MEDIUM_HIGH: riskLevel = "Medium-High"; break;
         case RISK_HIGH: riskLevel = "High"; break;
         case RISK_VERY_HIGH: riskLevel = "Very High"; break;
      }

      string ddModeTxt = "OFF";
      switch(InpDDMode) {
         case DD_PCT_CLOSE_CONTINUE: ddModeTxt = "[Pct.] Close all EA trades & CONTINUE"; break;
         case DD_PCT_CLOSE_REMOVE:   ddModeTxt = "[Pct.] Close all EA trades & REMOVE"; break;
         case DD_PCT_ALERT:          ddModeTxt = "[Pct.] Alert on Terminal"; break;
         case DD_MONEY_CLOSE_CONTINUE: ddModeTxt = "[Money] Close all EA trades & CONTINUE"; break;
         case DD_MONEY_CLOSE_REMOVE:   ddModeTxt = "[Money] Close all EA trades & REMOVE"; break;
         case DD_MONEY_ALERT:          ddModeTxt = "[Money] Alert on Terminal"; break;
      }

      string setTxt = "IC Markets - RAW - HIGH RISK";
      switch(InpSets) {
         case SET_ROBO_ECN: setTxt = "RoboForex - ECN"; break;
         case SET_FUSION: setTxt = "Fusion Markets - Zero"; break;
         case SET_IC_LOW:   setTxt = "IC Markets - RAW - LOW RISK"; break;
         case SET_IC_HIGH:  setTxt = "IC Markets - RAW - HIGH RISK"; break;
         default: setTxt = "IC Markets - RAW - HIGH RISK"; break;
      }

      double total_volume = GetTotalVolume();
      double total_pl = AccountInfoDouble(ACCOUNT_PROFIT);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      double margin_call = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
      double margin_stop = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
      if(margin_call <= 0) margin_call = 100;
      if(margin_stop < 0) margin_stop = 0;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      string broker_time = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);

      m_canvas.TextOut(startX, startY + lineH*0, "Lot Calculation Method: " + lotMode, col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*1, "Auto Lots Risk Level: " + riskLevel, col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*2, "Fixed: " + fixedTxt, col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*3, "Fixed per Balance: " + fixedBalTxt, col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*4, "DD. Control Mode: " + ddModeTxt, col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*5, StringFormat("DD. Value: %.1f %%", InpDDValue), col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*6, StringFormat("Magic Number: %d", InpMagicNumber), col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*7, "Comment: " + InpComment, col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*8, "MQID® Push Notif. [DD/TP/SL]: " + (IsOn(InpMQID) ? "ON" : "OFF"), col_text_dim);
      
      m_canvas.TextOut(startX, startY + lineH*10, "Set: " + setTxt, col_text);
      m_canvas.TextOut(startX, startY + lineH*12, StringFormat("Total P/L: %.2f USD", total_pl), col_text);
      m_canvas.TextOut(startX, startY + lineH*13, StringFormat("Balance: %.2f USD", balance), col_text);
      m_canvas.TextOut(startX, startY + lineH*14, StringFormat("Equity: %.2f USD", equity), col_text);
      m_canvas.TextOut(startX, startY + lineH*15, StringFormat("Margin Curr.: %.0f%%", margin_level), col_text);
      m_canvas.TextOut(startX, startY + lineH*16, StringFormat("Margin Call: %.0f %%", margin_call), col_text);
      m_canvas.TextOut(startX, startY + lineH*17, StringFormat("Margin StopOut: %.0f %%", margin_stop), col_text_dim);
      m_canvas.TextOut(startX, startY + lineH*18, StringFormat("Total Volume: %.2f Lots", total_volume), col_text);
      m_canvas.TextOut(startX, startY + lineH*20, "Name: Tester", col_text);
      m_canvas.TextOut(startX, startY + lineH*21, StringFormat("Broker: %s | %s", AccountInfoString(ACCOUNT_COMPANY), broker_time), col_text);
      m_canvas.TextOut(startX, startY + lineH*22, StringFormat("Account & Server: %d / %s", (int)AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoString(ACCOUNT_SERVER)), col_text);
      m_canvas.TextOut(startX, startY + lineH*23, StringFormat("Leverage & Currency: %d:1 / %s", (int)AccountInfoInteger(ACCOUNT_LEVERAGE), AccountInfoString(ACCOUNT_CURRENCY)), col_text);

      string active_type = "BUY";
      int active_counts[13] = {0};
      for(int p=0; p<PositionsTotal(); p++) {
         if(PositionSelectByTicket(PositionGetTicket(p))) {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               string comment = PositionGetString(POSITION_COMMENT);
               active_type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               // Parse strategy ID from comment "QQ[...]|...|[TX/SXX]"
               int s_pos = StringFind(comment, "/S");
               if(s_pos > 0) {
                  int s_id = (int)StringToInteger(StringSubstr(comment, s_pos + 2, 2));
                  if(s_id >= 1 && s_id <= 12) active_counts[s_id]++;
               }
            }
         }
      }

      for(int i=0; i<12; i++) {
         bool on = IsStrategyEnabled(i);
         int s_num = i + 1;
         string status = StringFormat("%s | Awaiting signals ...", on ? "ON" : "OFF");
         uint col = on ? col_text : col_text_off;
         
         if(active_counts[s_num] > 0) {
            status = StringFormat("ON | Cycle of %d %s trades ...", active_counts[s_num], active_type);
            col = ARGB(255, 255, 236, 166);
         }
         
         m_canvas.TextOut(strategyX, startY + (i*strategyLineH), StringFormat("[Strategy %d] %s", s_num, status), col);
      }

      m_canvas.Update();
   }
   
private:
   void DrawButton(int x, int y, int w, int h, string text, uint bg) {
      m_canvas.FillRectangle(x, y, x+w, y+h, bg);
      m_canvas.Rectangle(x, y, x+w, y+h, ARGB(255, 85, 105, 255));
      m_canvas.FontSet(InpFont, MathMax(11, InpFontSize + 5), FW_NORMAL);
      m_canvas.TextOut(x + (w/2) - (StringLen(text)*3), y + h/2 - 7, text, ARGB(255, 255, 255, 255));
   }
   
   double GetDailyProfit() {
      datetime start = iTime(_Symbol, PERIOD_D1, 0);
      if(start == 0) return 0.0;

      ulong now_ms = GetTickCount64();
      if(start == m_last_profit_day && (now_ms - m_last_profit_calc_ms) < 1000) {
         return m_cached_daily_profit;
      }

      double profit = 0;
      if(HistorySelect(start, TimeCurrent())) {
         for(int i=HistoryDealsTotal()-1; i>=0; i--) {
            ulong ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol && HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
               profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
               profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
               profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
            }
         }
      }

      m_last_profit_day = start;
      m_last_profit_calc_ms = now_ms;
      m_cached_daily_profit = profit;
      return m_cached_daily_profit;
   }

   double GetTotalVolume() {
      double vol = 0;
      for(int i=0; i<PositionsTotal(); i++) {
         if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               vol += PositionGetDouble(POSITION_VOLUME);
            }
         }
      }
      return vol;
   }
};

//+------------------------------------------------------------------+
//| CStrategyManager Class                                           |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
   int               m_magic;
   CTrade            m_trade;
   CPositionInfo     m_position;
   CMarketStructure  m_structure;
   int               m_swing_lookback;
   int               m_swing_offset;
   datetime          m_last_scan_time;
   int               m_transaction_id;
   datetime          m_last_trade_day;
   datetime          m_last_recovery_scan;
   double            m_single_peak_profit;
   int               m_ma_handles[4];
   datetime          m_last_strat_fire[13]; // Strategy Cooldown Array

public:
   CStrategyManager() : m_magic(0), m_swing_lookback(60), m_swing_offset(5), m_last_scan_time(0), m_transaction_id(1), m_last_trade_day(0), m_last_recovery_scan(0), m_single_peak_profit(0.0) {
      ArrayInitialize(m_ma_handles, INVALID_HANDLE);
      ArrayInitialize(m_last_strat_fire, 0);
   }

   ENUM_ORDER_TYPE GetOpenDirection() {
      for(int i = 0; i < PositionsTotal(); i++) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == _Symbol) {
               return (ENUM_ORDER_TYPE)m_position.PositionType();
            }
         }
      }
      return ORDER_TYPE_BUY; // Default
   }
   
   void Init(int magic) {
      m_magic = magic;
      m_trade.SetExpertMagicNumber(m_magic);
      uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK) != 0)      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      else if((filling & SYMBOL_FILLING_IOC) != 0) m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      else                                        m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
      PrepareTrendHandles();
   }

   void Deinit() {
      ReleaseTrendHandles();
   }
   
   void Update(double lot) {
      // 1. INSTITUTIONAL FILTERS
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      int mins = dt.hour * 60 + dt.min;
      if(mins >= 1430 || mins <= 15) return; 

      double spreadVal = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double maxSpread = (double)InpSpread;
      if(maxSpread <= 0.0) {   // AUTO: 25% do range medio do ativo (minimo 100 pontos)
         double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double rng = (pt > 0.0) ? GetAverageRange(_Symbol, _Period, 14, 1) / pt : 0.0;
         maxSpread = MathMax(100.0, rng * 0.25);
      }
      if(spreadVal > maxSpread) return;

      // 2. VIRTUAL TICK MONITORING
      ExitUpdate(lot);
      
      m_structure.Update(_Symbol, _Period);
      int count = CountOpenPositions();
      if(count >= 4) return; // Max 4 trades
      
      if(count == 0) {
         m_last_recovery_scan = 0;
         m_single_peak_profit = 0.0;
      }
      
      datetime current_bar = iTime(_Symbol, PERIOD_M1, 1);
      if(current_bar == 0) return;

      // 3. SIGNAL-SYNCED RECOVERY (only T2 at -$5.00)
      if(count > 0) {
         double total_p = GetTotalOpenProfit();
         ENUM_ORDER_TYPE original_type = GetOpenDirection();
         datetime now = TimeCurrent();
          double recovery_trigger = KingScaleUsd(CFG_RECOVERY_LOSS_USD, lot);
          double recovery_mult = CFG_RECOVERY_MULT;
         
         if(count == 1 && total_p <= -recovery_trigger && (now - m_last_recovery_scan >= 1)) {
            m_last_recovery_scan = now;
            int strategy_id = GetOpenStrategyId();
            string recovery_comment = GenerateComment("T2", strategy_id);
            double recLot = NormalizeVolume(lot * recovery_mult);
            ExecuteRecovery(original_type, recLot, recovery_comment);
            return;
         }
         return; 
      }

      // 4. SCAN FOR NEW INITIAL TRADES
      if(m_last_scan_time == current_bar) return; 
      
      SMC_Signal sig = ScanForSignals();
      if(sig.isValid) {
         m_last_scan_time = current_bar;
         double price = (sig.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(sig.type == ORDER_TYPE_BUY) m_trade.Buy(lot, _Symbol, price, 0, 0, sig.comment);
         else m_trade.Sell(lot, _Symbol, price, 0, 0, sig.comment);
      }
   }

   void CloseAll() {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == _Symbol) m_trade.PositionClose(m_position.Ticket());
         }
      }
   }
   
private:
   bool ExecuteTrade(SMC_Signal &signal, double lot) {
      double price = (signal.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(signal.type == ORDER_TYPE_BUY) return m_trade.Buy(lot, _Symbol, price, 0, 0, signal.comment);
      else return m_trade.Sell(lot, _Symbol, price, 0, 0, signal.comment);
   }

   void ExitUpdate(double lot) {
      int count = CountOpenPositions();
      if(count == 0) return;
      double total_p = GetTotalOpenProfit();

      if(count == 1) {
         if(total_p > m_single_peak_profit) m_single_peak_profit = total_p;
         double trail_dist = KingScaleUsd(CFG_SINGLE_TRAIL_USD, lot);
         if(m_single_peak_profit >= trail_dist) {
            double trail_lock = m_single_peak_profit - trail_dist;
            if(total_p <= trail_lock) {
               CloseAll();
               m_single_peak_profit = 0.0;
               return;
            }
         }
         return;
      }

      double cycle_target = KingScaleUsd(CFG_CYCLE_TARGET_USD, lot);
      if(total_p >= cycle_target) {
         CloseAll();
         m_single_peak_profit = 0.0;
         return;
      }
   }
   
   void ExecuteRecovery(ENUM_ORDER_TYPE type, double lot, const string &comment) {
      static datetime last_recovery_time = 0;
      if(TimeCurrent() - last_recovery_time < 5) return;
      double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool success = false;
      if(type == ORDER_TYPE_BUY) success = m_trade.Buy(lot, _Symbol, price, 0, 0, comment);
      else success = m_trade.Sell(lot, _Symbol, price, 0, 0, comment);
      if(success) last_recovery_time = TimeCurrent();
   }
   
   double GetTotalOpenProfit() {
      double total = 0;
      for(int i = 0; i < PositionsTotal(); i++) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == _Symbol) {
               total += m_position.Profit() + m_position.Commission() + m_position.Swap();
            }
         }
      }
      return total;
   }

   SMC_Signal ScanForSignals() {
      SMC_Signal signal; signal.isValid = false;
      
      // 1. INSTITUTIONAL VOLUME SNIPER (1.7x for Optimized HF)
      double v1 = (double)iVolume(_Symbol, _Period, 1);
      double v_avg = 0;
      for(int v=2; v<22; v++) v_avg += (double)iVolume(_Symbol, _Period, v);
      v_avg /= 20;
      if(v1 < v_avg * 1.7) return signal; 

      // 2. TREND ALIGNMENT (Full 4-TF Quality)
      ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4};
      if(!PrepareTrendHandles()) return signal;
      bool all_bull = true;
      bool all_bear = true;
      for(int i=0; i<ArraySize(tfs); i++) {
         double ma = 0.0;
         if(!GetTrendMAValue(i, 1, ma)) return signal;
         double close = iClose(_Symbol, tfs[i], 1);
         if(close < ma) all_bull = false;
         if(close > ma) all_bear = false;
      }
      if(!all_bull && !all_bear) return signal; 
      ENUM_ORDER_TYPE allowedType = all_bull ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      
      // 2.5 DEMARKER FILTER
      double dem = 0.0;
      if(!GetDeMarkerValue(1, dem)) return signal;
      
      // Bloqueia entradas ruins
      if(allowedType == ORDER_TYPE_BUY && dem > InpDeMarkerBuy)
         return signal;
      
      if(allowedType == ORDER_TYPE_SELL && dem < InpDeMarkerSell)
         return signal;

      // 3. SNIPER PULSE
      for(int i=0; i<12; i++) {
         if(!IsStrategyEnabled(i)) continue;
         
         // 4. COOLDOWN CHECK
         int s_id = i + 1;
         if(TimeCurrent() - m_last_strat_fire[s_id] < (datetime)CFG_COOLDOWN_MIN * 60) continue;

         int triggerGroup = (i / 2) + 1; 
         switch(i) {
            case 0: signal = Strat_LiquiditySweep(allowedType, triggerGroup, s_id); break;
            case 1: signal = Strat_OrderBlock(allowedType, triggerGroup, s_id); break;
            case 2: signal = Strat_MSS(allowedType, triggerGroup, s_id); break;
            case 3: signal = Strat_CHoCH(allowedType, triggerGroup, s_id); break;
            case 4: signal = Strat_BoS(allowedType, triggerGroup, s_id); break;
            case 5: signal = Strat_FVG(allowedType, triggerGroup, s_id); break;
            case 6: signal = Strat_Inducement(allowedType, triggerGroup, s_id); break;
            case 7: signal = Strat_BreakerBlock(allowedType, triggerGroup, s_id); break;
            case 8: signal = Strat_RejectionBlock(allowedType, triggerGroup, s_id); break;
            case 9: signal = Strat_VolumeImbalance(allowedType, triggerGroup, s_id); break;
            case 10: signal = Strat_SessionLiquidity(allowedType, triggerGroup, s_id); break;
            case 11: signal = Strat_DailyProfiles(allowedType, triggerGroup, s_id); break;
         }
         
         if(signal.isValid) {
            m_last_strat_fire[s_id] = TimeCurrent();
            return signal;
         }
      }
      return signal;
   }

   SMC_Signal Strat_LiquiditySweep(ENUM_ORDER_TYPE type, int t, int s) {
      SMC_Signal sig; sig.isValid = false;
      double h = m_structure.GetRecentExtremum(true);
      double l = m_structure.GetRecentExtremum(false);
      if(type == ORDER_TYPE_BUY && iLow(_Symbol, _Period, 1) < l && iClose(_Symbol, _Period, 1) > l) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s); }
      if(type == ORDER_TYPE_SELL && iHigh(_Symbol, _Period, 1) > h && iClose(_Symbol, _Period, 1) < h) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s); }
      return sig;
   }

   SMC_Signal Strat_OrderBlock(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double range = GetAverageRange(_Symbol, _Period, 14, 1);
      if(type == ORDER_TYPE_BUY) {
         double last_low = m_structure.GetRecentExtremum(false, 0);
         double prev_high = m_structure.GetRecentExtremum(true, 1);
         if(iClose(_Symbol, _Period, 1) > prev_high && iHigh(_Symbol, _Period, 1) > prev_high) {
            if(MathAbs(iLow(_Symbol, _Period, 0) - last_low) < range * 1.5) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
         }
      }
      if(type == ORDER_TYPE_SELL) {
         double last_high = m_structure.GetRecentExtremum(true, 0);
         double prev_low = m_structure.GetRecentExtremum(false, 1);
         if(iClose(_Symbol, _Period, 1) < prev_low && iLow(_Symbol, _Period, 1) < prev_low) {
            if(MathAbs(iHigh(_Symbol, _Period, 0) - last_high) < range * 1.5) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
         }
      }
      return sig;
   }

   double GetAverageRange(string smb, ENUM_TIMEFRAMES tf, int period, int index) {
      double sum = 0;
      for(int i=0; i<period; i++) {
         double high = iHigh(smb, tf, index + i);
         double low  = iLow(smb, tf, index + i);
         double prev_close = iClose(smb, tf, index + i + 1);
         double tr = MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));
         sum += tr;
      }
      return sum / period;
   }

   SMC_Signal Strat_MSS(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double h1 = m_structure.GetRecentExtremum(true, 0);
      double l1 = m_structure.GetRecentExtremum(false, 0);
      if(type == ORDER_TYPE_BUY && iClose(_Symbol, _Period, 1) > h1) {
         double prev_h = m_structure.GetRecentExtremum(true, 1);
         if(h1 < prev_h) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      }
      if(type == ORDER_TYPE_SELL && iClose(_Symbol, _Period, 1) < l1) {
         double prev_l = m_structure.GetRecentExtremum(false, 1);
         if(l1 > prev_l) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      }
      return sig;
   }

   SMC_Signal Strat_CHoCH(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double h1 = m_structure.GetRecentExtremum(true, 0);
      double l1 = m_structure.GetRecentExtremum(false, 0);
      if(type == ORDER_TYPE_BUY && iClose(_Symbol, _Period, 1) > h1 && iClose(_Symbol, _Period, 2) < h1) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      if(type == ORDER_TYPE_SELL && iClose(_Symbol, _Period, 1) < l1 && iClose(_Symbol, _Period, 2) > l1) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      return sig;
   }

   SMC_Signal Strat_BoS(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double h1 = m_structure.GetRecentExtremum(true, 0);
      double l1 = m_structure.GetRecentExtremum(false, 0);
      if(type == ORDER_TYPE_BUY && iClose(_Symbol, _Period, 1) > h1) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      if(type == ORDER_TYPE_SELL && iClose(_Symbol, _Period, 1) < l1) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      return sig;
   }

   SMC_Signal Strat_FVG(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double bodySize = MathAbs(iOpen(_Symbol, _Period, 2) - iClose(_Symbol, _Period, 2));
      double avgBody = GetAverageRange(_Symbol, _Period, 20, 2);
      if(iLow(_Symbol, _Period, 1) > iHigh(_Symbol, _Period, 3) && bodySize > avgBody * 1.5) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      if(iHigh(_Symbol, _Period, 1) < iLow(_Symbol, _Period, 3) && bodySize > avgBody * 1.5) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      return sig;
   }

   SMC_Signal Strat_Inducement(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double minor_l = m_structure.GetRecentExtremum(false, 1);
      double major_l = m_structure.GetRecentExtremum(false, 0);
      if(type == ORDER_TYPE_BUY && iLow(_Symbol, _Period, 1) < minor_l && iClose(_Symbol, _Period, 1) > major_l) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      double minor_h = m_structure.GetRecentExtremum(true, 1);
      double major_h = m_structure.GetRecentExtremum(true, 0);
      if(type == ORDER_TYPE_SELL && iHigh(_Symbol, _Period, 1) > minor_h && iClose(_Symbol, _Period, 1) < major_h) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      return sig;
   }

   SMC_Signal Strat_BreakerBlock(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double failed_h = m_structure.GetRecentExtremum(true, 1);
      if(type == ORDER_TYPE_BUY && iClose(_Symbol, _Period, 1) > failed_h && iLow(_Symbol, _Period, 0) <= failed_h) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      double failed_l = m_structure.GetRecentExtremum(false, 1);
      if(type == ORDER_TYPE_SELL && iClose(_Symbol, _Period, 1) < failed_l && iHigh(_Symbol, _Period, 0) >= failed_l) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      return sig;
   }

   SMC_Signal Strat_RejectionBlock(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double h = m_structure.GetRecentExtremum(true, 0);
      double l = m_structure.GetRecentExtremum(false, 0);
      if(type == ORDER_TYPE_SELL && iHigh(_Symbol, _Period, 1) >= h && iClose(_Symbol, _Period, 1) < h) {
         double wick = iHigh(_Symbol, _Period, 1) - MathMax(iOpen(_Symbol, _Period, 1), iClose(_Symbol, _Period, 1));
         if(wick > GetAverageRange(_Symbol, _Period, 14, 1) * 0.5) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      }
      if(type == ORDER_TYPE_BUY && iLow(_Symbol, _Period, 1) <= l && iClose(_Symbol, _Period, 1) > l) {
         double wick = MathMin(iOpen(_Symbol, _Period, 1), iClose(_Symbol, _Period, 1)) - iLow(_Symbol, _Period, 1);
         if(wick > GetAverageRange(_Symbol, _Period, 14, 1) * 0.5) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      }
      return sig;
   }

   SMC_Signal Strat_VolumeImbalance(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double v1 = (double)iVolume(_Symbol, _Period, 1);
      double v_avg = 0;
      for(int i=2; i<22; i++) v_avg += (double)iVolume(_Symbol, _Period, i);
      v_avg /= 20;
      if(v1 > v_avg * 2.5) { 
         if(type == ORDER_TYPE_BUY && iClose(_Symbol, _Period, 1) > iOpen(_Symbol, _Period, 1)) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
         if(type == ORDER_TYPE_SELL && iClose(_Symbol, _Period, 1) < iOpen(_Symbol, _Period, 1)) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      }
      return sig;
   }

   SMC_Signal Strat_SessionLiquidity(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      if(dt.hour >= 8 && dt.hour <= 10) { 
         double asiaH = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, 8, 2)); 
         double asiaL = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, 8, 2));   
         if(type == ORDER_TYPE_BUY && iLow(_Symbol, _Period, 1) < asiaL && iClose(_Symbol, _Period, 1) > asiaL) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
         if(type == ORDER_TYPE_SELL && iHigh(_Symbol, _Period, 1) > asiaH && iClose(_Symbol, _Period, 1) < asiaH) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      }
      return sig;
   }

   SMC_Signal Strat_DailyProfiles(ENUM_ORDER_TYPE type, int t, int s_id) {
      SMC_Signal sig; sig.isValid = false;
      double adr = GetAverageRange(_Symbol, PERIOD_D1, 5, 1);
      double dayRange = iHigh(_Symbol, PERIOD_D1, 0) - iLow(_Symbol, PERIOD_D1, 0);
      if(dayRange > adr * 1.2) { 
         if(type == ORDER_TYPE_BUY && iClose(_Symbol, _Period, 1) < iLow(_Symbol, PERIOD_D1, 0) + (adr * 0.1)) { sig.isValid = true; sig.type = ORDER_TYPE_BUY; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
         if(type == ORDER_TYPE_SELL && iHigh(_Symbol, _Period, 1) > iHigh(_Symbol, PERIOD_D1, 0) - (adr * 0.1)) { sig.isValid = true; sig.type = ORDER_TYPE_SELL; sig.comment = GenerateComment(StringFormat("T%d", t), s_id); }
      }
      return sig;
   }
   
   string GenerateComment(string tag, int strategy_id) { return StringFormat("QQ[%s]|%d|[%s/S%02d]", _Symbol, m_magic, tag, strategy_id); }

   double NormalizeVolume(double requested_lot) {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0.0) lotStep = 0.01;
      double lot = MathMax(minLot, MathMin(maxLot, requested_lot));
      lot = MathFloor(lot / lotStep) * lotStep;
      int lotDigits = 0;
      double step = lotStep;
      while(step < 1.0 && lotDigits < 8) { step *= 10.0; lotDigits++; }
      return NormalizeDouble(lot, lotDigits);
   }

   int GetOpenStrategyId() {
      for(int i = 0; i < PositionsTotal(); i++) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Magic() == m_magic && m_position.Symbol() == _Symbol) {
               string c = m_position.Comment();
               int s_pos = StringFind(c, "/S");
               if(s_pos >= 0 && StringLen(c) >= s_pos + 4) {
                  int s_id = (int)StringToInteger(StringSubstr(c, s_pos + 2, 2));
                  if(s_id >= 1 && s_id <= 12) return s_id;
               }
               break;
            }
         }
      }
      return 1;
   }
   
   bool PrepareTrendHandles() {
      ENUM_TIMEFRAMES tfs[4] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4};
      for(int i=0; i<4; i++) {
         if(m_ma_handles[i] == INVALID_HANDLE) {
            m_ma_handles[i] = iMA(_Symbol, tfs[i], 200, 0, MODE_EMA, PRICE_CLOSE);
            if(m_ma_handles[i] == INVALID_HANDLE) return false;
         }
      }
      return true;
   }

   bool GetTrendMAValue(int index, int shift, double &value) {
      value = 0.0;
      if(index < 0 || index >= 4) return false;
      if(m_ma_handles[index] == INVALID_HANDLE) return false;
      double buffer[1];
      if(shift < 0) shift = 0;
      if(CopyBuffer(m_ma_handles[index], 0, shift, 1, buffer) != 1) return false;
      value = buffer[0];
      return true;
   }

   void ReleaseTrendHandles() {
      for(int i=0; i<4; i++) { if(m_ma_handles[i] != INVALID_HANDLE) { IndicatorRelease(m_ma_handles[i]); m_ma_handles[i] = INVALID_HANDLE; } }
   }

   int CountOpenPositions() {
      int count = 0;
      for(int i = 0; i < PositionsTotal(); i++) { if(m_position.SelectByIndex(i)) { if(m_position.Magic() == m_magic && m_position.Symbol() == _Symbol) count++; } }
      return count;
   }
};

//--- INPUTS ---
input group "EA LivWell King MT5 v3.52 [MULTI-ASSET]"
input string             InpNoteName          = "EA LivWell King MT5 v3.52"; // Name:
input string             InpNoteOverview      = "Multi-asset: XAUUSD, US100, BTCUSD, Forex, acoes e indices B3. Anexe ao grafico desejado."; // Overview:
input string             InpWebsite           = "https://handliv.com"; // Website:

input group ">>>> GENERAL SETTINGS"
input ENUM_ON_OFF        InpPause             = SWITCH_OFF;        // Start EA Paused
input ENUM_LOT_METHOD    InpLotsCalc          = LOT_AUTO;          // Lot Calculation Method
input ENUM_RISK_LEVEL    InpAutoLotsValue     = RISK_MEDIUM;       // Auto Lots Risk Levels
input double             InpLotsFixed         = 0.01;              // Fixed
input double             InpLotsFixedBalance  = 500.0;             // Fixed per Balance
input ENUM_DD_MODE       InpDDMode            = DD_OFF;            // DD. Control Mode
input double             InpDDValue           = 0.0;               // DD. Value
input ENUM_ON_OFF        InpMQID              = SWITCH_OFF;        // MQID® Push Notif.
input int                InpMagicNumber       = 1234;              // Magic Number
input int                InpSpread            = 0;                 // Max. Spread (Points, 0 = Auto)
input int                InpSlippage          = 100;               // Max. Slippage (Points)
input ENUM_ON_OFF        InpXmas              = SWITCH_OFF;        // Holiday Trading Off (Dec 15–Jan 15)

input group ">>>> SETS & STRATEGIES"
input ENUM_PRESET_SETS   InpSets              = SET_IC_LOW;        // Sets

input group ">>>> PANEL & VISUAL SETTINGS"
input ENUM_ON_OFF        InpPanel             = SWITCH_ON;         // Show Panel
input string             InpFont              = "Trebuchet MS";    // Panel Font
input int                InpFontSize          = 6;                 // Panel Font Size
input string             InpComment           = "EA LivWell King MT5"; // Panel Comment
input ENUM_LINE_STYLE    InpLineStyle         = STYLE_SOLID;       // Line Style
input int                InpLineWidth         = 2;                 // Line Width
input color              InpTPColor           = clrLime;           // TP Line Color
input color              InpBEColor           = clrWhite;          // BE Line Color
input color              InpGridColor         = clrYellow;         // Grid Line Color

string               handliv_api_url      = "https://api.handliv.com/api/v1";    //? -?API Base URL
string               handliv_secret       = "6rsUNfHCWh0mj2nDEJG8OP3ZMlpbYXoR";  //? -?Secret (MT5_API_TOKEN)
bool                 handliv_checar_conta = true;                                //? -?Check account active?

//--- GLOBAL ---
int InpDeMarkerPeriod = 14;     // DeMarker Period
double InpDeMarkerBuy = 0.3;    // Zona de compra (oversold)
double InpDeMarkerSell = 0.7;   // Zona de venda (overbought)

CTrade            g_trade;
CStrategyManager  g_strategy_manager;
CQuantumDashboard g_dashboard;
bool              g_ea_paused = false;

int               m_dem_handle;

// ===== VALIDADE =====
#define DATA_VALIDADE D'2026.12.30 23:59'

int OnInit() {
   if(TimeCurrent() > DATA_VALIDADE)
   {
      Alert("ROBO EXPIRADO! Entre em contato com Handliv");
      ExpertRemove();
      return INIT_FAILED;
   }
   Comment(""); 
   
   vencimento2();
   
   g_ea_paused = IsOn(InpPause);
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   if(IsOn(InpPanel)) g_dashboard.Init();
   g_dashboard.OnPaused(g_ea_paused);
   g_strategy_manager.Init(InpMagicNumber);
   m_dem_handle = iDeMarker(_Symbol, _Period, InpDeMarkerPeriod);
   if(m_dem_handle == INVALID_HANDLE)
      ExpertRemove();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
  if(m_dem_handle != INVALID_HANDLE)
      IndicatorRelease(m_dem_handle);
   g_strategy_manager.Deinit();
   if(IsOn(InpPanel)) g_dashboard.Deinit();
}

void OnTick() {
   if(g_ea_paused) { if(IsOn(InpPanel)) g_dashboard.Update(); return; }
   ManageDrawdown();
   double lot = CalculateLotSize();
   g_strategy_manager.Update(lot);
   if(IsOn(InpPanel)) g_dashboard.Update();
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "QQ_Dashboard") {
      int x = (int)lparam - 40; int y = (int)dparam - 20; int panelW = 600; int btnW = (panelW - 15) / 2;
      if(x >= 5 && x <= (5 + btnW) && y >= 40 && y <= 72) { g_ea_paused = !g_ea_paused; g_dashboard.OnPaused(g_ea_paused); }
      int btn2x = panelW - btnW - 5;
      if(x >= btn2x && x <= (btn2x + btnW) && y >= 40 && y <= 72) g_strategy_manager.CloseAll();
   }
}

double CalculateLotSize() {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0.0) lotStep = 0.01;
   double lot = InpLotsFixed;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(InpLotsCalc == LOT_BALANCE) { if(InpLotsFixedBalance > 0) lot = (balance / InpLotsFixedBalance) * 0.01; }
   else if(InpLotsCalc == LOT_AUTO) {
      double riskRef = 1000.0;
      switch(InpAutoLotsValue) {
         case RISK_VERY_LOW: riskRef = 2000.0; break;
         case RISK_LOW: riskRef = 1500.0; break;
         case RISK_LOW_MEDIUM: riskRef = 1250.0; break;
         case RISK_MEDIUM: riskRef = 1000.0; break;
         case RISK_MEDIUM_HIGH: riskRef = 750.0; break;
         case RISK_HIGH: riskRef = 500.0; break;
         case RISK_VERY_HIGH: riskRef = 300.0; break;
      }
      lot = (balance / riskRef) * 0.01;
   }
   if(CFG_LOT_BOOST_STEPS > 0) lot += (double)CFG_LOT_BOOST_STEPS * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor((lot / lotStep) + 1e-8) * lotStep;
   return NormalizeDouble(lot, 2);
}

void ManageDrawdown() {
   if(InpDDMode == DD_OFF || InpDDValue <= 0) return;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dd_percent = (balance > 0) ? (1.0 - (equity / balance)) * 100.0 : 0;
   double dd_money = balance - equity;
   bool trigger = false;
   bool isPct = (InpDDMode == DD_PCT_CLOSE_CONTINUE || InpDDMode == DD_PCT_CLOSE_REMOVE || InpDDMode == DD_PCT_ALERT);
   if(isPct && dd_percent >= InpDDValue) trigger = true;
   if(!isPct && dd_money >= InpDDValue) trigger = true;
   if(trigger) {
      if(InpDDMode == DD_PCT_ALERT || InpDDMode == DD_MONEY_ALERT) { Alert("Drawdown Limit reached!"); }
      else { g_strategy_manager.CloseAll(); if(InpDDMode == DD_PCT_CLOSE_REMOVE || InpDDMode == DD_MONEY_CLOSE_REMOVE) ExpertRemove(); }
   }
}

bool GetDeMarkerValue(int shift, double &value)
{
   value = 0.0;
   if(m_dem_handle == INVALID_HANDLE) return false;

   double buffer[];
   if(CopyBuffer(m_dem_handle, 0, shift, 1, buffer) != 1)
      return false;

   value = buffer[0];
   return true;
}

string HandlivToken(string account, string secret)
  {
   string data = account + secret;
   uchar  src[], key[], dst[];
   int    len = StringToCharArray(data, src, 0, StringLen(data));
   if(!CryptEncode(CRYPT_HASH_SHA256, src, key, dst))
      return "";
   string hex = "";
   for(int i=0; i<ArraySize(dst); i++)
      hex += StringFormat("%02x", dst[i]);
   return hex;
  }
//+------------------------------------------------------------------+
void vencimento2()
{
   string cookie=NULL,headers;
   char   post[],result[];
   string url=handliv_api_url+"/mt5/ea/status?account="+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"&token="+HandlivToken(IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)), handliv_secret);
//--- To enable access to the server, you should add URL "https://api.handliv.com"
//--- to the list of allowed URLs (Main Menu->Tools->Options, tab "Expert Advisors"):
//--- Resetting the last error code
   ResetLastError();
//--- Downloading a html page from Yahoo Finance
   int res=WebRequest("GET",url,cookie,NULL,500,post,0,result,headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address
      MessageBox("Add the address '"+url+"' to the list of allowed URLs on tab 'Expert Advisors'","Error",MB_ICONINFORMATION);
      HandlivCheckOldAPI();
      //ExpertRemove();
      return;
     }
   if(res==4014)
     {
      Print("Está no backtest");
      ExpertRemove();
      return;
     }
   if(res==200)
     {
      CJAVal js(NULL, jtUNDEF);
      js.Deserialize(result);
      bool registered = js["registered"].ToBool();
      bool is_active  = js["is_active"].ToBool();
      PrintFormat("Handliv API: registered=%d is_active=%d",registered,is_active);
      if (registered && is_active)
        {
         PrintFormat("Robot permitido operar, File size %d byte.",ArraySize(result));
         return;
        }
     }
   else
     {
      PrintFormat("'%s' failed, error code %d",url,res);
     }
//--- Conta nao confirmada na API nova: tenta a API antiga (handliv.com/clientes)
   HandlivCheckOldAPI();
}
//+------------------------------------------------------------------+
void HandlivCheckOldAPI()
{
   string cookie=NULL,headers;
   char   post[],result[];
   string url="http://handliv.com/clientes/"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
//--- Resetting the last error code
   ResetLastError();
//--- Downloading a html page from handliv.com
   int res=WebRequest("GET",url,cookie,NULL,500,post,0,result,headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address
      MessageBox("Add the address '"+url+"' to the list of allowed URLs on tab 'Expert Advisors'","Error",MB_ICONINFORMATION);
      
      ExpertRemove();
      return;
     }
   if(res==4014)
     {
      Print("Está no backtest");
      ExpertRemove();
      return;
     }
   if(res==200)
     {
      PrintFormat("Robot permitido operar (API antiga), File size %d byte.",ArraySize(result));
      CJAVal js(NULL, jtUNDEF);
      js.Deserialize(result);
      string dt = js["clientes"]["dt_vencimento"].ToStr();
      datetime expiracao2 = datetime(dt);
      long ativo = js["clientes"]["ativo"].ToInt();
      if (TimeCurrent() > expiracao2 || ativo == 0)
        {
         Alert("Periodo de uso do robô expirado, contate a Handliv!");
         ExpertRemove();
        }
     }
   else
     {
      PrintFormat("'%s' failed, error code %d",url,res);
      ExpertRemove();
     }
}
