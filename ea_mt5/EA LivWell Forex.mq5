#include <Canvas\Canvas.mqh>
//#property  copyright "Valeriia Mishchenko"
//#property version    "2.12"
//#property strict
//#property description  "Waka Waka EA"
#property copyright   "2023 - Handliv®️"
#property link        "https://handliv.com"
#property version     "1.09"
#property description "Attention"
#property description "Handliv is not responsible for any losses that may occur due to the incorrect use of the program,"
#property description "by using this program you agree that you are aware of all risks associated with financial market and automatic trading,"
#property description "assuming full responsibility for the operations performed by the program."
#property strict
#property description ""
#property description "Contact: faleconosco.handliv@gmail.com | +55 1152866453"
#property icon          "logo_robo.ico"

#include <Trade\Trade.mqh>
CTrade trade;

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

#ifdef __MQL5__ #include <TradeFunctions.mqh> #endif
  enum LotSizingEnum      {LowRiskPreset = 5,//Low Risk Set 20% annual (0.25% load)
                   MidRiskPreset = 4,//Mid Risk Set 40% annual (0.5% load)
                   HighRiskPreset = 3,//Significant Risk Set 80% annual (1.0% load)
                   ExtremeRiskPreset = 7,//High Risk Set 120% annual (1.5% load)
                   LotsEquity = 2,//Dynamic Lot based on Equity
                   LotsBalance = 1,//Dynamic Lot based on Balance
                   LotsDepositLoad = 6,//Lots based on Deposit load
                   FixedLots = 0//Fixed Lot
                     };
  enum AllowBuySellEnum      {AllowSell2 = 2,//Sell only
                   AllowBuy1 = 1,//Buy only
                   AllowBuySell0 = 0//Buy and Sell
                     };
  enum eMaxDrawdownAction      {IgnoreNewUntilRestart = 3,//Prohibit opening new grids until restart
                   IgnoreNewSignals = 2,//Prohibit opening new grids
                   CloseStopTradingUntilRestart = 1,//Close trades & stop trading until restart
                   CloseStopTradingFor24h = 0//Close trades & stop trading for 24h
                     };
  enum eDrawdownCalculation      {ThisStrategy = 1,//This strategy
                   TheAccount = 0//The account
                     };


//------------------
class CCanvasX : public CCanvas  { public:
              //    CCanvasX(void);
                bool CCanvasX_12( string Para_0_st);
         };
   //  CCanvasX::CCanvasX(void){m_style=0xFFFFFFFF;m_style_idx=0;m_chart_id=0;m_objname=NULL;m_objtype=-1;m_rcname=NULL;m_width=0;m_height=0;m_format=0;m_fontname="arial";m_fontsize=-120;m_fontflags=0;m_fontangle=0;};
class SymbolInformation  { public:string  st_1; datetime  da_2; datetime  da_3; int  in_4; bool  bo_5; bool  bo_6; datetime  da_7; datetime  da_8; double  do_9; bool  bo_10; bool  bo_11; double  do_12; double  do_13; int  in_14; int  in_15; long  lo_16; double  do_17; bool  bo_18; bool  bo_19; bool  bo_20; int  in_21; double  do_22; double  do_23; double  do_24; double  do_25; double  do_26; datetime  da_27; datetime  da_28; 
                void SymbolInformation_13();
                void SymbolInformation_14();
                void SymbolInformation_15();
                void ~SymbolInformation();
         };
class CutTrade  { public:long  lo_1; double  do_2; bool  bo_3; 
                void CutTrade_17();
                void CutTrade_18();
                void CutTrade_19();
                void ~CutTrade();
         };
input string MM_Setting="Select the risk settings"  ;   //------> MM & Risk settings <------
input bool AllowOpeningNewGrid=true  ;    //Allow Opening a new Grid?
input  LotSizingEnum  LotSizingMethod=0  ;    //Lot-sizing Method
input double LotSizingValueFixed=0.01  ;    //Fixed Lot
input double LotSizingValueDynamic=10000  ;    //Dynamic Lot (Balance/Equity based)
input double LotSizingDepositLoadPercent=0.25  ;    //Deposit Load %
input bool FixedInitialDeposit=false ;    //Fixed Initial Deposit? (Tester only)
input double MaximumLot=100  ;    //Maximum Lot
input bool AutoSplit=false ;    //Auto Split?
input double MaximumSpread=10  ;    //Maximum Spread, in pips
input int MaximumSlippage=10  ;    //Maximum Slippage for a non-ECN acc, in pips
input int   MaximumSymbols=2  ;    //Maximum Symbols at a time
input bool AllowHedging=true  ;    //Allow Hedging?
input bool AllowTradingOnHolidays=false ;    //Allow Trading on Holidays?
input  AllowBuySellEnum  AllowToBuySell=0  ;    //Allow to Buy/Sell
input double MinimumFreeMargin=0  ;    //Minimum Free Margin % [0-disabled]
input double MaximumDrawdown=100  ;    //Max Floating Drawdown %
input double MaximumDrawdownMoney=0  ;    //Max Floating Drawdown in Money [0-disabled]
input  eMaxDrawdownAction  MaximumDrawdownAction=0  ;    //Max Drawdown Action
input  eDrawdownCalculation  DrawdownCalculation=1  ;    //Max Drawdown Calculation
input string Strategy_Setting="Select the strategy settings and symbols used"  ;   //------> Strategy settings <------
input string Symbols=""  ;   //Symbols separated by comma (custom if empty)
input int   HourToStartTrading=0  ;    //Hour to Start Trading (broker\'s time)
input int   HourToStopTrading=23  ;    //Hour to Stop Trading (broker\'s time)
input int   BollingerBandsPeriod=35  ;    //Bollinger Bands Period
input int   RSI_Period=20  ;    //RSI Period
input int   RSI_Value=15  ;    //Maximum RSI Value
input string Strategy_Setting_TP="Select TP settings"  ;   //------> TakeProfit settings <------
input double InitialTP=10  ;    //TakeProfit for Initial Trade, in pips
input bool WeightedTP=true  ;    //Weighted TakeProfit?
input double GridTP=0  ;    //TakeProfit for Grid, in pips (can also be zero or negative)
input int   BreakEvenAfterThisLevel=0  ;    //Break Even after this Level [0-disabled]
input bool HideTP=false ;    //Hide TakeProfit?
input bool Use_OPO_Method=false ;    //Use OPO method to handle TP
input  ENUM_TIMEFRAMES  OPO_TimeFrame=15  ;    //TF for OPO method
input bool SmartTP=false ;    //Smart TakeProfit?
input bool DoNotAdjustTPUnlessNewGrid=false ;    //Do not adjust TP unless new grid level opened
input string Strategy_Setting_SL="Select SL settings"  ;   //------> StopLoss settings <------
input double GridSL=0  ;    //StopLoss for Grid, in pips (1000pips if zero)
input bool HideSL=false ;    //Hide StopLoss?
input string Grid_Setting="Adjust the grid distance and multipliers"  ;   //------> Grid settings <------
input int   TradeDistance=35  ;    //Trade Distance
input bool SmartDistance=true  ;    //Smart Distance?
input double TradeMultiplier_2nd=1  ;    //2nd Trade Multiplier
input double TradeMultiplier_3rd=2  ;    //3rd-5th Trade Multiplier
input double TradeMultiplier_6th=1.5  ;    //6th- Trade Multiplier
input int   MaximumTrades=9  ;    //Maximum Trades
input int   GridLevelToStart=1  ;    //Grid Level to Start (1-initial trade)
input bool KeepOriginalProfitLotSize=false ;    //Keep Original Profit Level & Lot Size
input string Additional_Setting="Change the comment and UID if needed"  ;   //------> Additional settings <------
input string TradeComment="Handliv"  ;   //Trade Comment
input int   UID=0  ;    //UID (0...9)
input bool ShowPanel=true  ;    //ShowPanel

string               handliv_api_url      = "https://api.handliv.com/api/v1";    //? -?API Base URL
string               handliv_secret       = "6rsUNfHCWh0mj2nDEJG8OP3ZMlpbYXoR";  //? -?Secret (MT5_API_TOKEN)
bool                 handliv_checar_conta = true;                                //? -?Check account active?


//+------------------------------------------------------------------+
//| VARIAVIES DO PAINEL                                              |
//+------------------------------------------------------------------+

//---
   
   
  string    Global_1_st = "::W2.12LD_bmp\\WakaWakaEA.bmp";
  string    Global_2_st = "2.12";
  long      Global_3_lo = 0;
  string    Global_4_st = "";
  int       Global_5_in = 0;
  //string    Global_6_st = "";
  datetime  Global_7_da = 0;
  int       Global_8_in = 0;
  CCanvasX  Global_10_a_167;
  bool      Global_11_bo = true;
  int       Global_12_in = 3000;
  bool      Global_13_bo = false;
  int       Global_14_in = 50000;
  CutTrade  Global_15_a_169_ko[];
  int       Global_16_in = -1;
  double     Global_17_lo_ko[];
  double    Global_18_do_ko[];
  int       Global_19_in = -1;
  int       Global_20_in = 0;
  ENUM_TIMEFRAMES       Global_21_in = PERIOD_M15;
  SymbolInformation Global_22_a_168_ko[];
  ushort     Global_23_sh = 0;
  int       Global_24_in = 84570;
  double    Global_25_do = 0.0000001;
  int       Global_26_in = -1;
  long      Global_27_lo = 0;
  int       Global_28_in = 0;
  bool      Global_29_bo = false;
  int       Global_30_in = 0;
  bool      Global_31_bo = false;
  int       Global_32_in = -1;
  long      Global_33_lo = 0;
  long      Global_34_lo = 0;
  bool      Global_35_bo = false;
  string    Global_36_st = "Select pair";
  bool      Global_37_bo = true;
  double    Global_38_do = 0.0;
  bool      Global_39_bo = true;
  int       Global_40_in = 0;

/*
int _start_pos,_count;double fastma[],std[];
   ArraySetAsSeries(std,true);
   _start_pos=0;_count=300;_count++;
   iGetArray(hstd,0,_start_pos,_count,std);
*/

ENUM_ACCOUNT_TRADE_MODE contarealoudemo = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

datetime expiracao = D'30.12.2026';

int hatr96,hatr672,hrsi,hma,hstd;
 int OnInit()
 {
   //--- Validão dos dias
   if (TimeCurrent() > expiracao)
    {
       Alert("Periodo de uso do robô expirado, contate o admin!");
       return(INIT_FAILED);
    } 
   
   if(contarealoudemo == ACCOUNT_TRADE_MODE_REAL || contarealoudemo == ACCOUNT_TRADE_MODE_DEMO) //
      vencimento2();
      
  

   
   ChartSetSymbolPeriod(0, _Symbol, ENUM_TIMEFRAMES(PERIOD_M15));    
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrLime);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrLime);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrRed);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_ASK, C'255,121,198');
   ChartSetInteger(0, CHART_COLOR_BID, C'255,121,198'); 
  //hstd=iStdDev(_Symbol,0,global_18_in+1,1,3,0);
   /*hatr96=iATR(Local_1_st,Global_21_in,96);
   hatr672=iATR(Local_1_st,Global_21_in,672);
   hrsi=iRSI(Local_1_st,lizong_10(Global_21_in),RSI_Period,0) ;
   hma=iMA(Local_1_st,lizong_10(Global_21_in),BollingerBandsPeriod + 1,0,0,0) ;
   hstd=iStdDev(Local_1_st,lizong_10(Global_21_in),BollingerBandsPeriod + 1,0,0,0);*/
   int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  int       Local_8_in;
  int       Local_9_in;
  int       Local_10_in;
  int       Local_11_in;
  int       Local_12_in;
  int       Local_13_in;
  int       Local_14_in;
  int       Local_15_in;
  int       Local_16_in;
  int       Local_17_in;
  int       Local_18_in;
  int       Local_19_in;
  int       Local_20_in;
  int       Local_21_in;
  //uchar     Local_22_uc;
  //uchar     Local_23_uc;
  //uchar     Local_24_uc;
  int       Local_25_in;
  int       Local_26_in;
  bool      Local_27_bo;
  string    symb[];
  int       Local_29_in;
  int       Local_30_in;
  double    Local_31_do;
  double    Local_32_do;
  int       Local_33_in;
  int       Local_34_in;
//----- -----
 string     tmp_st_1;
 string     tmp_st_2;
 string     tmp_st_3;
 double     tmp_do_4;
 double     tmp_do_5;
 int        tmp_in_6;
 int        tmp_in_7;
 double     tmp_do_8;
 string     tmp_st_9;
 double     tmp_do_10;
 double     tmp_do_11;
 int        tmp_in_12;
 int        tmp_in_13;
 double     tmp_do_14;
 int        tmp_in_15;

 Print(TradeComment + " " + "->",": Initializing..."); 
 Global_30_in = 0 ;
 Global_31_bo = false ;
 Local_2_in = 0 ;
 Local_3_in = 1 ;
 Local_4_in=1 + 1;
 Local_5_in=Local_4_in + 1;
 Local_6_in=Local_4_in + Local_4_in;
 Local_7_in=Local_5_in + Local_4_in;
 Local_8_in=Local_5_in + Local_5_in;
 Local_9_in=Local_6_in + Local_5_in;
 Local_10_in=Local_8_in + Local_4_in;
 Local_11_in=Local_8_in + Local_5_in;
 Local_12_in = 0 ;
 Local_13_in = 1 ;
 Local_14_in = Local_4_in ;
 Local_15_in = Local_5_in ;
 Local_16_in=Local_5_in + 1;
 Local_17_in=Local_6_in + 1;
 Local_18_in=Local_17_in + 1;
 Local_19_in=Local_4_in + Local_17_in;
 Local_20_in=Local_16_in + Local_16_in;
 Local_21_in=Local_20_in + 1;
 /*
 for (Local_22_uc = Local_19_in * Local_21_in + Local_4_in ; Local_22_uc < Local_21_in * Local_11_in + Local_21_in + Local_3_in ; Local_22_uc ++)
 {
   Global_6_st +=CharToString(Local_22_uc);
 }
 for (Local_23_uc = Local_8_in * Local_10_in ; Local_23_uc < Local_19_in * Local_10_in + Local_14_in ; Local_23_uc ++)
 {
   Global_6_st +=CharToString(Local_23_uc);
 }
 for (Local_24_uc = 97 ; Local_24_uc < 123 ; Local_24_uc ++)
 {
   Global_6_st +=CharToString(Local_24_uc);
 }
 Global_6_st +=CharToString(32); //" !,.:/--"
 Global_6_st +=CharToString(33);
 Global_6_st +=CharToString(44);
 Global_6_st +=CharToString(46);
 Global_6_st +=CharToString(58);
 Global_6_st +=CharToString(47);
 Global_6_st +=CharToString(45);
 Global_6_st +=CharToString(95);
 */
 Local_25_in = 1 ;
 Local_26_in = 0 ;
 Global_3_lo = AccountInfoInteger(ACCOUNT_LOGIN) ;
 Global_4_st = AccountInfoString(ACCOUNT_NAME) ;
 Sleep(500); 
 if ( !(MQLInfoInteger(MQL_TESTER)) )
 {
   EventSetTimer(5); 
 }
 Global_27_lo = TimeCurrent() ;
 Global_29_bo = false ;
 Global_23_sh = StringGetCharacter(",",0) ;
 Global_16_in = -1 ;
 Local_27_bo = MQLInfoInteger(MQL_TESTER) ;
 Local_29_in = StringSplit(Symbols,Global_23_sh,symb) ;
 if ( Local_29_in >  0 && !(Local_27_bo) )
 {
   ArrayResize(Global_22_a_168_ko,Local_29_in,0); 
   for (Local_30_in = 0 ; Local_30_in < Local_29_in ; Local_30_in ++)
   {
      tmp_st_1 =symb[Local_30_in];
      StringTrimLeft(tmp_st_1);
     //tmp_st_1 = StringTrimLeft(symb[Local_30_in]);
     tmp_st_2 =symb[Local_30_in];
     StringTrimLeft(tmp_st_2);
     StringTrimRight(tmp_st_2);
     Global_22_a_168_ko[Local_30_in].st_1 = symb[Local_30_in];
     StringTrimLeft(Global_22_a_168_ko[Local_30_in].st_1);
     StringTrimRight(Global_22_a_168_ko[Local_30_in].st_1);
     if ( Global_22_a_168_ko[Local_30_in].st_1 == "" )
     {
       Global_22_a_168_ko[Local_30_in].st_1 = "??????";
       Print(TradeComment + " " + Global_22_a_168_ko[Local_30_in].st_1,": List of Symbols is incorrect! Check it for extra commas!"); 
       Global_35_bo = true ;
     }
     Global_22_a_168_ko[Local_30_in].da_2 = 0;
     Global_22_a_168_ko[Local_30_in].in_4 = 0;
     Global_22_a_168_ko[Local_30_in].bo_5 = false;
     Global_22_a_168_ko[Local_30_in].bo_6 = false;
     Global_22_a_168_ko[Local_30_in].da_7 = 0;
     Global_22_a_168_ko[Local_30_in].da_8 = 0;
     Global_22_a_168_ko[Local_30_in].do_9 = 0.0;
     Global_22_a_168_ko[Local_30_in].bo_10 = false;
     Global_22_a_168_ko[Local_30_in].bo_11 = false;
     Global_22_a_168_ko[Local_30_in].do_12 = 1.0;
     Global_22_a_168_ko[Local_30_in].do_13 = 0.0;
     Global_22_a_168_ko[Local_30_in].in_14 = 0;
     Global_22_a_168_ko[Local_30_in].in_15 = 0;
     Global_22_a_168_ko[Local_30_in].lo_16 = 0;
     Global_22_a_168_ko[Local_30_in].do_17 = 0.0;
     Global_22_a_168_ko[Local_30_in].bo_18 = true;
     Global_22_a_168_ko[Local_30_in].bo_19 = true;
     Global_22_a_168_ko[Local_30_in].bo_20 = true;
     Global_22_a_168_ko[Local_30_in].in_21 = 0;
     tmp_st_3 = Global_22_a_168_ko[Local_30_in].st_1;
     tmp_do_4 = 0.1;
     tmp_do_5 = 0.1;
     tmp_in_6 = 1;
     for (tmp_in_7=MaximumTrades - 1 ; tmp_in_6 <= tmp_in_7 ; tmp_in_7=MaximumTrades - 1)
     {
       tmp_do_5 = tmp_do_5 + lizong_36(tmp_st_3,tmp_do_4,tmp_in_6,0.0);
       tmp_in_6=tmp_in_6 + 1;
     }
     if ( tmp_do_4>Global_25_do )
     {
       tmp_do_8 = tmp_do_5 / tmp_do_4;
     }
     else
     {
       tmp_do_8 = 0.0;
     }
     Global_22_a_168_ko[Local_30_in].do_22 = tmp_do_8;
     Global_22_a_168_ko[Local_30_in].do_23 = 0.0;
     Global_22_a_168_ko[Local_30_in].do_24 = 0.0;
     Global_22_a_168_ko[Local_30_in].do_25 = 0.0;
     Global_22_a_168_ko[Local_30_in].do_26 = 0.0;
   }
 }
 else
 {
   ArrayResize(Global_22_a_168_ko,1,0); 
   Global_22_a_168_ko[0].st_1 = Symbol();
   Global_22_a_168_ko[0].da_2 = 0;
   Global_22_a_168_ko[0].in_4 = 0;
   Global_22_a_168_ko[0].bo_5 = false;
   Global_22_a_168_ko[0].bo_6 = false;
   Global_22_a_168_ko[0].da_7 = 0;
   Global_22_a_168_ko[0].da_8 = 0;
   Global_22_a_168_ko[0].do_9 = 0.0;
   Global_22_a_168_ko[0].bo_10 = false;
   Global_22_a_168_ko[0].bo_11 = false;
   Global_22_a_168_ko[0].do_12 = 1.0;
   Global_22_a_168_ko[0].do_13 = 0.0;
   Global_22_a_168_ko[0].in_14 = 0;
   Global_22_a_168_ko[0].in_15 = 0;
   Global_22_a_168_ko[0].lo_16 = 0;
   Global_22_a_168_ko[0].do_17 = 0.0;
   Global_22_a_168_ko[0].bo_18 = true;
   Global_22_a_168_ko[0].bo_19 = true;
   Global_22_a_168_ko[0].bo_20 = true;
   Global_22_a_168_ko[0].in_21 = 0;
   tmp_st_9 = Symbol();
   tmp_do_10 = 0.1;
   tmp_do_11 = 0.1;
   tmp_in_12 = 1;
   for (tmp_in_13=MaximumTrades - 1 ; tmp_in_12 <= tmp_in_13 ; tmp_in_13=MaximumTrades - 1)
   {
     tmp_do_11 = tmp_do_11 + lizong_36(tmp_st_9,tmp_do_10,tmp_in_12,0.0);
     tmp_in_12=tmp_in_12 + 1;
   }
   if ( tmp_do_10>Global_25_do )
   {
     tmp_do_14 = tmp_do_11 / tmp_do_10;
   }
   else
   {
     tmp_do_14 = 0.0;
   }
   Global_22_a_168_ko[0].do_22 = tmp_do_14;
   Global_22_a_168_ko[0].do_23 = 0.0;
   Global_22_a_168_ko[0].do_24 = 0.0;
   Global_22_a_168_ko[0].do_25 = 0.0;
   Global_22_a_168_ko[0].do_26 = 0.0;
 }
 if ( Global_13_bo )
 {
   ArrayResize(Global_15_a_169_ko,Global_14_in,0); 
 }
 if ( !(MQLInfoInteger(MQL_OPTIMIZATION)) )
 {
   ObjectsDeleteAll(0,-1); 
   if ( ShowPanel )
   {
     lizong_46(); 
     lizong_49(true); 
   }
   if ( MQLInfoInteger(MQL_VISUAL_MODE) )
   {
     if ( ObjectFind(0,"but_Buy") != -1 && ObjectGetInteger(0,"but_Buy",OBJPROP_STATE,0) != 0 )
     {
       lizong_48("but_Buy"); 
     }
     if ( ObjectFind(0,"but_Sell") != -1 && ObjectGetInteger(0,"but_Sell",OBJPROP_STATE,0) != 0 )
     {
       lizong_48("but_Sell"); 
     }
     if ( ObjectFind(0,"but_Pair") != -1 && ObjectGetInteger(0,"but_Pair",OBJPROP_STATE,0) != 0 )
     {
       lizong_48("but_Pair"); 
     }
     if ( ObjectFind(0,"but_Suspend") != -1 )
     {
       Global_37_bo=!(ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0));
       if ( ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0) == 0 )
       {
         ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,32768); 
         ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids allowed"); 
       }
       if ( !(Global_37_bo) )
       {
         ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,255); 
         ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids NOT allowed!"); 
         for (tmp_in_15 = 0 ; tmp_in_15 < ArraySize(Global_22_a_168_ko) ; tmp_in_15=tmp_in_15 + 1)
         {
           Global_22_a_168_ko[tmp_in_15].bo_5 = false;
           Global_22_a_168_ko[tmp_in_15].bo_6 = false;
         }
       }
       ChartRedraw(0); 
     }
   }
   ChartRedraw(0); 
 }
 if ( Global_11_bo )
 {
   ArrayResize(Global_17_lo_ko,Global_12_in,0); 
   ArrayFill(Global_17_lo_ko,0,Global_12_in,0);
   ArrayResize(Global_18_do_ko,Global_12_in,0); 
   if ( Global_12_in != 0 )
   {
     ArrayFill(Global_18_do_ko,0,Global_12_in,0.0);
   }
 }
 if ( Global_11_bo )
 {
   lizong_27(); 
 }
 if ( Global_11_bo )
 {
   Local_31_do = 0.0 ;
   Local_32_do = 0.0 ;
   for (Local_33_in = 0 ; Local_33_in < ArraySize(Global_18_do_ko) ; Local_33_in ++)
   {
     for (Local_34_in = 0 ; Local_34_in < ArraySize(Global_17_lo_ko) - Local_33_in - 1 ; Local_34_in ++)
     {
       if ( Global_18_do_ko[Local_34_in]>Global_18_do_ko[Local_34_in + 1] )
       {
         Local_31_do = Global_18_do_ko[Local_34_in] ;
         Local_32_do = Global_17_lo_ko[Local_34_in] ;
         Global_18_do_ko[Local_34_in] = Global_18_do_ko[Local_34_in + 1];
         Global_17_lo_ko[Local_34_in] = Global_17_lo_ko[Local_34_in + 1];
         Global_18_do_ko[Local_34_in + 1] = Local_31_do;
         Global_17_lo_ko[Local_34_in + 1] = Local_32_do;
       }
     }
   }
 }
  if ( InpHLVShowPanel && !MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION) )
    HLVPanelCreate();
  Global_38_do = AccountInfoDouble(ACCOUNT_BALANCE) ;
 if ( ( Local_2_in + Local_3_in + Local_4_in + Local_5_in + Local_6_in + Local_7_in + Local_8_in + Local_9_in + Local_10_in + Local_11_in != 45 || Local_12_in + Local_13_in + Local_14_in + Local_15_in + Local_16_in + Local_17_in + Local_18_in + Local_19_in + Local_20_in + Local_21_in != 45 ) )
 {
   return(32767); 
 }
 return(0); 
 }
//OnInit <<==--------   --------
 void OnTick()
 {
  if(NewDay())
     {
        if(contarealoudemo == ACCOUNT_TRADE_MODE_REAL || contarealoudemo == ACCOUNT_TRADE_MODE_DEMO)//
         vencimento2();
         
        if (TimeCurrent() > expiracao)
          {
             Alert("Periodo de uso do robô expirado, contate o admin!");
             ExpertRemove();
          }
     }
     

 
  int       Local_1_in;
//----- -----
 bool       tmp_bo_1;
 int        tmp_in_2;
 bool       tmp_bo_3;


//-------------------------

 for (Local_1_in = 0 ; Local_1_in < ArraySize(Global_22_a_168_ko) ; Local_1_in ++)
 {
   if ( iTime(Global_22_a_168_ko[Local_1_in].st_1,Global_21_in,0) <= Global_22_a_168_ko[Local_1_in].da_2 )
   {
     tmp_bo_1 = false;
   }
   else
   {
     Global_22_a_168_ko[Local_1_in].da_2 = iTime(Global_22_a_168_ko[Local_1_in].st_1,Global_21_in,0);
     tmp_bo_1 = true;
   }
   
   if ( tmp_bo_1 )
   {
     lizong_32(Local_1_in); 
     if ( MQLInfoInteger(MQL_TRADE_ALLOWED) )
     {
       tmp_in_2 = TerminalInfoInteger(8);
       if ( tmp_in_2 != 0 )
       {
         tmp_in_2 = (int)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
       }
       if ( tmp_in_2 != 0 )
       {
         tmp_in_2 = MQLInfoInteger(MQL_TRADE_ALLOWED);
       }
       if ( ( tmp_in_2 != 0 || MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) ) )
       {
         lizong_37(Local_1_in); 
         lizong_25(Local_1_in); 
         lizong_26(Local_1_in); 
       }
     }
   }
   if ( iTime(Global_22_a_168_ko[Local_1_in].st_1,OPO_TimeFrame,0) <= Global_22_a_168_ko[Local_1_in].da_3 )
   {
     tmp_bo_3 = false;
   }
   else
   {
     Global_22_a_168_ko[Local_1_in].da_3 = iTime(Global_22_a_168_ko[Local_1_in].st_1,OPO_TimeFrame,0);
     tmp_bo_3 = true;
   }
   if ( tmp_bo_3 )
   {
     Global_22_a_168_ko[Local_1_in].bo_11 = false;
   }
 }
 lizong_35(); 
 }
//OnTick <<==--------   --------
 void OnTimer()
 {
 int        tmp_in_1;

 if ( MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) )   return;
 Global_27_lo = TimeCurrent() ;
 if ( InpHLVShowPanel )
 {
   HLVPanelUpdate();
   HLVPanelPoll();
 }
 for (tmp_in_1 = 0 ; tmp_in_1 < ArraySize(Global_22_a_168_ko) ; tmp_in_1=tmp_in_1 + 1)
 {
   iTime(Global_22_a_168_ko[tmp_in_1].st_1,Global_21_in,0); 
   iTime(Global_22_a_168_ko[tmp_in_1].st_1,OPO_TimeFrame,0); 
 }
 if ( !(ShowPanel) )   return;
 lizong_49(false); 
 }
//OnTimer <<==--------   --------
 void OnChartEvent( const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
 {
 
 if(id==CHARTEVENT_OBJECT_CLICK) HLVPanelPoll();
 if ( id != 1 )   return;
 lizong_48(sparam);
 }
//OnChartEvent <<==--------   --------
 void OnDeinit( const int reason)
 {

 HLVPanelDelete();

 string     tmp_st_1;

 EventKillTimer();
 tmp_st_1 = "";
 switch(reason)
 {
   case 6 :
   tmp_st_1 = "Account changed";
     break;
   case 3 :
   tmp_st_1 = "Symbol/timeframe changed";
     break;
   case 4 :
   tmp_st_1 = "Chart closed";
     break;
   case 5 :
   tmp_st_1 = "Input parameters changed";
     break;
   case 2 :
   tmp_st_1 = "Expert recompiled";
     break;
   case 1 :
   tmp_st_1 = "Expert removed from the chart";
     break;
   case 7 :
   tmp_st_1 = "New template applied to the chart";
     break;
   default :
   tmp_st_1 = "Expert stopped";
 }
 Print(tmp_st_1); 
 if ( !(MQLInfoInteger(MQL_TESTER)) && !(MQLInfoInteger(MQL_OPTIMIZATION)) )
 {Global_10_a_167.Destroy();
 }
 if ( MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) )   return;
 ObjectsDeleteAll(0,-1); 
 }
//OnDeinit <<==--------   --------
 ENUM_TIMEFRAMES lizong_10( int Para_0_in)
 {
  //int       Local_1_in;
//----- -----

 switch(Para_0_in)
 {
   case 0 :
   return(PERIOD_CURRENT); 
   case 1 :
   return(PERIOD_M1); 
   case 5 :
   return(PERIOD_M5); 
   case 15 :
   return(PERIOD_M15); 
   case 30 :
   return(PERIOD_M30); 
   case 60 :
   return(PERIOD_H1); 
   case 240 :
   return(PERIOD_H4); 
   case 1440 :
   return(PERIOD_D1); 
   case 10080 :
   return(PERIOD_W1); 
   case 43200 :
   return(PERIOD_MN1); 
 }
 return(PERIOD_CURRENT); 
 }
//lizong_10 <<==--------   --------
 string lizong_11( int Para_0_in)
 {
  int       Local_1_in = 0;
  string    Local_2_st;
//----- -----
 string     tmp_st_1;

 if ( Para_0_in == -1 )
 {
   Local_1_in = GetLastError() ;
 }
 else
 {
   Local_1_in = Para_0_in ;
 }
 Local_2_st = " Err.code=" + IntegerToString(Local_1_in,0,32) + ": " ;
 switch(Local_1_in)
 {
   case 0 :
   tmp_st_1 = Local_2_st + "No error returned";
   return(tmp_st_1);
   case 1 :
   tmp_st_1 = Local_2_st + "No error returned, but the result is unknown";
   return(tmp_st_1);
   case 2 :
   tmp_st_1 = Local_2_st + "Common error";
   return(tmp_st_1);
   case 3 :
   tmp_st_1 = Local_2_st + "Invalid trade parameters";
   return(tmp_st_1);
   case 4 :
   tmp_st_1 = Local_2_st + "Trade server is busy";
   return(tmp_st_1);
   case 5 :
   tmp_st_1 = Local_2_st + "Old version of the client terminal";
   return(tmp_st_1);
   case 6 :
   tmp_st_1 = Local_2_st + "No connection with trade server";
   return(tmp_st_1);
   case 7 :
   tmp_st_1 = Local_2_st + "Not enough rights";
   return(tmp_st_1);
   case 8 :
   tmp_st_1 = Local_2_st + "Too frequent requests";
   return(tmp_st_1);
   case 9 :
   tmp_st_1 = Local_2_st + "Malfunctional trade operation";
   return(tmp_st_1);
   case 64 :
   tmp_st_1 = Local_2_st + "Account disabled";
   return(tmp_st_1);
   case 65 :
   tmp_st_1 = Local_2_st + "Invalid account";
   return(tmp_st_1);
   case 128 :
   tmp_st_1 = Local_2_st + "Trade timeout";
   return(tmp_st_1);
   case 129 :
   tmp_st_1 = Local_2_st + "Invalid price";
   return(tmp_st_1);
   case 130 :
   tmp_st_1 = Local_2_st + "Invalid stops";
   return(tmp_st_1);
   case 131 :
   tmp_st_1 = Local_2_st + "Invalid trade volume";
   return(tmp_st_1);
   case 132 :
   tmp_st_1 = Local_2_st + "Market is closed";
   return(tmp_st_1);
   case 133 :
   tmp_st_1 = Local_2_st + "Trade is disabled";
   return(tmp_st_1);
   case 134 :
   tmp_st_1 = Local_2_st + "Not enough money";
   return(tmp_st_1);
   case 135 :
   tmp_st_1 = Local_2_st + "Price changed";
   return(tmp_st_1);
   case 136 :
   tmp_st_1 = Local_2_st + "Off quotes";
   return(tmp_st_1);
   case 137 :
   tmp_st_1 = Local_2_st + "Broker is busy";
   return(tmp_st_1);
   case 138 :
   tmp_st_1 = Local_2_st + "Requote";
   return(tmp_st_1);
   case 139 :
   tmp_st_1 = Local_2_st + "Order is locked";
   return(tmp_st_1);
   case 140 :
   tmp_st_1 = Local_2_st + "Buy orders only allowed";
   return(tmp_st_1);
   case 141 :
   tmp_st_1 = Local_2_st + "Too many requests";
   return(tmp_st_1);
   case 145 :
   tmp_st_1 = Local_2_st + "Modification denied because order is too close to market";
   return(tmp_st_1);
   case 146 :
   tmp_st_1 = Local_2_st + "Trade context is busy";
   return(tmp_st_1);
   case 147 :
   tmp_st_1 = Local_2_st + "Expirations are denied by broker";
   return(tmp_st_1);
   case 148 :
   tmp_st_1 = Local_2_st + "The amount of open and pending orders has reached the limit set by the broker";
   return(tmp_st_1);
   case 149 :
   tmp_st_1 = Local_2_st + "An attempt to open an order opposite to the existing one when hedging is disabled";
   return(tmp_st_1);
   case 150 :
   tmp_st_1 = Local_2_st + "An attempt to close an order contravening the FIFO rule";
   return(tmp_st_1);
   case 4000 :
   tmp_st_1 = Local_2_st + "No error returned";
   return(tmp_st_1);
   case 4001 :
   tmp_st_1 = Local_2_st + "Wrong function pointer";
   return(tmp_st_1);
   case 4002 :
   tmp_st_1 = Local_2_st + "Array index is out of range";
   return(tmp_st_1);
   case 4003 :
   tmp_st_1 = Local_2_st + "No memory for function call stack";
   return(tmp_st_1);
   case 4004 :
   tmp_st_1 = Local_2_st + "Recursive stack overflow";
   return(tmp_st_1);
   case 4005 :
   tmp_st_1 = Local_2_st + "Not enough stack for parameter";
   return(tmp_st_1);
   case 4006 :
   tmp_st_1 = Local_2_st + "No memory for parameter string";
   return(tmp_st_1);
   case 4007 :
   tmp_st_1 = Local_2_st + "No memory for temp string";
   return(tmp_st_1);
   case 4008 :
   tmp_st_1 = Local_2_st + "Not initialized string";
   return(tmp_st_1);
   case 4009 :
   tmp_st_1 = Local_2_st + "Not initialized string in array";
   return(tmp_st_1);
   case 4010 :
   tmp_st_1 = Local_2_st + "No memory for array string";
   return(tmp_st_1);
   case 4011 :
   tmp_st_1 = Local_2_st + "Too long string";
   return(tmp_st_1);
   case 4012 :
   tmp_st_1 = Local_2_st + "Remainder from zero divide";
   return(tmp_st_1);
   case 4013 :
   tmp_st_1 = Local_2_st + "Zero divide";
   return(tmp_st_1);
   case 4014 :
   tmp_st_1 = Local_2_st + "Unknown command";
   return(tmp_st_1);
   case 4015 :
   tmp_st_1 = Local_2_st + "Wrong jump (never generated error)";
   return(tmp_st_1);
   case 4016 :
   tmp_st_1 = Local_2_st + "Not initialized array";
   return(tmp_st_1);
   case 4017 :
   tmp_st_1 = Local_2_st + "DLL calls are not allowed";
   return(tmp_st_1);
   case 4018 :
   tmp_st_1 = Local_2_st + "Cannot load library";
   return(tmp_st_1);
   case 4019 :
   tmp_st_1 = Local_2_st + "Cannot call function";
   return(tmp_st_1);
   case 4020 :
   tmp_st_1 = Local_2_st + "Expert function calls are not allowed";
   return(tmp_st_1);
   case 4021 :
   tmp_st_1 = Local_2_st + "Not enough memory for temp string returned from function";
   return(tmp_st_1);
   case 4022 :
   tmp_st_1 = Local_2_st + " System is busy (never generated error)";
   return(tmp_st_1);
   case 4023 :
   tmp_st_1 = Local_2_st + "DLL-function call critical error";
   return(tmp_st_1);
   case 4024 :
   tmp_st_1 = Local_2_st + "Internal error";
   return(tmp_st_1);
   case 4025 :
   tmp_st_1 = Local_2_st + "Out of memory";
   return(tmp_st_1);
   case 4026 :
   tmp_st_1 = Local_2_st + "Invalid pointer";
   return(tmp_st_1);
   case 4027 :
   tmp_st_1 = Local_2_st + "Too many formatters in the format function";
   return(tmp_st_1);
   case 4028 :
   tmp_st_1 = Local_2_st + "Parameters count exceeds formatters count";
   return(tmp_st_1);
   case 4029 :
   tmp_st_1 = Local_2_st + "Invalid array";
   return(tmp_st_1);
   case 4030 :
   tmp_st_1 = Local_2_st + "No reply from chart";
   return(tmp_st_1);
   case 4050 :
   tmp_st_1 = Local_2_st + "Invalid function parameters count";
   return(tmp_st_1);
   case 4051 :
   tmp_st_1 = Local_2_st + "Invalid function parameter value";
   return(tmp_st_1);
   case 4052 :
   tmp_st_1 = Local_2_st + "String function internal error";
   return(tmp_st_1);
   case 4053 :
   tmp_st_1 = Local_2_st + "Some array error";
   return(tmp_st_1);
   case 4054 :
   tmp_st_1 = Local_2_st + "Incorrect series array using";
   return(tmp_st_1);
   case 4055 :
   tmp_st_1 = Local_2_st + "Custom indicator error";
   return(tmp_st_1);
   case 4056 :
   tmp_st_1 = Local_2_st + "Arrays are incompatible";
   return(tmp_st_1);
   case 4057 :
   tmp_st_1 = Local_2_st + "Global variables processing error";
   return(tmp_st_1);
   case 4058 :
   tmp_st_1 = Local_2_st + "Global variable not found";
   return(tmp_st_1);
   case 4059 :
   tmp_st_1 = Local_2_st + "Function is not allowed in testing mode";
   return(tmp_st_1);
   case 4060 :
   tmp_st_1 = Local_2_st + "Function is not allowed for call";
   return(tmp_st_1);
   case 4061 :
   tmp_st_1 = Local_2_st + "Send mail error";
   return(tmp_st_1);
   case 4062 :
   tmp_st_1 = Local_2_st + "String parameter expected";
   return(tmp_st_1);
   case 4063 :
   tmp_st_1 = Local_2_st + "Integer parameter expected";
   return(tmp_st_1);
   case 4064 :
   tmp_st_1 = Local_2_st + "Double parameter expected";
   return(tmp_st_1);
   case 4065 :
   tmp_st_1 = Local_2_st + "Array as parameter expected";
   return(tmp_st_1);
   case 4066 :
   tmp_st_1 = Local_2_st + "Requested history data is in updating state";
   return(tmp_st_1);
   case 4067 :
   tmp_st_1 = Local_2_st + "Internal trade error";
   return(tmp_st_1);
   case 4068 :
   tmp_st_1 = Local_2_st + "Resource not found";
   return(tmp_st_1);
   case 4069 :
   tmp_st_1 = Local_2_st + "Resource not supported";
   return(tmp_st_1);
   case 4070 :
   tmp_st_1 = Local_2_st + "Duplicate resource";
   return(tmp_st_1);
   case 4071 :
   tmp_st_1 = Local_2_st + "Custom indicator cannot initialize";
   return(tmp_st_1);
   case 4072 :
   tmp_st_1 = Local_2_st + "Cannot load custom indicator";
   return(tmp_st_1);
   case 4073 :
   tmp_st_1 = Local_2_st + "No history data";
   return(tmp_st_1);
   case 4074 :
   tmp_st_1 = Local_2_st + "No memory for history data";
   return(tmp_st_1);
   case 4075 :
   tmp_st_1 = Local_2_st + "Not enough memory for indicator calculation";
   return(tmp_st_1);
   case 4099 :
   tmp_st_1 = Local_2_st + "End of file";
   return(tmp_st_1);
   case 4100 :
   tmp_st_1 = Local_2_st + "Some file error";
   return(tmp_st_1);
   case 4101 :
   tmp_st_1 = Local_2_st + "Wrong file name";
   return(tmp_st_1);
   case 4102 :
   tmp_st_1 = Local_2_st + "Too many opened files";
   return(tmp_st_1);
   case 4103 :
   tmp_st_1 = Local_2_st + "Cannot open file";
   return(tmp_st_1);
   case 4104 :
   tmp_st_1 = Local_2_st + "Incompatible access to a file";
   return(tmp_st_1);
   case 4105 :
   tmp_st_1 = Local_2_st + "No order selected";
   return(tmp_st_1);
   case 4106 :
   tmp_st_1 = Local_2_st + "Unknown symbol";
   return(tmp_st_1);
   case 4107 :
   tmp_st_1 = Local_2_st + "Invalid price";
   return(tmp_st_1);
   case 4108 :
   tmp_st_1 = Local_2_st + "Invalid ticket";
   return(tmp_st_1);
   case 4109 :
   tmp_st_1 = Local_2_st + "Trade is not allowed. Enable checkbox \'Allow live trading\' in the Expert Advisor properties";
   return(tmp_st_1);
   case 4110 :
   tmp_st_1 = Local_2_st + "Longs are not allowed. Check the Expert Advisor properties";
   return(tmp_st_1);
   case 4111 :
   tmp_st_1 = Local_2_st + "Shorts are not allowed. Check the Expert Advisor properties";
   return(tmp_st_1);
   case 4112 :
   tmp_st_1 = Local_2_st + "Automated trading by Expert Advisors/Scripts disabled by trade server";
   return(tmp_st_1);
   case 4200 :
   tmp_st_1 = Local_2_st + "Object already exists";
   return(tmp_st_1);
   case 4201 :
   tmp_st_1 = Local_2_st + "Unknown object property";
   return(tmp_st_1);
   case 4202 :
   tmp_st_1 = Local_2_st + "Object does not exist";
   return(tmp_st_1);
   case 4203 :
   tmp_st_1 = Local_2_st + "Unknown object type";
   return(tmp_st_1);
   case 4204 :
   tmp_st_1 = Local_2_st + "No object name";
   return(tmp_st_1);
   case 4205 :
   tmp_st_1 = Local_2_st + "Object coordinates error";
   return(tmp_st_1);
   case 4206 :
   tmp_st_1 = Local_2_st + "No specified subwindow";
   return(tmp_st_1);
   case 4207 :
   tmp_st_1 = Local_2_st + "Graphical object error";
   return(tmp_st_1);
   case 4210 :
   tmp_st_1 = Local_2_st + "Unknown chart property";
   return(tmp_st_1);
   case 4211 :
   tmp_st_1 = Local_2_st + "Chart not found";
   return(tmp_st_1);
   case 4212 :
   tmp_st_1 = Local_2_st + "Chart subwindow not found";
   return(tmp_st_1);
   case 4213 :
   tmp_st_1 = Local_2_st + "Chart indicator not found";
   return(tmp_st_1);
   case 4220 :
   tmp_st_1 = Local_2_st + "Symbol select error";
   return(tmp_st_1);
   case 4250 :
   tmp_st_1 = Local_2_st + "Notification error";
   return(tmp_st_1);
   case 4251 :
   tmp_st_1 = Local_2_st + "Notification parameter error";
   return(tmp_st_1);
   case 4252 :
   tmp_st_1 = Local_2_st + "Notifications disabled";
   return(tmp_st_1);
   case 4253 :
   tmp_st_1 = Local_2_st + "Notification send too frequent";
   return(tmp_st_1);
   case 4260 :
   tmp_st_1 = Local_2_st + "FTP server is not specified";
   return(tmp_st_1);
   case 4261 :
   tmp_st_1 = Local_2_st + "FTP login is not specified";
   return(tmp_st_1);
   case 4262 :
   tmp_st_1 = Local_2_st + "FTP connection failed";
   return(tmp_st_1);
   case 4263 :
   tmp_st_1 = Local_2_st + "FTP connection closed";
   return(tmp_st_1);
   case 4264 :
   tmp_st_1 = Local_2_st + "FTP path not found on server";
   return(tmp_st_1);
   case 4265 :
   tmp_st_1 = Local_2_st + "File not found in the MQL4\\Files directory to send on FTP server";
   return(tmp_st_1);
   case 4266 :
   tmp_st_1 = Local_2_st + "Common error during FTP data transmission";
   return(tmp_st_1);
   case 5001 :
   tmp_st_1 = Local_2_st + "Too many opened files";
   return(tmp_st_1);
   case 5002 :
   tmp_st_1 = Local_2_st + "Wrong file name";
   return(tmp_st_1);
   case 5003 :
   tmp_st_1 = Local_2_st + "Too long file name";
   return(tmp_st_1);
   case 5004 :
   tmp_st_1 = Local_2_st + "Cannot open file";
   return(tmp_st_1);
   case 5005 :
   tmp_st_1 = Local_2_st + "Text file buffer allocation error";
   return(tmp_st_1);
   case 5006 :
   tmp_st_1 = Local_2_st + "Cannot delete file";
   return(tmp_st_1);
   case 5007 :
   tmp_st_1 = Local_2_st + "Invalid file handle (file closed or was not opened)";
   return(tmp_st_1);
   case 5008 :
   tmp_st_1 = Local_2_st + "Wrong file handle (handle index is out of handle table)";
   return(tmp_st_1);
   case 5009 :
   tmp_st_1 = Local_2_st + "File must be opened with FILE_WRITE flag";
   return(tmp_st_1);
   case 5010 :
   tmp_st_1 = Local_2_st + "File must be opened with FILE_READ flag";
   return(tmp_st_1);
   case 5011 :
   tmp_st_1 = Local_2_st + "File must be opened with FILE_BIN flag";
   return(tmp_st_1);
   case 5012 :
   tmp_st_1 = Local_2_st + "File must be opened with FILE_TXT flag";
   return(tmp_st_1);
   case 5013 :
   tmp_st_1 = Local_2_st + "File must be opened with FILE_TXT or FILE_CSV flag";
   return(tmp_st_1);
   case 5014 :
   tmp_st_1 = Local_2_st + "File must be opened with FILE_CSV flag";
   return(tmp_st_1);
   case 5015 :
   tmp_st_1 = Local_2_st + "File read error";
   return(tmp_st_1);
   case 5016 :
   tmp_st_1 = Local_2_st + "File write error";
   return(tmp_st_1);
   case 5017 :
   tmp_st_1 = Local_2_st + "String size must be specified for binary file";
   return(tmp_st_1);
   case 5018 :
   tmp_st_1 = Local_2_st + "Incompatible file (for string arrays-TXT, for others-BIN)";
   return(tmp_st_1);
   case 5019 :
   tmp_st_1 = Local_2_st + "File is directory not file";
   return(tmp_st_1);
   case 5020 :
   tmp_st_1 = Local_2_st + "File does not exist";
   return(tmp_st_1);
   case 5021 :
   tmp_st_1 = Local_2_st + "File cannot be rewritten";
   return(tmp_st_1);
   case 5022 :
   tmp_st_1 = Local_2_st + "Wrong directory name";
   return(tmp_st_1);
   case 5023 :
   tmp_st_1 = Local_2_st + "Directory does not exist";
   return(tmp_st_1);
   case 5024 :
   tmp_st_1 = Local_2_st + "Specified file is not directory";
   return(tmp_st_1);
   case 5025 :
   tmp_st_1 = Local_2_st + "Cannot delete directory";
   return(tmp_st_1);
   case 5026 :
   tmp_st_1 = Local_2_st + "Cannot clean directory";
   return(tmp_st_1);
   case 5027 :
   tmp_st_1 = Local_2_st + "Array resize error";
   return(tmp_st_1);
   case 5028 :
   tmp_st_1 = Local_2_st + "String resize error";
   return(tmp_st_1);
   case 5029 :
   tmp_st_1 = Local_2_st + "Structure contains strings or dynamic arrays";
   return(tmp_st_1);
   case 5200 :
   tmp_st_1 = Local_2_st + "Invalid URL";
   return(tmp_st_1);
   case 5201 :
   tmp_st_1 = Local_2_st + "Failed to connect to specified URL";
   return(tmp_st_1);
   case 5202 :
   tmp_st_1 = Local_2_st + "Timeout exceeded";
   return(tmp_st_1);
   case 5203 :
   tmp_st_1 = Local_2_st + "HTTP request failed";
   return(tmp_st_1);
 }
 tmp_st_1 = Local_2_st + "Unknown error number";
 return(tmp_st_1);
 }
//lizong_11 <<==--------   --------
 bool CCanvasX::CCanvasX_12( string Para_0_st)
 {
  //bool      Local_2_bo;
  int       Local_3_in;
  string    Local_4_st;
  int       Local_5_in;
  int       Local_6_in = 0;
  int       Local_7_in = 0;
  int       Local_8_in = 0;
  int       Local_9_in = 0;
  CFileBin  Local_10_a_162;
//----- -----

 Local_5_in = -1 ;
 Local_4_st = "" ;
 Local_3_in = 32 ;
 //ver erro
 //if ( !(ResourceReadImage(Para_0_st,m_pixels,m_width,m_height)) )
 //{
 //   if ( Local_5_in != -1 )
 //  {
 //    FileClose(Local_5_in); 
 //    Local_5_in = -1 ;
 //    Local_4_st = "" ;
 //    Local_3_in &=96;
 //  }
 //  ; 
 //}
// return(true); 
 if ( Local_5_in != -1 )
 {
   FileClose(Local_5_in); 
   Local_5_in = -1 ;
   Local_4_st = "" ;
   Local_3_in &=96;
 }
 return(true); 
 }
//CCanvasX_12 <<==--------   --------
 void SymbolInformation::SymbolInformation_13()
 {
 }
//SymbolInformation_13 <<==--------   --------
 void SymbolInformation::SymbolInformation_14()
 {
 }
//SymbolInformation_14 <<==--------   --------
 void SymbolInformation::SymbolInformation_15()
 {
 SymbolInformation_13(); 
 SymbolInformation_14(); 
 }
//SymbolInformation_15 <<==--------   --------
 void SymbolInformation::~SymbolInformation()
 {
/*
*/
 }
//~SymbolInformation <<==--------   --------
 void CutTrade::CutTrade_17()
 {
 }
//CutTrade_17 <<==--------   --------
 void CutTrade::CutTrade_18()
 {
 }
//CutTrade_18 <<==--------   --------
 void CutTrade::CutTrade_19()
 {
 CutTrade_17(); 
 CutTrade_18(); 
 }
//CutTrade_19 <<==--------   --------
 void CutTrade::~CutTrade()
 {
/*
*/
 }
//~CutTrade <<==--------   --------
 bool lizong_21( string Para_0_st,int Para_1_in,int Para_2_in)
 {
  //bool      Local_1_bo;
  bool      Local_2_bo = false;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  int       Local_8_in;
  int       Local_9_in;
  int       Local_10_in;
  int       Local_11_in;
  int       Local_12_in;
  int       Local_13_in;
  int       Local_14_in;
  string    Local_15_st;
  int       Local_16_in;
  int       Local_17_in;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;

 Local_3_in=Global_24_in + UID;
 Local_4_in=StringLen(IntegerToString(Local_3_in,0,32)); 
 Local_5_in=Local_3_in + int(MathPow(10.0,Local_4_in));
 Local_6_in=Local_3_in + int(MathPow(10.0,Local_4_in)) * 2;
 Local_7_in = -1 ;
 Local_8_in = -1 ;
 Local_9_in = -1 ;
 Local_10_in = -1 ;
 Local_11_in = -1 ;
 Local_12_in = -1 ;
 if ( Para_2_in == 1 )
 {
   Local_7_in = 0 ;
   Local_8_in = 0 ;
   if ( Para_1_in >= 0 )
   {
     Local_9_in=int(MathPow(10.0,StringLen(IntegerToString(Local_3_in,0,32))  + 2)) + Local_3_in * 100 + Para_1_in;
     Local_10_in = Local_9_in ;
   }
   else
   {
     Local_11_in = Local_5_in ;
     Local_12_in = Local_5_in ;
   }
 }
 if ( Para_2_in == -1 )
 {
   Local_7_in = 1 ;
   Local_8_in = 1 ;
   if ( Para_1_in >= 0 )
   {
     Local_9_in=(int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32))  + 2))) * 2 + (Global_24_in + UID) * 100 + Para_1_in;
     Local_10_in = Local_9_in ;
   }
   else
   {
     Local_11_in = Local_6_in ;
     Local_12_in = Local_6_in ;
   }
 }
 if ( Para_2_in == 0 )
 {
   Local_7_in = 0 ;
   Local_8_in = 1 ;
   if ( Para_1_in >= 0 )
   {
     Local_9_in=int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32))  + 2)) + (Global_24_in + UID) * 100 + Para_1_in;
     if ( Para_1_in <  0 )
     {
       tmp_in_1 = -1;
     }
     else
     {
       tmp_in_2 = Global_24_in + UID;
       tmp_in_3 = StringLen(IntegerToString(tmp_in_2,0,32)) ;
       tmp_in_4 = 0;
       if ( -1 == 1 )
       {
         tmp_in_4 = 1;
       }
       if ( -1 == -1 )
       {
         tmp_in_4 = 2;
       }
       tmp_in_1 = int(MathPow(10.0,tmp_in_3 + 2)) * tmp_in_4 + tmp_in_2 * 100 + Para_1_in;
     }
     Local_10_in = tmp_in_1 ;
   }
   else
   {
     Local_11_in = Local_5_in ;
     Local_12_in = Local_6_in ;
   }
 }
 for (Local_13_in = 0 ; Local_13_in < OrdersTotal() ; Local_13_in ++)
 {
   if ( OrderSelect(Local_13_in,0,0) )
   {
     Local_14_in = OrderType() ;
     Local_15_st = OrderSymbol() ;
     Local_16_in = OrderMagicNumber() ;
     Local_17_in=Local_16_in / 100;
     if ( Para_1_in >= 0 && Local_15_st == Para_0_st && ( ( Local_16_in == Local_9_in && Local_14_in == Local_7_in ) || (Local_16_in == Local_10_in && Local_14_in == Local_8_in) ) )
     {
       return(true); 
     }
     if ( Para_1_in <  0 && Local_15_st == Para_0_st && ( ( Local_17_in == Local_11_in && Local_14_in == Local_7_in ) || (Local_17_in == Local_12_in && Local_14_in == Local_8_in) ) )
     {
       return(true); 
     }
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Failed to select an order! Error=",lizong_11(GetLastError())); 
     Local_2_bo = true ;
   }
 }
 return(Local_2_bo); 
 }
//lizong_21 <<==--------   --------
 double lizong_22( string Para_0_st,int Para_1_in,int Para_2_in)
 {
  //double    Local_1_do;
  double    Local_2_do = 0.0;
  int       Local_3_in;
  int       Local_4_in;
  double    Local_5_do;
  double    Local_6_do;
  int       Local_7_in;
  int       Local_8_in;
  string    Local_9_st;
  int       Local_10_in;
  double    Local_11_do;
  double    Local_12_do;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;
 int        tmp_in_5;

 tmp_in_1 = Para_2_in;
 if ( Para_1_in <  0 )
 {
   tmp_in_2 = -1;
 }
 else
 {
   tmp_in_3 = Global_24_in + UID;
   tmp_in_4 = StringLen(IntegerToString(tmp_in_3,0,32)) ;
   tmp_in_5 = 0;
   if ( tmp_in_1 == 1 )
   {
     tmp_in_5 = 1;
   }
   if ( tmp_in_1 == -1 )
   {
     tmp_in_5 = 2;
   }
   tmp_in_2 = int(MathPow(10.0,tmp_in_4 + 2)) * tmp_in_5 + tmp_in_3 * 100 + Para_1_in;
 }
 Local_3_in = tmp_in_2 ;
 Local_4_in = -1 ;
 if ( Para_2_in == 1 )
 {
   Local_4_in = 0 ;
 }
 if ( Para_2_in == -1 )
 {
   Local_4_in = 1 ;
 }
 Local_5_do = 0.0 ;
 Local_6_do = 0.0 ;
 for (Local_7_in = 0 ; Local_7_in < OrdersTotal() ; Local_7_in ++)
 {
   if ( OrderSelect(Local_7_in,0,0) )
   {
     Local_8_in = OrderType() ;
     Local_9_st = OrderSymbol() ;
     Local_10_in = OrderMagicNumber() ;
     Local_11_do = OrderOpenPrice() ;
     Local_12_do = OrderLots() ;
     if ( Local_9_st == Para_0_st && Local_10_in == Local_3_in && Local_8_in == Local_4_in )
     {
       Local_6_do = Local_11_do * Local_12_do + Local_6_do ;
       Local_5_do = Local_5_do + Local_12_do ;
       if ( !(AutoSplit) )
       {
         break;
       }
     }
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Failed to select an order! Error=",lizong_11(GetLastError())); 
   }
 }
 if ( Local_5_do>Global_25_do )
 {
   Local_2_do = Local_6_do / Local_5_do ;
 }
 return(Local_2_do); 
 }
//lizong_22 <<==--------   --------
 double lizong_23( string Para_0_st,int Para_1_in,bool Para_2_bo,bool Para_3_bo)
 {
  //double    Local_1_do;
  double    Local_2_do = 0.0;
  double    Local_3_do = 0.0;
  double    Local_4_do = 0.0;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  int       Local_8_in;
  double    Local_9_do;
  int       Local_10_in;
  string    Local_11_st;
  int       Local_12_in;
  int       Local_13_in;
  double    Local_14_do;
  int   Local_15_do;
  double    Local_16_do;
  int       Local_17_in;
  int       Local_18_in;
  string    Local_19_st;
  int       Local_20_in;
  double    Local_21_do;
  double    Local_22_do;
  double    Local_23_do;
  double    Local_24_do;
  int    Local_25_do;
//----- -----
 int        tmp_in_1;
 double     tmp_do_2;
 int        tmp_in_3;
 double     tmp_do_4;
 int        tmp_in_5;
 double     tmp_do_6;
 double     tmp_do_7;
 int        tmp_in_8;
 double     tmp_do_9;
 int        tmp_in_10;
 double     tmp_do_11;
 int        tmp_in_12;
 double     tmp_do_13;
 int        tmp_in_14;

 Local_5_in=Global_24_in + UID;
 Local_6_in=StringLen(IntegerToString(Local_5_in,0,32)); 
 Local_7_in = 0 ;
 Local_8_in = -1 ;
 if ( Para_1_in == 1 )
 {
   Local_8_in = 0 ;
   Local_7_in = 1 ;
 }
 if ( Para_1_in == -1 )
 {
   Local_8_in = 1 ;
   Local_7_in = 2 ;
 }
 Local_9_do = 0.0 ;
 if ( KeepOriginalProfitLotSize && Para_3_bo && GridLevelToStart >  1 && !(AutoSplit) )
 {
   for (Local_10_in = 0 ; Local_10_in < OrdersTotal() ; Local_10_in ++)
   {
     if ( OrderSelect(Local_10_in,0,0) )
     {
       Local_11_st = OrderSymbol() ;
       Local_12_in = OrderType() ;
       Local_13_in = OrderMagicNumber() ;
       Local_14_do = OrderLots() ;
       if ( Local_11_st == Para_0_st && Local_13_in / 100 == Local_5_in + int(MathPow(10.0,Local_6_in)) * Local_7_in && Local_12_in == Local_8_in )
       {
         Local_15_do=Local_13_in - Local_13_in / 100 * 100;
         if ( Local_15_do >= GridLevelToStart - 1 && Local_14_do>Global_25_do )
         {
           Local_9_do = Local_14_do ;
           tmp_in_1 = Local_15_do;
           tmp_do_2 = 1.0;
           for (tmp_in_3 = 1 ; tmp_in_3 <= tmp_in_1 ; tmp_in_3=tmp_in_3 + 1)
           {
             if ( tmp_in_3 == 1 )
             {
               tmp_do_2 = TradeMultiplier_2nd;
             }
             if ( tmp_in_3 >= 2 && tmp_in_3 <= 4 )
             {
               tmp_do_2 = tmp_do_2 * TradeMultiplier_3rd;
             }
             if ( tmp_in_3 >= 5 )
             {
               tmp_do_2 = tmp_do_2 * TradeMultiplier_6th;
             }
           }
           Local_16_do = tmp_do_2 ;
           if ( Local_16_do>Global_25_do )
           {
             Local_9_do = Local_9_do / Local_16_do ;
           }
           if ( Local_9_do>Global_25_do )
           {
             break;
           }
         }
       }
     }
     else
     {
       Print(TradeComment + " " + Para_0_st,": Failed to select an order! Error=",lizong_11(GetLastError())); 
     }
   }
 }
 for (Local_17_in = 0 ; Local_17_in < OrdersTotal() ; Local_17_in ++)
 {
   if ( OrderSelect(Local_17_in,0,0) )
   {
     Local_18_in = OrderType() ;
     Local_19_st = OrderSymbol() ;
     Local_20_in = OrderMagicNumber() ;
     Local_21_do = OrderLots() ;
     Local_22_do = OrderOpenPrice() ;
     if ( Local_19_st == Para_0_st && Local_20_in / 100 == Local_5_in + int(MathPow(10.0,Local_6_in)) * Local_7_in && Local_18_in == Local_8_in )
     {
       Local_23_do = Local_22_do ;
       if ( Para_2_bo )
       {
         tmp_do_4 = 0.0;
         if ( SymbolInfoDouble(Para_0_st,SYMBOL_TRADE_TICK_VALUE) * Local_21_do>Global_25_do )
         {
           tmp_in_5 = SymbolInfoInteger(Para_0_st,SYMBOL_DIGITS);
           tmp_do_6 = (OrderCommission() + OrderSwap()) / (SymbolInfoDouble(Para_0_st,SYMBOL_TRADE_TICK_VALUE) * Local_21_do);
           if ( SymbolInfoDouble(Para_0_st,SYMBOL_POINT)>Global_25_do )
           {
             tmp_do_7 = SymbolInfoDouble(Para_0_st,SYMBOL_POINT);
           }
           else
           {
             tmp_do_7 = 0.00001;
           }
           tmp_do_6 = tmp_do_6 * tmp_do_7;
           tmp_do_4 = NormalizeDouble(tmp_do_6,tmp_in_5);
         }
         Local_24_do = tmp_do_4 ;
         if ( Para_1_in == 1 )
         {
           tmp_in_8 = SymbolInfoInteger(Para_0_st,SYMBOL_DIGITS);
           if ( SymbolInfoDouble(Para_0_st,SYMBOL_POINT)>Global_25_do )
           {
             tmp_do_9 = SymbolInfoDouble(Para_0_st,SYMBOL_POINT);
           }
           else
           {
             tmp_do_9 = 0.00001;
           }
           Local_23_do = NormalizeDouble(Local_22_do + tmp_do_9 - Local_24_do,tmp_in_8) ;
         }
         if ( Para_1_in == -1 )
         {
           tmp_in_10 = SymbolInfoInteger(Para_0_st,SYMBOL_DIGITS);
           if ( SymbolInfoDouble(Para_0_st,SYMBOL_POINT)>Global_25_do )
           {
             tmp_do_11 = SymbolInfoDouble(Para_0_st,SYMBOL_POINT);
           }
           else
           {
             tmp_do_11 = 0.00001;
           }
           Local_23_do = NormalizeDouble(Local_22_do - tmp_do_11 + Local_24_do,tmp_in_10) ;
         }
       }
       if ( KeepOriginalProfitLotSize && Para_3_bo && GridLevelToStart >  1 && Local_9_do>Global_25_do && !(AutoSplit) )
       {
         Local_25_do=Local_20_in - Local_20_in / 100 * 100;
         if ( Local_25_do == 0 )
         {
           Local_21_do = Local_9_do ;
         }
         if ( Local_25_do >  0 )
         {
           tmp_in_12 = Local_25_do;
           tmp_do_13 = 1.0;
           for (tmp_in_14 = 1 ; tmp_in_14 <= tmp_in_12 ; tmp_in_14=tmp_in_14 + 1)
           {
             if ( tmp_in_14 == 1 )
             {
               tmp_do_13 = TradeMultiplier_2nd;
             }
             if ( tmp_in_14 >= 2 && tmp_in_14 <= 4 )
             {
               tmp_do_13 = tmp_do_13 * TradeMultiplier_3rd;
             }
             if ( tmp_in_14 >= 5 )
             {
               tmp_do_13 = tmp_do_13 * TradeMultiplier_6th;
             }
           }
           Local_21_do = Local_9_do * tmp_do_13 ;
         }
       }
       Local_3_do = Local_23_do * Local_21_do + Local_3_do ;
       Local_4_do = Local_4_do + Local_21_do ;
     }
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Failed to select an order! Error=",lizong_11(GetLastError())); 
   }
 }
 if ( Local_4_do>Global_25_do )
 {
   Local_2_do = Local_3_do / Local_4_do ;
 }
 Local_2_do = NormalizeDouble(Local_2_do,SymbolInfoInteger(Para_0_st,SYMBOL_DIGITS)) ;
 return(Local_2_do); 
 }
//lizong_23 <<==--------   --------
 double lizong_24( string Para_0_st,int Para_1_in,int Para_2_in,bool Para_3_bo)
 {
  //double    Local_1_do;
  double    Local_2_do = 0.0;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  int       Local_8_in;
  int       Local_9_in;
  int       Local_10_in;
  int       Local_11_in;
  int       Local_12_in;
  int       Local_13_in;
  int       Local_14_in;
  double    Local_15_do;
  int       Local_16_in;
  int       Local_17_in;
  string    Local_18_st;
  int       Local_19_in;
  double    Local_20_do;
  int       Local_21_in;
  int    Local_22_do;
  int    Local_23_do;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;
 int        tmp_in_5;
 double     tmp_do_6;
 int        tmp_in_7;
 int        tmp_in_8;
 double     tmp_do_9;
 int        tmp_in_10;

 Local_3_in=Global_24_in + UID;
 Local_4_in=StringLen(IntegerToString(Local_3_in,0,32)); 
 Local_5_in=Local_3_in + int(MathPow(10.0,Local_4_in));
 Local_6_in=Local_3_in + int(MathPow(10.0,Local_4_in)) * 2;
 Local_7_in = -1 ;
 Local_8_in = -1 ;
 Local_9_in = -1 ;
 Local_10_in = -1 ;
 Local_11_in = -1 ;
 Local_12_in = -1 ;
 if ( Para_2_in == 1 )
 {
   Local_7_in = 0 ;
   Local_8_in = 0 ;
   if ( Para_1_in >= 0 )
   {
     Local_9_in=int(MathPow(10.0,StringLen(IntegerToString(Local_3_in,0,32))  + 2)) + Local_3_in * 100 + Para_1_in;
     Local_10_in = Local_9_in ;
   }
   else
   {
     Local_11_in = Local_5_in ;
     Local_12_in = Local_5_in ;
   }
 }
 if ( Para_2_in == -1 )
 {
   Local_7_in = 1 ;
   Local_8_in = 1 ;
   if ( Para_1_in >= 0 )
   {
     Local_9_in=(int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32))  + 2))) * 2 + (Global_24_in + UID) * 100 + Para_1_in;
     Local_10_in = Local_9_in ;
   }
   else
   {
     Local_11_in = Local_6_in ;
     Local_12_in = Local_6_in ;
   }
 }
 if ( Para_2_in == 0 )
 {
   Local_7_in = 0 ;
   Local_8_in = 1 ;
   if ( Para_1_in >= 0 )
   {
     Local_9_in=int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32))  + 2)) + (Global_24_in + UID) * 100 + Para_1_in;
     if ( Para_1_in <  0 )
     {
       tmp_in_1 = -1;
     }
     else
     {
       tmp_in_2 = Global_24_in + UID;
       tmp_in_3 = StringLen(IntegerToString(tmp_in_2,0,32)) ;
       tmp_in_4 = 0;
       if ( -1 == 1 )
       {
         tmp_in_4 = 1;
       }
       if ( -1 == -1 )
       {
         tmp_in_4 = 2;
       }
       tmp_in_1 = int(MathPow(10.0,tmp_in_3 + 2)) * tmp_in_4 + tmp_in_2 * 100 + Para_1_in;
     }
     Local_10_in = tmp_in_1 ;
   }
   else
   {
     Local_11_in = Local_5_in ;
     Local_12_in = Local_6_in ;
   }
 }
 Local_13_in = 0 ;
 Local_14_in = -1 ;
 if ( Para_2_in == 1 )
 {
   Local_14_in = 0 ;
   Local_13_in = 1 ;
 }
 if ( Para_2_in == -1 )
 {
   Local_14_in = 1 ;
   Local_13_in = 2 ;
 }
 Local_15_do = 0.0 ;
 if ( KeepOriginalProfitLotSize && Para_3_bo && GridLevelToStart >  1 && !(AutoSplit) )
 {
   Local_15_do = 0.01 ;
 }
 for (Local_16_in = 0 ; Local_16_in < OrdersTotal() ; Local_16_in ++)
 {
   if ( OrderSelect(Local_16_in,0,0) )
   {
     Local_17_in = OrderType() ;
     Local_18_st = OrderSymbol() ;
     Local_19_in = OrderMagicNumber() ;
     Local_20_do = OrderLots() ;
     Local_21_in=Local_19_in / 100;
     if ( Para_1_in >= 0 && Local_18_st == Para_0_st && ( ( Local_19_in == Local_9_in && Local_17_in == Local_7_in ) || (Local_19_in == Local_10_in && Local_17_in == Local_8_in) ) )
     {
       if ( !(Para_3_bo) )
       {
         Local_2_do = Local_2_do + Local_20_do ;
       }
       else
       {
         if ( KeepOriginalProfitLotSize && Para_3_bo && GridLevelToStart >  1 && Local_15_do>Global_25_do && !(AutoSplit) )
         {
           Local_22_do=Local_19_in - Local_19_in / 100 * 100;
           if ( Local_22_do == 0 )
           {
             Local_20_do = Local_15_do ;
           }
           if ( Local_22_do >  0 )
           {
             tmp_in_5 = Local_22_do;
             tmp_do_6 = 1.0;
             for (tmp_in_7 = 1 ; tmp_in_7 <= tmp_in_5 ; tmp_in_7=tmp_in_7 + 1)
             {
               if ( tmp_in_7 == 1 )
               {
                 tmp_do_6 = TradeMultiplier_2nd;
               }
               if ( tmp_in_7 >= 2 && tmp_in_7 <= 4 )
               {
                 tmp_do_6 = tmp_do_6 * TradeMultiplier_3rd;
               }
               if ( tmp_in_7 >= 5 )
               {
                 tmp_do_6 = tmp_do_6 * TradeMultiplier_6th;
               }
             }
             Local_20_do = Local_15_do * tmp_do_6 ;
           }
         }
         Local_2_do = Local_2_do + Local_20_do ;
       }
       if ( !(AutoSplit) )
       {
         break;
       }
     }
     if ( Para_1_in <  0 && Local_18_st == Para_0_st && ( ( Local_21_in == Local_11_in && Local_17_in == Local_7_in ) || (Local_21_in == Local_12_in && Local_17_in == Local_8_in) ) )
     {
       if ( !(Para_3_bo) )
       {
         Local_2_do = Local_2_do + Local_20_do ;
       }
       else
       {
         if ( KeepOriginalProfitLotSize && Para_3_bo && GridLevelToStart >  1 && Local_15_do>Global_25_do && !(AutoSplit) )
         {
           Local_23_do=Local_19_in - Local_19_in / 100 * 100;
           if ( Local_23_do == 0 )
           {
             Local_20_do = Local_15_do ;
           }
           if ( Local_23_do >  0 )
           {
             tmp_in_8 = Local_23_do;
             tmp_do_9 = 1.0;
             for (tmp_in_10 = 1 ; tmp_in_10 <= tmp_in_8 ; tmp_in_10=tmp_in_10 + 1)
             {
               if ( tmp_in_10 == 1 )
               {
                 tmp_do_9 = TradeMultiplier_2nd;
               }
               if ( tmp_in_10 >= 2 && tmp_in_10 <= 4 )
               {
                 tmp_do_9 = tmp_do_9 * TradeMultiplier_3rd;
               }
               if ( tmp_in_10 >= 5 )
               {
                 tmp_do_9 = tmp_do_9 * TradeMultiplier_6th;
               }
             }
             Local_20_do = Local_15_do * tmp_do_9 ;
           }
         }
         Local_2_do = Local_2_do + Local_20_do ;
       }
     }
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Failed to select an order! Error=",lizong_11(GetLastError())); 
   }
 }
 return(Local_2_do); 
 }
//lizong_24 <<==--------   --------
 void lizong_25( int Para_0_in)
 {
  string    Local_1_st;
  int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  int       Local_8_in;
  int       Local_9_in;
  string    Local_10_st;
  double    Local_11_do;
  int       Local_12_in;
  double    Local_13_do;
  double    Local_14_do;
 datetime    Local_15_do;
  double    Local_16_do;
  double    Local_17_do;
//----- -----
 double     tmp_do_1;
 int        tmp_in_2;
 double     tmp_do_3;
 double     tmp_do_4;

 if ( OrdersTotal() == 0 )   return;
 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 Local_2_in=Global_24_in + UID;
 Local_3_in=StringLen(IntegerToString(Local_2_in,0,32)); 
 Local_4_in=Local_2_in + int(MathPow(10.0,Local_3_in));
 Local_5_in=Local_2_in + int(MathPow(10.0,Local_3_in)) * 2;
 if ( !(Global_29_bo) )
 {
   for (Local_6_in = 0 ; Local_6_in < 2 ; Local_6_in ++)
   {
     Local_7_in = 0 ;
     if ( OrdersTotal() <= 0 )   continue;
     
     for ( ; Local_7_in < OrdersTotal() ; Local_7_in ++)
     {
       if ( OrderSelect(Local_7_in,0,0) )
       {
         Local_8_in = OrderTicket() ;
         Local_9_in = OrderType() ;
         Local_10_st = OrderSymbol() ;
         Local_11_do = OrderLots() ;
         Local_12_in = OrderMagicNumber() ;
         Local_13_do = OrderTakeProfit() ;
         Local_14_do = OrderStopLoss() ;
         Local_15_do = OrderOpenTime() ;
         Local_16_do = OrderOpenPrice() ;
         tmp_do_1 = 0.0;
         if ( SymbolInfoDouble(Local_1_st,SYMBOL_TRADE_TICK_VALUE) * Local_11_do>Global_25_do )
         {
           tmp_in_2 = (int)SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS );
           tmp_do_3 = (OrderCommission() + OrderSwap()) / (SymbolInfoDouble(Local_1_st,SYMBOL_TRADE_TICK_VALUE) * Local_11_do);
           if ( SymbolInfoDouble(Local_1_st,SYMBOL_POINT)>Global_25_do )
           {
             tmp_do_4 = SymbolInfoDouble(Local_1_st,SYMBOL_POINT);
           }
           else
           {
             tmp_do_4 = 0.00001;
           }
           tmp_do_3 = tmp_do_3 * tmp_do_4;
           tmp_do_1 = NormalizeDouble(tmp_do_3,tmp_in_2);
         }
         Local_17_do = tmp_do_1 ;
         if ( Local_6_in == 0 && Local_9_in == 0 && Local_10_st == Local_1_st && Local_12_in / 100 == Local_4_in )
         {
           lizong_38(Para_0_in,Local_8_in,Local_9_in,Local_10_st,Local_11_do,Local_12_in,Local_13_do,
                     Local_14_do,Local_15_do,Local_16_do,Local_17_do); 
         }
         if ( Local_6_in == 1 && Local_9_in == 1 && Local_10_st == Local_1_st && Local_12_in / 100 == Local_5_in )
         {
           lizong_39(Para_0_in,Local_8_in,Local_9_in,Local_10_st,Local_11_do,Local_12_in,Local_13_do,
                     Local_14_do,Local_15_do,Local_16_do,Local_17_do); 
         }
       }
       else
       {
         Print(TradeComment + " " + Local_1_st,": Failed to select an order! Error=",lizong_11(GetLastError())); 
       }
     }
     
   }
 }
 }
//lizong_25 <<==--------   --------
 void lizong_26( int Para_0_in)
 {
  string    Local_1_st;
  int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  int       Local_8_in;
  int       Local_9_in;
  int       Local_10_in;
  int       Local_11_in;
  string    Local_12_st;
  double    Local_13_do;
  int       Local_14_in;
  double    Local_15_do;
  double    Local_16_do;
  long      Local_17_lo;
  double    Local_18_do;
  bool      Local_19_bo;
  bool      Local_20_bo;
//----- -----

 if ( OrdersTotal() == 0 )   return;
 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 Local_2_in=Global_24_in + UID;
 Local_3_in=StringLen(IntegerToString(Local_2_in,0,32)); 
 Local_4_in=Local_2_in + int(MathPow(10.0,Local_3_in));
 Local_5_in=Local_2_in + int(MathPow(10.0,Local_3_in)) * 2;
 Local_6_in = OrdersTotal() ;
 if ( Local_6_in >  99 )
 {
   Local_6_in = 99 ;
 }
 for (Local_7_in = 0 ; Local_7_in < 2 ; Local_7_in ++)
 {
   Local_8_in = 0 ;
   if ( Local_6_in <= 0 )   continue;
   
   for ( ; Local_8_in < Local_6_in ; Local_8_in ++)
   {
     Local_9_in = 0 ;
     if ( OrdersTotal() <= 0 )   continue;
     
     for ( ; Local_9_in < OrdersTotal() ; Local_9_in ++)
     {
       if ( OrderSelect(Local_9_in,0,0) )
       {
         Local_10_in = OrderTicket() ;
         Local_11_in = OrderType() ;
         Local_12_st = OrderSymbol() ;
         Local_13_do = OrderLots() ;
         Local_14_in = OrderMagicNumber() ;
         Local_15_do = OrderTakeProfit() ;
         Local_16_do = OrderStopLoss() ;
         Local_17_lo = OrderOpenTime() ;
         Local_18_do = OrderOpenPrice() ;
         if ( Local_7_in == 0 && Local_11_in == 0 && Local_12_st == Local_1_st && Local_14_in / 100 == Local_4_in )
         {
           Local_19_bo = lizong_44(Para_0_in,Local_10_in,Local_11_in,Local_12_st,Local_13_do,Local_14_in,Local_15_do,Local_16_do,Local_17_lo,Local_18_do) ;
           if ( Local_19_bo )
           {
             break;
           }
         }
         if ( Local_7_in == 1 && Local_11_in == 1 && Local_12_st == Local_1_st && Local_14_in / 100 == Local_5_in )
         {
           Local_20_bo = lizong_45(Para_0_in,Local_10_in,Local_11_in,Local_12_st,Local_13_do,Local_14_in,Local_15_do,Local_16_do,Local_17_lo,Local_18_do) ;
           if ( Local_20_bo )
           {
             break;
           }
         }
       }
       else
       {
         Print(TradeComment + " " + Local_1_st,": Failed to select an order! Error=",lizong_11(GetLastError())); 
       }
     }
     
   }
   
 }
 }
//lizong_26 <<==--------   --------
 void lizong_27()
 {
  double    Local_1_do_ko[];
  int       Local_2_in;
  int       Local_3_in;
//----- -----

 ArrayResize(Local_1_do_ko,Global_12_in,0); 
 ArrayFill(Local_1_do_ko,0,Global_12_in,0.0);
 Local_2_in = -1 ;
 Global_19_in = -1 ;
 if ( SmartTP )
 {
   Local_2_in=-1 + 1;
   Local_1_do_ko[Local_2_in] = 58775.01158022;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 3854.012011184;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 39358.01174733;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 1269.011355758;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 56140.01164918;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 64530.01196917;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 60307.01246761;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 6648.014426477;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 45131.01330754;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 7950.01201108;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 45131.01330601;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 60854.01428551;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 65055.01297945;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 9460.013983523;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 10540.01337538;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 4544.014977765;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 248.0143470455;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 61247.0136825;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 52086.0134722;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 63574.01398307;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 47413.01467299;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 4155.014336146;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 2704.015830312;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 9089.014985123;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 45154.01433637;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 216.014348892;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 22495.01993742;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 9381.020399422;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 60747.01945847;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 65444.01670228;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 65217.01617163;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 64233.01657642;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 48506.01584509;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 33278.01883977;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 8650.017266761;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 48737.01661989;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 35446.0173142;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 55737.01834805;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 22494.01992731;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 15784.01696432;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 63403.01613634;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 42600.01646525;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 36063.01684867;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 41629.01739422;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 62737.01369688;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 45131.01330601;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 39673.0184521;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 48616.01696441;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 22822.01496536;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 9429.011354072;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 4667.014336799;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 2659.013857216;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 885.0113855871;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 60747.01481364;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 63709.01464703;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 9883.012018778;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 65481.01889697;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 6652.014425881;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 45131.01330867;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 1016.014955805;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 9460.013983523;
   Local_2_in ++;
   Local_1_do_ko[Local_2_in] = 8284.018428598;
 }
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 57309.01392841;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13471.01393551;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62737.01369688;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65243.01422747;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 18653.01429452;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12883.01589119;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17668.0156589;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61870.01519367;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 26663.01437642;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 22666.01491749;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11113.01466572;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61047.01463275;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5163.014844659;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 44787.01421445;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 40165.01459569;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 23094.01496487;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2643.015406373;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5197.014638163;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4109.014394233;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5323.01428411;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64308.01410924;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1851.013989072;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 25753.01453975;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 39664.01845956;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60744.01959539;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2651.020666013;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 29873.01918727;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64156.01948546;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7404.017344148;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56105.01633881;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64950.01613449;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 53211.01670127;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60156.01615407;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 40079.01584289;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64857.01557208;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 547.0162711932;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64866.01602218;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7149.016702509;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64370.01570261;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10444.01640047;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 57251.01603322;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63101.01634664;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2348.016326638;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 57251.01603322;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6310.011802273;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 47990.01192367;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 8555.011328002;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7442.011792083;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 19612.01145358;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1697.011001875;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 43477.0108115;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 46429.01090545;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60377.01181679;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3726.012653958;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 837.0122232008;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5164.012393892;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6717.012155909;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 59263.01198725;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16432.01451182;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63387.01420649;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13229.01392075;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 23889.01351881;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 928.0142407292;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3031.013743902;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2221.013470928;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 52513.01329229;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 36565.01402667;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 910.0137729072;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2770.013600246;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3064.013876089;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1755.013118797;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63219.01358184;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3441.013430833;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61433.01289695;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3852.013463712;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1755.012100862;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 20622.01368159;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3852.013463712;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4264.013583712;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4264.013583712;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 21333.01387241;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62934.01251469;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56687.01271473;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54267.01328379;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65375.01365708;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 31095.01427242;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64255.01373438;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48058.01300547;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61428.012654;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 35181.01479144;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63643.0154672;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 45936.01556469;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10320.01551479;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62218.01447119;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 44139.01458713;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 22822.01496536;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5196.014638125;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5315.014284631;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 627.0141667045;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2329.013082898;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 574.0145977273;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65391.01476261;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 35427.01384144;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 26273.01415376;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60782.01794053;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12492.0194133;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2452.019703333;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 59819.01618939;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61780.01628349;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65105.01662631;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61390.01535454;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60092.01615633;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64793.01557475;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 422.0161619697;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62818.01602322;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7085.016703258;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48490.0159386;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 38570.01618589;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9422.016099063;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65333.01563527;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4696.016474811;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64793.01602974;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62589.01635285;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65034.01592282;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61363.01583589;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64330.01020252;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2433.012330341;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2221.012248845;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 58964.01254474;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 49014.01192558;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63925.00960272;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 15798.01179155;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11048.01204053;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17565.01145348;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1700.011005076;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4447.011557045;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 797.0113839205;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1606.012653826;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17092.01240473;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 27297.01221147;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63359.01199056;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61811.01297195;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16416.01451531;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65435.01421039;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 23897.01352519;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2976.014242831;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2951.013743267;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 52183.01402705;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60051.01456152;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54130.01405045;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 399.0137739015;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 722.013601553;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 20910.01368195;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63218.01358308;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11571.01343113;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63300.0130937;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12456.01358552;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56265.01031179;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6840.012158352;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 26272.01298145;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3406.013386619;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12765.0118572;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9397.011358523;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64420.00960795;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 53460.00980464;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 27809.01180436;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4999.011699432;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9545.010567519;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61341.01175994;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 41941.01081364;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11418.01181061;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48975.01144347;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4479.011554545;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 8989.011381345;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60369.01182045;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3276.012656042;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17221.01222742;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63351.01198748;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65152.0135328;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3630.013954687;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1856.014249953;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3015.01374572;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 36567.01402781;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16981.01390998;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1747.013121383;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 735.0121057197;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17268.01222799;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6292.0123616;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61421.0130191;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 21032.01438019;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63201.01366268;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3015.01374572;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16647.01573295;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 635.0138940341;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 55002.0122268;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62254.01501761;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12947.01589384;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 59321.01548826;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5190.016007273;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10576.01551276;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62862.01519499;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12546.01440332;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48082.01486509;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 26809.01506428;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62219.01446873;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61171.01421608;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6718.014964422;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64268.01411022;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61046.01463234;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54985.01946629;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3931.020664489;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13479.02039716;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61290.01945805;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9361.01924536;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13062.01894559;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65014.01613473;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 55213.01693375;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 388.0161624527;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 690.0163215909;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64874.01602347;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12741.01614296;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61908.01628101;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62322.01405152;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 398.0137752178;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2258.013603097;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3379.013433182;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48657.01311622;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6198.014966373;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13.01439551136;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64292.01411114;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54763.01601634;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 38826.01618771;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65247.0142268;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13011.0158911;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 27943.01549838;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61606.01519364;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 40101.01459483;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6206.014965862;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 77.0143927178;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2073.013081402;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6175.018758428;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3907.020667027;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 36315.01670303;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48234.01593876;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10445.01640248;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64795.01602865;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 52184.01182288;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2629.012066146;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1639.012648759;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 836.0122299432;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17204.01223163;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65397.01199134;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65179.01420997;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56609.01329214;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 35543.01402632;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62099.01456007;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 20654.01368307;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60866.01366031;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11563.01343161;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 58775.01557738;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2851.016005265;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10490.01571146;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13750.0154139;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61819.01297205;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62861.01423976;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 210.0161590246;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 22575.01496553;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64324.01410996;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 771.0186513258;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12906.01467613;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1349.015917727;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 22067.01929612;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9351.019477102;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13066.01894816;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11557.01668195;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 18841.01608823;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 44426.01495178;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61331.01583266;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6182.014966477;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16725.01387396;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10701.01640389;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9416.016098703;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11416.01181476;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13477.02039932;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4872.019235492;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 45513.01928348;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6183.019680473;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17522.01911291;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 14544.01618753;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 35541.01402647;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62780.01397489;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16910.01364792;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16613.0133896;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 49005.01608724;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1119.015516392;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 21264.01508722;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63343.01488099;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64992.01434217;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10842.01523296;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9519.015378333;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 21543.01564866;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64909.01513704;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 51170.01467243;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4892.01449553;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63321.01395811;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54416.01475575;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11645.0146381;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64255.01373438;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10465.0144106;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 8294.016047983;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62188.01252236;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 19305.01669887;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 50555.01332981;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1128.016370417;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56942.01639359;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 25840.01660438;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6155.017036544;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 40009.01393721;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 53871.01700154;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9355.017067311;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 40156.01663305;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 44767.01293335;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9996.016453002;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 51550.01326464;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65000.01434072;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56059.01323903;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 23541.01701494;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64425.01570618;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9304.014352055;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6917.014490909;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61862.01630003;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63481.01486609;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61360.01644927;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 58873.01664922;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64614.01347494;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63437.01270191;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 45037.01301862;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 8657.013331013;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63563.01602347;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48490.01584416;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54448.01475665;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2273.014411288;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3807.012108958;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 53682.01457561;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4626.013807017;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62712.01463289;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9515.015378485;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1688.016103854;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9376.014633722;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17005.01676512;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 51174.01467303;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10903.01650006;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16649.01689754;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4557.016143011;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1087.016112169;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60666.01589207;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7780.014078191;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1826.016364498;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 55286.01308316;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60318.01598253;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 409.0126363542;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62493.01262849;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3144.012697102;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 816.01689375;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6189.016596307;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61171.01421328;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 18840.01609098;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56717.0151377;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48873.01657642;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 3657.013662689;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 38314.01618546;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1916.013339555;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 390.0144965246;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 51703.01271346;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63313.01395756;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5980.013519356;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 14188.01642238;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62902.01596231;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63428.01309241;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 60381.01738902;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48477.01091287;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 56795.01954348;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 35423.01605786;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65441.01669926;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 6901.017011866;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 36605.01596594;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61870.01629715;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 57185.01644852;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63764.01661937;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64630.01347598;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61238.01651973;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16715.01689844;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61338.01270005;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48118.01323105;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1079.016112992;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 59326.01560837;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11579.01343258;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64466.01269705;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61639.01602384;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 55294.01308541;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4956.013521297;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 48474.01584589;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10540.01633083;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 12984.01358776;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54955.01318312;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 11563.01343161;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 43477.0108115;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 192.0185782197;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64810.01608257;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 13419.01558728;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 65221.01616853;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64519.0164206;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64300.0141106;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 51120.0159382;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 1122.013547756;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16482.01354835;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4616.012207945;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 39673.0184521;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 61151.01293346;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 58280.01336552;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 51839.01606055;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 54130.01405045;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 22491.01541652;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 526.0136482102;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2258.0134966;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16806.01208334;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 4520.010874953;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 16482.0191152;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 9883.012018778;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7950.01201108;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 2442.013018684;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 17506.01354839;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 18713.01308448;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 785.0162674716;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64858.01196998;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63817.01605056;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 62899.01609798;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 690.0163181061;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7084.016704384;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 63966.01331726;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 25298.01419737;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 64332.01410942;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 7736.013030312;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 5635.013818911;
 Local_2_in ++;
 Local_1_do_ko[Local_2_in] = 10340.01359628;
 Local_2_in ++;
 for (Local_3_in = 0 ; Local_3_in < Local_2_in ; Local_3_in ++)
 {
   Global_19_in ++;
   Global_17_lo_ko[Global_19_in] = Local_1_do_ko[Local_3_in];
   Global_18_do_ko[Global_19_in] = (int(Local_1_do_ko[Local_3_in]) - int(Local_1_do_ko[Local_3_in])) * 66.0;
 }
 }
//lizong_27 <<==--------   --------
 void lizong_28( int Para_0_in)
 {
  string    Local_1_st;
  int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  double    Local_5_do;
  double    Local_6_do;
  string    Local_7_st;
  int       Local_8_in;
  double    Local_9_do;
  double    Local_10_do;
  int       Local_11_in;
  int       Local_12_in;
  double    Local_13_do;
//----- -----
 string     tmp_st_1;
 int     tmp_do_2;
 int        tmp_in_3;
 int       tmp_lo_4=0;
 double     tmp_do_5;

 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 Local_2_in = 1 ;
 if ( Global_22_a_168_ko[Para_0_in].bo_18 != 0x0 )
 {
   Local_2_in = 96 ;
 }
 for (Local_3_in = 0 ; Local_3_in < Local_2_in ; Local_3_in ++)
 {
   Local_4_in = 16 ;
   Local_5_do = 0.002 ;
   Local_6_do = 0.0 ;
   Local_7_st = "" ;
   Global_22_a_168_ko[Para_0_in].lo_16 = 0;
   Global_22_a_168_ko[Para_0_in].do_17 = 0.0;
   if ( iBars(Local_1_st,Global_21_in) <  Local_4_in * 2 + Local_3_in )
   {
     return;
   }
   for (Local_8_in = 1 ; Local_8_in <= Local_4_in ; Local_8_in ++)
   {
     Local_9_do = iClose(Local_1_st,Global_21_in,Local_8_in + Local_3_in) ;
     Local_10_do = iOpen(Local_1_st,Global_21_in,Local_8_in + Local_3_in) ;
     Local_6_do = Local_6_do + Local_9_do ;
     if ( Local_9_do - Local_10_do>=0.0 )
     {
       Local_7_st +="1";
     }
     else
     {
       Local_7_st +="0";
     }
   }
   Global_22_a_168_ko[Para_0_in].do_17 = Local_6_do / Local_4_in;
   tmp_st_1 = Local_7_st;
   tmp_do_2 = 0;
   for (tmp_in_3 = 0 ; tmp_in_3 < StringLen(tmp_st_1)  ; tmp_in_3=tmp_in_3 + 1)
   {
     if ( StringGetCharacter(tmp_st_1,tmp_in_3) == 49 )
     {
       tmp_lo_4=tmp_do_2 * 2 + 1;
     }
   }
   Global_22_a_168_ko[Para_0_in].lo_16 = tmp_lo_4;
   if ( Global_22_a_168_ko[Para_0_in].bo_5 == 0x0 && Global_22_a_168_ko[Para_0_in].bo_6 == 0x0 && Global_22_a_168_ko[Para_0_in].bo_19 == 0x0 && Global_22_a_168_ko[Para_0_in].bo_20 == 0x0 )
   {
     return;
   }
   for (Local_11_in=Global_12_in / 100 - 1 ; Local_11_in >= 0 ; Local_11_in --)
   {
     Local_12_in=(Local_11_in + 1) * 100 - 1;
     if ( Local_12_in < Local_11_in * 100 )   continue;
     
     for ( ; Local_12_in >= Local_11_in * 100 ; Local_12_in --)
     {
       if ( Global_18_do_ko[Local_12_in]<Global_25_do )   break;
       
       if ( Global_22_a_168_ko[Para_0_in].do_17<Global_18_do_ko[Local_11_in * 100] )   break;
       Local_13_do = 1.0 ;
       if ( Global_18_do_ko[Local_12_in]<0.0 )
       {
         Local_13_do = -1.0 ;
       }
       tmp_do_5 = Local_5_do * Local_13_do;
       if ( !(Global_22_a_168_ko[Para_0_in].do_17<(Local_5_do * Local_13_do + 1.0) * Global_18_do_ko[Local_12_in]) || !(Global_22_a_168_ko[Para_0_in].do_17>(1.0 - tmp_do_5) * Global_18_do_ko[Local_12_in]) || Global_22_a_168_ko[Para_0_in].lo_16 != Global_17_lo_ko[Local_12_in] )   continue;
       Global_22_a_168_ko[Para_0_in].bo_5 = false;
       Global_22_a_168_ko[Para_0_in].bo_6 = false;
       Global_22_a_168_ko[Para_0_in].bo_19 = false;
       Global_22_a_168_ko[Para_0_in].bo_20 = false;
       break;
       
     }
     
   }
 }
 Global_22_a_168_ko[Para_0_in].bo_18 = false;
 }
//lizong_28 <<==--------   --------
 void lizong_29()
 {
  double    Local_1_do = 0.0;
  double    Local_2_do;
//----- -----
 double     tmp_do_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;
 int        tmp_in_5;
 string     tmp_st_6;
 int        tmp_in_7;
 int        tmp_in_8;
 int        tmp_in_9;
 int        tmp_in_10;
 int        tmp_in_11;
 double     tmp_do_12;
 int        tmp_in_13;
 int        tmp_in_14;
 int        tmp_in_15;
 int        tmp_in_16;
 string     tmp_st_17;
 int        tmp_in_18;
 int        tmp_in_19;
 int        tmp_in_20;
 int        tmp_in_21;
 int        tmp_in_22;

 if ( MaximumDrawdown>Global_25_do && MaximumDrawdown<99.99 )
 {
   if ( DrawdownCalculation == 1 )
   {
     tmp_do_1 = 0.0;
     tmp_in_2 = Global_24_in + UID + int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32)) ));
     tmp_in_3 = Global_24_in + UID + int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32)) )) * 2;
     for (tmp_in_4 = 0 ; tmp_in_4 < OrdersTotal() ; tmp_in_4=tmp_in_4 + 1)
     {
       if ( OrderSelect(tmp_in_4,0,0) )
       {
         tmp_in_5 = OrderType();
         OrderSymbol(); 
         tmp_in_7 = OrderMagicNumber() / 100;
         if ( ( ( tmp_in_5 != 0 || tmp_in_2 != tmp_in_7 ) && (tmp_in_5 != 1 || tmp_in_3 != tmp_in_7) ) )   continue;
         tmp_do_1 = OrderProfit() + OrderSwap() + OrderCommission() + tmp_do_1;
          continue;
       }
       Print(TradeComment + " " + "------",": Failed to select an order! Error=",lizong_11(GetLastError())); 
       
     }
     Local_1_do = -(tmp_do_1);
   }
   if ( DrawdownCalculation == 0 )
   {
     Local_1_do = AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY) ;
   }
   if ( Local_1_do>MaximumDrawdown / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE) )
   {
     if ( MaximumDrawdownAction == 0 )
     {
       Global_29_bo = true ;
       Global_30_in = 24 ;
       for (tmp_in_8 = 0 ; tmp_in_8 < ArraySize(Global_22_a_168_ko) ; tmp_in_8=tmp_in_8 + 1)
       {
         Global_22_a_168_ko[tmp_in_8].bo_5 = false;
         Global_22_a_168_ko[tmp_in_8].bo_6 = false;
       }
     }
     if ( MaximumDrawdownAction == 1 )
     {
       Global_29_bo = true ;
       Global_31_bo = true ;
       for (tmp_in_9 = 0 ; tmp_in_9 < ArraySize(Global_22_a_168_ko) ; tmp_in_9=tmp_in_9 + 1)
       {
         Global_22_a_168_ko[tmp_in_9].bo_5 = false;
         Global_22_a_168_ko[tmp_in_9].bo_6 = false;
       }
     }
     if ( MaximumDrawdownAction == 2 )
     {
       for (tmp_in_10 = 0 ; tmp_in_10 < ArraySize(Global_22_a_168_ko) ; tmp_in_10=tmp_in_10 + 1)
       {
         Global_22_a_168_ko[tmp_in_10].bo_5 = false;
         Global_22_a_168_ko[tmp_in_10].bo_6 = false;
       }
     }
     if ( MaximumDrawdownAction == 3 )
     {
       Global_31_bo = true ;
       for (tmp_in_11 = 0 ; tmp_in_11 < ArraySize(Global_22_a_168_ko) ; tmp_in_11=tmp_in_11 + 1)
       {
         Global_22_a_168_ko[tmp_in_11].bo_5 = false;
         Global_22_a_168_ko[tmp_in_11].bo_6 = false;
       }
     }
   }
 }
 if ( !(MaximumDrawdownMoney>Global_25_do) )   return;
 Local_2_do = 0.0 ;
 if ( DrawdownCalculation == 1 )
 {
   tmp_do_12 = 0.0;
   tmp_in_13 = Global_24_in + UID + int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32)) ));
   tmp_in_14 = Global_24_in + UID + int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32)) )) * 2;
   for (tmp_in_15 = 0 ; tmp_in_15 < OrdersTotal() ; tmp_in_15=tmp_in_15 + 1)
   {
     if ( OrderSelect(tmp_in_15,0,0) )
     {
       tmp_in_16 = OrderType();
       OrderSymbol(); 
       tmp_in_18 = OrderMagicNumber() / 100;
       if ( ( ( tmp_in_16 != 0 || tmp_in_13 != tmp_in_18 ) && (tmp_in_16 != 1 || tmp_in_14 != tmp_in_18) ) )   continue;
       tmp_do_12 = OrderProfit() + OrderSwap() + OrderCommission() + tmp_do_12;
        continue;
     }
     Print(TradeComment + " " + "------",": Failed to select an order! Error=",lizong_11(GetLastError())); 
     
   }
   Local_2_do = -(tmp_do_12);
 }
 if ( DrawdownCalculation == 0 )
 {
   Local_2_do = AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY) ;
 }
 if ( !(Local_2_do>MaximumDrawdownMoney) )   return;
 
 if ( MaximumDrawdownAction == 0 )
 {
   Global_29_bo = true ;
   Global_30_in = 24 ;
   for (tmp_in_19 = 0 ; tmp_in_19 < ArraySize(Global_22_a_168_ko) ; tmp_in_19=tmp_in_19 + 1)
   {
     Global_22_a_168_ko[tmp_in_19].bo_5 = false;
     Global_22_a_168_ko[tmp_in_19].bo_6 = false;
   }
 }
 if ( MaximumDrawdownAction == 1 )
 {
   Global_29_bo = true ;
   Global_31_bo = true ;
   for (tmp_in_20 = 0 ; tmp_in_20 < ArraySize(Global_22_a_168_ko) ; tmp_in_20=tmp_in_20 + 1)
   {
     Global_22_a_168_ko[tmp_in_20].bo_5 = false;
     Global_22_a_168_ko[tmp_in_20].bo_6 = false;
   }
 }
 if ( MaximumDrawdownAction == 2 )
 {
   for (tmp_in_21 = 0 ; tmp_in_21 < ArraySize(Global_22_a_168_ko) ; tmp_in_21=tmp_in_21 + 1)
   {
     Global_22_a_168_ko[tmp_in_21].bo_5 = false;
     Global_22_a_168_ko[tmp_in_21].bo_6 = false;
   }
 }
 if ( MaximumDrawdownAction != 3 )   return;
 Global_31_bo = true ;
 for (tmp_in_22 = 0 ; tmp_in_22 < ArraySize(Global_22_a_168_ko) ; tmp_in_22=tmp_in_22 + 1)
 {
   Global_22_a_168_ko[tmp_in_22].bo_5 = false;
   Global_22_a_168_ko[tmp_in_22].bo_6 = false;
 }
 }
//lizong_29 <<==--------   --------
 bool lizong_30( string Para_0_st,int Para_1_in,int Para_2_in,double Para_3_do,double Para_4_do,double Para_5_do,double Para_6_do,double Para_7_do,double Para_8_do)
 {
  //bool      Local_1_bo;
  int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  double    Local_5_do;
  double    Local_6_do;
  double    Local_7_do;
  double    Local_8_do;
  double    Local_9_do;
  double    Local_10_do;
  double    Local_11_do;
  int       Local_12_in;
  double    Local_13_do;
  double    Local_14_do;
//----- -----

 if ( Global_5_in == 0 )
 {
   return(false); 
 }
 if ( Global_28_in == 0 && TimeMinute(TimeCurrent()) <= 1 && !(MQLInfoInteger(MQL_TESTER)) )
 {
   return(false); 
 }
 if ( Global_28_in == 0 && TimeMinute(TimeCurrent()) <= 5 && TimeDayOfWeek(Global_28_in) == 1 && !(MQLInfoInteger(MQL_TESTER)) )
 {
   return(false); 
 }
 Local_2_in = 0 ;
 Local_3_in = -1 ;
 Local_4_in = 0 ;
 Local_5_do = 0.0 ;
 Local_6_do = 0.0 ;
 Local_7_do = 0.0 ;
 Local_8_do = 0.0 ;
 Local_9_do = 0.0 ;
 Local_10_do = 0.0 ;
 Local_11_do = SymbolInfoDouble(Para_0_st,SYMBOL_POINT) ;
 Local_12_in = SymbolInfoInteger(Para_0_st,SYMBOL_DIGITS) ;
 Local_13_do = NormalizeDouble(SymbolInfoInteger(Para_0_st,SYMBOL_TRADE_STOPS_LEVEL) * Local_11_do,Local_12_in) ;
 Local_14_do = NormalizeDouble(SymbolInfoInteger(Para_0_st,SYMBOL_TRADE_FREEZE_LEVEL) * Local_11_do,Local_12_in) ;
 Local_2_in = Para_1_in ;
 Local_3_in = Para_2_in ;
 Local_4_in=Para_1_in * 10 + Para_2_in;
 if ( Para_1_in == 1 )
 {
   Local_5_do = NormalizeDouble(Para_3_do,Local_12_in) ;
   Local_6_do = NormalizeDouble(Para_5_do,Local_12_in) ;
   Local_7_do = NormalizeDouble(Para_4_do,Local_12_in) ;
 }
 if ( Local_2_in == 2 )
 {
   Local_8_do = NormalizeDouble(Para_6_do,Local_12_in) ;
   Local_9_do = NormalizeDouble(Para_8_do,Local_12_in) ;
   Local_10_do = NormalizeDouble(Para_7_do,Local_12_in) ;
 }
 if ( Local_2_in == 3 )
 {
   Local_5_do = NormalizeDouble(Para_3_do,Local_12_in) ;
   Local_6_do = NormalizeDouble(Para_5_do,Local_12_in) ;
   Local_7_do = NormalizeDouble(Para_4_do,Local_12_in) ;
   Local_8_do = NormalizeDouble(Para_6_do,Local_12_in) ;
   Local_9_do = NormalizeDouble(Para_8_do,Local_12_in) ;
   Local_10_do = NormalizeDouble(Para_7_do,Local_12_in) ;
 }
 ChartRedraw(0); 
 switch(Local_4_in)
 {
   case 10 :
   if ( ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_7_do,Local_12_in)>Local_14_do) && !(Local_7_do<Local_11_do) ) || ( !(NormalizeDouble(Local_6_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)>Local_14_do) && !(Local_6_do<Local_11_do) ) || Local_2_in != 1 )   break;
   return(true); 
   case 11 :
   if ( ( !(NormalizeDouble(Local_7_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)>Local_14_do) && !(Local_7_do<Local_11_do) ) || ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_6_do,Local_12_in)>Local_14_do) && !(Local_6_do<Local_11_do) ) || Local_2_in != 1 )   break;
   return(true); 
   case 12 :
   if ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_5_do,Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_7_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_6_do - Local_5_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || Local_2_in != 1 )   break;
   return(true); 
   case 13 :
   if ( !(NormalizeDouble(Local_5_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_7_do - Local_5_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_6_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || Local_2_in != 1 )   break;
   return(true); 
   case 14 :
   if ( !(NormalizeDouble(Local_5_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_7_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_6_do - Local_5_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || Local_2_in != 1 )   break;
   return(true); 
   case 15 :
   if ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_5_do,Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_7_do - Local_5_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_6_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || Local_2_in != 1 )   break;
   return(true); 
   case 20 :
   if ( ( !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_10_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_9_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
   case 21 :
   if ( ( !(Local_13_do<NormalizeDouble(Local_10_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_9_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
   case 22 :
   if ( !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_8_do,Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_10_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_9_do - Local_8_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) || Local_2_in != 2 )   break;
   return(true); 
   case 23 :
   if ( !(Local_13_do<NormalizeDouble(Local_8_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_10_do - Local_8_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_9_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) || Local_2_in != 2 )   break;
   return(true); 
   case 24 :
   if ( !(Local_13_do<NormalizeDouble(Local_8_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_10_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_9_do - Local_8_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) || Local_2_in != 2 )   break;
   return(true); 
   case 25 :
   if ( !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_8_do,Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_10_do - Local_8_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_9_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) || Local_2_in != 2 )   break;
   return(true); 
   case 30 :
   if ( ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_7_do,Local_12_in)>Local_14_do) && !(Local_7_do<Local_11_do) ) || ( !(NormalizeDouble(Local_6_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)>Local_14_do) && !(Local_6_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_10_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_9_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
   case 31 :
   if ( ( !(NormalizeDouble(Local_7_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)>Local_14_do) && !(Local_7_do<Local_11_do) ) || ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_6_do,Local_12_in)>Local_14_do) && !(Local_6_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_10_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_9_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
   case 32 :
   if ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_5_do,Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_7_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_6_do - Local_5_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_ASK) - Local_8_do,Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_10_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_9_do - Local_8_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
   case 33 :
   if ( !(NormalizeDouble(Local_5_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_7_do - Local_5_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_6_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || !(Local_13_do<NormalizeDouble(Local_8_do - SymbolInfoDouble(Para_0_st,SYMBOL_BID),Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_10_do - Local_8_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_9_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
   case 34 :
   if ( !(NormalizeDouble(Local_5_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_7_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_6_do - Local_5_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || !(Local_13_do<NormalizeDouble(Local_8_do - SymbolInfoDouble(Para_0_st,SYMBOL_ASK),Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_10_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_9_do - Local_8_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
   case 35 :
   if ( !(NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_5_do,Local_12_in)>Local_14_do) || ( !(Local_13_do<NormalizeDouble(Local_7_do - Local_5_do,Local_12_in)) && !(Local_7_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_5_do - Local_6_do,Local_12_in)) && !(Local_6_do<Local_11_do) ) || !(Local_13_do<NormalizeDouble(SymbolInfoDouble(Para_0_st,SYMBOL_BID) - Local_8_do,Local_12_in)) || ( !(Local_13_do<NormalizeDouble(Local_10_do - Local_8_do,Local_12_in)) && !(Local_10_do<Local_11_do) ) || ( !(Local_13_do<NormalizeDouble(Local_8_do - Local_9_do,Local_12_in)) && !(Local_9_do<Local_11_do) ) )   break;
   return(true); 
 }
 return(false); 
 }
//lizong_30 <<==--------   --------
 void lizong_31( string Para_0_st,int Para_1_in,int Para_2_in,int Para_3_in,string Para_4_st,string Para_5_st,color Para_6_co,int Para_7_in)
 {
 /*if ( ObjectFind(0,Para_0_st) != -1 )
 {
   ObjectSetText(Para_0_st,Para_4_st,Para_7_in,Para_5_st,Para_6_co); 
   return;
 }
 if ( !(ObjectCreate(Para_0_st,23,Para_1_in,0,0.0,0,0.0,0,0.0)) )   return;
 ObjectSet(Para_0_st,101,0.0); 
 ObjectSet(Para_0_st,1028,1.0); 
 ObjectSet(Para_0_st,1000,0.0); 
 ObjectSetString(0,Para_0_st,206,"WakaWakaEA"); 
 ObjectSetInteger(0,Para_0_st,OBJPROP_HIDDEN,1); 
 ObjectSet(Para_0_st,102,Para_2_in); 
 ObjectSet(Para_0_st,103,Para_3_in); 
 ObjectSetText(Para_0_st,Para_4_st,Para_7_in,Para_5_st,Para_6_co); 
 */
 }
//lizong_31 <<==--------   --------
 void lizong_32( int Para_0_in)
 {
  string    Local_1_st;
  int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  int       Local_8_in;
  int       Local_9_in;
  int       Local_10_in;
  int       Local_11_in;
  int       Local_12_in;
  int       Local_13_in;
  int       Local_14_in;
  int       Local_15_in;
  int       Local_16_in;
  int       Local_17_in;
  int       Local_18_in;
  int       Local_19_in;
  int       Local_20_in;
  int       Local_21_in;
  int       Local_22_in;
  bool      Local_23_bo;
  int       Local_24_in;
  int       Local_25_in;
  int       Local_26_in;
  int       Local_27_in;
  int       Local_28_in;
  datetime  Local_29_da;
  int       Local_30_in;
  datetime  Local_31_da;
  int       Local_32_in;
  int       Local_33_in;
  int       Local_34_in;
  int       Local_35_in;
  int       Local_36_in;
  int       Local_37_in;
  int       Local_38_in;
  bool      Local_39_bo;
  int       Local_40_in;
  int       Local_41_in;
  int       Local_42_in;
  int       Local_43_in;
  int       Local_44_in;
  int       Local_45_in;
  double    Local_46_do;
  double    Local_47_do;
  double    Local_48_do;
  double    Local_49_do;
  double    Local_50_do;
  double    Local_51_do;
  double    Local_52_do;
  double    Local_53_do;
  int       Local_54_in;
//----- -----
 int        tmp_in_1;
 string     tmp_st_2;
 int        tmp_in_3;
 string     tmp_st_4;
 int        tmp_in_10;
 int        tmp_in_11;
 int        tmp_in_12;

 Global_22_a_168_ko[Para_0_in].in_4 ++;
 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 Local_2_in = 86400 ;
 Local_3_in = 0 ;
 Local_4_in = 1 ;
 Local_5_in=1 + 1;
 Local_6_in=Local_5_in + 1;
 Local_7_in=Local_5_in + Local_5_in;
 Local_8_in=Local_6_in + Local_5_in;
 Local_9_in=Local_6_in + Local_6_in;
 Local_10_in=Local_7_in + Local_6_in;
 Local_11_in=Local_9_in + Local_5_in;
 Local_12_in=Local_9_in + Local_6_in;
 Local_13_in = 0 ;
 Local_14_in = 1 ;
 Local_15_in = Local_5_in ;
 Local_16_in = Local_6_in ;
 Local_17_in=Local_6_in + 1;
 Local_18_in=Local_7_in + 1;
 Local_19_in=Local_18_in + 1;
 Local_20_in=Local_5_in + Local_18_in;
 Local_21_in=Local_17_in + Local_17_in;
 Local_22_in=Local_21_in + 1;
 Local_23_bo = true ;
 Global_7_da = TimeCurrent() ;
 Local_24_in = TimeHour(Global_7_da) ;
 Local_25_in = TimeMinute(Global_7_da) ;
 Local_26_in = (int)MathFloor(Local_25_in / 15.0) * 15 ;
 Local_27_in = 0 ;
 Local_28_in = 0 ;
 ResetLastError();
 Local_29_da = iTime(Local_1_st,15,0) ;
 Local_28_in = GetLastError() ;
 if ( ( TimeMinute(Local_29_da) != Local_26_in || Local_28_in == 4066 ) && Global_7_da >  0 )
 {
   for (Local_30_in = 0 ; Local_30_in < 10 ; Local_30_in ++)
   {
     Sleep(1000); 
     ResetLastError();
     Local_29_da = iTime(Local_1_st,15,0) ;
     Local_27_in = GetLastError() ;
     if ( Local_27_in != 0 )   continue;
     if ( TimeMinute(Local_29_da) == Local_26_in )   break;
     
   }
   if ( ( TimeMinute(Local_29_da) != Local_26_in || Local_27_in == 4066 ) && Global_22_a_168_ko[Para_0_in].in_4 >  0x1 && Local_27_in >  0 )
   {
     tmp_in_1 = Global_21_in;
     tmp_st_2 = "current";
     if ( Global_21_in == 0 )
     {
       tmp_st_2 = "current";
     }
     if ( tmp_in_1 == 1 )
     {
       tmp_st_2 = "M1";
     }
     if ( tmp_in_1 == 5 )
     {
       tmp_st_2 = "M5";
     }
     if ( tmp_in_1 == 0xF )
     {
       tmp_st_2 = "M15";
     }
     if ( tmp_in_1 == 30 )
     {
       tmp_st_2 = "M30";
     }
     if ( tmp_in_1 == 60 )
     {
       tmp_st_2 = "H1";
     }
     if ( tmp_in_1 == 240 )
     {
       tmp_st_2 = "H4";
     }
     if ( tmp_in_1 == 1440 )
     {
       tmp_st_2 = "D1";
     }
     if ( tmp_in_1 == 10080 )
     {
       tmp_st_2 = "W1";
     }
     if ( tmp_in_1 == 43200 )
     {
       tmp_st_2 = "MN1";
     }
     Print(TradeComment + " " + Local_1_st,":",lizong_11(Local_27_in)," when updating history on ",tmp_st_2); 
     Local_23_bo = false ;
   }
 }
 if ( iBars(Local_1_st,Global_21_in) <  1000 )
 {
   tmp_in_3 = Global_21_in;
   tmp_st_4 = "current";
   if ( Global_21_in == 0 )
   {
     tmp_st_4 = "current";
   }
   if ( tmp_in_3 == 1 )
   {
     tmp_st_4 = "M1";
   }
   if ( tmp_in_3 == 5 )
   {
     tmp_st_4 = "M5";
   }
   if ( tmp_in_3 == 0xF )
   {
     tmp_st_4 = "M15";
   }
   if ( tmp_in_3 == 30 )
   {
     tmp_st_4 = "M30";
   }
   if ( tmp_in_3 == 60 )
   {
     tmp_st_4 = "H1";
   }
   if ( tmp_in_3 == 240 )
   {
     tmp_st_4 = "H4";
   }
   if ( tmp_in_3 == 1440 )
   {
     tmp_st_4 = "D1";
   }
   if ( tmp_in_3 == 10080 )
   {
     tmp_st_4 = "W1";
   }
   if ( tmp_in_3 == 43200 )
   {
     tmp_st_4 = "MN1";
   }
   Print(TradeComment + " " + Local_1_st,": Not enough historical data on ",tmp_st_4); 
   Local_23_bo = false ;
   Local_3_in = 1 ;
   Local_4_in = 1 ;
   Local_5_in = 1 ;
   Local_6_in = 1 ;
   Local_7_in = 1 ;
   Local_8_in = 1 ;
   Local_9_in = 1 ;
   Local_10_in = 1 ;
   Local_11_in = 1 ;
   Local_12_in = 1 ;
   Local_13_in = 1 ;
   Local_14_in = 1 ;
   Local_15_in = 1 ;
   Local_16_in = 1 ;
   Local_17_in = 1 ;
   Local_18_in = 1 ;
   Local_19_in = 1 ;
   Local_20_in = 1 ;
   Local_21_in = 1 ;
   Local_22_in = 1 ;
 }
 if ( AccountInfoDouble(ACCOUNT_MARGIN_FREE)<10.0 )
 {
   Local_23_bo = false ;
   Print(TradeComment + " " + Local_1_st,": Not enough money: ",DoubleToString(MathFloor(AccountInfoDouble(ACCOUNT_MARGIN_FREE)),2)); 
 }
 if ( ( UID > 9 || UID <  0 ) )
 {
   Print(TradeComment + " " + Local_1_st,": UID value issue!"); 
   Local_23_bo = false ;
 }
 Global_22_a_168_ko[Para_0_in].da_7 = iTime(Local_1_st,Global_21_in,0);
 Global_22_a_168_ko[Para_0_in].da_8 = Global_22_a_168_ko[Para_0_in].da_7;
 Local_31_da = Global_22_a_168_ko[Para_0_in].da_7 ;
 if ( Global_22_a_168_ko[Para_0_in].in_4 <  0x2 )
 {
   Local_23_bo = false ;
 }
 if ( !(AllowOpeningNewGrid) )
 {
   Local_23_bo = false ;
 }
 if ( !(Global_37_bo) )
 {
   Local_23_bo = false ;
 }
 Global_28_in = TimeHour(Local_31_da) ;
 Local_32_in = TimeMinute(Local_31_da) ;
 Local_33_in = TimeDayOfWeek(Local_31_da) ;
 Local_34_in = TimeMonth(Local_31_da) ;
 Local_35_in = TimeDay(Local_31_da) ;
 Local_36_in = TimeDayOfWeek(Local_31_da) ;
 Local_37_in = TimeYear(Local_31_da) ;
 Global_22_a_168_ko[Para_0_in].bo_5 = Local_23_bo;
 Global_22_a_168_ko[Para_0_in].bo_6 = Local_23_bo;
 Global_22_a_168_ko[Para_0_in].bo_10 = false;
 Local_38_in = (int)SymbolInfoInteger(Local_1_st,30) ;
 switch(Local_38_in)
 {
   case 0 :
   Print(TradeComment + " " + Local_1_st,": Trading is disabled for ",Local_1_st); 
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
     break;
   case 3 :
   Global_22_a_168_ko[Para_0_in].bo_5 = true;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
     break;
   case 4 :
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = true;
     break;
   case 1 :
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
 }
 if ( AllowToBuySell == 1 )
 {
   Global_22_a_168_ko[Para_0_in].bo_5 = true;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
 }
 if ( AllowToBuySell == 2 )
 {
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = true;
 }
 Global_22_a_168_ko[Para_0_in].do_9 = iClose(Local_1_st,Global_21_in,1);
 Global_22_a_168_ko[Para_0_in].bo_5 &=AllowOpeningNewGrid;
 Global_22_a_168_ko[Para_0_in].bo_6 &=AllowOpeningNewGrid;
 Local_39_bo = true ;
 Local_40_in = 0 ;
 Local_41_in = 0 ;
 Local_42_in = 0 ;
 Local_43_in = 0 ;
 Local_44_in = 59 ;
 Local_40_in=Local_32_in + Global_28_in * 100;
 Local_41_in=HourToStartTrading * 100;
 Local_42_in=HourToStopTrading * 100 + 59;
 if ( Local_42_in >= Local_41_in )
 {
   Local_39_bo &= Local_40_in>=Local_41_in && Local_40_in<=Local_42_in;
 }
 if ( Local_42_in <  Local_41_in )
 {
   Local_39_bo &= Local_40_in>=Local_41_in && Local_40_in<=Local_42_in;
 }
 Local_45_in = 5 ;
 if ( AllowTradingOnHolidays )
 {
   Local_45_in = 0 ;
 }
 if ( Local_45_in >  0 && ( Local_34_in == 1 || Local_34_in == 12 ) && Local_45_in <  31 )
 {
   if ( Local_34_in == 12 && Local_35_in >  31 - Local_45_in )
   {
     Local_39_bo = false ;
   }
   if ( Local_34_in == 1 && Local_35_in <= Local_45_in )
   {
     Local_39_bo = false ;
   }
 }
 Local_39_bo &=Local_32_in==0 || Local_32_in==15 || Local_32_in==30 || Local_32_in==45;
 Global_22_a_168_ko[Para_0_in].bo_5 &=Local_39_bo;
 Global_22_a_168_ko[Para_0_in].bo_6 &=Local_39_bo;
 //HideTestIndicators(true); 
 TesterHideIndicators(true);
 hma=iMA(Local_1_st,lizong_10(Global_21_in),BollingerBandsPeriod + 1,0,0,0) ;
 int _start_pos,_count;double mma[],mstd[];
 ArraySetAsSeries(mma,true);
 _start_pos=0;_count=300;_count++;
 iGetArray(hma,0,_start_pos,_count,mma);
 hstd=iStdDev(Local_1_st,lizong_10(Global_21_in),BollingerBandsPeriod + 1,0,0,0);
 ArraySetAsSeries(mstd,true);
 _start_pos=0;_count=300;_count++;
 iGetArray(hstd,0,_start_pos,_count,mstd);
 Local_46_do = (mstd[1]) * 2.0 + mma[1] ;
 Local_47_do = mma[1] - ((mstd[1])) * 2.0 ;
 TesterHideIndicators(true);
 Local_46_do = NormalizeDouble(Local_46_do,SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS)) ;
 Local_47_do = NormalizeDouble(Local_47_do,SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS)) ;
 Local_48_do = iHigh(Local_1_st,lizong_10(Global_21_in),iHighest(Local_1_st,lizong_10(Global_21_in),2,BollingerBandsPeriod + 1,2)) ;
 Local_49_do = iLow(Local_1_st,lizong_10(Global_21_in),iLowest(Local_1_st,lizong_10(Global_21_in),1,BollingerBandsPeriod + 1,2)) ;
 Local_48_do = NormalizeDouble(Local_48_do,SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS)) ;
 Local_49_do = NormalizeDouble(Local_49_do,SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS)) ;
 Global_22_a_168_ko[Para_0_in].do_13 = Local_46_do - Local_47_do;
 if ( RSI_Period != 0 && RSI_Value >  0 )
 {
   hrsi=iRSI(Local_1_st,lizong_10(Global_21_in),RSI_Period,0) ;
   
   int _start_pos,_count;double mrsi[];
   ArraySetAsSeries(mrsi,true);
   _start_pos=0;_count=300;_count++;
   iGetArray(hrsi,0,_start_pos,_count,mrsi);
   Local_50_do = mrsi[1];
   Local_50_do = NormalizeDouble(Local_50_do,(int)SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS)) ;
   Global_22_a_168_ko[Para_0_in].bo_5 &=Local_50_do<50 - RSI_Value;
   Global_22_a_168_ko[Para_0_in].bo_6 &=Local_50_do>RSI_Value + 50;
 }
 Global_22_a_168_ko[Para_0_in].bo_5 &=Global_22_a_168_ko[Para_0_in].do_9<Local_49_do;
 Global_22_a_168_ko[Para_0_in].bo_5 &=Local_49_do>0.0;
 Global_22_a_168_ko[Para_0_in].bo_6 &=Global_22_a_168_ko[Para_0_in].do_9>Local_48_do;
 Global_22_a_168_ko[Para_0_in].bo_6 &=Local_48_do>0.0;
 tmp_in_10 = 0;
 for (tmp_in_11 = 0 ; tmp_in_11 < ArraySize(Global_22_a_168_ko) ; tmp_in_11=tmp_in_11 + 1)
 {
   if ( lizong_21(Global_22_a_168_ko[tmp_in_11].st_1,0,0) )
   {
     tmp_in_10=tmp_in_10 + 1;
   }
 }
 if ( tmp_in_10 >= MaximumSymbols )
 {
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
 }
 if ( SmartDistance )
 {
   hatr96=iATR(Local_1_st,Global_21_in,96);
   hatr672=iATR(Local_1_st,Global_21_in,672);
   
   int _start_pos,_count;double m96[],m672[];
   ArraySetAsSeries(m96,true);
   _start_pos=0;_count=300;_count++;
   iGetArray(hatr96,0,_start_pos,_count,m96);
   ArraySetAsSeries(m672,true);
   _start_pos=0;_count=300;_count++;
   iGetArray(hatr672,0,_start_pos,_count,m672);

   Local_51_do = m96[1];
   Local_52_do = m672[1];
   if ( Local_52_do>Global_25_do )
   {
     Global_22_a_168_ko[Para_0_in].do_12 = Local_51_do / Local_52_do;
   }
   if ( Global_22_a_168_ko[Para_0_in].do_12<1.0 )
   {
     Global_22_a_168_ko[Para_0_in].do_12 = 1.0;
   }
   if ( Global_22_a_168_ko[Para_0_in].do_12>1.5 )
   {
     Global_22_a_168_ko[Para_0_in].do_12 = 1.5;
   }
 }
 if ( Local_36_in != Global_22_a_168_ko[Para_0_in].in_21 && Global_22_a_168_ko[Para_0_in].in_21 != 0x0 )
 {
   Global_22_a_168_ko[Para_0_in].bo_19 = Global_22_a_168_ko[Para_0_in].bo_20;
   Global_22_a_168_ko[Para_0_in].bo_20 = true;
 }
 Global_22_a_168_ko[Para_0_in].in_21 = Local_36_in;
 Global_22_a_168_ko[Para_0_in].bo_5 &=Global_22_a_168_ko[Para_0_in].bo_19;
 Global_22_a_168_ko[Para_0_in].bo_6 &=Global_22_a_168_ko[Para_0_in].bo_19;
 if ( Global_11_bo && Local_37_in * 10000 + Local_34_in * 100 + Local_35_in <  20211020 )
 {
   lizong_28(Para_0_in); 
 }
 Global_5_in ++;
 Global_5_in ++;
 lizong_29(); 
 if ( MinimumFreeMargin>Global_25_do && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL)<MinimumFreeMargin && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL)>Global_25_do )
 {
   for (tmp_in_12 = 0 ; tmp_in_12 < ArraySize(Global_22_a_168_ko) ; tmp_in_12=tmp_in_12 + 1)
   {
     Global_22_a_168_ko[tmp_in_12].bo_5 = false;
     Global_22_a_168_ko[tmp_in_12].bo_6 = false;
   }
   if ( TimeCurrent() - Global_34_lo >  1800 )
   {
     Print(TradeComment + " " + "->",": Too low account margin level: ",DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),2),". Trading is not allowed!"); 
     Global_34_lo = TimeCurrent() ;
   }
 }
 if ( Global_32_in != Global_28_in )
 {
   Global_30_in --;
 }
 if ( Global_30_in <  0 )
 {
   Global_30_in = 0 ;
 }
 if ( Global_29_bo )
 {
   Local_53_do = 0.0 ;
   for (Local_54_in = 0 ; Local_54_in < ArraySize(Global_22_a_168_ko) ; Local_54_in ++)
   {
     Local_53_do = Local_53_do + lizong_24(Global_22_a_168_ko[Local_54_in].st_1,-1,0,false) ;
   }
   if ( Local_53_do<Global_25_do )
   {
     Global_29_bo = false ;
   }
 }
 if ( Global_29_bo )
 {
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
   if ( TimeCurrent() - Global_33_lo >  3600 )
   {
     Print(TradeComment + " " + Global_22_a_168_ko[Para_0_in].st_1,": Trading not allowed: got a signal to close all trades!"); 
     Global_33_lo = TimeCurrent() ;
   }
 }
 if ( Global_31_bo )
 {
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
   if ( TimeCurrent() - Global_33_lo >  3600 )
   {
     Print(TradeComment + " " + Global_22_a_168_ko[Para_0_in].st_1,": Max DD reached: trading not allowed until restart!"); 
     Global_33_lo = TimeCurrent() ;
   }
 }
 if ( Global_30_in >  0 )
 {
   Global_22_a_168_ko[Para_0_in].bo_5 = false;
   Global_22_a_168_ko[Para_0_in].bo_6 = false;
   if ( TimeCurrent() - Global_33_lo >  3600 )
   {
     Print(TradeComment + " " + Global_22_a_168_ko[Para_0_in].st_1,": Max DD reached: trading is not allowed for ",IntegerToString(Global_30_in,0,32)," hour(s)!"); 
     Global_33_lo = TimeCurrent() ;
   }
 }
 Global_32_in = Global_28_in ;
 lizong_33(Para_0_in,false); 
 }
//lizong_32 <<==--------   --------
 void lizong_33( int Para_0_in,bool Para_1_bo)
 {
  string    Local_1_st;
  double    Local_2_do;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  bool      Local_6_bo;
  double    Local_7_do;
  double    Local_8_do;
  double    Local_9_do;
  double    Local_10_do;
  int       Local_11_in;
  double    Local_12_do;
  int       Local_13_in;
  double    Local_14_do;
  long      Local_16_lo;
  double    Local_17_do;
  int       Local_18_in;
  int       Local_19_in;
  bool      Local_20_bo;
  double    Local_21_do;
  double    Local_22_do;
  double    Local_23_do;
  double    Local_24_do;
  int       Local_25_in;
  double    Local_26_do;
  int       Local_27_in;
  double    Local_28_do;
  int      Local_30_lo;
  int       Local_31_in;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;
 int        tmp_in_3;
 bool       tmp_bo_4;
 int        tmp_in_5;
 int        tmp_in_6;
 double     tmp_do_7;
 double     tmp_do_8;
 double     tmp_do_9;
 double     tmp_do_10;
 int        tmp_in_11;
 datetime     tmp_do_12;
 int        tmp_in_13;
 int        tmp_in_14;
 string     tmp_st_15;
 string     tmp_st_16;
 double     tmp_do_17;
 double     tmp_do_18;
 int        tmp_in_19;
 int        tmp_in_20;
 long       tmp_lo_21;
 int        tmp_in_22;
 int        tmp_in_23;
 bool       tmp_bo_24;
 int        tmp_in_25;
 int        tmp_in_26;
 double     tmp_do_27;
 double     tmp_do_28;
 double     tmp_do_29;
 double     tmp_do_30;
 int        tmp_in_31;
 int     tmp_do_32;
 int        tmp_in_33;
 int        tmp_in_34;
 string     tmp_st_35;
 string     tmp_st_36;
 double     tmp_do_37;
 double     tmp_do_38;
 int        tmp_in_39;
 int        tmp_in_40;
 long       tmp_lo_41;

 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 tmp_in_1 = TerminalInfoInteger(8);
 if ( tmp_in_1 != 0 )
 {
   tmp_in_1 = (int)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
 }
 if ( tmp_in_1 != 0 )
 {
   tmp_in_1 = MQLInfoInteger(MQL_TRADE_ALLOWED);
 }
 if ( tmp_in_1 == 0 && !(MQLInfoInteger(MQL_TESTER)) && MQLInfoInteger(MQL_OPTIMIZATION) )
 {
   if ( ( Global_22_a_168_ko[Para_0_in].bo_5 != 0x0 || Global_22_a_168_ko[Para_0_in].bo_6 != 0x0 ) )
   {
     Print(TradeComment + " " + Local_1_st,": Trading is not allowed!"); 
   }
   return;
 }
 if ( Global_22_a_168_ko[Para_0_in].bo_5 != 0x0 )
 {
   ChartRedraw(0); 
   Local_2_do = SymbolInfoInteger(Local_1_st,SYMBOL_SPREAD) ;
   if ( ( ( !(lizong_21(Local_1_st,-1,1)) && AllowHedging ) || (!(lizong_21(Local_1_st,-1,0)) && !(AllowHedging)) ) )
   {
     tmp_in_2 = 0;
     for (tmp_in_3 = 0 ; tmp_in_3 < ArraySize(Global_22_a_168_ko) ; tmp_in_3=tmp_in_3 + 1)
     {
       if ( lizong_21(Global_22_a_168_ko[tmp_in_3].st_1,0,0) )
       {
         tmp_in_2=tmp_in_2 + 1;
       }
     }
     if ( tmp_in_2 <  MaximumSymbols )
     {
       Local_3_in = 0 ;
       Local_4_in = 10 ;
       Local_5_in = 0 ;
       Local_6_bo = false ;
         if(!(IsStopped())){
       do
       {
         ChartRedraw(0); 
         Local_7_do = SymbolInfoDouble(Local_1_st,SYMBOL_ASK) ;
         Local_8_do = lizong_34(Local_1_st,true) ;
         if ( Local_8_do<Global_25_do )
         {
           Print(TradeComment + " " + Local_1_st,": Sending stopped because los size is too small: ",DoubleToString(Local_8_do,8)); 
           return;
         }
         if ( MQLInfoInteger(MQL_TESTER) )
         {
           tmp_bo_4 = true;
         }
         else
         {
           if ( TerminalInfoInteger(6) == 0 )
           {
             Global_22_a_168_ko[Para_0_in].bo_5 = false;
             Global_22_a_168_ko[Para_0_in].bo_6 = false;
             Print(TradeComment + " " + Global_22_a_168_ko[Para_0_in].st_1,": Signal rejected due to absence of network connection!"); 
             tmp_bo_4 = false;
           }
           else
           {
             tmp_bo_4 = true;
           }
         }
         if ( !(tmp_bo_4) && !(MQLInfoInteger(MQL_TESTER)) )
         {
           Print(TradeComment + " " + Local_1_st,": No connection to trading server!"); 
           return;
         }
         Local_9_do = 1000;//AccountFreeMarginCheck(Local_1_st,0,Local_8_do) ;
         if ( Local_9_do<=0.0 )
         {
           Print(TradeComment + " " + Local_1_st,": Not enough money to send a new initial buy order: ",DoubleToString(Local_9_do,2)); 
           Global_22_a_168_ko[Para_0_in].bo_5 = false;
           Local_6_bo = true ;
         }
         else
         {
           Print(TradeComment + " " + Local_1_st,": Sending a new initial buy order, attempt N",IntegerToString(Local_3_in + 1,0,32)); 
           tmp_in_5 = 10;
           tmp_in_6 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
           if ( tmp_in_6 == 5 )
           {
             tmp_in_5 = 10;
           }
           if ( tmp_in_6 == 4 )
           {
             tmp_in_5 = 1;
           }
           if ( tmp_in_6 == 0x3 )
           {
             tmp_in_5 = 10;
           }
           if ( ( tmp_in_6 == 2 || tmp_in_6 == 1 || tmp_in_6 == 0 ) )
           {
             tmp_in_5 = 1;
           }
           if ( ( Local_2_do<MaximumSpread * tmp_in_5 || MaximumSpread<Global_25_do ) )
           {
             tmp_do_7 = SymbolInfoDouble(Local_1_st,35);
             tmp_do_8 = SymbolInfoDouble(Local_1_st,36);
             if ( tmp_do_7>SymbolInfoDouble(Local_1_st,55) && SymbolInfoDouble(Local_1_st,55)>Global_25_do )
             {
               tmp_do_7 = SymbolInfoDouble(Local_1_st,55);
             }
             if ( tmp_do_7>MaximumLot )
             {
               tmp_do_7 = MaximumLot;
             }
             if ( tmp_do_8<0.001001 && tmp_do_8>0.000999 )
             {
               tmp_do_7 = NormalizeDouble(tmp_do_7,3);
             }
             if ( tmp_do_8<0.010001 && tmp_do_8>0.009999 )
             {
               tmp_do_7 = NormalizeDouble(tmp_do_7,2);
             }
             if ( tmp_do_8<0.100001 && tmp_do_8>0.099999 )
             {
               tmp_do_7 = NormalizeDouble(tmp_do_7,1);
             }
             if ( tmp_do_8<1.000001 && tmp_do_8>0.999999 )
             {
               tmp_do_7 = NormalizeDouble(tmp_do_7,0);
             }
             Local_10_do = tmp_do_7 ;
             Local_11_in = 1 ;
             if ( Local_8_do>Local_10_do && AutoSplit )
             {
               Local_11_in = (int)MathCeil(Local_8_do / Local_10_do) ;
             }
             Local_12_do = Local_8_do ;
             for (Local_13_in = 0 ; Local_13_in < Local_11_in ; Local_13_in ++)
             {
               Local_14_do = MathMin(Local_10_do,Local_12_do) ;
               tmp_do_9 = Local_14_do;
               tmp_do_10 = SymbolInfoDouble(Local_1_st,36);
               if ( tmp_do_10<0.001001 && tmp_do_10>0.000999 )
               {
                 tmp_do_9 = NormalizeDouble(tmp_do_9,3);
               }
               if ( tmp_do_10<0.010001 && tmp_do_10>0.009999 )
               {
                 tmp_do_9 = NormalizeDouble(tmp_do_9,2);
               }
               if ( tmp_do_10<0.100001 && tmp_do_10>0.099999 )
               {
                 tmp_do_9 = NormalizeDouble(tmp_do_9,1);
               }
               if ( tmp_do_10<1.000001 && tmp_do_10>0.999999 )
               {
                 tmp_do_9 = NormalizeDouble(tmp_do_9,0);
               }
               Local_14_do = tmp_do_9 ;
               tmp_in_11 = -1;
               tmp_do_12 = 0;
               tmp_in_13 = int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32))  + 2)) + (Global_24_in + UID) * 100;
               tmp_in_14 = 0;
               tmp_st_15 = TradeComment;
               if ( Para_1_bo )
               {
                 tmp_st_15 = TradeComment + " M";
               }
               if ( tmp_in_14 >  0 )
               {
                 tmp_st_15 = tmp_st_15 + " #" + string(tmp_in_14);
               }
               tmp_st_16 = tmp_st_15;
               tmp_do_17 = 0.0;
               tmp_do_18 = 0.0;
               tmp_in_19 = 10;
               tmp_in_20 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
               if ( tmp_in_20 == 5 )
               {
                 tmp_in_19 = 10;
               }
               if ( tmp_in_20 == 4 )
               {
                 tmp_in_19 = 1;
               }
               if ( tmp_in_20 == 0x3 )
               {
                 tmp_in_19 = 10;
               }
               if ( ( tmp_in_20 == 2 || tmp_in_20 == 1 || tmp_in_20 == 0 ) )
               {
                 tmp_in_19 = 1;
               }
               Local_16_lo = OrderSend( Local_1_st,0,Local_14_do,Local_7_do,int(MaximumSlippage * tmp_in_19),tmp_do_18,tmp_do_17,tmp_st_16,tmp_in_13,tmp_do_12,tmp_in_11) ;
               if ( Local_16_lo <  0 )
               {
                 Local_5_in = GetLastError() ;
                 Print(TradeComment + " " + Local_1_st,": Failed to send a new initial buy order. Error:",lizong_11(Local_5_in)); 
                 if ( Local_5_in == 4110 && MQLInfoInteger(MQL_TESTER) )
                 {
                   Local_6_bo = true ;
                 }
                 if ( Local_5_in == 149 )
                 {
                   Local_6_bo = true ;
                   Global_22_a_168_ko[Para_0_in].bo_5 = false;
                 }
                 if ( ( Local_5_in == 148 || Local_5_in == 139 || Local_5_in == 134 || Local_5_in == 133 || Local_5_in == 128 || Local_5_in == 64 || Local_5_in == 6 || Local_5_in == 4 || Local_5_in == 3 || Local_5_in == 2 || Local_5_in == 1 ) )
                 {
                   Local_6_bo = true ;
                   Global_22_a_168_ko[Para_0_in].bo_5 = false;
                   Print(TradeComment + " " + Local_1_st,": Stopped trying to send a new initial buy order due to fatal error!"); 
                 }
                 Sleep(5000); 
               }
               else
               {
                 Print(TradeComment + " " + Local_1_st,": Initial buy trade is opened id: ",IntegerToString(Local_16_lo,0,32)); 
                 Local_6_bo = true ;
                 Global_22_a_168_ko[Para_0_in].bo_5 = false;
                 Global_22_a_168_ko[Para_0_in].bo_10 = true;
                 Global_22_a_168_ko[Para_0_in].bo_11 = true;
                 Global_22_a_168_ko[Para_0_in].da_27 = TimeCurrent();
               }
               Local_12_do = Local_12_do - Local_14_do ;
               Sleep(500); 
             }
           }
           else
           {
             Print(TradeComment + " " + Local_1_st,": Cannot open a new initial buy trade due to high spread: ",DoubleToString(Local_2_do,2)); 
             Sleep(5000); 
           }
         }
         if ( !(MQLInfoInteger(MQL_TESTER)) && !(MQLInfoInteger(MQL_OPTIMIZATION)) )
         {
           tmp_lo_21 = TerminalInfoInteger(8);
           if ( tmp_lo_21 != 0 )
           {
             tmp_lo_21 = AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
           }
           if ( tmp_lo_21 != 0 )
           {
             tmp_lo_21 = MQLInfoInteger(MQL_TRADE_ALLOWED);
           }
           if ( tmp_lo_21 == 0 )
           {
             Local_6_bo = true ;
           }
         }
         if ( Local_3_in >= Local_4_in )
         {
           Local_6_bo = true ;
         }
         Local_3_in ++;
         if ( IsStopped() )   break;
         
       }
       while(!(Local_6_bo));
       }
     }
   }
 }
 if ( Global_22_a_168_ko[Para_0_in].bo_6 != 0x0 )
 {
   ChartRedraw(0); 
   Local_17_do = SymbolInfoInteger(Local_1_st,SYMBOL_SPREAD) ;
   if ( ( ( !(lizong_21(Local_1_st,-1,-1)) && AllowHedging ) || (!(lizong_21(Local_1_st,-1,0)) && !(AllowHedging)) ) )
   {
     tmp_in_22 = 0;
     for (tmp_in_23 = 0 ; tmp_in_23 < ArraySize(Global_22_a_168_ko) ; tmp_in_23=tmp_in_23 + 1)
     {
       if ( lizong_21(Global_22_a_168_ko[tmp_in_23].st_1,0,0) )
       {
         tmp_in_22=tmp_in_22 + 1;
       }
     }
     if ( tmp_in_22 <  MaximumSymbols )
     {
       Local_18_in = 0 ;
       Local_19_in = 10 ;
       Local_20_bo = false ;
         if(!(IsStopped())){
       do 
       {
         ChartRedraw(0); 
         Local_21_do = SymbolInfoDouble(Local_1_st,SYMBOL_BID) ;
         Local_22_do = lizong_34(Local_1_st,true) ;
         if ( Local_22_do<Global_25_do )
         {
           Print(TradeComment + " " + Local_1_st,": Sending stopped because lot size is too small: ",DoubleToString(Local_22_do,8)); 
           return;
         }
         if ( MQLInfoInteger(MQL_TESTER) )
         {
           tmp_bo_24 = true;
         }
         else
         {
           if ( TerminalInfoInteger(6) == 0 )
           {
             Global_22_a_168_ko[Para_0_in].bo_5 = false;
             Global_22_a_168_ko[Para_0_in].bo_6 = false;
             Print(TradeComment + " " + Global_22_a_168_ko[Para_0_in].st_1,": Signal rejected due to absence of network connection!"); 
             tmp_bo_24 = false;
           }
           else
           {
             tmp_bo_24 = true;
           }
         }
         if ( !(tmp_bo_24) && !(MQLInfoInteger(MQL_TESTER)) )
         {
           Print(TradeComment + " " + Local_1_st,": No connection to trading server!"); 
           return;
         }
         Local_23_do = 1000;//AccountFreeMarginCheck(Local_1_st,1,Local_22_do) ;
         if ( Local_23_do<=0.0 )
         {
           Print(TradeComment + " " + Local_1_st,": Not enough money to send a new initial sell order: ",DoubleToString(Local_23_do,2)); 
           Global_22_a_168_ko[Para_0_in].bo_6 = false;
           Local_20_bo = true ;
         }
         else
         {
           Print(TradeComment + " " + Local_1_st,": Sending a new initial sell order, attempt N",IntegerToString(Local_18_in + 1,0,32)); 
           tmp_in_25 = 10;
           tmp_in_26 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
           if ( tmp_in_26 == 5 )
           {
             tmp_in_25 = 10;
           }
           if ( tmp_in_26 == 4 )
           {
             tmp_in_25 = 1;
           }
           if ( tmp_in_26 == 0x3 )
           {
             tmp_in_25 = 10;
           }
           if ( ( tmp_in_26 == 2 || tmp_in_26 == 1 || tmp_in_26 == 0 ) )
           {
             tmp_in_25 = 1;
           }
           if ( ( Local_17_do<MaximumSpread * tmp_in_25 || MaximumSpread<Global_25_do ) )
           {
             tmp_do_27 = SymbolInfoDouble(Local_1_st,35);
             tmp_do_28 = SymbolInfoDouble(Local_1_st,36);
             if ( tmp_do_27>SymbolInfoDouble(Local_1_st,55) && SymbolInfoDouble(Local_1_st,55)>Global_25_do )
             {
               tmp_do_27 = SymbolInfoDouble(Local_1_st,55);
             }
             if ( tmp_do_27>MaximumLot )
             {
               tmp_do_27 = MaximumLot;
             }
             if ( tmp_do_28<0.001001 && tmp_do_28>0.000999 )
             {
               tmp_do_27 = NormalizeDouble(tmp_do_27,3);
             }
             if ( tmp_do_28<0.010001 && tmp_do_28>0.009999 )
             {
               tmp_do_27 = NormalizeDouble(tmp_do_27,2);
             }
             if ( tmp_do_28<0.100001 && tmp_do_28>0.099999 )
             {
               tmp_do_27 = NormalizeDouble(tmp_do_27,1);
             }
             if ( tmp_do_28<1.000001 && tmp_do_28>0.999999 )
             {
               tmp_do_27 = NormalizeDouble(tmp_do_27,0);
             }
             Local_24_do = tmp_do_27 ;
             Local_25_in = 1 ;
             if ( Local_22_do>Local_24_do && AutoSplit )
             {
               Local_25_in = (int)MathCeil(Local_22_do / Local_24_do) ;
             }
             Local_26_do = Local_22_do ;
             for (Local_27_in = 0 ; Local_27_in < Local_25_in ; Local_27_in ++)
             {
               Local_28_do = MathMin(Local_24_do,Local_26_do) ;
               tmp_do_29 = Local_28_do;
               tmp_do_30 = SymbolInfoDouble(Local_1_st,36);
               if ( tmp_do_30<0.001001 && tmp_do_30>0.000999 )
               {
                 tmp_do_29 = NormalizeDouble(tmp_do_29,3);
               }
               if ( tmp_do_30<0.010001 && tmp_do_30>0.009999 )
               {
                 tmp_do_29 = NormalizeDouble(tmp_do_29,2);
               }
               if ( tmp_do_30<0.100001 && tmp_do_30>0.099999 )
               {
                 tmp_do_29 = NormalizeDouble(tmp_do_29,1);
               }
               if ( tmp_do_30<1.000001 && tmp_do_30>0.999999 )
               {
                 tmp_do_29 = NormalizeDouble(tmp_do_29,0);
               }
               Local_28_do = tmp_do_29 ;
               tmp_in_31 = -1;
               tmp_do_32 = 0;
               tmp_in_33 = (int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32))  + 2))) * 2 + (Global_24_in + UID) * 100;
               tmp_in_34 = 0;
               tmp_st_35 = TradeComment;
               if ( Para_1_bo )
               {
                 tmp_st_35 = TradeComment + " M";
               }
               if ( tmp_in_34 >  0 )
               {
                 tmp_st_35 = tmp_st_35 + " #" + string(tmp_in_34);
               }
               tmp_st_36 = tmp_st_35;
               tmp_do_37 = 0.0;
               tmp_do_38 = 0.0;
               tmp_in_39 = 10;
               tmp_in_40 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
               if ( tmp_in_40 == 5 )
               {
                 tmp_in_39 = 10;
               }
               if ( tmp_in_40 == 4 )
               {
                 tmp_in_39 = 1;
               }
               if ( tmp_in_40 == 0x3 )
               {
                 tmp_in_39 = 10;
               }
               if ( ( tmp_in_40 == 2 || tmp_in_40 == 1 || tmp_in_40 == 0 ) )
               {
                 tmp_in_39 = 1;
               }
               Local_30_lo = OrderSend(Local_1_st,1,Local_28_do,Local_21_do,int(MaximumSlippage * tmp_in_39),tmp_do_38,tmp_do_37,tmp_st_36,tmp_in_33,tmp_do_32,tmp_in_31) ;
               if ( Local_30_lo <  0 )
               {
                 Local_31_in = GetLastError() ;
                 Print(TradeComment + " " + Local_1_st,": Failed to send a new initial sell order. Error:",lizong_11(Local_31_in)); 
                 if ( Local_31_in == 0x100F && MQLInfoInteger(MQL_TESTER) )
                 {
                   Local_20_bo = true ;
                 }
                 if ( Local_31_in == 149 )
                 {
                   Local_20_bo = true ;
                   Global_22_a_168_ko[Para_0_in].bo_6 = false;
                 }
                 if ( ( Local_31_in == 148 || Local_31_in == 0x8B || Local_31_in == 134 || Local_31_in == 133 || Local_31_in == 128 || Local_31_in == 64 || Local_31_in == 6 || Local_31_in == 4 || Local_31_in == 0x3 || Local_31_in == 2 || Local_31_in == 1 ) )
                 {
                   Local_20_bo = true ;
                   Global_22_a_168_ko[Para_0_in].bo_6 = false;
                   Print(TradeComment + " " + Local_1_st,": Stopped trying to send a new initial sell order due to fatal error!"); 
                 }
                 Sleep(5000); 
               }
               else
               {
                 Print(TradeComment + " " + Local_1_st,": Initial sell trade is opened, id: ",IntegerToString(Local_30_lo,0,32)); 
                 Local_20_bo = true ;
                 Global_22_a_168_ko[Para_0_in].bo_6 = false;
                 Global_22_a_168_ko[Para_0_in].bo_10 = true;
                 Global_22_a_168_ko[Para_0_in].bo_11 = true;
                 Global_22_a_168_ko[Para_0_in].da_28 = TimeCurrent();
               }
               Local_26_do = Local_26_do - Local_28_do ;
               Sleep(500); 
             }
           }
           else
           {
             Print(TradeComment + " " + Local_1_st,": Cannot open a new initial sell trade due to high spread: ",DoubleToString(Local_17_do,2)); 
             Sleep(5000); 
           }
         }
         if ( !(MQLInfoInteger(MQL_TESTER)) && !(MQLInfoInteger(MQL_OPTIMIZATION)) )
         {
           tmp_lo_41 = TerminalInfoInteger(8);
           if ( tmp_lo_41 != 0 )
           {
             tmp_lo_41 = AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
           }
           if ( tmp_lo_41 != 0 )
           {
             tmp_lo_41 = MQLInfoInteger(MQL_TRADE_ALLOWED);
           }
           if ( tmp_lo_41 == 0 )
           {
             Local_20_bo = true ;
           }
         }
         if ( Local_18_in >= Local_19_in )
         {
           Local_20_bo = true ;
         }
         Local_18_in ++;
         if ( IsStopped() )   break;
         
       }
       while(!(Local_20_bo));
       }
     }
   }
 }
 }
//lizong_33 <<==--------   --------
 double lizong_34( string Para_0_st,bool Para_1_bo)
 {
  //double    Local_1_do;
  double    Local_2_do;
  double    Local_3_do;
  double    Local_4_do;
  double    Local_5_do;
  double    Local_6_do;
  double    Local_7_do;
  double    Local_8_do;
  double    Local_9_do;
  double    Local_10_do;
  double    Local_11_do;
  double    Local_12_do;
  double    Local_13_do;
  double    Local_14_do;
  int       Local_15_in;
  int       Local_16_in;
  int       Local_17_in;
  int       Local_18_in;
  int       Local_19_in;
  int       Local_20_in;
  int       Local_21_in;
  int       Local_22_in;
  double    Local_23_do;
  int       Local_24_in;
  int       Local_25_in;
  double    Local_26_do;
//----- -----

 Local_2_do = SymbolInfoDouble(Para_0_st,36) ;
 Local_3_do = SymbolInfoDouble(Para_0_st,34) ;
 Local_4_do = SymbolInfoDouble(Para_0_st,35) ;
 Local_5_do = (SymbolInfoDouble(Para_0_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Para_0_st,SYMBOL_POINT):0.00001  ;
 if ( Local_2_do<0.0001 )
 {
   Local_2_do = 0.001 ;
 }
 Local_6_do = AccountInfoDouble(ACCOUNT_MARGIN_FREE) ;
 Local_7_do = AccountInfoDouble(ACCOUNT_BALANCE) ;
 Local_8_do = AccountInfoDouble(ACCOUNT_EQUITY) ;
 if ( FixedInitialDeposit && MQLInfoInteger(MQL_TESTER) && Global_38_do>Global_25_do )
 {
   Local_6_do = Global_38_do ;
   Local_7_do = Global_38_do ;
   Local_8_do = Global_38_do ;
 }
 Local_9_do = 10;//MarketInfo(Para_0_st,32) ;
 Local_10_do = (int)AccountInfoInteger(ACCOUNT_LEVERAGE) ;
 if ( Local_9_do<Global_25_do && Para_0_st != "??????" )
 {
   Sleep(100); 
   Local_9_do = 10;//MarketInfo(Para_0_st,32) ;
   if ( Local_9_do<Global_25_do )
   {
     Print(TradeComment + " " + Para_0_st,": Failed to get MODE_MARGINREQUIRED. Trying to get it again #2"); 
     Sleep(1000); 
     Local_9_do = 10;//MarketInfo(Para_0_st,32) ;
   }
   if ( Local_9_do<Global_25_do )
   {
     Print(TradeComment + " " + Para_0_st,": Failed to get MODE_MARGINREQUIRED. Trying to get it again #3"); 
     Sleep(2000); 
     Local_9_do = 10;//MarketInfo(Para_0_st,32) ;
   }
 }
 if ( Local_10_do<Global_25_do && Para_0_st != "??????" )
 {
   Sleep(100); 
   Local_10_do = (int)AccountInfoInteger(ACCOUNT_LEVERAGE) ;
   if ( Local_10_do<Global_25_do )
   {
     Print(TradeComment + " " + Para_0_st,": Failed to get ACCOUNT_LEVERAGE. Trying to get it again #2"); 
     Sleep(1000); 
     Local_10_do = (int)AccountInfoInteger(ACCOUNT_LEVERAGE) ;
   }
   if ( Local_10_do<Global_25_do )
   {
     Print(TradeComment + " " + Para_0_st,": Failed to get ACCOUNT_LEVERAGE. Trying to get it again #3"); 
     Sleep(2000); 
     Local_10_do = (int)AccountInfoInteger(ACCOUNT_LEVERAGE) ;
   }
 }
 Local_11_do = Local_3_do ;
 Local_12_do = 0.0 ;
 Local_13_do = 0.0 ;
 Local_14_do = 0.0 ;
 if ( AccountInfoDouble(ACCOUNT_CREDIT)>0.0 )
 {
   Local_14_do = AccountInfoDouble(ACCOUNT_CREDIT) ;
 }
 if ( LotSizingMethod == 0 )
 {
   Local_11_do = LotSizingValueFixed ;
   Local_13_do = 0.0 ;
 }
 if ( LotSizingMethod == 1 )
 {
   Local_13_do = LotSizingValueDynamic ;
 }
 if ( LotSizingMethod == 2 )
 {
   Local_13_do = -(LotSizingValueDynamic);
 }
 if ( LotSizingMethod == 6 )
 {
   Local_13_do = 0.0 ;
   if ( LotSizingDepositLoadPercent>Global_25_do && Local_9_do>Global_25_do && Local_10_do>Global_25_do )
   {
     Local_11_do = MathFloor(100.0 / Local_10_do * Local_6_do / Local_9_do * LotSizingDepositLoadPercent / 100.0 / Local_2_do) * Local_2_do ;
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Can\'t calculate lot size, because no data received: ACCOUNT_LEVERAGE / MODE_MARGINREQUIRED!"); 
   }
 }
 if ( LotSizingMethod == 7 )
 {
   Local_13_do = 0.0 ;
   Local_16_in = 0 ;
   Local_15_in = 1073217536 ;
   if ( Local_9_do>Global_25_do && Local_10_do>Global_25_do )
   {
     Local_11_do = MathFloor(100.0 / Local_10_do * Local_6_do / Local_9_do * 1.5 / 100.0 / Local_2_do) * Local_2_do ;
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Can\'t calculate lot size, because no data received: ACCOUNT_LEVERAGE / MODE_MARGINREQUIRED!"); 
   }
 }
 if ( LotSizingMethod == 3 )
 {
   Local_13_do = 0.0 ;
   Local_18_in = 0 ;
   Local_17_in = 1072693248 ;
   if ( Local_9_do>Global_25_do && Local_10_do>Global_25_do )
   {
     Local_11_do = MathFloor(100.0 / Local_10_do * Local_6_do / Local_9_do / 100.0 / Local_2_do) * Local_2_do ;
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Can\'t calculate lot size, because no data received: ACCOUNT_LEVERAGE / MODE_MARGINREQUIRED!"); 
   }
 }
 if ( LotSizingMethod == 4 )
 {
   Local_13_do = 0.0 ;
   Local_20_in = 0 ;
   Local_19_in = 1071644672 ;
   if ( Local_9_do>Global_25_do && Local_10_do>Global_25_do )
   {
     Local_11_do = MathFloor(100.0 / Local_10_do * Local_6_do / Local_9_do * 0.5 / 100.0 / Local_2_do) * Local_2_do ;
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Can\'t calculate lot size, because no data received: ACCOUNT_LEVERAGE / MODE_MARGINREQUIRED!"); 
   }
 }
 if ( LotSizingMethod == 5 )
 {
   Local_13_do = 0.0 ;
   Local_22_in = 0 ;
   Local_21_in = 1070596096 ;
   if ( Local_9_do>Global_25_do && Local_10_do>Global_25_do )
   {
     Local_11_do = MathFloor(100.0 / Local_10_do * Local_6_do / Local_9_do * 0.25 / 100.0 / Local_2_do) * Local_2_do ;
   }
   else
   {
     Print(TradeComment + " " + Para_0_st,": Can\'t calculate lot size, because no data received: ACCOUNT_LEVERAGE / MODE_MARGINREQUIRED!"); 
   }
 }
 if ( Local_13_do>Global_25_do )
 {
   Local_12_do = Local_7_do / Local_13_do ;
   Local_11_do = MathRound(Local_12_do * 0.01 / Local_2_do) * Local_2_do ;
 }
 if ( Local_13_do< -(Global_25_do) )
 {
   Local_12_do = Local_8_do / ( -(Local_13_do)) ;
   Local_11_do = MathRound(Local_12_do * 0.01 / Local_2_do) * Local_2_do ;
 }
 if ( Global_39_bo && !(AutoSplit) )
 {
   Local_23_do = 0.0 ;
   for (Local_24_in = 0 ; Local_24_in < ArraySize(Global_22_a_168_ko) ; Local_24_in ++)
   {
     if ( Global_22_a_168_ko[Local_24_in].do_22>Local_23_do )
     {
       Local_23_do = Global_22_a_168_ko[Local_24_in].do_22 ;
     }
   }
   if ( (Local_23_do + 1.0) * Local_11_do>Local_4_do * 2.0 && Local_23_do + 1.0>1.0 )
   {
     Local_11_do = Local_4_do * 2.0 / (Local_23_do + 1.0) ;
   }
 }
 if ( GridLevelToStart >  1 && Para_1_bo )
 {
   Local_11_do = Local_3_do ;
 }
 Local_25_in = (int)(Local_11_do / Local_2_do) ;
 Local_11_do = Local_25_in * Local_2_do ;
 if ( Local_11_do<Local_3_do )
 {
   Local_11_do = Local_3_do ;
 }
 if ( Local_11_do>MaximumLot )
 {
   Local_11_do = MaximumLot ;
 }
 Local_26_do = SymbolInfoDouble(Para_0_st,55) ;
 if ( Local_11_do>Local_26_do && Local_26_do>Global_25_do )
 {
   Local_11_do = Local_26_do ;
 }
 if ( Local_11_do>Local_4_do && !(AutoSplit) )
 {
   Local_11_do = Local_4_do ;
 }
 if ( Local_2_do<0.001001 && Local_2_do>0.000999 )
 {
   Local_11_do = NormalizeDouble(Local_11_do,3) ;
 }
 if ( Local_2_do<0.010001 && Local_2_do>0.009999 )
 {
   Local_11_do = NormalizeDouble(Local_11_do,2) ;
 }
 if ( Local_2_do<0.100001 && Local_2_do>0.099999 )
 {
   Local_11_do = NormalizeDouble(Local_11_do,1) ;
 }
 if ( Local_2_do<1.000001 && Local_2_do>0.999999 )
 {
   Local_11_do = NormalizeDouble(Local_11_do,0) ;
 }
 return(Local_11_do); 
 }
//lizong_34 <<==--------   --------
 void lizong_35()
 {
  int       Local_1_in;
  int       Local_2_in;
  int       Local_3_in;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;

 Local_1_in=MinuteMQL4() + HourMQL4() * 100;
 if ( !(MQLInfoInteger(MQL_TESTER)) )
 {
   for (tmp_in_1 = 0 ; tmp_in_1 < ArraySize(Global_22_a_168_ko) ; tmp_in_1=tmp_in_1 + 1)
   {
     iTime(Global_22_a_168_ko[tmp_in_1].st_1,Global_21_in,0); 
     iTime(Global_22_a_168_ko[tmp_in_1].st_1,OPO_TimeFrame,0); 
   }
 }
 if ( ( ( HideTP && !(SmartTP) ) || HideSL || ( MaximumDrawdown>Global_25_do && MaximumDrawdown<99.99 ) || MaximumDrawdownMoney>Global_25_do ) )
 {
   for (Local_2_in = 0 ; Local_2_in < ArraySize(Global_22_a_168_ko) ; Local_2_in ++)
   {
     lizong_26(Local_2_in); 
   }
 }
 if ( Global_26_in != Local_1_in )
 {
   if ( TimeCurrent() >  Global_27_lo + 60 && !(MQLInfoInteger(MQL_TESTER)) && !(MQLInfoInteger(MQL_TESTER)) && !(MQLInfoInteger(MQL_OPTIMIZATION)) )
   {
     Global_27_lo = TimeCurrent() ;
     for (tmp_in_2 = 0 ; tmp_in_2 < ArraySize(Global_22_a_168_ko) ; tmp_in_2=tmp_in_2 + 1)
     {
       iTime(Global_22_a_168_ko[tmp_in_2].st_1,Global_21_in,0); 
       iTime(Global_22_a_168_ko[tmp_in_2].st_1,OPO_TimeFrame,0); 
     }
     if ( ShowPanel )
     {
       lizong_49(false); 
     }
   }
   lizong_29(); 
   tmp_in_3 = TerminalInfoInteger(8);
   if ( tmp_in_3 != 0 )
   {
     tmp_in_3 =(int) AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   }
   if ( tmp_in_3 != 0 )
   {
     tmp_in_3 = MQLInfoInteger(MQL_TRADE_ALLOWED);
   }
   if ( ( tmp_in_3 != 0 || MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) ) )
   {
     for (Local_3_in = 0 ; Local_3_in < ArraySize(Global_22_a_168_ko) ; Local_3_in ++)
     {
       tmp_in_3 = Local_3_in;
       if ( !(MQLInfoInteger(MQL_TRADE_ALLOWED)) )   continue;
       tmp_in_4 = TerminalInfoInteger(8);
       if ( tmp_in_4 != 0 )
       {
         tmp_in_4 = (int)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
       }
       if ( tmp_in_4 != 0 )
       {
         tmp_in_4 = MQLInfoInteger(MQL_TRADE_ALLOWED);
       }
       if ( ( tmp_in_4 == 0 && !(MQLInfoInteger(MQL_TESTER)) && !(MQLInfoInteger(MQL_OPTIMIZATION)) ) )   continue;
       lizong_37(tmp_in_3); 
       lizong_25(tmp_in_3); 
       lizong_26(tmp_in_3); 
       
     }
   }
 }
 if ( MQLInfoInteger(MQL_VISUAL_MODE) )
 {
   if ( ObjectFind(0,"but_Buy") != -1 && ObjectGetInteger(0,"but_Buy",OBJPROP_STATE,0) != 0 )
   {
     lizong_48("but_Buy"); 
   }
   if ( ObjectFind(0,"but_Sell") != -1 && ObjectGetInteger(0,"but_Sell",OBJPROP_STATE,0) != 0 )
   {
     lizong_48("but_Sell"); 
   }
   if ( ObjectFind(0,"but_Pair") != -1 && ObjectGetInteger(0,"but_Pair",OBJPROP_STATE,0) != 0 )
   {
     lizong_48("but_Pair"); 
   }
   if ( ObjectFind(0,"but_Suspend") != -1 )
   {
     Global_37_bo=!(ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0));
     if ( ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0) == 0 )
     {
       ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,32768); 
       ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids allowed"); 
     }
     if ( !(Global_37_bo) )
     {
       ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,255); 
       ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids NOT allowed!"); 
       tmp_in_4 = 0;
         if(ArraySize(Global_22_a_168_ko) >  0){
       do
       {
         Global_22_a_168_ko[tmp_in_4].bo_5 = false;
         Global_22_a_168_ko[tmp_in_4].bo_6 = false;
       }
       while(tmp_in_4 + 1 < ArraySize(Global_22_a_168_ko));
       }
     }
     ChartRedraw(0); 
   }
 }
 Global_26_in = Local_1_in ;
 }
//lizong_35 <<==--------   --------
 double lizong_36( string Para_0_st,double Para_1_do,int Para_2_in,double Para_3_do)
 {
  //double    Local_1_do;
  double    Local_2_do;
  double    Local_3_do;
  double    Local_4_do;
  double    Local_5_do;
  double    Local_6_do;
  double    Local_7_do;
  double    Local_8_do;
  int       Local_9_in;
  double    Local_10_do;
//----- -----
 int        tmp_in_1;
 double     tmp_do_2;
 int        tmp_in_3;
 int        tmp_in_4;
 double     tmp_do_5;
 int        tmp_in_6;
 int        tmp_in_7;
 double     tmp_do_8;
 int        tmp_in_9;
 int        tmp_in_10;
 double     tmp_do_11;
 int        tmp_in_12;
 int        tmp_in_13;
 double     tmp_do_14;
 int        tmp_in_15;

 Local_2_do = SymbolInfoDouble(Para_0_st,36) ;
 Local_3_do = SymbolInfoDouble(Para_0_st,34) ;
 Local_4_do = SymbolInfoDouble(Para_0_st,35) ;
 if ( Local_2_do<0.0001 )
 {
   Local_2_do = 0.001 ;
 }
 Local_5_do = 1.0 ;
 Local_6_do = Local_3_do ;
 Local_7_do = 0.0 ;
 if ( GridLevelToStart >  1 && Para_3_do<0.0099 )
 {
   Local_7_do = lizong_34(Para_0_st,false) ;
 }
 if ( GridLevelToStart >  1 && Para_3_do>0.0099 )
 {
   Local_7_do = Para_3_do ;
 }
 if ( GridLevelToStart >  1 )
 {
   if ( Para_2_in <  GridLevelToStart - 1 )
   {
     tmp_in_1 = Para_2_in;
     tmp_do_2 = 1.0;
     for (tmp_in_3 = 1 ; tmp_in_3 <= tmp_in_1 ; tmp_in_3=tmp_in_3 + 1)
     {
       if ( tmp_in_3 == 1 )
       {
         tmp_do_2 = TradeMultiplier_2nd;
       }
       if ( tmp_in_3 >= 2 && tmp_in_3 <= 4 )
       {
         tmp_do_2 = tmp_do_2 * TradeMultiplier_3rd;
       }
       if ( tmp_in_3 >= 5 )
       {
         tmp_do_2 = tmp_do_2 * TradeMultiplier_6th;
       }
     }
     Local_5_do = tmp_do_2 ;
     Local_6_do = Para_1_do * Local_5_do ;
   }
   else
   {
     if ( KeepOriginalProfitLotSize && !(AutoSplit) )
     {
       tmp_in_4 = Para_2_in;
       tmp_do_5 = 1.0;
       for (tmp_in_6 = 1 ; tmp_in_6 <= tmp_in_4 ; tmp_in_6=tmp_in_6 + 1)
       {
         if ( tmp_in_6 == 1 )
         {
           tmp_do_5 = TradeMultiplier_2nd;
         }
         if ( tmp_in_6 >= 2 && tmp_in_6 <= 4 )
         {
           tmp_do_5 = tmp_do_5 * TradeMultiplier_3rd;
         }
         if ( tmp_in_6 >= 5 )
         {
           tmp_do_5 = tmp_do_5 * TradeMultiplier_6th;
         }
       }
       Local_5_do = tmp_do_5 ;
       tmp_in_7 = GridLevelToStart - 1;
       tmp_do_8 = 1.0;
       for (tmp_in_9 = 1 ; tmp_in_9 <= tmp_in_7 ; tmp_in_9=tmp_in_9 + 1)
       {
         if ( tmp_in_9 == 1 )
         {
           tmp_do_8 = TradeMultiplier_2nd;
         }
         if ( tmp_in_9 >= 2 && tmp_in_9 <= 4 )
         {
           tmp_do_8 = tmp_do_8 * TradeMultiplier_3rd;
         }
         if ( tmp_in_9 >= 5 )
         {
           tmp_do_8 = tmp_do_8 * TradeMultiplier_6th;
         }
       }
       Local_8_do = tmp_do_8 ;
       if ( Para_2_in != GridLevelToStart - 1 )
       {
         Local_7_do = Local_7_do / Local_8_do ;
       }
     }
     else
     {
       tmp_in_10 = Para_2_in - (GridLevelToStart - 1);
       tmp_do_11 = 1.0;
       for (tmp_in_12 = 1 ; tmp_in_12 <= tmp_in_10 ; tmp_in_12=tmp_in_12 + 1)
       {
         if ( tmp_in_12 == 1 )
         {
           tmp_do_11 = TradeMultiplier_2nd;
         }
         if ( tmp_in_12 >= 2 && tmp_in_12 <= 4 )
         {
           tmp_do_11 = tmp_do_11 * TradeMultiplier_3rd;
         }
         if ( tmp_in_12 >= 5 )
         {
           tmp_do_11 = tmp_do_11 * TradeMultiplier_6th;
         }
       }
       Local_5_do = tmp_do_11 ;
     }
     Local_6_do = Local_7_do * Local_5_do ;
   }
 }
 else
 {
   tmp_in_13 = Para_2_in;
   tmp_do_14 = 1.0;
   for (tmp_in_15 = 1 ; tmp_in_15 <= tmp_in_13 ; tmp_in_15=tmp_in_15 + 1)
   {
     if ( tmp_in_15 == 1 )
     {
       tmp_do_14 = TradeMultiplier_2nd;
     }
     if ( tmp_in_15 >= 2 && tmp_in_15 <= 4 )
     {
       tmp_do_14 = tmp_do_14 * TradeMultiplier_3rd;
     }
     if ( tmp_in_15 >= 5 )
     {
       tmp_do_14 = tmp_do_14 * TradeMultiplier_6th;
     }
   }
   Local_5_do = tmp_do_14 ;
   Local_6_do = Para_1_do * Local_5_do ;
 }
 Local_9_in = (int)(Local_6_do / Local_2_do) ;
 Local_6_do = Local_9_in * Local_2_do ;
 if ( Local_6_do<Local_3_do )
 {
   Local_6_do = Local_3_do ;
 }
 if ( Local_6_do>Local_4_do && !(AutoSplit) )
 {
   Local_6_do = Local_4_do ;
 }
 Local_10_do = SymbolInfoDouble(Para_0_st,55) ;
 if ( Local_6_do>Local_10_do && Local_10_do>Global_25_do )
 {
   Local_6_do = Local_10_do ;
 }
 if ( Local_2_do<0.001001 && Local_2_do>0.000999 )
 {
   Local_6_do = NormalizeDouble(Local_6_do,3) ;
 }
 if ( Local_2_do<0.010001 && Local_2_do>0.009999 )
 {
   Local_6_do = NormalizeDouble(Local_6_do,2) ;
 }
 if ( Local_2_do<0.100001 && Local_2_do>0.099999 )
 {
   Local_6_do = NormalizeDouble(Local_6_do,1) ;
 }
 if ( Local_2_do<1.000001 && Local_2_do>0.999999 )
 {
   Local_6_do = NormalizeDouble(Local_6_do,0) ;
 }
 return(Local_6_do); 
 }
//lizong_36 <<==--------   --------
 void lizong_37( int Para_0_in)
 {
  string    Local_1_st;
  double    Local_2_do;
  double    Local_3_do;
  double    Local_4_do;
  int       Local_5_in;
  double    Local_6_do;
  double    Local_7_do;
  double    Local_8_do;
  int       Local_9_in;
  double    Local_10_do;
  int       Local_11_in;
  double    Local_12_do;
  double    Local_13_do;
  double    Local_14_do;
  int       Local_15_in;
  double    Local_16_do;
  double    Local_17_do;
  double    Local_18_do;
  int       Local_19_in;
  double    Local_20_do;
  int       Local_21_in;
  double    Local_22_do;
//----- -----
 int        tmp_in_1;
 double     tmp_do_2;
 double     tmp_do_3;
 double     tmp_do_4;
 int        tmp_in_5;
 int        tmp_in_6;
 double     tmp_do_7;
 double     tmp_do_8;
 double     tmp_do_9;
 double     tmp_do_10;
 int        tmp_in_11;
 int        tmp_in_12;
 int        tmp_in_13;
 int        tmp_in_14;
 int        tmp_in_15;
 int        tmp_in_16;
 int        tmp_in_17;
 int        tmp_in_18;
 int        tmp_in_19;
 int        tmp_in_20;
 int        tmp_in_21;
 int        tmp_in_22;
 int        tmp_in_23;
 int        tmp_in_24;
 int        tmp_in_25;
 double     tmp_do_26;
 double     tmp_do_27;
 double     tmp_do_28;
 int        tmp_in_29;
 int        tmp_in_30;
 double     tmp_do_31;
 double     tmp_do_32;
 double     tmp_do_33;
 double     tmp_do_34;
 int        tmp_in_35;
 int        tmp_in_36;
 int        tmp_in_37;
 int        tmp_in_38;
 int        tmp_in_39;
 int        tmp_in_40;
 int        tmp_in_41;
 int        tmp_in_42;
 int        tmp_in_43;
 int        tmp_in_44;
 int        tmp_in_45;
 int        tmp_in_46;
 int        tmp_in_47;
 int        tmp_in_48;
 int        tmp_in_49;

 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 ChartRedraw(0); 
 Local_2_do = SymbolInfoInteger(Local_1_st,SYMBOL_SPREAD) ;
 if ( MaximumTrades - 1 <= 0 || !(TradeMultiplier_3rd>0.0) || !(TradeDistance>Global_25_do) )   return;
 
 if ( lizong_21(Local_1_st,0,1) )
 {
   Local_3_do = lizong_24(Local_1_st,0,1,false) ;
   Local_4_do = 0.0 ;
   Local_5_in = 1 ;
   tmp_in_1=MaximumTrades - 1;
   for ( ; Local_5_in <= MaximumTrades - 1 ; Local_5_in ++)
   {
     tmp_in_1=TradeDistance * Local_5_in;
     Local_4_do = tmp_in_1 ;
     tmp_do_2 = Global_22_a_168_ko[Para_0_in].do_9 - lizong_22(Local_1_st,0,1);
     if ( SymbolInfoDouble(Local_1_st,SYMBOL_POINT)>Global_25_do )
     {
       tmp_do_3 = SymbolInfoDouble(Local_1_st,SYMBOL_POINT);
     }
     else
     {
       tmp_do_3 = 0.00001;
     }
     tmp_do_4 = ( -(Local_4_do)) * tmp_do_3;
     tmp_in_5 = 10;
     tmp_in_6 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
     if ( tmp_in_6 == 5 )
     {
       tmp_in_5 = 10;
     }
     if ( tmp_in_6 == 4 )
     {
       tmp_in_5 = 1;
     }
     if ( tmp_in_6 == 0x3 )
     {
       tmp_in_5 = 10;
     }
     if ( ( tmp_in_6 == 2 || tmp_in_6 == 1 || tmp_in_6 == 0 ) )
     {
       tmp_in_5 = 1;
     }
     if ( !(tmp_do_2<tmp_do_4 * tmp_in_5 * Global_22_a_168_ko[Para_0_in].do_12) || lizong_21(Local_1_st,Local_5_in,1) || Global_22_a_168_ko[Para_0_in].bo_10 != 0x0 )   continue;
     Local_6_do = 0.0 ;
     if ( GridLevelToStart >  1 )
     {
       Local_6_do = lizong_24(Local_1_st,GridLevelToStart - 1,1,false) ;
     }
     Local_7_do = lizong_36(Local_1_st,Local_3_do,Local_5_in,Local_6_do) ;
     if ( Local_7_do>0.0 )
     {
       if ( AutoSplit )
       {
         tmp_do_7 = SymbolInfoDouble(Local_1_st,35);
         tmp_do_8 = SymbolInfoDouble(Local_1_st,36);
         if ( tmp_do_7>SymbolInfoDouble(Local_1_st,55) && SymbolInfoDouble(Local_1_st,55)>Global_25_do )
         {
           tmp_do_7 = SymbolInfoDouble(Local_1_st,55);
         }
         if ( tmp_do_8<0.001001 && tmp_do_8>0.000999 )
         {
           tmp_do_7 = NormalizeDouble(tmp_do_7,3);
         }
         if ( tmp_do_8<0.010001 && tmp_do_8>0.009999 )
         {
           tmp_do_7 = NormalizeDouble(tmp_do_7,2);
         }
         if ( tmp_do_8<0.100001 && tmp_do_8>0.099999 )
         {
           tmp_do_7 = NormalizeDouble(tmp_do_7,1);
         }
         if ( tmp_do_8<1.000001 && tmp_do_8>0.999999 )
         {
           tmp_do_7 = NormalizeDouble(tmp_do_7,0);
         }
         Local_8_do = tmp_do_7 ;
         if ( Local_7_do>Local_8_do )
         {
           Local_9_in = (int)MathCeil(Local_7_do / Local_8_do) ;
           Local_10_do = Local_7_do ;
           for (Local_11_in = 0 ; Local_11_in < Local_9_in ; Local_11_in ++)
           {
             Local_12_do = MathMin(Local_8_do,Local_10_do) ;
             tmp_do_9 = Local_12_do;
             tmp_do_10 = SymbolInfoDouble(Local_1_st,36);
             if ( tmp_do_10<0.001001 && tmp_do_10>0.000999 )
             {
               tmp_do_9 = NormalizeDouble(tmp_do_9,3);
             }
             if ( tmp_do_10<0.010001 && tmp_do_10>0.009999 )
             {
               tmp_do_9 = NormalizeDouble(tmp_do_9,2);
             }
             if ( tmp_do_10<0.100001 && tmp_do_10>0.099999 )
             {
               tmp_do_9 = NormalizeDouble(tmp_do_9,1);
             }
             if ( tmp_do_10<1.000001 && tmp_do_10>0.999999 )
             {
               tmp_do_9 = NormalizeDouble(tmp_do_9,0);
             }
             Local_12_do = tmp_do_9 ;
             tmp_in_11 = Local_5_in;
             if ( Local_5_in <  0 )
             {
               tmp_in_12 = -1;
             }
             else
             {
               tmp_in_13 = Global_24_in + UID;
               tmp_in_14 = StringLen(IntegerToString(tmp_in_13,0,32)) ;
               tmp_in_15 = 0;
               if ( 1 == 1 )
               {
                 tmp_in_15 = 1;
               }
               if ( 1 == -1 )
               {
                 tmp_in_15 = 2;
               }
               tmp_in_12 = int(MathPow(10.0,tmp_in_14 + 2)) * tmp_in_15 + tmp_in_13 * 100 + Local_5_in;
             }
             lizong_42(Para_0_in,Local_12_do,tmp_in_12,tmp_in_11); 
             Local_10_do = Local_10_do - Local_12_do ;
             Sleep(500); 
           }
         }
         else
         {
           tmp_in_16 = Local_5_in;
           if ( Local_5_in <  0 )
           {
             tmp_in_17 = -1;
           }
           else
           {
             tmp_in_18 = Global_24_in + UID;
             tmp_in_19 = StringLen(IntegerToString(tmp_in_18,0,32)) ;
             tmp_in_20 = 0;
             if ( 1 == 1 )
             {
               tmp_in_20 = 1;
             }
             if ( 1 == -1 )
             {
               tmp_in_20 = 2;
             }
             tmp_in_17 = int(MathPow(10.0,tmp_in_19 + 2)) * tmp_in_20 + tmp_in_18 * 100 + Local_5_in;
           }
           lizong_42(Para_0_in,Local_7_do,tmp_in_17,tmp_in_16); 
         }
       }
       else
       {
         tmp_in_21 = Local_5_in;
         if ( Local_5_in <  0 )
         {
           tmp_in_22 = -1;
         }
         else
         {
           tmp_in_23 = Global_24_in + UID;
           tmp_in_24 = StringLen(IntegerToString(tmp_in_23,0,32)) ;
           tmp_in_25 = 0;
           if ( 1 == 1 )
           {
             tmp_in_25 = 1;
           }
           if ( 1 == -1 )
           {
             tmp_in_25 = 2;
           }
           tmp_in_22 = int(MathPow(10.0,tmp_in_24 + 2)) * tmp_in_25 + tmp_in_23 * 100 + Local_5_in;
         }
         lizong_42(Para_0_in,Local_7_do,tmp_in_22,tmp_in_21); 
       }
       Sleep(5000); 
     }
     if ( !(lizong_21(Local_1_st,Local_5_in,1)) )   continue;
     Global_22_a_168_ko[Para_0_in].bo_10 = true;
     Global_22_a_168_ko[Para_0_in].bo_11 = true;
     
   }
 }
 if ( !(lizong_21(Local_1_st,0,-1)) )   return;
 Local_13_do = lizong_24(Local_1_st,0,-1,false) ;
 Local_14_do = 0.0 ;
 for (Local_15_in = 1 ; Local_15_in <= MaximumTrades - 1 ; Local_15_in ++)
 {
   Local_14_do = TradeDistance * Local_15_in ;
   tmp_do_26 = Global_22_a_168_ko[Para_0_in].do_9 - lizong_22(Local_1_st,0,-1);
   if ( SymbolInfoDouble(Local_1_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_27 = SymbolInfoDouble(Local_1_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_27 = 0.00001;
   }
   tmp_do_28 = Local_14_do * tmp_do_27;
   tmp_in_29 = 10;
   tmp_in_30 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
   if ( tmp_in_30 == 5 )
   {
     tmp_in_29 = 10;
   }
   if ( tmp_in_30 == 4 )
   {
     tmp_in_29 = 1;
   }
   if ( tmp_in_30 == 0x3 )
   {
     tmp_in_29 = 10;
   }
   if ( ( tmp_in_30 == 2 || tmp_in_30 == 1 || tmp_in_30 == 0 ) )
   {
     tmp_in_29 = 1;
   }
   if ( !(tmp_do_26>tmp_do_28 * tmp_in_29 * Global_22_a_168_ko[Para_0_in].do_12) || lizong_21(Local_1_st,Local_15_in,-1) || Global_22_a_168_ko[Para_0_in].bo_10 != 0x0 )   continue;
   Local_16_do = 0.0 ;
   if ( GridLevelToStart >  1 )
   {
     Local_16_do = lizong_24(Local_1_st,GridLevelToStart - 1,-1,false) ;
   }
   Local_17_do = lizong_36(Local_1_st,Local_13_do,Local_15_in,Local_16_do) ;
   if ( Local_17_do>0.0 )
   {
     if ( AutoSplit )
     {
       tmp_do_31 = SymbolInfoDouble(Local_1_st,35);
       tmp_do_32 = SymbolInfoDouble(Local_1_st,36);
       if ( tmp_do_31>SymbolInfoDouble(Local_1_st,55) && SymbolInfoDouble(Local_1_st,55)>Global_25_do )
       {
         tmp_do_31 = SymbolInfoDouble(Local_1_st,55);
       }
       if ( tmp_do_32<0.001001 && tmp_do_32>0.000999 )
       {
         tmp_do_31 = NormalizeDouble(tmp_do_31,3);
       }
       if ( tmp_do_32<0.010001 && tmp_do_32>0.009999 )
       {
         tmp_do_31 = NormalizeDouble(tmp_do_31,2);
       }
       if ( tmp_do_32<0.100001 && tmp_do_32>0.099999 )
       {
         tmp_do_31 = NormalizeDouble(tmp_do_31,1);
       }
       if ( tmp_do_32<1.000001 && tmp_do_32>0.999999 )
       {
         tmp_do_31 = NormalizeDouble(tmp_do_31,0);
       }
       Local_18_do = tmp_do_31 ;
       if ( Local_17_do>Local_18_do )
       {
         Local_19_in = (int)MathCeil(Local_17_do / Local_18_do) ;
         Local_20_do = Local_17_do ;
         for (Local_21_in = 0 ; Local_21_in < Local_19_in ; Local_21_in ++)
         {
           Local_22_do = MathMin(Local_18_do,Local_20_do) ;
           tmp_do_33 = Local_22_do;
           tmp_do_34 = SymbolInfoDouble(Local_1_st,36);
           if ( tmp_do_34<0.001001 && tmp_do_34>0.000999 )
           {
             tmp_do_33 = NormalizeDouble(tmp_do_33,3);
           }
           if ( tmp_do_34<0.010001 && tmp_do_34>0.009999 )
           {
             tmp_do_33 = NormalizeDouble(tmp_do_33,2);
           }
           if ( tmp_do_34<0.100001 && tmp_do_34>0.099999 )
           {
             tmp_do_33 = NormalizeDouble(tmp_do_33,1);
           }
           if ( tmp_do_34<1.000001 && tmp_do_34>0.999999 )
           {
             tmp_do_33 = NormalizeDouble(tmp_do_33,0);
           }
           Local_22_do = tmp_do_33 ;
           tmp_in_35 = Local_15_in;
           if ( Local_15_in <  0 )
           {
             tmp_in_36 = -1;
           }
           else
           {
             tmp_in_37 = Global_24_in + UID;
             tmp_in_38 = StringLen(IntegerToString(tmp_in_37,0,32)) ;
             tmp_in_39 = 0;
             if ( -1 == 1 )
             {
               tmp_in_39 = 1;
             }
             if ( -1 == -1 )
             {
               tmp_in_39 = 2;
             }
             tmp_in_36 = int(MathPow(10.0,tmp_in_38 + 2)) * tmp_in_39 + tmp_in_37 * 100 + Local_15_in;
           }
           lizong_43(Para_0_in,Local_22_do,tmp_in_36,tmp_in_35); 
           Local_20_do = Local_20_do - Local_22_do ;
           Sleep(500); 
         }
       }
       else
       {
         tmp_in_40 = Local_15_in;
         if ( Local_15_in <  0 )
         {
           tmp_in_41 = -1;
         }
         else
         {
           tmp_in_42 = Global_24_in + UID;
           tmp_in_43 = StringLen(IntegerToString(tmp_in_42,0,32)) ;
           tmp_in_44 = 0;
           if ( -1 == 1 )
           {
             tmp_in_44 = 1;
           }
           if ( -1 == -1 )
           {
             tmp_in_44 = 2;
           }
           tmp_in_41 = int(MathPow(10.0,tmp_in_43 + 2)) * tmp_in_44 + tmp_in_42 * 100 + Local_15_in;
         }
         lizong_43(Para_0_in,Local_17_do,tmp_in_41,tmp_in_40); 
       }
     }
     else
     {
       tmp_in_45 = Local_15_in;
       if ( Local_15_in <  0 )
       {
         tmp_in_46 = -1;
       }
       else
       {
         tmp_in_47 = Global_24_in + UID;
         tmp_in_48 = StringLen(IntegerToString(tmp_in_47,0,32)) ;
         tmp_in_49 = 0;
         if ( -1 == 1 )
         {
           tmp_in_49 = 1;
         }
         if ( -1 == -1 )
         {
           tmp_in_49 = 2;
         }
         tmp_in_46 = int(MathPow(10.0,tmp_in_48 + 2)) * tmp_in_49 + tmp_in_47 * 100 + Local_15_in;
       }
       lizong_43(Para_0_in,Local_17_do,tmp_in_46,tmp_in_45); 
     }
     Sleep(5000); 
   }
   if ( !(lizong_21(Local_1_st,Local_15_in,-1)) )   continue;
   Global_22_a_168_ko[Para_0_in].bo_10 = true;
   Global_22_a_168_ko[Para_0_in].bo_11 = true;
   
 }
 }
//lizong_37 <<==--------   --------
 void lizong_38( int Para_0_in,int Para_1_lo,int Para_2_in,string Para_3_st,double Para_4_do,
                 datetime Para_6_da,double Para_6_in,double Para_7_in,double Para_8_do,double Para_11_do,double Para_10_in)
 {
  double    Local_1_do = 0.0;
  double    Local_2_do = 0.0;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  double    Local_6_do;
  double    Local_7_do;
  double    Local_8_do;
  double    Local_9_do;
  double    Local_10_do;
  int       Local_11_in;
  double    Local_12_do;
  int       Local_13_in;
  double    Local_14_do;
  int       Local_15_in;
  double    Local_16_do;
  double    Local_17_do;
  double    Local_18_do;
  bool      Local_19_bo;
  int       Local_20_in;
//----- -----
 double     tmp_do_1;
 double     tmp_do_2;
 double     tmp_do_3;
 double     tmp_do_4;
 double     tmp_do_5;

 if ( ( DoNotAdjustTPUnlessNewGrid && TimeCurrent() - Global_22_a_168_ko[Para_0_in].da_27 > 300 ) )   return;
 Local_3_in=Global_24_in + UID;
 Local_4_in=StringLen(IntegerToString(Local_3_in,0,32)); 
 Local_5_in=Local_3_in + int(MathPow(10.0,Local_4_in));
 Local_6_do=(int)(Para_6_da - Local_5_in * 100);
 Local_7_do = Para_11_do ;
 Local_8_do = Para_11_do ;
 if ( MaximumTrades - 1 >  0 && TradeMultiplier_3rd>0.0 && TradeDistance>Global_25_do )
 {
   if ( lizong_21(Para_3_st,0,1) )
   {
     Local_7_do = NormalizeDouble(lizong_22(Para_3_st,0,1),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
     Global_22_a_168_ko[Para_0_in].do_23 = Local_7_do;
   }
   else
   {
     if ( Global_22_a_168_ko[Para_0_in].do_23>Global_25_do )
     {
       Local_7_do = Global_22_a_168_ko[Para_0_in].do_23 ;
     }
   }
   Local_8_do = NormalizeDouble(lizong_23(Para_3_st,1,true,false),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   if ( KeepOriginalProfitLotSize && GridLevelToStart >  1 && !(AutoSplit) )
   {
     Local_8_do = NormalizeDouble(lizong_23(Para_3_st,1,true,true),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   }
 }
 Local_2_do = lizong_40(Para_0_in,Local_8_do,1,false,Para_6_in) ;
 Local_1_do = lizong_41(Para_0_in,Local_7_do,1);//,false ,Para_7_in,Para_10_in) ;
 if ( WeightedTP )
 {
   Local_9_do = Local_2_do - Local_8_do ;
   if ( lizong_21(Para_3_st,0,1) )
   {
     Local_10_do = lizong_24(Para_3_st,-1,1,false) ;
     if ( KeepOriginalProfitLotSize && GridLevelToStart >  1 && !(AutoSplit) )
     {
       Local_10_do = lizong_24(Para_3_st,-1,1,true) ;
     }
     if ( Local_10_do>Global_25_do )
     {
       Local_11_in = 0 ;
       if ( GridLevelToStart >  1 && !(KeepOriginalProfitLotSize) && lizong_24(Para_3_st,GridLevelToStart - 1,1,false)>Global_25_do )
       {
         Local_11_in=GridLevelToStart - 1;
       }
       Local_12_do = lizong_24(Para_3_st,Local_11_in,1,false) ;
       if ( KeepOriginalProfitLotSize && GridLevelToStart >  1 && !(AutoSplit) )
       {
         Local_12_do = lizong_24(Para_3_st,0,1,true) ;
       }
       Local_12_do = Local_12_do / Local_10_do ;
       Local_9_do = Local_12_do * Local_9_do ;
       Local_2_do = NormalizeDouble(Local_9_do + Local_8_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
     }
   }
 }
 if ( SmartTP && Global_22_a_168_ko[Para_0_in].do_13>Global_25_do && lizong_21(Para_3_st,0,1) && GridLevelToStart == 1 )
 {
   Local_13_in = 2 ;
   Local_14_do = InitialTP / 100.0 ;
   if ( !(lizong_21(Para_3_st,2,1)) )
   {
     Local_8_do = Para_11_do ;
     Local_2_do = Local_14_do * (Local_6_do - 2) * Global_22_a_168_ko[Para_0_in].do_13 + Para_11_do ;
   }
   else
   {
     if ( !(lizong_21(Para_3_st,Local_13_in + 3,1)) )
     {
       Local_2_do = Local_14_do * Global_22_a_168_ko[Para_0_in].do_13 + Local_8_do ;
     }
     else
     {
       Local_2_do = Local_14_do / 2.0 * Global_22_a_168_ko[Para_0_in].do_13 + Local_8_do ;
     }
   }
   Local_2_do = NormalizeDouble(Local_2_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
 }
 if ( lizong_21(Para_3_st,0,1) )
 {
   Global_22_a_168_ko[Para_0_in].do_25 = Local_2_do;
 }
 for (Local_15_in = 0 ; Local_15_in < 5 ; Local_15_in ++)
 {
   ChartRedraw(0); 
   Local_16_do = SymbolInfoInteger(Para_3_st,SYMBOL_SPREAD) ;
   tmp_do_1 = SymbolInfoInteger(Para_3_st,SYMBOL_TRADE_STOPS_LEVEL);
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_2 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_2 = 0.00001;
   }
   Local_17_do = tmp_do_1 * tmp_do_2 ;
   tmp_do_1 = SymbolInfoInteger(Para_3_st,SYMBOL_TRADE_FREEZE_LEVEL);
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_3 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_3 = 0.00001;
   }
   Local_18_do = tmp_do_1 * tmp_do_3 ;
   if ( Local_1_do>Global_25_do )
   {
     if ( Local_17_do>Global_25_do && Para_7_in<Global_25_do )
     {
       Local_1_do = MathMin(SymbolInfoDouble(Para_3_st,SYMBOL_BID) - Local_17_do,Local_1_do) ;
     }
     if ( Local_17_do<Global_25_do )
     {
       Local_1_do = MathMin(SymbolInfoDouble(Para_3_st,SYMBOL_BID),Local_1_do) ;
     }
   }
   if ( Local_2_do>Global_25_do )
   {
     if ( Local_17_do>Global_25_do && Para_6_in<Global_25_do )
     {
       Local_2_do = MathMax(SymbolInfoDouble(Para_3_st,SYMBOL_BID) + Local_17_do,Local_2_do) ;
     }
     if ( Local_17_do<Global_25_do )
     {
       Local_2_do = MathMax(SymbolInfoDouble(Para_3_st,SYMBOL_BID),Local_2_do) ;
     }
   }
   if ( HideSL )
   {
     Local_1_do = 0.0 ;
   }
   if ( ( HideTP || Use_OPO_Method ) && !(SmartTP) )
   {
     Local_2_do = 0.0 ;
   }
   Local_19_bo = true ;
   if ( Local_2_do<Global_25_do && !(HideTP) && !(Use_OPO_Method) )
   {
     Local_19_bo = false ;
   }
   if ( Local_2_do<Global_25_do && SmartTP )
   {
     Local_19_bo = false ;
   }
   if ( Local_1_do<Global_25_do && !(HideSL) )
   {
     Local_19_bo = false ;
   }
   if ( ( !(MathAbs(Para_6_in - Local_2_do)>=((SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Para_3_st,SYMBOL_POINT):0.00001 ) * 2.0) && !(MathAbs(Para_7_in - Local_1_do)>=((SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Para_3_st,SYMBOL_POINT):0.00001 ) * 2.0) ) || !(Local_19_bo) )   continue;
   
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_4 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_4 = 0.00001;
   }
   if ( MathAbs(Para_6_in - Local_2_do)<=tmp_do_4 )
   {
     Local_2_do = Para_6_in ;
   }
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_5 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_5 = 0.00001;
   }
   if ( MathAbs(Para_7_in - Local_1_do)<=tmp_do_5 )
   {
     Local_1_do = Para_7_in ;
   }
   if ( HideSL )
   {
     Local_1_do = 0.0 ;
   }
   if ( ( HideTP || Use_OPO_Method ) && !(SmartTP) )
   {
     Local_2_do = 0.0 ;
   }
   Local_1_do = NormalizeDouble(Local_1_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   Local_2_do = NormalizeDouble(Local_2_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   if ( lizong_30(Para_3_st,3,0,Para_11_do,Para_7_in,Para_6_in,Para_11_do,Local_1_do,Local_2_do) )
   {
     Print(TradeComment + " " + Para_3_st,": Modifying buy trade: " + IntegerToString(Para_1_lo,0,32) + ", attempt N",IntegerToString(Local_15_in + 1,0,32)); 
     if ( !(OrderModify(Para_1_lo,Para_11_do,Local_1_do,Local_2_do,0,16711680)) )
     {
       Local_20_in = GetLastError() ;
       Print(TradeComment + " " + Para_3_st,": Failed to modify buy trade: " + IntegerToString(Para_1_lo,0,32) + ". Error=",lizong_11(Local_20_in)); 
       Sleep(5000); 
       if ( ( Local_20_in != 132 && Local_20_in != 10018 && Local_20_in != 4756 ) )   continue;
       Sleep(15000); 
        continue;
     }
     Print(TradeComment + " " + Para_3_st,": Buy trade: " + IntegerToString(Para_1_lo,0,32) + " successfully modified"); 
     return;
   }
   Sleep(5000); 
   
 }
 }
//lizong_38 <<==--------   --------
 void lizong_39( int Para_0_in,int Para_1_lo,int Para_2_in,string Para_3_st,double Para_4_do,datetime Para_6_da,
                 double Para_6_in,double Para_7_in,double Para_8_do,double Para_11_do,double Para_10_in)
 {
  double    Local_1_do = 0.0;
  double    Local_2_do = 0.0;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  double    Local_6_do;
  double    Local_7_do;
  double    Local_8_do;
  double    Local_9_do;
  double    Local_10_do;
  int       Local_11_in;
  double    Local_12_do;
  int       Local_13_in;
  double    Local_14_do;
  int       Local_15_in;
  double    Local_16_do;
  double    Local_17_do;
  double    Local_18_do;
  bool      Local_19_bo;
  int       Local_20_in;
//----- -----
 double     tmp_do_1;
 double     tmp_do_2;
 double     tmp_do_3;
 double     tmp_do_4;
 double     tmp_do_5;

 if ( ( DoNotAdjustTPUnlessNewGrid && TimeCurrent() - Global_22_a_168_ko[Para_0_in].da_28 > 300 ) )   return;
 Local_3_in=Global_24_in + UID;
 Local_4_in=StringLen(IntegerToString(Local_3_in,0,32)); 
 Local_5_in=Local_3_in + int(MathPow(10.0,Local_4_in)) * 2;
 Local_6_do=(int)(Para_6_da - Local_5_in * 100);
 Local_7_do = Para_11_do ;
 Local_8_do = Para_11_do ;
 if ( MaximumTrades - 1 >  0 && TradeMultiplier_3rd>0.0 && TradeDistance>Global_25_do )
 {
   if ( lizong_21(Para_3_st,0,-1) )
   {
     Local_7_do = NormalizeDouble(lizong_22(Para_3_st,0,-1),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
     Global_22_a_168_ko[Para_0_in].do_24 = Local_7_do;
   }
   else
   {
     if ( Global_22_a_168_ko[Para_0_in].do_24>Global_25_do )
     {
       Local_7_do = Global_22_a_168_ko[Para_0_in].do_24 ;
     }
   }
   Local_8_do = NormalizeDouble(lizong_23(Para_3_st,-1,true,false),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   if ( KeepOriginalProfitLotSize && GridLevelToStart >  1 && !(AutoSplit) )
   {
     Local_8_do = NormalizeDouble(lizong_23(Para_3_st,-1,true,true),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   }
 }
 Local_2_do = lizong_40(Para_0_in,Local_8_do,-1,false,Para_6_in) ;
 Local_1_do = lizong_41(Para_0_in,Local_7_do,-1);//,false ,Para_7_in,Para_10_in) ;
 if ( WeightedTP )
 {
   Local_9_do = Local_8_do - Local_2_do ;
   if ( lizong_21(Para_3_st,0,-1) )
   {
     Local_10_do = lizong_24(Para_3_st,-1,-1,false) ;
     if ( KeepOriginalProfitLotSize && GridLevelToStart >  1 && !(AutoSplit) )
     {
       Local_10_do = lizong_24(Para_3_st,-1,-1,true) ;
     }
     if ( Local_10_do>Global_25_do )
     {
       Local_11_in = 0 ;
       if ( GridLevelToStart >  1 && !(KeepOriginalProfitLotSize) && lizong_24(Para_3_st,GridLevelToStart - 1,-1,false)>Global_25_do )
       {
         Local_11_in=GridLevelToStart - 1;
       }
       Local_12_do = lizong_24(Para_3_st,Local_11_in,-1,false) ;
       if ( KeepOriginalProfitLotSize && GridLevelToStart >  1 && !(AutoSplit) )
       {
         Local_12_do = lizong_24(Para_3_st,0,-1,true) ;
       }
       Local_12_do = Local_12_do / Local_10_do ;
       Local_9_do = Local_12_do * Local_9_do ;
       Local_2_do = NormalizeDouble(Local_8_do - Local_9_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
     }
   }
 }
 if ( SmartTP && Global_22_a_168_ko[Para_0_in].do_13>Global_25_do && lizong_21(Para_3_st,0,-1) && GridLevelToStart == 1 )
 {
   Local_13_in = 2 ;
   Local_14_do = InitialTP / 100.0 ;
   if ( !(lizong_21(Para_3_st,2,-1)) )
   {
     Local_8_do = Para_11_do ;
     Local_2_do = Para_11_do - Local_14_do * (Local_6_do - 2) * Global_22_a_168_ko[Para_0_in].do_13 ;
   }
   else
   {
     if ( !(lizong_21(Para_3_st,Local_13_in + 3,-1)) )
     {
       Local_2_do = Local_8_do - Local_14_do * Global_22_a_168_ko[Para_0_in].do_13 ;
     }
     else
     {
       Local_2_do = Local_8_do - Local_14_do / 2.0 * Global_22_a_168_ko[Para_0_in].do_13 ;
     }
   }
   Local_2_do = NormalizeDouble(Local_2_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
 }
 if ( lizong_21(Para_3_st,0,-1) )
 {
   Global_22_a_168_ko[Para_0_in].do_26 = Local_2_do;
 }
 for (Local_15_in = 0 ; Local_15_in < 5 ; Local_15_in ++)
 {
   ChartRedraw(0); 
   Local_16_do = SymbolInfoInteger(Para_3_st,SYMBOL_SPREAD) ;
   tmp_do_1 = SymbolInfoInteger(Para_3_st,SYMBOL_TRADE_STOPS_LEVEL);
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_2 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_2 = 0.00001;
   }
   Local_17_do = tmp_do_1 * tmp_do_2 ;
   tmp_do_1 = SymbolInfoInteger(Para_3_st,SYMBOL_TRADE_FREEZE_LEVEL);
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_3 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_3 = 0.00001;
   }
   Local_18_do = tmp_do_1 * tmp_do_3 ;
   if ( Local_1_do>Global_25_do )
   {
     if ( Local_17_do>Global_25_do && Para_7_in<Global_25_do )
     {
       Local_1_do = MathMax(SymbolInfoDouble(Para_3_st,SYMBOL_ASK) + Local_17_do,Local_1_do) ;
     }
     if ( Local_17_do<Global_25_do )
     {
       Local_1_do = MathMax(SymbolInfoDouble(Para_3_st,SYMBOL_ASK),Local_1_do) ;
     }
   }
   if ( Local_2_do>Global_25_do )
   {
     if ( Local_17_do>Global_25_do && Para_6_in<Global_25_do )
     {
       Local_2_do = MathMin(SymbolInfoDouble(Para_3_st,SYMBOL_ASK) - Local_17_do,Local_2_do) ;
     }
     if ( Local_17_do<Global_25_do )
     {
       Local_2_do = MathMin(SymbolInfoDouble(Para_3_st,SYMBOL_ASK),Local_2_do) ;
     }
   }
   if ( HideSL )
   {
     Local_1_do = 0.0 ;
   }
   if ( ( HideTP || Use_OPO_Method ) && !(SmartTP) )
   {
     Local_2_do = 0.0 ;
   }
   Local_19_bo = true ;
   if ( Local_2_do<Global_25_do && !(HideTP) && !(Use_OPO_Method) )
   {
     Local_19_bo = false ;
   }
   if ( Local_2_do<Global_25_do && SmartTP )
   {
     Local_19_bo = false ;
   }
   if ( Local_1_do<Global_25_do && !(HideSL) )
   {
     Local_19_bo = false ;
   }
   if ( ( !(MathAbs(Para_6_in - Local_2_do)>=((SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Para_3_st,SYMBOL_POINT):0.00001 ) * 2.0) && !(MathAbs(Para_7_in - Local_1_do)>=((SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Para_3_st,SYMBOL_POINT):0.00001 ) * 2.0) ) || !(Local_19_bo) )   continue;
   
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_4 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_4 = 0.00001;
   }
   if ( MathAbs(Para_6_in - Local_2_do)<=tmp_do_4 )
   {
     Local_2_do = Para_6_in ;
   }
   if ( SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do )
   {
     tmp_do_5 = SymbolInfoDouble(Para_3_st,SYMBOL_POINT);
   }
   else
   {
     tmp_do_5 = 0.00001;
   }
   if ( MathAbs(Para_7_in - Local_1_do)<=tmp_do_5 )
   {
     Local_1_do = Para_7_in ;
   }
   if ( HideSL )
   {
     Local_1_do = 0.0 ;
   }
   if ( ( HideTP || Use_OPO_Method ) && !(SmartTP) )
   {
     Local_2_do = 0.0 ;
   }
   Local_1_do = NormalizeDouble(Local_1_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   Local_2_do = NormalizeDouble(Local_2_do,SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
   if ( lizong_30(Para_3_st,3,1,Para_11_do,Para_7_in,Para_6_in,Para_11_do,Local_1_do,Local_2_do) )
   {
     Print(TradeComment + " " + Para_3_st,": Modifying sell trade: " + IntegerToString(Para_1_lo,0,32) + ", attempt N",IntegerToString(Local_15_in + 1,0,32)); 
     if ( !(OrderModify(Para_1_lo,Para_11_do,Local_1_do,Local_2_do,0,255)) )
     {
       Local_20_in = GetLastError() ;
       Print(TradeComment + " " + Para_3_st,": Failed to modify sell trade: " + IntegerToString(Para_1_lo,0,32) + ". Error=",lizong_11(Local_20_in)); 
       Sleep(5000); 
       if ( ( Local_20_in != 132 && Local_20_in != 10018 && Local_20_in != 4756 ) )   continue;
       Sleep(15000); 
        continue;
     }
     Print(TradeComment + " " + Para_3_st,": Sell trade: " + IntegerToString(Para_1_lo,0,32) + " successfully modified"); 
     return;
   }
   Sleep(5000); 
   
 }
 }
//lizong_39 <<==--------   --------
 double lizong_40( int Para_0_in,double Para_1_do,int Para_2_in,int Para_3_in,double Para_4_in)
 {
  //double    Local_1_do;
  string    Local_2_st;
  double    Local_3_do;
  double    Local_4_do;
  double    Local_5_do;
  int       Local_6_in;
  double    Local_7_do;
  double    Local_8_do;
  double    Local_9_do;
  double    Local_10_do;
  double    Local_11_do;
  double    Local_12_do;
  double    Local_13_do;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;

 Local_2_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 ChartRedraw(0); 
 Local_3_do = 0.0 ;
 Local_4_do = 1000.0 ;
 Local_5_do = 0.0 ;
 tmp_in_1 = 10;
 tmp_in_2 = SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS);
 if ( tmp_in_2 == 5 )
 {
   tmp_in_1 = 10;
 }
 if ( tmp_in_2 == 4 )
 {
   tmp_in_1 = 1;
 }
 if ( tmp_in_2 == 0x3 )
 {
   tmp_in_1 = 10;
 }
 if ( ( tmp_in_2 == 2 || tmp_in_2 == 1 || tmp_in_2 == 0 ) )
 {
   tmp_in_1 = 1;
 }
 Local_6_in = tmp_in_1 ;
 Local_7_do = (SymbolInfoDouble(Local_2_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Local_2_st,SYMBOL_POINT):0.00001  ;
 Local_8_do = InitialTP * Local_7_do * Local_6_in ;
 if ( Local_8_do<Global_25_do )
 {
   Local_8_do = Local_4_do * Local_7_do * Local_6_in ;
 }
 if ( Para_2_in == 1 )
 {
   Local_9_do = 0.0 ;
   if ( !(WeightedTP) )
   {
     Local_9_do = lizong_24(Local_2_st,1,1,false) ;
     if ( Local_9_do>Global_25_do )
     {
       Local_8_do = GridTP * Local_7_do * Local_6_in ;
     }
   }
   if ( BreakEvenAfterThisLevel >  0 )
   {
     Local_10_do = lizong_24(Local_2_st,BreakEvenAfterThisLevel - 1,1,false) ;
     if ( Local_10_do>Global_25_do )
     {
       Local_8_do = 0.0 ;
     }
   }
   Local_3_do = NormalizeDouble(Para_1_do + Local_8_do - Local_5_do,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   if ( Global_22_a_168_ko[Para_0_in].do_9>Global_25_do && Local_3_do - Para_1_do>Para_1_do * 0.5 && Local_7_do>0.0 )
   {
     Local_3_do = NormalizeDouble(Para_1_do + Para_1_do * 0.5,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   }
 }
 if ( Para_2_in == -1 )
 {
   Local_11_do = 0.0 ;
   if ( !(WeightedTP) )
   {
     Local_11_do = lizong_24(Local_2_st,1,-1,false) ;
     if ( Local_11_do>Global_25_do )
     {
       Local_8_do = GridTP * Local_7_do * Local_6_in ;
     }
   }
   if ( BreakEvenAfterThisLevel >  0 )
   {
     Local_12_do = lizong_24(Local_2_st,BreakEvenAfterThisLevel - 1,-1,false) ;
     if ( Local_12_do>Global_25_do )
     {
       Local_8_do = 0.0 ;
     }
   }
   Local_3_do = NormalizeDouble(Para_1_do - Local_8_do + Local_5_do,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   if ( Global_22_a_168_ko[Para_0_in].do_9>Global_25_do && Para_1_do - Local_3_do>Para_1_do * 0.5 && Local_7_do>0.0 )
   {
     Local_3_do = NormalizeDouble(Para_1_do - Para_1_do * 0.5,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   }
 }
 Local_13_do = SymbolInfoDouble(Local_2_st,27) ;
 if ( Local_13_do>0.0 )
 {
   Local_3_do = MathRound(Local_3_do / Local_13_do) * Local_13_do ;
   Local_3_do = NormalizeDouble(Local_3_do,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
 }
 return(Local_3_do); 
 }
//lizong_40 <<==--------   --------
double lizong_41( int Para_0_in,double Para_1_do,int Para_2_in)//,int Para_3_in ,int Para_4_in,int Para_5_in)
{
  //double    Local_1_do;
  string    Local_2_st;
  double    Local_3_do;
  double    Local_4_do;
  int       Local_5_in;
  double    Local_6_do;
  double    Local_7_do;
  double    Local_8_do;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;

 Local_2_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 ChartRedraw(0); 
 Local_3_do = 0.0 ;
 Local_4_do = 1000.0 ;
 tmp_in_1 = 10;
 tmp_in_2 = SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS);
 if ( tmp_in_2 == 5 )
 {
   tmp_in_1 = 10;
 }
 if ( tmp_in_2 == 4 )
 {
   tmp_in_1 = 1;
 }
 if ( tmp_in_2 == 3 )
 {
   tmp_in_1 = 10;
 }
 if ( ( tmp_in_2 == 2 || tmp_in_2 == 1 || tmp_in_2 == 0 ) )
 {
   tmp_in_1 = 1;
 }
 Local_5_in = tmp_in_1 ;
 Local_6_do = (SymbolInfoDouble(Local_2_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Local_2_st,SYMBOL_POINT):0.00001  ;
 Local_7_do = GridSL * Local_6_do * Local_5_in ;
 if ( Local_7_do<Global_25_do )
 {
   Local_7_do = Local_4_do * Local_6_do * Local_5_in ;
 }
 if ( Para_2_in == 1 )
 {
   Local_3_do = NormalizeDouble(Para_1_do - Local_7_do,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   if ( Global_22_a_168_ko[Para_0_in].do_9>Global_25_do && Para_1_do - Local_3_do>Para_1_do * 0.5 && Local_6_do>0.0 )
   {
     Local_3_do = NormalizeDouble(Para_1_do - Para_1_do * 0.5,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   }
 }
 if ( Para_2_in == -1 )
 {
   Local_3_do = NormalizeDouble(Para_1_do + Local_7_do,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   if ( Global_22_a_168_ko[Para_0_in].do_9>Global_25_do && Local_3_do - Para_1_do>Para_1_do * 0.5 && Local_6_do>0.0 )
   {
     Local_3_do = NormalizeDouble(Para_1_do + Para_1_do * 0.5,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
   }
 }
 Local_8_do = SymbolInfoDouble(Local_2_st,27) ;
 if ( Local_8_do>0.0 )
 {
   Local_3_do = MathRound(Local_3_do / Local_8_do) * Local_8_do ;
   Local_3_do = NormalizeDouble(Local_3_do,SymbolInfoInteger(Local_2_st,SYMBOL_DIGITS)) ;
 }
 return(Local_3_do); 
 }
//lizong_41 <<==--------   --------
 void lizong_42( int Para_0_in,double Para_1_do,int Para_2_in,int Para_3_in)
 {
  string    Local_1_st;
  double    Local_2_do;
  double    Local_3_do;
  long      Local_5_lo;
  int       Local_6_in;
//----- -----
 bool       tmp_bo_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;
 int     tmp_do_5;
 int        tmp_in_6;
 string     tmp_st_7;
 string     tmp_st_8;
 double     tmp_do_9;
 double     tmp_do_10;
 int        tmp_in_11;
 int        tmp_in_12;

 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 ChartRedraw(0); 
 Local_2_do = SymbolInfoInteger(Local_1_st,SYMBOL_SPREAD) ;
 Local_3_do = 1000;//AccountFreeMarginCheck(Local_1_st,0,Para_1_do) ;
 if ( MQLInfoInteger(MQL_TESTER) )
 {
   tmp_bo_1 = true;
 }
 else
 {
   if ( TerminalInfoInteger(6) == 0 )
   {
     Global_22_a_168_ko[Para_0_in].bo_5 = false;
     Global_22_a_168_ko[Para_0_in].bo_6 = false;
     Print(TradeComment + " " + Global_22_a_168_ko[Para_0_in].st_1,": Signal rejected due to absence of network connection!"); 
     tmp_bo_1 = false;
   }
   else
   {
     tmp_bo_1 = true;
   }
 }
 if ( !(tmp_bo_1) )
 {
   return;
 }
 if ( Local_3_do<=0.0 )
 {
   Print(TradeComment + " " + Local_1_st,": Not enough money to send a new averaging buy order: ",DoubleToString(Local_3_do,2)); 
 }
 else
 {
   Print(TradeComment + " " + Local_1_st,": Sending a new averaging buy order, attempt N1"); 
   tmp_in_2 = 10;
   tmp_in_3 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
   if ( tmp_in_3 == 5 )
   {
     tmp_in_2 = 10;
   }
   if ( tmp_in_3 == 4 )
   {
     tmp_in_2 = 1;
   }
   if ( tmp_in_3 == 3 )
   {
     tmp_in_2 = 10;
   }
   if ( ( tmp_in_3 == 2 || tmp_in_3 == 1 || tmp_in_3 == 0 ) )
   {
     tmp_in_2 = 1;
   }
   if ( ( Local_2_do<MaximumSpread * tmp_in_2 || MaximumSpread<Global_25_do ) )
   {
     tmp_in_4 = -1;
     tmp_do_5 = 0;
     tmp_in_6 = Para_2_in;
     tmp_st_7 = TradeComment;
     if ( Para_3_in >  0 )
     {
       tmp_st_7 = TradeComment + " #" + string(Para_3_in);
     }
     tmp_st_8 = tmp_st_7;
     tmp_do_9 = 0.0;
     tmp_do_10 = 0.0;
     tmp_in_11 = 10;
     tmp_in_12 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
     if ( tmp_in_12 == 5 )
     {
       tmp_in_11 = 10;
     }
     if ( tmp_in_12 == 4 )
     {
       tmp_in_11 = 1;
     }
     if ( tmp_in_12 == 0x3 )
     {
       tmp_in_11 = 10;
     }
     if ( ( tmp_in_12 == 2 || tmp_in_12 == 1 || tmp_in_12 == 0 ) )
     {
       tmp_in_11 = 1;
     }
     Local_5_lo = OrderSend(Local_1_st,0,Para_1_do,SymbolInfoDouble(Local_1_st,SYMBOL_ASK),int(MaximumSlippage * tmp_in_11),tmp_do_10,tmp_do_9,tmp_st_8,tmp_in_6,tmp_do_5,tmp_in_4) ;
     if ( Local_5_lo <  0 )
     {
       Local_6_in = GetLastError() ;
       Print(TradeComment + " " + Local_1_st,": Failed to send a new averaging sell order. Error:",lizong_11(Local_6_in)); 
       Sleep(1000); 
     }
     else
     {
       Print(TradeComment + " " + Local_1_st,": Averaging buy trade is opened, id: ",IntegerToString(Local_5_lo,0,32)); 
       Global_22_a_168_ko[Para_0_in].da_27 = TimeCurrent();
     }
   }
   else
   {
     Print(TradeComment + " " + Local_1_st,": Cannot open a new averaging buy trade due to high spread: ",DoubleToString(Local_2_do,2)); 
     Sleep(5000); 
   }
 }
 }
//lizong_42 <<==--------   --------
 void lizong_43( int Para_0_in,double Para_1_do,int Para_2_in,int Para_3_in)
 {
  string    Local_1_st;
  double    Local_2_do;
  double    Local_3_do;
  int      Local_5_lo;
  int       Local_6_in;
//----- -----
 bool       tmp_bo_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;
 datetime     tmp_do_5;
 int        tmp_in_6;
 string     tmp_st_7;
 string     tmp_st_8;
 double     tmp_do_9;
 double     tmp_do_10;
 int        tmp_in_11;
 int        tmp_in_12;

 Local_1_st = Global_22_a_168_ko[Para_0_in].st_1 ;
 ChartRedraw(0); 
 Local_2_do = SymbolInfoInteger(Local_1_st,SYMBOL_SPREAD) ;
 Local_3_do = 1000;//AccountFreeMarginCheck(Local_1_st,1,Para_1_do) ;
 if ( MQLInfoInteger(MQL_TESTER) )
 {
   tmp_bo_1 = true;
 }
 else
 {
   if ( TerminalInfoInteger(6) == 0 )
   {
     Global_22_a_168_ko[Para_0_in].bo_5 = false;
     Global_22_a_168_ko[Para_0_in].bo_6 = false;
     Print(TradeComment + " " + Global_22_a_168_ko[Para_0_in].st_1,": Signal rejected due to absence of network connection!"); 
     tmp_bo_1 = false;
   }
   else
   {
     tmp_bo_1 = true;
   }
 }
 if ( !(tmp_bo_1) )
 {
   return;
 }
 if ( Local_3_do<=0.0 )
 {
   Print(TradeComment + " " + Local_1_st,": Not enough money to send a new averaging sell order: ",DoubleToString(Local_3_do,2)); 
 }
 else
 {
   Print(TradeComment + " " + Local_1_st,": Sending a new averaging sell order, attempt N1"); 
   tmp_in_2 = 10;
   tmp_in_3 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
   if ( tmp_in_3 == 5 )
   {
     tmp_in_2 = 10;
   }
   if ( tmp_in_3 == 4 )
   {
     tmp_in_2 = 1;
   }
   if ( tmp_in_3 == 3 )
   {
     tmp_in_2 = 10;
   }
   if ( ( tmp_in_3 == 2 || tmp_in_3 == 1 || tmp_in_3 == 0 ) )
   {
     tmp_in_2 = 1;
   }
   if ( ( Local_2_do<MaximumSpread * tmp_in_2 || MaximumSpread<Global_25_do ) )
   {
     tmp_in_4 = -1;
     tmp_do_5 = 0;
     tmp_in_6 = Para_2_in;
     tmp_st_7 = TradeComment;
     if ( Para_3_in >  0 )
     {
       tmp_st_7 = TradeComment + " #" + string(Para_3_in);
     }
     tmp_st_8 = tmp_st_7;
     tmp_do_9 = 0.0;
     tmp_do_10 = 0.0;
     tmp_in_11 = 10;
     tmp_in_12 = SymbolInfoInteger(Local_1_st,SYMBOL_DIGITS);
     if ( tmp_in_12 == 5 )
     {
       tmp_in_11 = 10;
     }
     if ( tmp_in_12 == 4 )
     {
       tmp_in_11 = 1;
     }
     if ( tmp_in_12 == 0x3 )
     {
       tmp_in_11 = 10;
     }
     if ( ( tmp_in_12 == 2 || tmp_in_12 == 1 || tmp_in_12 == 0 ) )
     {
       tmp_in_11 = 1;
     }
     Local_5_lo = OrderSend(Local_1_st,1,Para_1_do,SymbolInfoDouble(Local_1_st,SYMBOL_BID),(MaximumSlippage * tmp_in_11),tmp_do_10,tmp_do_9,tmp_st_8,tmp_in_6,tmp_do_5,tmp_in_4) ;
     if ( Local_5_lo <  0 )
     {
       Local_6_in = GetLastError() ;
       Print(TradeComment + " " + Local_1_st,": Failed to send a new averaging sell order. Error:",lizong_11(Local_6_in)); 
       Sleep(1000); 
     }
     else
     {
       Print(TradeComment + " " + Local_1_st,": Averaging sell trade is opened, id: ",IntegerToString(Local_5_lo,0,32)); 
       Global_22_a_168_ko[Para_0_in].da_28 = TimeCurrent();
     }
   }
   else
   {
     Print(TradeComment + " " + Local_1_st,": Cannot open a new averaging sell trade due to high spread: ",DoubleToString(Local_2_do,2)); 
     Sleep(5000); 
   }
 }
 }
//lizong_43 <<==--------   --------
 bool lizong_44( int Para_0_in,int Para_1_lo,int Para_2_in,string Para_3_st,double Para_4_do,double Para_5_do,double Para_6_do,double Para_7_do,datetime Para_9_拆da,double Para_10_do)
 {
  //bool      Local_1_bo;
  double    Local_2_do;
  double    Local_3_do;
  double    Local_4_do;
  int       Local_5_in;
  double    Local_6_do;
  int       Local_7_in;
  double    Local_8_do;
  int       Local_9_in;
  double    Local_10_do;
  double    Local_11_do;
  double    Local_12_do;
  double    Local_13_do;
  int       Local_14_in;
  int       Local_15_in;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;

 ChartRedraw(0); 
 Local_2_do = SymbolInfoInteger(Para_3_st,SYMBOL_SPREAD) ;
 Local_3_do = SymbolInfoDouble(Para_3_st,SYMBOL_ASK) ;
 Local_4_do = SymbolInfoDouble(Para_3_st,SYMBOL_BID) ;
 tmp_in_1 = 10;
 tmp_in_2 = SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS);
 if ( tmp_in_2 == 5 )
 {
   tmp_in_1 = 10;
 }
 if ( tmp_in_2 == 4 )
 {
   tmp_in_1 = 1;
 }
 if ( tmp_in_2 == 3 )
 {
   tmp_in_1 = 10;
 }
 if ( ( tmp_in_2 == 2 || tmp_in_2 == 1 || tmp_in_2 == 0 ) )
 {
   tmp_in_1 = 1;
 }
 Local_5_in = tmp_in_1 ;
 Local_6_do = (SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Para_3_st,SYMBOL_POINT):0.00001  ;
 Local_7_in = MaximumSlippage * Local_5_in ;
 Local_8_do = MaximumSpread * Local_5_in ;
 Local_9_in = iBarShift(Para_3_st,Global_21_in,Para_9_拆da,true) ;
 Global_22_a_168_ko[Para_0_in].in_15 = Local_9_in;
 Local_10_do = 0.0 ;
 Local_11_do = 999999999.0 ;
 if ( ( HideTP || HideSL || Use_OPO_Method ) )
 {
   Local_12_do = Para_10_do ;
   if ( MaximumTrades - 1 >  0 && TradeMultiplier_3rd>0.0 && TradeDistance>Global_25_do )
   {
     if ( lizong_21(Para_3_st,0,1) )
     {
       Local_12_do = NormalizeDouble(lizong_22(Para_3_st,0,1),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
     }
     else
     {
       if ( Global_22_a_168_ko[Para_0_in].do_23>Global_25_do )
       {
         Local_12_do = Global_22_a_168_ko[Para_0_in].do_23 ;
       }
     }
   }
   Local_10_do = lizong_41(Para_0_in,Local_12_do,1);//,false,Para_7_do,0) ;
   if ( Global_22_a_168_ko[Para_0_in].do_25>Global_25_do )
   {
     Local_11_do = Global_22_a_168_ko[Para_0_in].do_25 ;
   }
 }
 Local_13_do = Global_22_a_168_ko[Para_0_in].do_9 ;
 if ( OPO_TimeFrame != 15 )
 {
   Local_13_do = iClose(Global_22_a_168_ko[Para_0_in].st_1,OPO_TimeFrame,1) ;
 }
 if ( ( ( Local_9_in >  Global_22_a_168_ko[Para_0_in].in_14 && Global_22_a_168_ko[Para_0_in].in_14 != 0x0 ) || ( HideSL && Local_4_do<=Local_10_do ) || ( HideTP && Local_4_do>=Local_11_do && !(Use_OPO_Method) && !(SmartTP) ) || ( Use_OPO_Method && Local_13_do>=Local_11_do && !(SmartTP) && Global_22_a_168_ko[Para_0_in].bo_10 == 0x0 && Global_22_a_168_ko[Para_0_in].bo_11 == 0x0 ) || Global_29_bo ) )
 {
   Print(TradeComment + " " + Para_3_st,": Closing buy trade: " + IntegerToString(Para_1_lo,0,32)); 
   if ( HideSL )
   {
     Local_14_in = 0 ;
     tmp_in_3 = 0;
   }
   if ( ( HideTP || Use_OPO_Method ) && !(SmartTP) )
   {
     Local_15_in = 0 ;
     tmp_in_4 = 0;
   }
   if ( ( Local_2_do<Local_8_do || MaximumSpread<Global_25_do ) )
   {
     if ( lizong_30(Para_3_st,1,0,Para_10_do,Para_7_do,Para_6_do,0.0,0.0,0.0) )
     {
       if ( !(OrderClose(Para_1_lo,Para_4_do,Local_4_do,Local_7_in,-1)) )
       {
         Print(TradeComment + " " + Para_3_st,": Failed to close buy trade: " + IntegerToString(Para_1_lo,0,32) + ". Error=",lizong_11(GetLastError())); 
         return(true); 
       }
       Print(TradeComment + " " + Para_3_st,": Buy trade: " + IntegerToString(Para_1_lo,0,32) + " successfully closed"); 
       return(true); 
     }
     Sleep(1000); 
   }
   else
   {
     Print(TradeComment + " " + Para_3_st,": Cannot close buy trade due to high spread: ",DoubleToString(Local_2_do,2)); 
     Sleep(1000); 
   }
 }
 return(false); 
 }
//lizong_44 <<==--------   --------
 bool lizong_45( int Para_0_in,int Para_1_lo,int Para_2_in,string Para_3_st,double Para_4_do,double Para_5_do,double Para_6_do,double Para_7_do,datetime Para_9_拆da,double Para_10_do)
 {
  //bool      Local_1_bo;
  double    Local_2_do;
  double    Local_3_do;
  double    Local_4_do;
  int       Local_5_in;
  double    Local_6_do;
  int       Local_7_in;
  double    Local_8_do;
  int       Local_9_in;
  double    Local_10_do;
  double    Local_11_do;
  double    Local_12_do;
  double    Local_13_do;
  int       Local_14_in;
  int       Local_15_in;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;
 int        tmp_in_3;
 int        tmp_in_4;

 ChartRedraw(0); 
 Local_2_do = SymbolInfoInteger(Para_3_st,SYMBOL_SPREAD) ;
 Local_3_do = SymbolInfoDouble(Para_3_st,SYMBOL_ASK) ;
 Local_4_do = SymbolInfoDouble(Para_3_st,SYMBOL_BID) ;
 tmp_in_1 = 10;
 tmp_in_2 = SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS);
 if ( tmp_in_2 == 5 )
 {
   tmp_in_1 = 10;
 }
 if ( tmp_in_2 == 4 )
 {
   tmp_in_1 = 1;
 }
 if ( tmp_in_2 == 3 )
 {
   tmp_in_1 = 10;
 }
 if ( ( tmp_in_2 == 2 || tmp_in_2 == 1 || tmp_in_2 == 0 ) )
 {
   tmp_in_1 = 1;
 }
 Local_5_in = tmp_in_1 ;
 Local_6_do = (SymbolInfoDouble(Para_3_st,SYMBOL_POINT)>Global_25_do) ?SymbolInfoDouble(Para_3_st,SYMBOL_POINT):0.00001  ;
 Local_7_in = MaximumSlippage * Local_5_in ;
 Local_8_do = MaximumSpread * Local_5_in ;
 Local_9_in = iBarShift(Para_3_st,Global_21_in,Para_9_拆da,true) ;
 Global_22_a_168_ko[Para_0_in].in_15 = Local_9_in;
 Local_10_do = 999999999.0 ;
 Local_11_do = 0.0 ;
 if ( ( HideTP || HideSL || Use_OPO_Method ) )
 {
   Local_12_do = Para_10_do ;
   if ( MaximumTrades - 1 >  0 && TradeMultiplier_3rd>0.0 && TradeDistance>Global_25_do )
   {
     if ( lizong_21(Para_3_st,0,-1) )
     {
       Local_12_do = NormalizeDouble(lizong_22(Para_3_st,0,-1),SymbolInfoInteger(Para_3_st,SYMBOL_DIGITS)) ;
     }
     else
     {
       if ( Global_22_a_168_ko[Para_0_in].do_24>Global_25_do )
       {
         Local_12_do = Global_22_a_168_ko[Para_0_in].do_24 ;
       }
     }
   }
   Local_10_do = lizong_41(Para_0_in,Local_12_do,-1);//false,Para_7_do,0) ;
   if ( Global_22_a_168_ko[Para_0_in].do_26>Global_25_do )
   {
     Local_11_do = Global_22_a_168_ko[Para_0_in].do_26 ;
   }
 }
 Local_13_do = Global_22_a_168_ko[Para_0_in].do_9 ;
 if ( OPO_TimeFrame != 15 )
 {
   Local_13_do = iClose(Global_22_a_168_ko[Para_0_in].st_1,OPO_TimeFrame,1) ;
 }
 if ( ( ( Local_9_in >  Global_22_a_168_ko[Para_0_in].in_14 && Global_22_a_168_ko[Para_0_in].in_14 != 0x0 ) || ( HideSL && Local_3_do>=Local_10_do ) || ( HideTP && Local_3_do<=Local_11_do && !(Use_OPO_Method) && !(SmartTP) ) || ( Use_OPO_Method && Local_3_do - Local_4_do + Local_13_do<=Local_11_do && !(SmartTP) && Global_22_a_168_ko[Para_0_in].bo_10 == 0x0 && Global_22_a_168_ko[Para_0_in].bo_11 == 0x0 ) || Global_29_bo ) )
 {
   Print(TradeComment + " " + Para_3_st,": Closing sell trade: " + IntegerToString(Para_1_lo,0,32)); 
   if ( HideSL )
   {
     Local_14_in = 0 ;
     tmp_in_3 = 0;
   }
   if ( ( HideTP || Use_OPO_Method ) && !(SmartTP) )
   {
     Local_15_in = 0 ;
     tmp_in_4 = 0;
   }
   if ( ( Local_2_do<Local_8_do || MaximumSpread<Global_25_do ) )
   {
     if ( lizong_30(Para_3_st,1,1,Para_10_do,Para_7_do,Para_6_do,0.0,0.0,0.0) )
     {
       if ( !(OrderClose(Para_1_lo,Para_4_do,Local_3_do,Local_7_in,-1)) )
       {
         Print(TradeComment + " " + Para_3_st,": Failed to close sell trade: " + IntegerToString(Para_1_lo,0,32) + ". Error=",lizong_11(GetLastError())); 
         return(true); 
       }
       Print(TradeComment + " " + Para_3_st,": Sell trade: " + IntegerToString(Para_1_lo,0,32) + " successfully closed"); 
       return(true); 
     }
     Sleep(1000); 
   }
   else
   {
     Print(TradeComment + " " + Para_3_st,": Cannot close sell trade due to high spread: ",DoubleToString(Local_2_do,2)); 
     Sleep(1000); 
   }
 }
 return(false); 
 }
//lizong_45 <<==--------   --------
 void lizong_46()
 {
  string    Local_1_st;
  int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  bool      Local_8_bo;
  bool      Local_9_bo;
  bool      Local_10_bo;
  int       Local_11_in;
  int       Local_12_in;
//----- -----

 Local_1_st = "R_Label" ;
 Local_2_in = 2960685 ;
 Local_3_in = 1 ;
 Local_4_in = 0 ;
 Local_5_in = 8388608 ;
 Local_6_in = 0 ;
 Local_7_in = 2 ;
 Local_8_bo = false ;
 Local_9_bo = false ;
 Local_10_bo = true ;
 Local_12_in = 0 ;
 Local_11_in = 0 ;
 ResetLastError();
 if ( ObjectFind(0,Local_1_st) == -1 )
 {
   if ( !(Global_10_a_167.CreateBitmap(0,0,"R_Label",5,17,100,100)) )
   {
     Print("Error creating canvas: ",GetLastError()); 
   }
   else
   {
     Global_10_a_167.CCanvasX_12("::W2.12LD_bmp\\WakaWakaEA.bmp"); 
     Global_10_a_167.TransparentLevelSet(210);
     Global_10_a_167.Update(0);
   }
 }
 ChartRedraw(0); 
 Sleep(500); 
 }
//lizong_46 <<==--------   --------
 void lizong_47( string Para_0_st,int Para_1_in)
 {
  bool      Local_1_bo = false;
  bool      Local_2_bo = false;
  int       Local_3_in;
  int       Local_4_in;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;

 if ( Para_1_in == -1 )
 {
   Local_2_bo = true ;
 }
 if ( Para_1_in == 1 )
 {
   Local_1_bo = true ;
 }
 if ( AccountInfoDouble(ACCOUNT_MARGIN_FREE)<10.0 )
 {
   Local_1_bo = false ;
   Local_2_bo = false ;
   Print(TradeComment + " " + Para_0_st,": Not enough money: ",DoubleToString(MathFloor(AccountInfoDouble(ACCOUNT_MARGIN_FREE)),2)); 
 }
 if ( ( UID > 9 || UID <  0 ) )
 {
   Print(TradeComment + " " + Para_0_st,": UID value issue!"); 
   Local_1_bo = false ;
   Local_2_bo = false ;
 }
 Local_3_in = (int)SymbolInfoInteger(Para_0_st,30) ;
 switch(Local_3_in)
 {
   case 0 :
   Print(TradeComment + " " + Para_0_st,": Trading is disabled for ",Para_0_st); 
   Local_1_bo = false ;
   Local_2_bo = false ;
     break;
   case 3 :
   Local_1_bo = false ;
   Local_2_bo = false ;
     break;
   case 4 :
   Local_1_bo = false ;
   Local_2_bo = false ;
     break;
   case 1 :
   Local_1_bo = false ;
   Local_2_bo = false ;
 }
 tmp_in_1 = 0;
 for (tmp_in_2 = 0 ; tmp_in_2 < ArraySize(Global_22_a_168_ko) ; tmp_in_2=tmp_in_2 + 1)
 {
   if ( lizong_21(Global_22_a_168_ko[tmp_in_2].st_1,0,0) )
   {
     tmp_in_1=tmp_in_1 + 1;
   }
 }
 if ( tmp_in_1 >= MaximumSymbols )
 {
   Local_1_bo = false ;
   Local_2_bo = false ;
 }
 for (Local_4_in = 0 ; Local_4_in < ArraySize(Global_22_a_168_ko) ; Local_4_in ++)
 {
   if ( Global_22_a_168_ko[Local_4_in].st_1 == Para_0_st )
   {
     Global_22_a_168_ko[Local_4_in].bo_5 = Local_1_bo;
     Global_22_a_168_ko[Local_4_in].bo_6 = Local_2_bo;
     lizong_33(Local_4_in,true); 
     Global_22_a_168_ko[Local_4_in].bo_5 = false;
     Global_22_a_168_ko[Local_4_in].bo_6 = false;
     return;
   }
 }
 }
//lizong_47 <<==--------   --------
 void lizong_48( string Para_0_st)
 {
  int       Local_1_in;
//----- -----
 int        tmp_in_1;
 int        tmp_in_2;

 if ( Para_0_st == "but_Suspend" && ObjectFind(0,"but_Suspend") != -1 )
 {
   Global_37_bo=!(ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0));
   if ( ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0) == 0 )
   {
     ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,32768); 
     ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids allowed"); 
   }
   if ( !(Global_37_bo) )
   {
     ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,255); 
     ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids NOT allowed!"); 
     for (tmp_in_1 = 0 ; tmp_in_1 < ArraySize(Global_22_a_168_ko) ; tmp_in_1=tmp_in_1 + 1)
     {
       Global_22_a_168_ko[tmp_in_1].bo_5 = false;
       Global_22_a_168_ko[tmp_in_1].bo_6 = false;
     }
   }
   ChartRedraw(0); 
 }
 if ( Para_0_st == "but_Buy" && ObjectFind(0,"but_Buy") != -1 )
 {
   Sleep(100); 
   ObjectSetInteger(0,"but_Buy",OBJPROP_STATE,0); 
   ChartRedraw(0); 
   lizong_47(Global_36_st,1); 
 }
 if ( Para_0_st == "but_Sell" && ObjectFind(0,"but_Sell") != -1 )
 {
   Sleep(100); 
   ObjectSetInteger(0,"but_Sell",OBJPROP_STATE,0); 
   ChartRedraw(0); 
   lizong_47(Global_36_st,-1); 
 }
 if ( Para_0_st != "but_Pair" || ObjectFind(0,"but_Pair") == -1 )   return;
 Sleep(100); 
 ObjectSetInteger(0,"but_Pair",OBJPROP_STATE,0); 
 if ( Global_36_st == "Select pair" )
 {
   Global_36_st = Global_22_a_168_ko[0].st_1 ;
 }
 else
 {
   for (Local_1_in = 0 ; Local_1_in < ArraySize(Global_22_a_168_ko) ; Local_1_in ++)
   {
     if ( Global_22_a_168_ko[Local_1_in].st_1 == Global_36_st && Local_1_in <  ArraySize(Global_22_a_168_ko) - 1 )
     {
       Global_36_st = Global_22_a_168_ko[Local_1_in + 1].st_1 ;
       break;
     }
     if ( Global_22_a_168_ko[Local_1_in].st_1 != Global_36_st )   continue;
     tmp_in_2=ArraySize(Global_22_a_168_ko) - 1;
     if ( Local_1_in != tmp_in_2 )   continue;
     Global_36_st = "Select pair" ;
     break;
     
   }
 }
 ObjectSetString(0,"but_Pair",OBJPROP_TEXT,Global_36_st); 
 ChartRedraw(0); 
 }
//lizong_48 <<==--------   --------
 void lizong_49( bool Para_0_bo)
 {
  int       Local_1_in;
  int       Local_2_in;
  int       Local_3_in;
  int       Local_4_in;
  int       Local_5_in;
  int       Local_6_in;
  int       Local_7_in;
  string    Local_8_st;
  int       Local_9_in;
  int       Local_10_in;
  string    Local_11_st;
  string    Local_12_st;
  double    Local_13_do;
  int       Local_14_in;
  double    Local_15_do;
  int       Local_16_in;
  int       Local_17_in;
  string    Local_18_st;
//----- -----
 int        tmp_in_1;
 double     tmp_do_2;
 int        tmp_in_3;
 int        tmp_in_4;
 int        tmp_in_5;
 int        tmp_in_6;
 string     tmp_st_7;
 int        tmp_in_8;
 bool       tmp_bo_9;
 tmp_st_7 = "7318875";
 Local_1_in = 16777215 ;
 Local_2_in = 14474460 ;
 tmp_in_1 = TerminalInfoInteger(8);
 if ( tmp_in_1 != 0 )
 {
   tmp_in_1 = (int)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
 }
 if ( tmp_in_1 != 0 )
 {
   tmp_in_1 = MQLInfoInteger(MQL_TRADE_ALLOWED);
 }
 if ( ( tmp_in_1 == 0 || Global_35_bo ) )
 {
   Local_1_in = 4678655 ;
   Local_2_in = 4678655 ;
 }
 Local_3_in = 0 ;
 Local_4_in = 23 ;
 Local_5_in = 15 ;
 Local_6_in = 14 ;
 Local_7_in = 100 ;
 Local_8_st = "MS Sans Serif" ;
 Local_9_in = 6 ;
 Local_10_in = 205 ;
 if ( ObjectFind(0,"but_Buy") == -1 )
 {
   lizong_50(0,"but_Buy",0,10,205,40,20,0,"Buy",Local_8_st,6,16777215,25600,25600,false,false,false,true,0); 
 }
 if ( ObjectFind(0,"but_Sell") == -1 )
 {
   lizong_50(0,"but_Sell",0,125,Local_10_in,40,20,0,"Sell",Local_8_st,Local_9_in,16777215,139,139,false,false,false,true,0); 
 }
 if ( ObjectFind(0,"but_Pair") == -1 )
 {
   lizong_50(0,"but_Pair",0,52,Local_10_in,71,20,0,Global_36_st,Local_8_st,Local_9_in,16777215,2139610,2139610,false,false,false,true,0); 
 }
 if ( ObjectFind(0,"but_Suspend") == -1 )
 {
   lizong_50(0,"but_Suspend",0,10,162,155,20,0,"New grids allowed",Local_8_st,Local_9_in,16777215,32768,32768,false,false,false,true,0); 
 }
 if ( ObjectFind(0,"but_Suspend") != -1 )
 {
   Global_37_bo=!(ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0));
   if ( ObjectGetInteger(0,"but_Suspend",OBJPROP_STATE,0) == 0 )
   {
     ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,32768); 
     ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids allowed"); 
   }
   if ( !(Global_37_bo) )
   {
     ObjectSetInteger(0,"but_Suspend",OBJPROP_BGCOLOR,255); 
     ObjectSetString(0,"but_Suspend",OBJPROP_TEXT,"New grids NOT allowed!"); 
     for (tmp_in_1 = 0 ; tmp_in_1 < ArraySize(Global_22_a_168_ko) ; tmp_in_1=tmp_in_1 + 1)
     {
       Global_22_a_168_ko[tmp_in_1].bo_5 = false;
       Global_22_a_168_ko[tmp_in_1].bo_6 = false;
     }
   }
   ChartRedraw(0); 
 }
 Local_4_in +=30;
 Local_11_st = "-----" ;
 if ( ( !(Para_0_bo) || MQLInfoInteger(MQL_TESTER) ) )
 {
   Local_11_st = DoubleToString(lizong_34(Global_22_a_168_ko[0].st_1,false),2) ;
 }
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,"Start lot:",Local_8_st,Local_2_in,Local_9_in); 
 lizong_31("GraphicsV" + string(Local_4_in),Local_3_in,Local_7_in,Local_4_in,Local_11_st,Local_8_st,Local_1_in,Local_9_in); 
 Local_4_in +=Local_6_in;
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,"Currencies:",Local_8_st,Local_2_in,Local_9_in); 
 lizong_31("GraphicsV" + string(Local_4_in),Local_3_in,Local_7_in,Local_4_in,string(ArraySize(Global_22_a_168_ko)),Local_8_st,Local_1_in,Local_9_in); 
 Local_4_in +=Local_6_in;
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,"Leverage:",Local_8_st,Local_2_in,Local_9_in); 
 lizong_31("GraphicsV" + string(Local_4_in),Local_3_in,Local_7_in,Local_4_in,"1:" + (string)AccountInfoInteger(ACCOUNT_LEVERAGE),Local_8_st,Local_1_in,Local_9_in); 
 Local_4_in +=Local_6_in;
 Local_12_st = TradeComment ;
 if ( StringLen(TradeComment)  >  9.881312916825e-323 )
 {
   Local_12_st = StringSubstr(TradeComment,0,20) ;
 }
 Local_13_do = 0.0 ;
 for (Local_14_in = 0 ; Local_14_in < ArraySize(Global_22_a_168_ko) ; Local_14_in ++)
 {
   Local_13_do = Local_13_do + lizong_24(Global_22_a_168_ko[Local_14_in].st_1,-1,0,false) ;
 }
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,"Lots opened:",Local_8_st,Local_2_in,Local_9_in); 
 lizong_31("GraphicsV" + string(Local_4_in),Local_3_in,Local_7_in,Local_4_in,DoubleToString(Local_13_do,3),Local_8_st,Local_1_in,Local_9_in); 
 Local_4_in +=Local_6_in;
 tmp_do_2 = 0.0;
 tmp_in_3 = Global_24_in + UID + int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32)) ));
 tmp_in_4 = Global_24_in + UID + int(MathPow(10.0,StringLen(IntegerToString(Global_24_in + UID,0,32)) )) * 2;
 for (tmp_in_5 = 0 ; tmp_in_5 < OrdersTotal() ; tmp_in_5=tmp_in_5 + 1)
 {
   if ( OrderSelect(tmp_in_5,0,0) )
   {
     tmp_in_6 = OrderType();
     OrderSymbol(); 
     tmp_in_8 = OrderMagicNumber() / 100;
     if ( ( ( tmp_in_6 != 0 || tmp_in_3 != tmp_in_8 ) && (tmp_in_6 != 1 || tmp_in_4 != tmp_in_8) ) )   continue;
     tmp_do_2 = OrderProfit() + OrderSwap() + OrderCommission() + tmp_do_2;
      continue;
   }
   Print(TradeComment + " " + "------",": Failed to select an order! Error=",lizong_11(GetLastError())); 
   
 }
 Local_15_do = tmp_do_2 ;
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,"Floating PnL:",Local_8_st,Local_2_in,Local_9_in); 
 Local_16_in = Local_1_in ;
 if ( Local_15_do<0.0 )
 {
   Local_16_in = 4678655 ;
 }
 lizong_31("GraphicsV" + string(Local_4_in),Local_3_in,Local_7_in,Local_4_in,DoubleToString(Local_15_do,2),Local_8_st,Local_16_in,Local_9_in); 
 Local_4_in +=Local_6_in;
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,"Comment:",Local_8_st,Local_2_in,Local_9_in); 
 lizong_31("GraphicsV" + string(Local_4_in),Local_3_in,Local_7_in,Local_4_in,Local_12_st,Local_8_st,Local_1_in,Local_9_in); 
 Local_4_in +=Local_6_in;
 Local_4_in +=8;
 Local_17_in = 16495626 ;
 Local_18_st = "Live trading" ;
 tmp_bo_9 = TerminalInfoInteger(8);
 if ( tmp_bo_9 )
 {
   tmp_bo_9 = AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
 }
 if ( tmp_bo_9 )
 {
   tmp_bo_9 = MQLInfoInteger(MQL_TRADE_ALLOWED);
 }
 if ( !(tmp_bo_9) )
 {
   Local_18_st = "Trading not allowed!" ;
   Local_17_in = 4678655 ;
 }
 if ( !(AllowOpeningNewGrid) )
 {
   Local_18_st = "New grids NOT allowed!" ;
   Local_17_in = 4678655 ;
 }
 if ( TerminalInfoInteger(8) == 0 )
 {
   Local_18_st = "Terminal: trading not allowed!" ;
   Local_17_in = 4678655 ;
 }
 if ( AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == 0 )
 {
   Local_18_st = "Account: trading not allowed!" ;
   Local_17_in = 4678655 ;
 }
 if ( MQLInfoInteger(MQL_TRADE_ALLOWED) == 0 )
 {
   Local_18_st = "MQL: trading not allowed!" ;
   Local_17_in = 4678655 ;
 }
 if ( Period() != 15 )
 {
   Local_18_st = "M15 is needed!" ;
   Local_17_in = 4678655 ;
 }
 if ( Global_35_bo )
 {
   Local_18_st = "Check Symbols!" ;
   Local_17_in = 4678655 ;
 }
 if ( MQLInfoInteger(MQL_VISUAL_MODE) )
 {
   Local_18_st = "Backtesting" ;
 }
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,Local_18_st,Local_8_st,Local_17_in,Local_9_in); 
 Local_4_in +=160;
 lizong_31("GraphicsC" + string(Local_4_in),Local_3_in,Local_5_in,Local_4_in,"v" + Global_2_st,Local_8_st,Local_2_in,Local_9_in); 
 }
//lizong_49 <<==--------   --------
 bool lizong_50( long Para_0_lo,string Para_1_st,int Para_2_in,int Para_3_in,int Para_4_in,int Para_5_in,int Para_6_in,int Para_7_in,string Para_8_st,string Para_9_st,int Para_10_in,int Para_11_in,int Para_12_in,int Para_13_in,char Para_14_ch,char Para_15_ch,char Para_16_ch,char Para_17_ch,long Para_18_lo)
 {
  //bool      Local_1_bo;
//----- -----

 ResetLastError();
 if ( !(ObjectCreate(Para_0_lo,Para_1_st,25,Para_2_in,0,0.0)) )
 {
   Print("Error creating canvas: ",lizong_11(GetLastError())); 
   return(false); 
 }
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_XDISTANCE,Para_3_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_YDISTANCE,Para_4_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_XSIZE,Para_5_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_YSIZE,Para_6_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_CORNER,Para_7_in); 
 ObjectSetString(Para_0_lo,Para_1_st,OBJPROP_TEXT,Para_8_st); 
 ObjectSetString(Para_0_lo,Para_1_st,OBJPROP_FONT,Para_9_st); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_FONTSIZE,Para_10_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_COLOR,Para_11_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_BGCOLOR,Para_12_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_BORDER_COLOR,Para_13_in); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_BACK,Para_15_ch); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_STATE,Para_14_ch); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_SELECTABLE,Para_16_ch); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_SELECTED,Para_16_ch); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_HIDDEN,Para_17_ch); 
 ObjectSetInteger(Para_0_lo,Para_1_st,OBJPROP_ZORDER,Para_18_lo); 
 return(true); 
 }
//<<==lizong_50 <<==

int YearMQL4(){MqlDateTime tm;   TimeCurrent(tm);   return(tm.year);}
int MonthMQL4(){   MqlDateTime tm;   TimeCurrent(tm);   return(tm.mon);}
int DayMQL4(){   MqlDateTime tm;   TimeCurrent(tm);   return(tm.day);}
int DayOfWeekMQL4(){   MqlDateTime tm;   TimeCurrent(tm);   return(tm.day_of_week);}
int HourMQL4(){   MqlDateTime tm;   TimeCurrent(tm);   return(tm.hour);}
int MinuteMQL4(){   MqlDateTime tm;   TimeCurrent(tm);   return(tm.min);}
int SecondsMQL4(){   MqlDateTime tm;   TimeCurrent(tm);   return(tm.sec);}
int TimeDayOfYear(datetime xtime){
   MqlDateTime tm;   
   TimeToStruct(xtime,tm);
   return(tm.day_of_year);
}
int TimeDay(datetime xtine){
   MqlDateTime tm;   
   TimeToStruct(xtine,tm);
   return(tm.day);
}
int TimeMinute(datetime xtine){
   MqlDateTime tm;   
   TimeToStruct(xtine,tm);
   return(tm.min);
}
int TimeDayOfWeek(datetime xtine){  
 MqlDateTime tm;   TimeToStruct(xtine,tm);   return(tm.day_of_week);}
int TimeHour(datetime xtine){
   MqlDateTime tm;   
   TimeToStruct(xtine,tm);
   return(tm.hour);
}
int TimeMonth(datetime xtine){
   MqlDateTime tm;   
   TimeToStruct(xtine,tm);
   return(tm.mon);
}
int TimeYear(datetime xtine){
   MqlDateTime tm;   
   TimeToStruct(xtine,tm);
   return(tm.year);
}
double iGetArray(const int handle,const int buffer,const int start_pos,const int count,double &arr_buffer[]){
   bool result=true;
   if(!ArrayIsDynamic(arr_buffer))return(false);
   ArrayFree(arr_buffer);
   ResetLastError();
   int copied=CopyBuffer(handle,buffer,start_pos,count,arr_buffer);
   if(copied!=count)return(false);
   return(result);
}

   //+------------------------------------------------------------------+
//|   NOVO DIA                                                       |
//+------------------------------------------------------------------+
bool NewDay()
{
   static datetime PrevDay;

   if(PrevDay < iTime(NULL, PERIOD_D1, 0)) {
      PrevDay = iTime(NULL, PERIOD_D1, 0);
         Print("Novo dia identificado");
      return(true);
   }
   else {
      return(false);
   }
}

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| PAINEL HANDLIV - EA LIVWELL FOREX                                 |
//| Painel visual no grafico: conta, P/L do dia e botoes manuais     |
//+------------------------------------------------------------------+
input bool   InpHLVShowPanel = true;   // Mostrar painel Handliv no grafico
input double InpHLVVolume    = 0.10;   // Volume manual dos botoes (lotes)

CTrade   g_hlvTrade;
string   g_hlvStatus    = "";
bool     g_hlvStatusOk  = true;
datetime g_hlvStatusAt  = 0;

#define HLVX_NAVY   C'10,17,32'
#define HLVX_LINE   C'28,43,71'
#define HLVX_GREEN  C'22,211,154'
#define HLVX_UP     C'22,199,132'
#define HLVX_DOWN   C'234,57,67'
#define HLVX_AMBER  C'245,166,35'
#define HLVX_WHITE  C'233,239,249'
#define HLVX_FAINT  C'94,112,147'
#define HLVX_BLUE   C'76,141,255'

#define LWFX_BG        "LWFX_BG"
#define LWFX_ACCENT    "LWFX_ACCENT"
#define LWFX_TITLE     "LWFX_TITLE"
#define LWFX_SEP       "LWFX_SEP"
#define LWFX_ACCT      "LWFX_ACCT"
#define LWFX_STATUS    "LWFX_STATUS"
#define LWFX_L1        "LWFX_L1"
#define LWFX_V1        "LWFX_V1"
#define LWFX_L2        "LWFX_L2"
#define LWFX_V2        "LWFX_V2"
#define LWFX_L3        "LWFX_L3"
#define LWFX_V3        "LWFX_V3"
#define LWFX_L4        "LWFX_L4"
#define LWFX_V4        "LWFX_V4"
#define LWFX_L5        "LWFX_L5"
#define LWFX_V5        "LWFX_V5"
#define LWFX_L6        "LWFX_L6"
#define LWFX_V6        "LWFX_V6"
#define LWFX_VOL       "LWFX_VOL"
#define LWFX_BTN_BUY   "LWFX_BTN_BUY"
#define LWFX_BTN_SELL  "LWFX_BTN_SELL"
#define LWFX_BTN_CLOSE "LWFX_BTN_CLOSE"

//+------------------------------------------------------------------+
//| Helpers de objetos (canto superior ESQUERDO - nao corta)          |
//+------------------------------------------------------------------+
void HLVRLabel(const string name, int x, int y, const string text, color clr, int size,
               const string font = "Arial", ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void HLVRRect(const string name, int x, int y, int w, int h, color bg, color border)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void HLVRButton(const string name, int x, int y, int w, int h, const string text, color bg)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, HLVX_WHITE);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, HLVX_NAVY);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

void HLVSetText(const string name, const string text)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void HLVSetColor(const string name, color clr)
{
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Formatacao monetaria BR: 12.345,67                                |
//+------------------------------------------------------------------+
string HLVGroup(string intpart)
{
   string res = "";
   int len = StringLen(intpart);
   for(int i = 0; i < len; i++)
   {
      if(i > 0 && (len - i) % 3 == 0) res += ".";
      res += StringSubstr(intpart, i, 1);
   }
   return res;
}

string HLVFmt(double v)
{
   string s = DoubleToString(MathAbs(v), 2);
   int dot = StringFind(s, ".");
   if(dot < 0) return s;
   string ip = StringSubstr(s, 0, dot);
   string dp = StringSubstr(s, dot);
   StringReplace(dp, ".", ",");
   return HLVGroup(ip) + dp;
}

string HLVMoney(double v)
{
   string sgn = (v >= 0 ? "+" : "-");
   return sgn + HLVFmt(v) + " " + AccountInfoString(ACCOUNT_CURRENCY);
}

//+------------------------------------------------------------------+
//| P/L do dia (realizado + flutuante)                                |
//+------------------------------------------------------------------+
double HLVDayProfit()
{
   double total = 0.0;
   datetime day0 = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(HistorySelect(day0, TimeCurrent() + 60))
   {
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
      {
         ulong t = HistoryDealGetTicket(i);
         if(t == 0) continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(t, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         total += HistoryDealGetDouble(t, DEAL_PROFIT)
                + HistoryDealGetDouble(t, DEAL_SWAP)
                + HistoryDealGetDouble(t, DEAL_COMMISSION);
      }
   }
   return total + AccountInfoDouble(ACCOUNT_PROFIT);
}

double HLVNormVolume(const string symbol, double vol)
{
   double mn = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(st <= 0) st = 0.01;
   vol = MathMax(mn, MathMin(mx, vol));
   return NormalizeDouble(MathRound(vol / st) * st, 2);
}

//+------------------------------------------------------------------+
//| Ordens manuais do painel                                          |
//+------------------------------------------------------------------+
bool HLVManualBuy()
{
   string sym = _Symbol;
   SymbolSelect(sym, true);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   if(ask <= 0) return false;
   g_hlvTrade.SetExpertMagicNumber(20260918);
   g_hlvTrade.SetDeviationInPoints(10);
   if(!g_hlvTrade.Buy(HLVNormVolume(sym, InpHLVVolume), sym, ask, 0, 0, "LivWellPanel")) return false;
   return (g_hlvTrade.ResultRetcode() == TRADE_RETCODE_DONE);
}

bool HLVManualSell()
{
   string sym = _Symbol;
   SymbolSelect(sym, true);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(bid <= 0) return false;
   g_hlvTrade.SetExpertMagicNumber(20260918);
   g_hlvTrade.SetDeviationInPoints(10);
   if(!g_hlvTrade.Sell(HLVNormVolume(sym, InpHLVVolume), sym, bid, 0, 0, "LivWellPanel")) return false;
   return (g_hlvTrade.ResultRetcode() == TRADE_RETCODE_DONE);
}

bool HLVManualClose()
{
   bool any = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(g_hlvTrade.PositionClose(tk)) any = true;
   }
   return any;
}

//+------------------------------------------------------------------+
//| Painel: criar / atualizar / destruir                              |
//+------------------------------------------------------------------+
void HLVPanelDelete()
{
   ObjectsDeleteAll(0, "LWFX_");
}

void HLVPanelCreate()
{
   HLVPanelDelete();

   // Fundo (navy) + barra de acento verde no topo
   HLVRRect(LWFX_BG, 10, 25, 272, 232, HLVX_NAVY, HLVX_LINE);
   HLVRRect(LWFX_ACCENT, 10, 25, 272, 3, HLVX_GREEN, HLVX_GREEN);

   // Cabecalho
   HLVRLabel(LWFX_TITLE, 22, 33, "HANDLIV - LIVWELL FOREX", HLVX_GREEN, 9, "Arial Black");
   HLVRRect(LWFX_SEP, 22, 55, 248, 1, HLVX_LINE, HLVX_LINE);

   // Conta / status
   HLVRLabel(LWFX_ACCT, 22, 62,
             "CONTA " + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + " - " + AccountInfoString(ACCOUNT_CURRENCY),
             HLVX_FAINT, 8);
   HLVRLabel(LWFX_STATUS, 22, 78, "* ROBO OPERANDO", HLVX_GREEN, 8, "Arial", ANCHOR_LEFT_UPPER);

   // Linhas: rotulo a esquerda / valor a direita
   HLVRLabel(LWFX_L1, 22, 98,  "PATRIMONIO",       HLVX_FAINT, 8);
   HLVRLabel(LWFX_V1, 260, 96, "0,00",             HLVX_WHITE, 9, "Arial", ANCHOR_RIGHT_UPPER);
   HLVRLabel(LWFX_L2, 22, 116, "SALDO",            HLVX_FAINT, 8);
   HLVRLabel(LWFX_V2, 260, 114, "0,00",            HLVX_WHITE, 9, "Arial", ANCHOR_RIGHT_UPPER);
   HLVRLabel(LWFX_L3, 22, 134, "FLUTUANTE",         HLVX_FAINT, 8);
   HLVRLabel(LWFX_V3, 260, 132, "0,00",             HLVX_WHITE, 9, "Arial", ANCHOR_RIGHT_UPPER);
   HLVRLabel(LWFX_L4, 22, 152, "P/L HOJE",          HLVX_FAINT, 8);
   HLVRLabel(LWFX_V4, 260, 150, "0,00",             HLVX_WHITE, 9, "Arial", ANCHOR_RIGHT_UPPER);
   HLVRLabel(LWFX_L5, 22, 170, "POSICOES ABERTAS",  HLVX_FAINT, 8);
   HLVRLabel(LWFX_V5, 260, 168, "0",                HLVX_WHITE, 9, "Arial", ANCHOR_RIGHT_UPPER);
   HLVRLabel(LWFX_L6, 22, 188, "SPREAD",            HLVX_FAINT, 8);
   HLVRLabel(LWFX_V6, 260, 186, "0 PTS",            HLVX_FAINT, 9, "Arial", ANCHOR_RIGHT_UPPER);

   // Volume + botoes
   HLVRLabel(LWFX_VOL, 22, 203, "VOLUME MANUAL: " + DoubleToString(InpHLVVolume, 2) + " LOTES", HLVX_FAINT, 7);
   HLVRButton(LWFX_BTN_BUY,   22,  216, 78, 28, "COMPRAR", HLVX_UP);
   HLVRButton(LWFX_BTN_SELL,  106, 216, 78, 28, "VENDER",  HLVX_DOWN);
   HLVRButton(LWFX_BTN_CLOSE, 190, 216, 80, 28, "FECHAR",  HLVX_AMBER);

   HLVPanelUpdate();
}

void HLVPanelUpdate()
{
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double flo = AccountInfoDouble(ACCOUNT_PROFIT);
   double day = HLVDayProfit();
   int    pos = PositionsTotal();
   int    spd = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   string cur = AccountInfoString(ACCOUNT_CURRENCY);

   HLVSetText(LWFX_V1, HLVFmt(eq) + " " + cur);
   HLVSetText(LWFX_V2, HLVFmt(bal) + " " + cur);
   HLVSetText(LWFX_V3, HLVMoney(flo));
   HLVSetColor(LWFX_V3, flo >= 0 ? HLVX_UP : HLVX_DOWN);
   HLVSetText(LWFX_V4, HLVMoney(day));
   HLVSetColor(LWFX_V4, day >= 0 ? HLVX_UP : HLVX_DOWN);
   HLVSetText(LWFX_V5, IntegerToString(pos));
   HLVSetColor(LWFX_V5, pos > 0 ? HLVX_BLUE : HLVX_FAINT);
   HLVSetText(LWFX_V6, IntegerToString(spd) + " PTS");

   // Status: volta ao padrao 8s apos uma acao manual
   if(TimeCurrent() - g_hlvStatusAt > 8)
   {
      g_hlvStatus   = "* ROBO OPERANDO";
      g_hlvStatusOk = true;
   }
   HLVSetText(LWFX_STATUS, g_hlvStatus);
   HLVSetColor(LWFX_STATUS, g_hlvStatusOk ? HLVX_GREEN : HLVX_DOWN);

   ChartRedraw(0);
}

void HLVPanelPoll()
{
   if(!InpHLVShowPanel) return;
   if(ObjectFind(0, LWFX_BTN_BUY) < 0) return;

   if(ObjectGetInteger(0, LWFX_BTN_BUY, OBJPROP_STATE))
   {
      ObjectSetInteger(0, LWFX_BTN_BUY, OBJPROP_STATE, false);
      bool ok = HLVManualBuy();
      g_hlvStatus   = (ok ? "* COMPRA EXECUTADA " : "* COMPRA FALHOU ") + TimeToString(TimeCurrent(), TIME_SECONDS);
      g_hlvStatusOk = ok;
      g_hlvStatusAt = TimeCurrent();
      HLVPanelUpdate();
   }
   if(ObjectGetInteger(0, LWFX_BTN_SELL, OBJPROP_STATE))
   {
      ObjectSetInteger(0, LWFX_BTN_SELL, OBJPROP_STATE, false);
      bool ok = HLVManualSell();
      g_hlvStatus   = (ok ? "* VENDA EXECUTADA " : "* VENDA FALHOU ") + TimeToString(TimeCurrent(), TIME_SECONDS);
      g_hlvStatusOk = ok;
      g_hlvStatusAt = TimeCurrent();
      HLVPanelUpdate();
   }
   if(ObjectGetInteger(0, LWFX_BTN_CLOSE, OBJPROP_STATE))
   {
      ObjectSetInteger(0, LWFX_BTN_CLOSE, OBJPROP_STATE, false);
      bool ok = HLVManualClose();
      g_hlvStatus   = (ok ? "* POSICOES FECHADAS " : "* NADA PARA FECHAR ") + TimeToString(TimeCurrent(), TIME_SECONDS);
      g_hlvStatusOk = ok;
      g_hlvStatusAt = TimeCurrent();
      HLVPanelUpdate();
   }
}
//+------------------------------------------------------------------+
