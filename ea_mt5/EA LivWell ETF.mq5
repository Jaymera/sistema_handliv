//+------------------------------------------------------------------+
//|                                                     EA CURSO.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright   "2023 - Handliv®️"
#property link        "https://handliv.com"
#property version     "1.08"
#property description "Attention"
#property description "Handliv is not responsible for any losses that may occur due to the incorrect use of the program,"
#property description "by using this program you agree that you are aware of all risks associated with financial market and automatic trading,"
#property description "assuming full responsibility for the operations performed by the program."
#property strict
#property description ""
#property description "Contact: faleconosco.handliv@gmail.com | +39 350 164 5248"
//#property icon          "logo_robo.ico"

//#resource  "\\Indicators\\LivWell Indicators.ex5";
////#resource  "\\Indicators\\macd_histogram.ex5";

#include <Trade/Trade.mqh>
//#include <Modulos_EA.mqh>
//#include <MQLMySQL.mqh>
//#include <RenkoBluebyte.mqh>
#include <Trade\SymbolInfo.mqh>
//#include  "includes\\CReentrie.mqh"

CSymbolInfo           m_symbol;                     // Objeto de informação de símbolo

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
//|        INCLUDE DO SYMBOL
//+------------------------------------------------------------------+
class SYMBOL
{
public:
  const string Name;

  SYMBOL( const string Symb = NULL, const string Path = NULL ) : Name((Symb == NULL) ? _Symbol : Symb)
  {
    if (!SYMBOL::SymbolIsExist(this.Name))
      ::CustomSymbolCreate(this.Name, Path);
  }

  static bool SymbolIsExist( const string Symb = NULL )
  {
    ::ResetLastError();

    ::SymbolInfoInteger((Symb == NULL) ? _Symbol : Symb, SYMBOL_CUSTOM);

    return(::GetLastError() != ERR_MARKET_UNKNOWN_SYMBOL);
  }

  bool SetProperty( const ENUM_SYMBOL_INFO_DOUBLE Property, double Value ) const
  {
    return(::CustomSymbolSetDouble(this.Name, Property, Value));
  }

  bool SetProperty( const ENUM_SYMBOL_INFO_INTEGER Property, long Value ) const
  {
    return(::CustomSymbolSetInteger(this.Name, Property, Value));
  }

  bool SetProperty( const ENUM_SYMBOL_INFO_STRING Property, string Value ) const
  {
    return(::CustomSymbolSetString(this.Name, Property, Value));
  }

  long GetProperty( const ENUM_SYMBOL_INFO_INTEGER Property ) const
  {
    return(::SymbolInfoInteger(this.Name, Property));
  }

  double GetProperty( const ENUM_SYMBOL_INFO_DOUBLE Property ) const
  {
    return(::SymbolInfoDouble(this.Name, Property));
  }

  string GetProperty( const ENUM_SYMBOL_INFO_STRING Property ) const
  {
    return(::SymbolInfoString(this.Name, Property));
  }

  bool Delete( void ) const
  {
    return(this.IsCustom() && this.Off() && ::CustomSymbolDelete(this.Name));
  }

#define CLONE(A) this.SetProperty(A, Source.GetProperty(A))

  bool CloneProperties( const string Symb = NULL ) const
  {
    const SYMBOL Source(Symb);

    return(SYMBOL::SymbolIsExist(Symb) && this.IsCustom() &&
    CLONE(SYMBOL_BASIS) &&
    CLONE(SYMBOL_CURRENCY_BASE) &&
    CLONE(SYMBOL_CURRENCY_MARGIN) &&
    CLONE(SYMBOL_CURRENCY_PROFIT) &&
    CLONE(SYMBOL_DESCRIPTION) &&
    CLONE(SYMBOL_FORMULA) &&
    CLONE(SYMBOL_ISIN) &&
    CLONE(SYMBOL_PAGE) &&
//    CLONE(SYMBOL_PATH) &&

    CLONE(SYMBOL_MARGIN_HEDGED) &&
    CLONE(SYMBOL_MARGIN_INITIAL) &&
    CLONE(SYMBOL_MARGIN_MAINTENANCE) &&
    CLONE(SYMBOL_OPTION_STRIKE) &&
    CLONE(SYMBOL_POINT) &&
    CLONE(SYMBOL_SESSION_PRICE_LIMIT_MAX) &&
    CLONE(SYMBOL_SESSION_PRICE_LIMIT_MIN) &&
    CLONE(SYMBOL_SESSION_PRICE_SETTLEMENT) &&
    CLONE(SYMBOL_SWAP_LONG) &&
    CLONE(SYMBOL_SWAP_SHORT) &&
    CLONE(SYMBOL_TRADE_ACCRUED_INTEREST) &&
    CLONE(SYMBOL_TRADE_CONTRACT_SIZE) &&
    CLONE(SYMBOL_TRADE_FACE_VALUE) &&
    CLONE(SYMBOL_TRADE_LIQUIDITY_RATE) &&
    CLONE(SYMBOL_TRADE_TICK_SIZE) &&
    CLONE(SYMBOL_TRADE_TICK_VALUE) &&
    CLONE(SYMBOL_VOLUME_LIMIT) &&
    CLONE(SYMBOL_VOLUME_MAX) &&
    CLONE(SYMBOL_VOLUME_MIN) &&
    CLONE(SYMBOL_VOLUME_STEP) &&

    CLONE(SYMBOL_BACKGROUND_COLOR) &&
    CLONE(SYMBOL_CHART_MODE) &&
    CLONE(SYMBOL_DIGITS) &&
    CLONE(SYMBOL_EXPIRATION_MODE) &&
    CLONE(SYMBOL_EXPIRATION_TIME) &&
    CLONE(SYMBOL_FILLING_MODE) &&
    CLONE(SYMBOL_MARGIN_HEDGED_USE_LEG) &&
    CLONE(SYMBOL_OPTION_MODE) &&
    CLONE(SYMBOL_OPTION_RIGHT) &&
    CLONE(SYMBOL_ORDER_GTC_MODE) &&
    CLONE(SYMBOL_ORDER_MODE) &&
    CLONE(SYMBOL_SPREAD) &&
    CLONE(SYMBOL_SPREAD_FLOAT) &&
    CLONE(SYMBOL_START_TIME) &&
    CLONE(SYMBOL_SWAP_MODE) &&
    CLONE(SYMBOL_SWAP_ROLLOVER3DAYS) &&
    CLONE(SYMBOL_TICKS_BOOKDEPTH) &&
    CLONE(SYMBOL_TRADE_CALC_MODE) &&
    CLONE(SYMBOL_TRADE_EXEMODE) &&
    CLONE(SYMBOL_TRADE_FREEZE_LEVEL) &&
    CLONE(SYMBOL_TRADE_MODE) &&
    CLONE(SYMBOL_TRADE_STOPS_LEVEL));
  }

#undef CLONE

  int CloneHistory( string Symb = NULL ) const
  {
    return(::MathMax(this.CloneRates(Symb), this.CloneTicks(Symb)));
  }

  int CloneRates( const MqlRates &Rates[] ) const
  {
    return(this.IsCustom() ? ::CustomRatesReplace(this.Name, 0, LONG_MAX, Rates) : -1);
  }

  int CloneRates( string Symb = NULL ) const
  {
    int Res = this.IsCustom() && SYMBOL::SymbolIsExist(Symb) ? 0 : -1;

    if (Res != -1)
    {
      Symb = (Symb == NULL) ? _Symbol : Symb;
      MqlRates Rates[];

      ::CopyRates(Symb, PERIOD_M1, 0, ::Bars(Symb, PERIOD_M1), Rates);

      Res = this.CloneRates(Rates);
    }

    return(Res);
  }

  int CloneTicks( const MqlTick &Ticks[] ) const
  {
    return(this.IsCustom() ? ::CustomTicksReplace(this.Name, 0, LONG_MAX, Ticks) : -1);
  }

  int CloneTicks( string Symb = NULL ) const
  {
    Symb = (Symb == NULL) ? _Symbol : Symb;

    int Res = this.IsCustom() && ::SymbolInfoInteger(Symb, SYMBOL_CUSTOM) ? 0 : -1;

    if (Res != -1)
    {
      MqlTick Ticks[];

      ::CopyTicksRange(Symb, Ticks, COPY_TICKS_ALL, 0, LONG_MAX);

      Res = this.CloneTicks(Ticks);
    }

    return(Res);
  }

  bool Clone( const string Symb = NULL ) const
  {
    return(this.CloneProperties(Symb) && (this.CloneHistory(Symb) != -1));
  }

  virtual bool operator =( const string Symb ) const
  {
    return(this.Clone(Symb));
  }

  bool On( void ) const
  {
    return(::SymbolSelect(this.Name, true));
  }

  bool Off( void ) const
  {
    return(::SymbolSelect(this.Name, false));
  }

  bool IsCustom( void ) const
  {
    //return(this.GetProperty(SYMBOL_CUSTOM));
    bool retorno = this.GetProperty(SYMBOL_CUSTOM);
    return(retorno);
  }

  bool IsExist( void ) const
  {
    return(SYMBOL::SymbolIsExist(this.Name));
  }
};

//+------------------------------------------------------------------+
//|                                                LivWellRenko.mqh |
//|                                Copyright 2022, Handliv.         |
//+------------------------------------------------------------------+
//| includes                                                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2020                                                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2020.1                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2021.2                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2020.3                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2020.4                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2021.1                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2021.2                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2021.3                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2021.4                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2021.5                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2022.1                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| UPDATE 2022.2                                                    |
//+------------------------------------------------------------------+
//#include "Symbol.mqh"
//+------------------------------------------------------------------+
//| types                                                            |
//+------------------------------------------------------------------+
enum ENUM_RENKO_TYPE
  {
   RENKO_TYPE_TICKS, //Ticks
   RENKO_TYPE_PIPS,  //Pips
   RENKO_TYPE_POINTS //Points
  };
//Enum
enum ENUM_RENKO_WINDOW
  {
   RENKO_NO_WINDOW,        //No Window
   RENKO_CURRENT_WINDOW,   //Current Window
   RENKO_NEW_WINDOW,       //New Window
   RENKO_MINI_CHART        //Mini Chart
  };
//+------------------------------------------------------------------+
//| class                                                            |
//+------------------------------------------------------------------+
class RenkoCharts
  {
   //Internal Variables
private:
   MqlTick           ticks[];             //Ticks buffer
   MqlRates rates[],             //Rates buffer
            renko_buffer[];      //Renko buffer
   string   renko_symbol,        //Original symbol
            custom_symbol;       //Custom symbol
   double   renko_size,          //Renko size
            brick_size,          //Brick size
            up_wick,             //Upper wick size
            down_wick,           //Down wick size
            last_price;          //Last price
   long     tick_volumes,        //Tick Volumes
            volumes;             //Volumes
   bool              show_wicks;          //Show renko wicks
   ENUM_RENKO_TYPE   renko_type;
   //Methods
public:
                     RenkoCharts();
                    ~RenkoCharts();
                     RenkoCharts(string symbol, ENUM_RENKO_TYPE type, double size, bool wicks);
   bool              Setup(string symbol, ENUM_RENKO_TYPE type, double size, bool wicks);
   int               LoadFrom(datetime start);
   long              LoadVolumes(datetime start, bool ticks);
   int               UpdateRates();
   int               UpdatePrice(double price, datetime time, long tick_volume, long volume, int spread);
   int               ClearRates();
   double            GetValue(int buffer, int index);
   double            GetValueAsSeries(int buffer, int index);
   //Custom Symbol Methods
   string            GetSymbolName();
   void              CreateCustomSymbol(string name);
   bool              CheckCustomSymbol();
   int               ClearCustomSymbol();
   int               ReplaceCustomSymbol();
   int               UpdateCustomSymbol(int count);
   long              OpenCustomSymbol();
   void              SetCustomSymbol(long chart_id);
   bool              ValidateSymbol(string &name);
   int               UpdateCustomTick();
   //Event Methods
   void              Start(ENUM_RENKO_WINDOW window);
   void              Stop();
   void              Refresh();
   //Internal Methods
private:
   int               AddOne(datetime time);
   int               CloseUp(double points, datetime time, int spread);
   int               CloseDown(double points, datetime time, int spread);
   int               LoadPrice(double price, datetime time, long tick_volume, long volume, int spread);
   int               LoadPrice(const MqlRates &price);
   int               LoadPriceOHLC(const MqlRates &price);
   void              MiniChartCustomSymbol();
  };
//+------------------------------------------------------------------+
//| methods                                                          |
//+------------------------------------------------------------------+
//Default Constructors
RenkoCharts::RenkoCharts()
  {
   Setup(_Symbol, RENKO_TYPE_TICKS, 20, true);
   return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
RenkoCharts::RenkoCharts(string symbol, ENUM_RENKO_TYPE type = RENKO_TYPE_TICKS, double size = 20, bool wicks = true)
  {
   Setup(symbol, type, size, wicks);
   return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
RenkoCharts::~RenkoCharts()
  {
   ArrayFree(rates);
   ArrayFree(renko_buffer);
  }

//Setup
bool RenkoCharts::Setup(string symbol, ENUM_RENKO_TYPE type = RENKO_TYPE_TICKS, double size = 20, bool wicks = true)
  {
//Check Symbol
   if(symbol == "" || symbol == NULL || SymbolInfoInteger(symbol, SYMBOL_CUSTOM))
     {
      Print("Símbolo inválido selecionado.");
      return(false);
     }
//Select Symbol
   if(SymbolSelect(symbol, true) == false)
     {
      Print("Erro de seleção de símbolo.");
      return(false);
     }
//Renko setup
   renko_symbol = symbol;
   renko_type = type;
   renko_size = size;
   show_wicks = wicks;
//Renko brick size
   int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pip_size = (digits == 5 || digits == 3) ? points * 10 : points;
   if(renko_type == RENKO_TYPE_TICKS)
      brick_size = renko_size * tick_size;
   else
      if(renko_type == RENKO_TYPE_PIPS)
         brick_size = renko_size * pip_size;
      else
         brick_size = renko_size;
//Invalid brick size
   if(brick_size <= 0)
     {
      Print("Tamanho de tijolo inválido. Valor de ", brick_size, " selecionada.");
      return(false);
     }
//Minimum brick size
   if(brick_size < tick_size)
     {
      brick_size = tick_size;
      Print("Tamanho de tijolo inválido. Valor mínimo de ", brick_size, " será usado.");
     }
   brick_size = NormalizeDouble(brick_size, digits);
//Success
   return(true);
  }

//Add one to buffer array
int RenkoCharts::AddOne(datetime time = 0)
  {
//Resize buffers
   int index = ArrayResize(renko_buffer, ArraySize(renko_buffer)+1, 100000) - 1;
   if(index <= 0)
      return 0;
//Time
   if(time == 0)
      time = TimeCurrent();
   if(time <= renko_buffer[index-1].time)
      renko_buffer[index].time = renko_buffer[index-1].time+60;
   else
      renko_buffer[index].time = time;
//Defaults
   renko_buffer[index].open = renko_buffer[index].high = renko_buffer[index].low = renko_buffer[index].close = renko_buffer[index-1].close;
   renko_buffer[index].tick_volume = renko_buffer[index].real_volume = 0;
   renko_buffer[index].spread = 0;
   return index;
  }

//Add positive renko bar
int RenkoCharts::CloseUp(double points, datetime time=0, int spread=0)
  {
   int index = ArraySize(renko_buffer) -1;
//OHLC
   renko_buffer[index].open = renko_buffer[index-1].close + points - brick_size;
   renko_buffer[index].high = renko_buffer[index-1].close + points;
   renko_buffer[index].close = renko_buffer[index-1].close+points;
//Wicks
   if(show_wicks && down_wick < renko_buffer[index-1].close)
      renko_buffer[index].low = down_wick;
   else
      renko_buffer[index].low = renko_buffer[index].open;
   up_wick = down_wick = renko_buffer[index].close;
//Volumes
   renko_buffer[index].tick_volume = tick_volumes;
   renko_buffer[index].real_volume = volumes;
   renko_buffer[index].spread = spread;
   tick_volumes = volumes = 0;
//Add one
   return AddOne(time);
  }

//Add negative renko bar
int RenkoCharts::CloseDown(double points, datetime time=0, int spread=0)
  {
   int index = ArraySize(renko_buffer) -1;
//OHLC
   renko_buffer[index].open = renko_buffer[index-1].close-points+brick_size;
   renko_buffer[index].low = renko_buffer[index-1].close-points;
   renko_buffer[index].close = renko_buffer[index-1].close-points;
//Wicks
   if(show_wicks && up_wick > renko_buffer[index-1].close)
      renko_buffer[index].high = up_wick;
   else
      renko_buffer[index].high = renko_buffer[index].open;
   up_wick = down_wick = renko_buffer[index].close;
//Volumes
   renko_buffer[index].tick_volume = tick_volumes;
   renko_buffer[index].real_volume = volumes;
   renko_buffer[index].spread = spread;
   tick_volumes = volumes = 0;
//Add one
   return AddOne(time);
  }

//Load price information
int RenkoCharts::LoadPrice(double price, datetime time=0, long tick_volume=0, long volume=0, int spread=0)
  {
   static datetime last_time;
   static long last_tick_volume, last_volume;
//Time
   if(time == 0)
      time = TimeCurrent();
//Buffer size
   int size = ArraySize(renko_buffer);
   int index = size-1;
//First bricks
   if(size==0)
     {
      //1st Buffers
      ArrayResize(renko_buffer, 2, 1000);
      renko_buffer[1].time = time - 60;
      renko_buffer[1].close = renko_buffer[1].high = NormalizeDouble(MathFloor(price/brick_size) * brick_size,_Digits);
      renko_buffer[1].open = renko_buffer[1].low = renko_buffer[1].close - brick_size;
      renko_buffer[1].tick_volume = renko_buffer[1].real_volume = 0;
      renko_buffer[1].spread = 0;
      renko_buffer[0].time = renko_buffer[1].time - 120;
      renko_buffer[0].open = renko_buffer[0].low = renko_buffer[1].open - brick_size;
      renko_buffer[0].high = renko_buffer[0].close = renko_buffer[1].open;
      renko_buffer[0].tick_volume = renko_buffer[0].real_volume = 0;
      renko_buffer[0].spread = 0;
      //Current Buffer
      index = AddOne(time);
     }
//Time change
   if(time != last_time)
     {
      last_time = time;
      tick_volumes += last_tick_volume;
      volumes += last_volume;
     }
//Volume change
   last_tick_volume = tick_volume;
   last_volume = volume;
//Wicks
   up_wick = MathMax(up_wick, price);
   down_wick = MathMin(down_wick, price);
   if(down_wick<=0)
      down_wick = price;
//Price change
   if(price != last_price)
     {
      last_price = price;
      //Up
      if(renko_buffer[index-1].close >= renko_buffer[index-2].close)
        {
         if(price >= renko_buffer[index-1].close+brick_size)
           {
            for(; price >= renko_buffer[index-1].close+brick_size;)
               index = CloseUp(brick_size, time, spread);
           }
         //Down 2x
         else
            if(price <= renko_buffer[index-1].close-2.0*brick_size)
              {
               index = CloseDown(2.0*brick_size, time, spread);
               for(; price <= renko_buffer[index-1].close-brick_size;)
                  index = CloseDown(brick_size, time, spread);
              }
        }
      //Down
      if(renko_buffer[index-1].close <= renko_buffer[index-2].close)
        {
         if(price <= renko_buffer[index-1].close-brick_size)
           {
            for(; price <= renko_buffer[index-1].close-brick_size;)
               index = CloseDown(brick_size, time, spread);
           }
         //Up 2x
         else
            if(price >= renko_buffer[index-1].close+2.0*brick_size)
              {
               index = CloseUp(2.0*brick_size, time, spread);
               for(; price >= renko_buffer[index-1].close+brick_size;)
                  index = CloseUp(brick_size, time, spread);
              }
        }
     }
//Current buffer
   renko_buffer[index].open = renko_buffer[index-1].close;
   renko_buffer[index].high = MathMax(up_wick, price);
   renko_buffer[index].low = MathMin(down_wick, price);
   renko_buffer[index].close = price;
   renko_buffer[index].tick_volume = tick_volumes + tick_volume;
   renko_buffer[index].real_volume = volumes + volume;
   renko_buffer[index].spread = spread;

   return index + 1;
  }

//Load price rates information
int RenkoCharts::LoadPrice(const MqlRates &price)
  {
//Price
   return LoadPrice(price.close, price.time, price.tick_volume, price.real_volume, price.spread);
  }

//Load OHLC price rates information
int RenkoCharts::LoadPriceOHLC(const MqlRates &price)
  {
   LoadPrice(price.open, price.time, 0, 0, price.spread);
   if(price.close > price.open)
     {
      LoadPrice(price.low, price.time, 0, 0, price.spread);
      LoadPrice(price.high, price.time, 0, 0, price.spread);
     }
   else
     {
      LoadPrice(price.high, price.time, 0, 0, price.spread);
      LoadPrice(price.low, price.time, 0, 0, price.spread);
     }
   return LoadPrice(price.close, price.time, price.tick_volume, price.real_volume, price.spread);
  }

//Load history
int RenkoCharts::LoadFrom(datetime start = 0)
  {
   ResetLastError();
   int total, size = ArraySize(renko_buffer);
//Copy rates
   if(size == 0)
      total = CopyRates(renko_symbol, PERIOD_M1, 0, 1000000, rates);
   else
      total = CopyRates(renko_symbol, PERIOD_M1, start - 59, TimeCurrent(), rates);
//Return
   if(total <= 0)
      return 0;
   else
      if(total == 1)
         size = LoadPrice(rates[0]);
      else
         for(int i=0; i<total; i++)
            size = LoadPriceOHLC(rates[i]);
   return size;
  }

//Update Rates
int RenkoCharts::UpdateRates()
  {
   static datetime last_update = 0;
   int size = LoadFrom(last_update);
   last_update = TimeCurrent();
   return size;
  }

//Clear Rates
int RenkoCharts::ClearRates()
  {
   return ArrayResize(renko_buffer, 0);
  }

//Get values
double RenkoCharts::GetValue(int buffer = 0, int index = -1)
  {
   index = (index<0) ? ArraySize(renko_buffer)-1 : index;
   if(index<0)
      return EMPTY_VALUE;
   switch(buffer)
     {
      case  0:
         return (double) renko_buffer[index].time;
         break; //Time
      case  1:
         return          renko_buffer[index].open;
         break; //Open
      case  2:
         return          renko_buffer[index].high;
         break; //High
      case  3:
         return          renko_buffer[index].low;
         break; //Low
      case  4:
         return          renko_buffer[index].close;
         break; //Close
      case  5:
         return (double) renko_buffer[index].tick_volume;
         break; //Tick volume
      case  6:
         return (double) renko_buffer[index].real_volume;
         break; //Volume
      case  7:
         return (double) renko_buffer[index].spread;
         break; //Spread
      case  8:
         return (double) renko_buffer[index].open < renko_buffer[index].close ? 1 : renko_buffer[index].open == renko_buffer[index].close ? 0 : -1;
         break; //Direction
      default:
         return EMPTY_VALUE;
         break;
     }
  }

//Get values as Series
double RenkoCharts::GetValueAsSeries(int buffer = 0, int index = -1)
  {
   index = ArraySize(renko_buffer)-index;
   index = (index<=0) ? ArraySize(renko_buffer)-1 : index-1;
   if(index<0)
      return EMPTY_VALUE;
   switch(buffer)
     {
      case  0:
         return (double) renko_buffer[index].time;
         break; //Time
      case  1:
         return          renko_buffer[index].open;
         break; //Open
      case  2:
         return          renko_buffer[index].high;
         break; //High
      case  3:
         return          renko_buffer[index].low;
         break; //Low
      case  4:
         return          renko_buffer[index].close;
         break; //Close
      case  5:
         return (double) renko_buffer[index].tick_volume;
         break; //Tick volume
      case  6:
         return (double) renko_buffer[index].real_volume;
         break; //Volume
      case  7:
         return (double) renko_buffer[index].spread;
         break; //Spread
      case  8:
         return (double) renko_buffer[index].open < renko_buffer[index].close ? 1 : renko_buffer[index].open == renko_buffer[index].close ? 0 : -1;
         break; //Direction
      default:
         return EMPTY_VALUE;
         break;
     }
  }

//+------------------------------------------------------------------+
//| custom symbol methods                                            |
//+------------------------------------------------------------------+
//Return custom symbol name
string RenkoCharts::GetSymbolName()
  {
   return custom_symbol;
  }

//Create renko custom symbol
void RenkoCharts::CreateCustomSymbol(string name = "")
  {
   custom_symbol = name;
//Symbol name
   if(name == "" || name == NULL)
     {
      string sufix = StringFormat("%g", renko_size);
      if(renko_type == RENKO_TYPE_TICKS)
         sufix += "TICKS";
      else
         if(renko_type == RENKO_TYPE_PIPS)
            sufix += "PIPS";
         else
            sufix += "POINTS";
      custom_symbol = renko_symbol + "_" + sufix;
     }
//Create symbol
   const SYMBOL Symb(custom_symbol, "RenkoCharts");
   Symb.CloneProperties(renko_symbol);
   Symb.On();
//Select Custom Symbol
   if(SymbolSelect(custom_symbol, true) == false)
      Print("Custom Symbol selection error.");
   return;
  }

//Check custom symbol
bool RenkoCharts::CheckCustomSymbol()
  {
   if(custom_symbol == "" || custom_symbol == NULL)
      return(false);
   //return(SymbolInfoInteger(custom_symbol, SYMBOL_CUSTOM));
   bool retorno = SymbolInfoInteger(custom_symbol, SYMBOL_CUSTOM);
   return(retorno);
  }

//Clear custom symbol rates
int RenkoCharts::ClearCustomSymbol()
  {
   if(!CheckCustomSymbol())
      return 0;
   return CustomRatesDelete(custom_symbol, D'1970.01.01 00:00', D'3000.12.31 00:00');
  }

//Update custom symbol rates
int RenkoCharts::ReplaceCustomSymbol()
  {
   if(!CheckCustomSymbol())
      return 0;
   return CustomRatesUpdate(custom_symbol, renko_buffer);
  }

//Refresh custom symbol last rates
int RenkoCharts::UpdateCustomSymbol(int count = 0)
  {
   static int last_position = 0;
   if(!CheckCustomSymbol())
      return 0;
//Update buffer
   MqlRates update_buffer[];
   ArraySetAsSeries(update_buffer, true);
//Start position
   int start = last_position - count;
   if(start < 0)
      start = 0;
//Copy last buffer
   int copied = ArrayCopy(update_buffer, renko_buffer, 0, start);
   if(copied <= 0)
      return 0;
//Save last position
   last_position = ArraySize(renko_buffer) - 1;
   return CustomRatesUpdate(custom_symbol, update_buffer);
  }

//Update custom tick
int RenkoCharts::UpdateCustomTick()
  {
   if(!CheckCustomSymbol())
      return 0;
//Get current tick
   int copied = CopyTicks(renko_symbol, ticks, COPY_TICKS_ALL, 0, 1);
   if(copied <= 0)
      return 0;
//Update current tick
   ticks[0].time = (datetime) GetValue(0); //Time buffer
   ticks[0].time_msc = 1000 * (long) ticks[0].time;
//Update Custom Tick
   copied = CustomTicksAdd(custom_symbol, ticks);
   return copied;
  }

//Open custom symbol window
long RenkoCharts::OpenCustomSymbol()
  {
   if(!CheckCustomSymbol())
      return -1;
   long chart_handle = ChartOpen(custom_symbol, PERIOD_M1);
   ChartSetInteger(chart_handle, CHART_MODE, CHART_CANDLES);
   return chart_handle;
  }

//Set chart current symbol
void RenkoCharts::SetCustomSymbol(long chart_id = 0)
  {
   if(!CheckCustomSymbol())
      return;
   ChartSetSymbolPeriod(chart_id, custom_symbol, PERIOD_M1);
   ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES);
  }

//Validate original symbol
bool RenkoCharts::ValidateSymbol(string &name)
  {
   if(name=="" || name==NULL)
      name = _Symbol;
   if(SymbolInfoInteger(name, SYMBOL_CUSTOM))
     {
      string new_name = StringAt(name, "_");
      if(SymbolInfoInteger(new_name, SYMBOL_CUSTOM))
         return false;
      else
         name = new_name;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| event methods                                                    |
//+------------------------------------------------------------------+

//Creates OnBookEvent on renko symbol
void RenkoCharts::Start(ENUM_RENKO_WINDOW window = RENKO_NO_WINDOW)
  {
//Open/Set Custom Symbol
   Print("Atualizando símbolo personalizado: ", custom_symbol);
   if(window == RENKO_NEW_WINDOW)
     {
      Comment("Atualizando símbolo personalizado: ", custom_symbol);
      OpenCustomSymbol();
     }
   else
      if(window == RENKO_CURRENT_WINDOW)
        {
         SetCustomSymbol();
        }
      else
         if(window == RENKO_MINI_CHART)
           {
            MiniChartCustomSymbol();
           }
   MarketBookAdd(renko_symbol);
  }

//Release OnBookEvent
void RenkoCharts::Stop()
  {
//---
   Comment("");
   MarketBookRelease(renko_symbol);
   ObjectDelete(0,custom_symbol);
  }

//Refresh rates on OnTick and OnBookEvent events
void RenkoCharts::Refresh()
  {
   static datetime last_update;
   static int last_size;
//Update custom symbol
   int size = UpdateRates();
   if(last_size != size)
      if(TimeCurrent() - last_update > 60)
         ReplaceCustomSymbol();
      else
         UpdateCustomSymbol();
//Update custom tick
   UpdateCustomTick();
   last_update = TimeCurrent();
   last_size = size;
  }

//Open selectable mini-chart
void RenkoCharts::MiniChartCustomSymbol()
  {
   ObjectCreate(0,custom_symbol,OBJ_CHART,0,0,0);
   ObjectSetString(0,custom_symbol,OBJPROP_SYMBOL,custom_symbol);
   ObjectSetInteger(0,custom_symbol,OBJPROP_XDISTANCE,0);
   ObjectSetInteger(0,custom_symbol,OBJPROP_YDISTANCE,200);
   ObjectSetInteger(0,custom_symbol,OBJPROP_XSIZE,300);
   ObjectSetInteger(0,custom_symbol,OBJPROP_YSIZE,200);
   ObjectSetInteger(0,custom_symbol,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,custom_symbol,OBJPROP_PERIOD,PERIOD_M1);
   ObjectSetInteger(0,custom_symbol,OBJPROP_CHART_SCALE,3);
   ObjectSetInteger(0,custom_symbol,OBJPROP_DATE_SCALE,false);
   ObjectSetInteger(0,custom_symbol,OBJPROP_BACK,false);
   ObjectSetInteger(0,custom_symbol,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,custom_symbol,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,custom_symbol,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
//| custom functions                                                 |
//+------------------------------------------------------------------+
string StringAt(string text, string separator, int position = 0)
  {
   string result[];
   ushort s = StringGetCharacter(separator, 0);
   int n = StringSplit(text, s, result);
   if(position < n)
      return result[position];
   else
      return "";
  }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
/********************************************************************
 * MQLMySQL interface library                                       *
 ********************************************************************
 * This library uses MQLMySQL.DLL was developed as interface to con-*
 * nect to the MySQL database server.                               *
 * Note: Check expert advisor "Common" parameters to be sure that   *
 *       DLL imports are allowed.                                   *
 ********************************************************************/
//bool SQLTrace = false;
//datetime MySqlLastConnect=0;
//
//#import "..\libraries\MQLMySQL.dll"
//// returns version of MySqlCursor.dll library
//string cMySqlVersion ();
//
//// number of last error of connection
//int    cGetMySqlErrorNumber(int pConnection);
//
//// number of last error of cursor
//int    cGetCursorErrorNumber(int pCursorID);
//
//// description of last error for connection
//string cGetMySqlErrorDescription(int pConnection);
//
//// description of last error for cursor
//string cGetCursorErrorDescription(int pCursorID);
//
//// establish connection to MySql database server
//// and return connection identifier
//int    cMySqlConnect       (string pHost,       // Host name
//                            string pUser,       // User
//                            string pPassword,   // Password
//                            string pDatabase,   // Database name
//                            int    pPort,       // Port
//                            string pSocket,     // Socket for Unix
//                            int    pClientFlag);// Client flag
//// closes connection to database
//void   cMySqlDisconnect    (int pConnection);   // pConnection - database identifier (pointer to structure)
//// executes non-SELECT statements
//bool   cMySqlExecute       (int    pConnection, // pConnection - database identifier (pointer to structure)
//                            string pQuery);     // pQuery      - SQL query for execution
//// creates an cursor based on SELECT statement
//// return valuse - cursor identifier
//int    cMySqlCursorOpen    (int    pConnection, // pConnection - database identifier (pointer to structure)
//                            string pQuery);     // pQuery      - SELECT statement for execution
//// closes opened cursor
//void   cMySqlCursorClose   (int pCursorID);     // pCursorID  - internal identifier of cursor
//// return number of rows was selected by cursor
//int    cMySqlCursorRows    (int pCursorID);     // pCursorID  - internal identifier of cursor
//// fetch next row from cursor into current row buffer
//// return true - if succeeded, otherwise - false
//bool   cMySqlCursorFetchRow(int pCursorID);     // pCursorID  - internal identifier of cursor
//// retrieves the value from current row was fetched by cursor
//string cMySqlGetRowField   (int    pCursorID,   // pCursorID  - internal identifier of cursor
//                            int    pField);     // pField     - number of field in SELECT clause (started from 0,1,2... e.t.c.)
//
//// Reads and returns the key value from standard INI-file
//string ReadIni             (string pFileName,   // INI-filename
//                            string pSection,    // name of section
//                            string pKey);       // name of key
//#import
//
//
////interface variables
//int    MySqlErrorNumber;       // recent MySQL error number
//string MySqlErrorDescription;  // error description
//
//// return the version of MySQLCursor.DLL
//string MySqlVersion()
//{
// return(cMySqlVersion());
//}
//
//// Interface function MySqlConnect - make connection to MySQL database using parameter:
//// pHost       - DNS name or IP-address
//// pUser       - database user (f.e. root)
//// pPassword   - password of user (f.e. Zok1LmVdx)
//// pDatabase   - database name (f.e. metatrader)
//// pPort       - TCP/IP port of database listener (f.e. 3306)
//// pSocket     - unix socket (for sockets or named pipes using)
//// pClientFlag - combination of the flags for features (usual 0)
//// ------------------------------------------------------------------------------------
//// RETURN      - database connection identifier
////               if return value = 0, check MySqlErrorNumber and MySqlErrorDescription
//int MySqlConnect(string pHost, string pUser, string pPassword, string pDatabase, int pPort, string pSocket, int pClientFlag)
//{
// int connection;
// ClearErrors();
// connection = cMySqlConnect(pHost, pUser, pPassword, pDatabase, pPort, pSocket, pClientFlag);
//
// if (SQLTrace) Print ("Connecting to Host=", pHost, ", User=", pUser, ", Database=", pDatabase, " DBID#", connection);
//
// if (connection == -1)
//    {
//     MySqlErrorNumber = cGetMySqlErrorNumber(-1);
//     MySqlErrorDescription = cGetMySqlErrorDescription(-1);
//     if (SQLTrace) Print ("Connection error #",MySqlErrorNumber," ",MySqlErrorDescription);
//    }
// else
//    {
//     MySqlLastConnect = TimeCurrent();
//     if (SQLTrace) Print ("Connected! DBID#",connection);
//    }
// 
// return (connection);
//}
//
//// Interface function MySqlDisconnect - closes connection "pConnection" to database
//// When no connection was established - nothing happends
//void MySqlDisconnect(int &pConnection)
//{
// ClearErrors();
// if (pConnection != -1) 
//    {
//     cMySqlDisconnect(pConnection);
//     if (SQLTrace) Print ("DBID#",pConnection," disconnected");
//     pConnection = -1;
//    }
//}
//
//// Interface function MySqlExecute - executes SQL query via specified connection
//// pConnection - opened database connection
//// pQuery      - SQL query
//// ------------------------------------------------------
//// RETURN      - true : when execution succeded
////             - false: when any error was raised (see MySqlErrorNumber, MySqlErrorDescription, MySqlErrorQuery)
//bool MySqlExecute(int pConnection, string pQuery)
//{
// ClearErrors();
// if (SQLTrace) {Print ("DBID#",pConnection,", CMD:",pQuery);}
// if (pConnection == -1) 
//    {
//     // no connection
//     MySqlErrorNumber = -2;
//     MySqlErrorDescription = "No connection to the database.";
//     if (SQLTrace) Print ("CMD>",MySqlErrorNumber, ": ", MySqlErrorDescription);
//     return (false);
//    }
// 
// if (!cMySqlExecute(pConnection, pQuery))
//    {
//     MySqlErrorNumber = cGetMySqlErrorNumber(pConnection);
//     MySqlErrorDescription = cGetMySqlErrorDescription(pConnection);
//     if (SQLTrace) Print ("CMD>",MySqlErrorNumber, ": ", MySqlErrorDescription);
//     return (false);
//    }
// return (true);
//}
//
//// creates an cursor based on SELECT statement
//// return valuse - cursor identifier
//int MySqlCursorOpen(int pConnection, string pQuery)
//{
// int result;
// if (SQLTrace) {Print ("DBID#",pConnection,", QRY:",pQuery);}
// ClearErrors();
// result = cMySqlCursorOpen(pConnection, pQuery);
// if (result == -1)
//    {
//     MySqlErrorNumber = cGetMySqlErrorNumber(pConnection);
//     MySqlErrorDescription = cGetMySqlErrorDescription(pConnection);
//     if (SQLTrace) Print ("QRY>",MySqlErrorNumber, ": ", MySqlErrorDescription);
//    }
// return (result);
//}
//
//// closes opened cursor
//void MySqlCursorClose(int pCursorID)
//{
// ClearErrors();
// cMySqlCursorClose(pCursorID);
// MySqlErrorNumber = cGetCursorErrorNumber(pCursorID);
// MySqlErrorDescription = cGetCursorErrorDescription(pCursorID);
// if (SQLTrace) 
//    {
//     if (MySqlErrorNumber!=0)
//        {
//         Print ("Cursor #",pCursorID," closing error:", MySqlErrorNumber, ": ", MySqlErrorDescription);
//        }
//     else 
//        {
//         Print ("Cursor #",pCursorID," closed");
//        }
//    }
//}
//
//// return number of rows was selected by cursor
//int MySqlCursorRows(int pCursorID)
//{
// int result;
// result = cMySqlCursorRows(pCursorID);
// MySqlErrorNumber = cGetCursorErrorNumber(pCursorID);
// MySqlErrorDescription = cGetCursorErrorDescription(pCursorID);
// if (SQLTrace) Print ("Cursor #",pCursorID,", rows: ",result);
// return (result);
//}
//
//// fetch next row from cursor into current row buffer
//// return true - if succeeded, otherwise - false
//bool MySqlCursorFetchRow(int pCursorID)
//{
// bool result;
// result = cMySqlCursorFetchRow(pCursorID);
// MySqlErrorNumber = cGetCursorErrorNumber(pCursorID);
// MySqlErrorDescription = cGetCursorErrorDescription(pCursorID);
// return (result); 
//}
//
//// retrieves the value from current row was fetched by cursor
//string MySqlGetRowField(int pCursorID, int pField)
//{
// string result;
// result = cMySqlGetRowField(pCursorID, pField);
// MySqlErrorNumber = cGetCursorErrorNumber(pCursorID);
// MySqlErrorDescription = cGetCursorErrorDescription(pCursorID);
// return (result);
//}
//
//int MySqlGetFieldAsInt(int pCursorID, int pField)
//{
// return ((int)StringToInteger(MySqlGetRowField(pCursorID, pField)));
//}
//
//double MySqlGetFieldAsDouble(int pCursorID, int pField)
//{
// return (StringToDouble(MySqlGetRowField(pCursorID, pField)));
//}
//
//datetime MySqlGetFieldAsDatetime(int pCursorID, int pField)
//{
// string x = MySqlGetRowField(pCursorID, pField);
// StringReplace(x,"-",".");
// return (StringToTime(x));
//}
//
//string MySqlGetFieldAsString(int pCursorID, int pField)
//{
// return (MySqlGetRowField(pCursorID, pField));
//}
//
//// just to clear error buffer before any function started its functionality
//void ClearErrors()
//{
// MySqlErrorNumber = 0;
// MySqlErrorDescription = "No errors.";
//}
//
//
//
///********************************************************************
// * MySQL standard definitions                                       *
// ********************************************************************/
//#define CLIENT_LONG_PASSWORD               1 /* new more secure passwords */
//#define CLIENT_FOUND_ROWS                  2 /* Found instead of affected rows */
//#define CLIENT_LONG_FLAG                   4 /* Get all column flags */
//#define CLIENT_CONNECT_WITH_DB             8 /* One can specify db on connect */
//#define CLIENT_NO_SCHEMA                  16 /* Don't allow database.table.column */
//#define CLIENT_COMPRESS                   32 /* Can use compression protocol */
//#define CLIENT_ODBC                       64 /* Odbc client */
//#define CLIENT_LOCAL_FILES               128 /* Can use LOAD DATA LOCAL */
//#define CLIENT_IGNORE_SPACE              256 /* Ignore spaces before '(' */
//#define CLIENT_PROTOCOL_41               512 /* New 4.1 protocol */
//#define CLIENT_INTERACTIVE              1024 /* This is an interactive client */
//#define CLIENT_SSL                      2048 /* Switch to SSL after handshake */
//#define CLIENT_IGNORE_SIGPIPE           4096 /* IGNORE sigpipes */
//#define CLIENT_TRANSACTIONS             8192 /* Client knows about transactions */
//#define CLIENT_RESERVED                16384 /* Old flag for 4.1 protocol  */
//#define CLIENT_SECURE_CONNECTION       32768 /* New 4.1 authentication */
//#define CLIENT_MULTI_STATEMENTS        65536 /* Enable/disable multi-stmt support */
//#define CLIENT_MULTI_RESULTS          131072 /* Enable/disable multi-results */
//#define CLIENT_PS_MULTI_RESULTS       262144 /* Multi-results in PS-protocol */
//+------------------------------------------------------------------+
//|                                               Filtro de Notícias |
//|                                          2020 - 2022 Ds Coding ®️ |
//|                                      https://www.dscoding.com.br |
//+------------------------------------------------------------------+
class CNews {
private:
    string currencies[];
    int level;
    long before;
    long after;
    MqlCalendarValue calendar[];
    struct NEWS {
        int importance;
        string name;
        long time;
    };
    NEWS news[];
public:
    void Currency(string value);
    string Currency(int index) { return (int)currencies.Size() <= index ? NULL : currencies[index]; }
    void Level(int value) { level = value; }
    void Before(long value) { before = value; }
    void After(long value) { after = value; }
    int  Level() { return level; }
    long Before() { return before; }
    long After() { return after; }
    bool Sync(datetime date_start, datetime date_end);
    bool Check();

    CNews();
    ~CNews();
};

//+------------------------------------------------------------------+
CNews::CNews(): level(3), before(30), after(30) {}
CNews::~CNews() {}
//+------------------------------------------------------------------+
void CNews::Currency(string value) {
    uint size = currencies.Size();
    ArrayResize(currencies, size + 1);
    currencies[size] = value;
}
//+------------------------------------------------------------------+
bool CNews::Sync(datetime date_start, datetime date_end) {
    ArrayFree(news);
    for (uint i = 0; i < currencies.Size(); i++) {
        MqlCalendarValue data[];
        if (!CalendarValueHistory(data, date_start, date_end, "", currencies[i])) return false;
        for (uint a = 0; a < data.Size(); a++) {
            MqlCalendarEvent event;
            MqlCalendarCountry country;
            if (CalendarEventById(data[a].event_id, event))
                if (CalendarCountryById(event.country_id, country))
                    if (country.currency == currencies[i])
                        if (event.importance >= level) {
                            uint size = ArraySize(news);
                            ArrayResize(news, size + 1);
                            news[size].importance = event.importance;
                            news[size].name = event.name;
                            news[size].time = data[a].time;
                        }
        }
    }
    return true;
}
//+------------------------------------------------------------------+
bool CNews::Check() {
    datetime now = TimeTradeServer();
    for (uint i = 0; i < news.Size(); i++) {
        if (now > news[i].time - (before * 60))
            if (now < news[i].time + (after * 60))
                return false;
    }
    return true;
}



//+------------------------------------------------------------------+
//| Enums customizadas                                               |
//+------------------------------------------------------------------+
enum BOOL {
   OFF,   //No
   ON     //Yes
};
enum MA_MODE {
   MA_MODE_OFF,               // Off
   MA_MODE_UP_BUY_DN_SELL,    // Acima Compra/Abaixo Venda
   MA_MODE_DN_BUY_UP_SELL,    // Acima Venda/Abaixo Compra
   MA_MODE_RIS_BUY_FAL_SELL,  // Subindo Compra/Caindo venda
   MA_MODE_RIS_SELL_FAL_BUY   // Subindo Venda/Caindo Compra
};

enum RSI_MODE {
   RSI_OFF,     // Desligado
   RSI_LOWER,   // Menor que
   RSI_UPPER    // Maior que
};

enum ENTRY_DIRECTION {
   BUY_AND_SELL, // Buy & Sell
   BUY_ONLY,     // Buy Only
   SELL_ONLY     // Sell Only
};

enum TARGET_MODE {
   TARGET_PERCENTAGE,  // Percentage
   TARGET_POINTS,      // Points
   TARGET_POINT        // Pontos
};
//+------------------------------------------------------------------+
//| EXTRUTURAS DE DADOS                                              |
//+------------------------------------------------------------------+
struct RESULT {
   double             profit;
   double             loss;
   double             liquid;
   double             win_rate;
   int                trades;
   int                trades_win;
   int                trades_loss;

   void Clear() {
      profit = 0;
      loss = 0;
      liquid = 0;
      win_rate = 0;
      trades = 0;
      trades_win = 0;
      trades_loss = 0;
   }
};
struct HISTORY {
   RESULT day;
   RESULT week;
   RESULT month;
   RESULT all;

   void Clear() {
      day.Clear();
      week.Clear();
      month.Clear();
      all.Clear();
   }
};
//+------------------------------------------------------------------+
struct REENTRIE {
   double           volume;
   double           distance;
};

struct REENTRIE_STATUS {
   ulong ticket;
   int level;
};
//+------------------------------------------------------------------+





class CFileBackup {
 public:
   string m_name;
   template<typename T>
   bool ReadStruct(T& arr[]);
   template<typename T>
   bool SaveStruct(T& arr[]);

   void Name(string name) { m_name = name; }
   CFileBackup();
   ~CFileBackup();
};
//+------------------------------------------------------------------+
CFileBackup::CFileBackup() {}
//+------------------------------------------------------------------+
CFileBackup::~CFileBackup() {}
//+------------------------------------------------------------------+
template<typename T>
bool CFileBackup::ReadStruct(T& arr[]) {
   ResetLastError();

   if (!FileIsExist(m_name + ".bin")) return false;
   int handle = FileOpen(m_name + ".bin", FILE_READ | FILE_BIN);
   if (handle == INVALID_HANDLE) {
      Print("Falha abrir a o arquivo '" + m_name + "' para ler!  Erro: ", _LastError);
      return false;
   }

   while (!FileIsEnding(handle)) {
      T result;
      uint size = FileReadStruct(handle, result);
      if (size != sizeof(T)) {
         Print("Falha ler a estrutura PARTIAL do arquivo Erro: ", _LastError);
         FileClose(handle);
         return false;
      }
      int arr_size = ArraySize(arr);
      ArrayResize(arr, arr_size + 1);
      arr[arr_size] = result;
   }
   FileClose(handle);
   return true;
}
//+------------------------------------------------------------------+
template<typename T>
bool CFileBackup::SaveStruct(T& arr[]) {
   ResetLastError();

   int handle = FileOpen(m_name + ".bin", FILE_READ | FILE_WRITE | FILE_BIN);
   if (handle == INVALID_HANDLE) {
      Print("Falha abrir a o arquivo '" + m_name  + "' para gravar!  Erro: ", _LastError);
      return false;
   }
   int length = ArraySize(arr);
   for (int i = 0; i < length; i++) {
      uint size = FileWriteStruct(handle, arr[i]);
      if (size != sizeof(arr[i])) {
         Print("Falha salvar a estrutura no arquivo Erro: ", _LastError);
         FileClose(handle);
         return false;
      }
   }
   FileFlush(handle);
   FileClose(handle);

   return true;
}





class CReentrie {
 private:
   ulong             m_magic;
   CFileBackup       m_backup;
   CTrade*           m_trade;
   CSymbolInfo       m_symbol;
   TARGET_MODE       m_measure;
   REENTRIE          reentries[];
   REENTRIE_STATUS   m_status[];
   double NormalizeSize(TARGET_MODE mode, double size);
   template<typename T>
   int InsertArray(T& data, T& arr[]);
   template<typename T>
   int SearchInArray(ulong ticket, T& arr[]);
 public:
   void              Reentrie(double distance, double volume);
   void              DistanceMode(TARGET_MODE value) {
      m_measure = value;
   }
   bool              Update();
   CReentrie(CTrade* tdr, ulong magic);
   ~CReentrie();
};
//+------------------------------------------------------------------+
CReentrie::CReentrie(CTrade* tdr, ulong magic) {
   m_trade = GetPointer(tdr);
   m_symbol.Name(_Symbol);
   m_magic = magic;
   m_backup.Name("reentries_status_" + _Symbol + "_" + IntegerToString(m_magic));
   m_backup.ReadStruct(m_status);
}
//+------------------------------------------------------------------+
CReentrie::~CReentrie() {
   m_backup.SaveStruct(m_status);
}
//+------------------------------------------------------------------+
void CReentrie::Reentrie(double distance, double volume) {
   if (distance <= 0 || volume <= 0) return;
   REENTRIE add;
   add.distance = distance;
   add.volume = volume;
   int length = ArraySize(reentries);
   ArrayResize(reentries, length + 1);
   reentries[length] = add;
}
//+------------------------------------------------------------------+
bool CReentrie::Update() {
   if (reentries.Size() <= 0) return true;
   REENTRIE_STATUS status;
   double open, sl, tp, current;
   ulong ticket;
   long type;
   string comment;

   m_symbol.RefreshRates();
   for (int i = 0; i < PositionsTotal(); i++) {
      ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))continue;
      if (PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;


      comment = PositionGetString(POSITION_COMMENT);

      if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
         if(StringFind(comment, "R[") != -1) continue;

      type = PositionGetInteger(POSITION_TYPE);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open = PositionGetDouble(POSITION_PRICE_OPEN);
      current = PositionGetDouble(POSITION_PRICE_CURRENT);

      int pos = SearchInArray(ticket, m_status);
      if (pos == -1) {
         status.ticket = ticket;
         status.level = 0;
         pos = InsertArray(status, m_status);
      }

      //Realizar reentradas
      for (int j = m_status[pos].level; j < ArraySize(reentries); j++) {
         if (type == POSITION_TYPE_BUY) {
            if (current <= m_symbol.NormalizePrice(open - NormalizeSize(m_measure, reentries[j].distance)))
               if (m_trade.Buy(reentries[j].volume, m_symbol.Name(), m_symbol.Ask(), sl, tp, "R[" + IntegerToString(j + 1) + "]" + comment)) {
                  m_status[pos].level++;
               }
         } else if (type == POSITION_TYPE_SELL)
            if (current >= m_symbol.NormalizePrice(open + NormalizeSize(m_measure, reentries[j].distance)))
               if (m_trade.Sell(reentries[j].volume, m_symbol.Name(), m_symbol.Bid(), sl, tp,  "R[" + IntegerToString(j + 1) + "]" + comment)) {
                  m_status[pos].level++;
               }
      }
   }

   for (uint i = m_status.Size() - 1; i > 0; i--) {
      bool search = false;
      for (int a = 0; a < PositionsTotal(); a++)
         if (PositionGetTicket(a) == m_status[i].ticket) {
            search = true;
            break;
         }
      if (!search) ArrayRemove(m_status, i, 1);
   }

   return true;
}
//+------------------------------------------------------------------+
double CReentrie::NormalizeSize(TARGET_MODE mode, double size) {
   switch(mode) {
   case TARGET_PERCENTAGE:
      return (size / 100) * SymbolInfoDouble(_Symbol, SYMBOL_BID);
   case TARGET_POINTS:
      return size * _Point;
   default:
      return size;
   }
}
//+------------------------------------------------------------------+
template<typename T>
int CReentrie::InsertArray(T& data, T& arr[]) {
   int size = ArraySize(arr);
   ArrayResize(arr, size + 1);
   arr[size] = data;
   return size;
}
//+------------------------------------------------------------------+
template<typename T>
int CReentrie::SearchInArray(ulong ticket, T& arr[]) {
   for (int i = 0; i < ArraySize(arr); i++)
      if (arr[i].ticket == ticket) return i;

   return -1;
}
//+------------------------------------------------------------------+
CReentrie* Reentrie;
CNews* News;

enum LIGA
  {
   SIM, //Yes
   NAO  //No
  };
  
enum ESTRATEGIA_ENTRADA
  {
   //APENAS_MM,   //Apenas Médias Móveis
   //APENAS_MACD, //Apenas MACD
   //MM_E_MACD,   //Médias mais MACD
   //APENAS_CONSERVADOR,      //Day Trade
   //B3_DAY_TRADE,            //B3 Day Trade
   //B3,                      //Supply Demand
   LIVWELL,                   //LivWell
   LIVWELL_TENDENCIA,        //LivWell Têndencia
   SUPPLY,                      //Supply and Demand
   DRAGON,                     //Grid Linear
   RENKO_OURO,                 //PVSRA
   EU_ROBO                      //EU ROBO
  };
  
enum LIGA_TS
  {
   SIM_TS, //Yes
   NAO_TS  //No
  };
  
enum LIGA_PARCIAL
  {
   SIM_PARCIAL, //Yes
   NAO_PARCIAL  //No
  };
  
enum LIGA_RENKO
  {
   SIM_RENKO, //Yes
   NAO_RENKO //No
  };
  
enum eMeasure {
  pontos,        //[01] Pontos
  points,        //[02] Points
  ticks,         //[03] Tick
  pips,          //[04] Pip
};

enum ENUM_UNIDADE_MEDIDA
{
   UNIDADE_PIPS,//Points
   UNIDADE_PONTOS,//Pontos
   UNIDADE_PORCENTAGEM,//Percentage
};

enum enum_nao_sim
{
   nao,//No
   sim//Yes
};

  
input group                "▶▶▶   RENKO"
input LIGA_RENKO           ativa_renko   = NAO_RENKO;    //ᅟ→ᅟWoul you like to activate Renko?
input double RenkoSize = 11;                             //ᅟ→ᅟRenko Size
input string               ativoOperacao = "";     //ᅟ→ᅟSymbol Name

input group                "▶▶▶   STRATEGY SETUP"
input double               max_dd     = 0;//ᅟ→ᅟMaximum Drawdown
input ENTRY_DIRECTION      trade_mode = BUY_AND_SELL;                            //ᅟ→ᅟEntry Direction
input BOOL                 out_by_ma = OFF;                //ᅟ→ᅟOut on the touch of Moving Average?
input ESTRATEGIA_ENTRADA   estrategia    = SUPPLY;  //ᅟ→ᅟEntry Strategy Trader
input ulong                magic_magico  = 102030;                   //ᅟ→ᅟMagic Number
BOOL                 chart_colors_enable = ON;                              //ᅟ→ᅟEnable Automatic Template?
input BOOL                 gerar_log = OFF;                              //ᅟ→ᅟGenerate Log?
input bool                 inverte_ordem  = false;                       //ᅟ→ᅟReverse the Order?  

input group                "▶▶▶   RECOVERY"
input bool                 ativar_recovery                      = false;                               //ᅟ→ᅟExecute Recovery on the next signal?
input double               multiplicador_recovery           = 1;                                   //ᅟ→ᅟRecovery Multiplier 
input int                  max_lot_recovery                          = 10;                                  //ᅟ→ᅟLot Maximum

input group                "▶▶▶   BREAKEVEN"
input LIGA                 liga_breakeven= NAO;          //ᅟ→ᅟActivate Breakeven?
//input double               StartBE       = 75;          //ᅟ→ Start Breakeven
//input double               PointBE       = 5;           //ᅟ→ᅟBreakeven Steps
input ENUM_UNIDADE_MEDIDA  medida_breakeven = UNIDADE_PIPS;                   //ᅟ→ᅟTypes of Entry
input double               distancia_break1 = 0;//ᅟ→ᅟStart Breakeven
input double               pontos_break1 = 0;//ᅟ→ᅟBreakeven Steps
input group                "▶▶▶   TRALING STOP"
input LIGA_TS              liga_train    = SIM_TS;       //ᅟ→ᅟTurn on TS?
input bool              liga_train_candle_candle    = false;       //ᅟ→ᅟTurn on TS candle candle?
input eMeasure    inpMedidaTr    = points;               //ᅟ→ᅟTypes of Entry
input double      inpTrStart     = 22;                   //ᅟ→ᅟStart TS
input double      inpTrStep      = 5;                    //ᅟ→ᅟTS Steps
input group                "▶▶▶   PARTIAL EXIT"
input LIGA_PARCIAL         liga_par      = NAO_PARCIAL;  //ᅟ→ᅟActivate Partial?
input int                  nContrato     = 1;            //ᅟ→ᅟNumber of Lots 1
input double               StartParcial  = 50;           //ᅟ→ᅟStart Partial 1
input int                  nContrato2     = 1;            //ᅟ→ᅟNumber of Lots 2
input double               StartParcial2  = 50;           //ᅟ→ᅟStart Partial 2
input int                  nContrato3     = 1;            //ᅟ→ᅟNumber of Lots 3
input double               StartParcial3  = 50;           //ᅟ→ᅟStart Partial 3
input int                  nContrato4     = 1;            //ᅟ→ᅟNumber of Lots 4
input double               StartParcial4  = 50;           //ᅟ→ᅟStart Partial 4
input int                  nContrato5     = 1;            //ᅟ→ᅟNumber of Lots 5
input double               StartParcial5  = 50;           //ᅟ→ᅟStart Partial 5
input int                  nContrato6     = 1;            //ᅟ→ᅟNumber of Lots 6
input double               StartParcial6  = 50;           //ᅟ→ᅟStart Partial 6
input int                  nContrato7     = 1;            //ᅟ→ᅟNumber of Lots 7
input double               StartParcial7  = 50;           //ᅟ→ᅟStart Partial 7



//input group                "▶▶▶   MOVINNG AVERAGE"
//input int mm_rapida_periodo               = 21;             //ᅟ→ᅟMoving Average of ATR
int mm_media_periodo                = 7;             //ᅟ→ᅟMoving Average 1
ENUM_APPLIED_PRICE mm_preco_1         = PRICE_HIGH;    //ᅟ→ᅟMoving Average Price 1
int mm_lenta_periodo                = 7;            //ᅟ→ᅟMoving Average 2
ENUM_APPLIED_PRICE mm_preco_2         = PRICE_LOW;    //ᅟ→ᅟMoving Average Price 2
int mm_swing_periodo                = 200;            //ᅟ→ᅟMoving Average 3
ENUM_APPLIED_PRICE mm_preco_3         = PRICE_CLOSE;    //ᅟ→ᅟMoving Average Price 3
ENUM_TIMEFRAMES   mm_tempo_grafico  = PERIOD_CURRENT; //ᅟ→ᅟMoving Average Time Frame
ENUM_MA_METHOD    mm_metodo         = MODE_EMA;       //ᅟ→ᅟMoving Average Method
//input ENUM_APPLIED_PRICE mm_preco         = PRICE_CLOSE;    //ᅟ→ Moving Average Price

//--- indice o nivel macd e 16
//sinput string s3; //----MACD----
ENUM_APPLIED_PRICE TIPOPRECOMACD    = PRICE_CLOSE;    //Tipo Preço
int MARAPIDAMACD = 17;                                //MACD Rápida
int MALENTAMACD = 161;                                 //MACD Lento
int PERIODOMACD = 13;                                  //MACD Período
double NIVELMACD = 0.62;                                //MACD Nível

//input group                "▶▶▶   RSI"
//input int ifr_periodo                      = 2;             //ᅟ→  Período IFR
//input ENUM_TIMEFRAMES ifr_tempo_grafico    = PERIOD_CURRENT;//ᅟ→  Tempo Gráfico  
//input ENUM_APPLIED_PRICE ifr_preco         = PRICE_CLOSE;   //ᅟ→  Preço Aplicado 
//input double               sobrevendarsi = 30;                                    //ᅟ→ᅟNivel inferiorᅟᅟ
//input double               sobrecomprarsi = 70;                                    //ᅟ→ᅟNivel superiorᅟᅟ

//input group                "▶▶▶   FILTER - STOCH"
int                  stoch_period_k = 8;                                   //ᅟ→ᅟPeriod %K
int                  stoch_period_d = 3;                                   //ᅟ→ᅟPeriod %D
int                  stoch_slowing = 3;                                    //ᅟ→ᅟSlowing
ENUM_STO_PRICE       stoch_price = STO_LOWHIGH;                            //ᅟ→ᅟPrice
ENUM_MA_METHOD       stoch_method = MODE_SMA;                              //ᅟ→ᅟMethod
double               sobrecomprastoch = 20;                                  //ᅟ→ᅟBuying level
double               sobrevendastoch = 80;                                  //ᅟ→ᅟSelling level

input group                "▶▶▶   SUPPLY AND DEMAND"
input int                  back_limit = 1000;//ᅟ→ᅟBacklimit
input enum_nao_sim         history_mode = nao;//ᅟ→ᅟHistory mode?
input enum_nao_sim         show_weak_zones = nao;//ᅟ→ᅟShow weak zones
input enum_nao_sim         show_untested_zones = sim;//ᅟ→ᅟShow untested zones
input enum_nao_sim         show_broken_zones = sim;//ᅟ→ᅟShow broken zones
input double               zone_atr_factor = 0.75;//ᅟ→ᅟZone atr factor
input enum_nao_sim         zone_merge = sim;//ᅟ→ᅟZone merge
input enum_nao_sim         zone_extend = sim;//ᅟ→ᅟZone extend
input double               fractal_fast_factor = 3;//ᅟ→ᅟFractal fast factor
input double               fractal_slow_factor = 6;//ᅟ→ᅟFractal slow factor

input group                "▶▶▶   FINANCIAL"
input double               entries_lot_size = 1;                                 //ᅟ→ᅟLot (-1 = Use the whole portfolio)
input TARGET_MODE          entries_target_type = TARGET_POINTS;                  //ᅟ→ᅟTarget Type TP
input double               entries_target_size = 20000;                              //ᅟ→ᅟTake Profit
input TARGET_MODE          entries_stop_type = TARGET_POINTS;                    //ᅟ→ᅟTarget Type Stop 
input double               entries_stop_size = 0;                                //ᅟ→ᅟStop Loss
input bool                 stop_anterior     = false;                            //ᅟ→ᅟStop at previous Candle 
input bool                 stop_atr          = false;                            //ᅟ→ᅟStop ATR
input int                  entries_stop_candles = 0;                             //ᅟ→ᅟReset after how many candles? (0 = Off)
input BOOL                 entries_only_one_per_candle = 1;                      //ᅟ→ᅟOnly one entry per candle?

//input double num_lots            = 1;     //Números de Lotes
//input double pts_TK              = 500;   //TAKE PROFIT
//input double pts_SL              = 500; //Stop Loss
input double                  LD                   = 0;             //ᅟ→ᅟMax daily gain
input double                  LDN                  = 0;             //ᅟ→ᅟMax daily loss 

input group                "▶▶▶   OPERATION TIME"
//input string hora_limite_fecha_op   = "00:59"; //Horário Limite Fechar Posição
input string inicio_op              = "00:00"; //ᅟ→ᅟStarting time for operation
input string fim_op                 = "23:59"; //ᅟ→ᅟEnding time for operation

input group                "▶▶▶   REENTRY"
input TARGET_MODE          iReentrie_type = TARGET_POINTS;                       //ᅟ→ᅟTarget Type Reentry
input double               iReentriesDistance1 = 260;                              //ᅟ→ᅟDistance 1 (0 OFF)
input double               iReentriesVolume1 = 2;                             //ᅟ→ᅟLot 1
input double               iReentriesDistance2 = 520;                              //ᅟ→ᅟDistance 2 (0 OFF)
input double               iReentriesVolume2 = 4;                             //ᅟ→ᅟLot 2
input double               iReentriesDistance3 = 0;                              //ᅟ→ᅟDistance 3 (0 OFF)
input double               iReentriesVolume3 = 0.08;                             //ᅟ→ᅟLot 3
input double               iReentriesDistance4 = 0;                              //ᅟ→ᅟDistance 4 (0 OFF)
input double               iReentriesVolume4 = 0.16;                             //ᅟ→ᅟLot 4
input double               iReentriesDistance5 = 0;                              //ᅟ→ᅟDistance 5 (0 OFF)
input double               iReentriesVolume5 = 0.32;                             //ᅟ→ᅟLot 5
input double               iReentriesDistance6 = 0;                              //ᅟ→ᅟDistance 6 (0 OFF)
input double               iReentriesVolume6 = 0.64;                             //ᅟ→ᅟLot 6
input double               iReentriesDistance7 = 0;                              //ᅟ→ᅟDistance 7 (0 OFF)
input double               iReentriesVolume7 = 1.28;                             //ᅟ→ᅟLot 7
input double               iReentriesDistance8 = 0;                              //ᅟ→ᅟDistance 8 (0 OFF)
input double               iReentriesVolume8 = 2.56;                             //ᅟ→ᅟLot 8
input double               iReentriesDistance9 = 0;                              //ᅟ→ᅟDistance 9 (0 OFF)
input double               iReentriesVolume9 = 5.12;                             //ᅟ→ᅟLot 9
input double               iReentriesDistance10 = 0;                              //ᅟ→ᅟDistance 10 (0 OFF)
input double               iReentriesVolume10 = 10.24;                             //ᅟ→ᅟLot 10

input group                "▶▶▶   AVERAGE PRICE"
input bool                 usar_preco_medio = false;//ᅟ→ᅟActivate?
input double               ganho_preco_medio = 50;//ᅟ→ᅟGain $
input double               perda_preco_medio = 50;//ᅟ→ᅟLoss $
input double               distancia_medio = 200;//ᅟ→ᅟDistance
input double               multiplicador_medio = 2;//ᅟ→ᅟMultiplier
input double               max_lote_medio = 0;//ᅟ→ᅟMaximum lot

input group                "▶▶▶   INVERTED AVERAGE PRICE"
input bool                 ativar_medio_invertido = false;//ᅟ→ᅟActivate?
input double               multiplicador_medio_invertido = 2;//ᅟ→ᅟMultiplier
input int                  max_hedge = 0;//ᅟ→ᅟMaximum lot

input group                "▶▶▶   TURNING-POINT"
input bool               iUseVM                     = false; //ᅟ→ᅟActivate Turning-Point?
//input uint RTOTAL=4;        // →ᅟTotal de repitição
input double             multiplicador_vm           = 2; //ᅟ→ᅟLot Multiplier
//input double             ilotVM1                    = 2; //ᅟ→ᅟLot Size
input double             iDistanceVM1               = 100; //ᅟ→ᅟDistance for entry

input group    "▶▶▶   BOX FILTER";
input bool                 ativar_caixa_stop = false;//ᅟ→ᅟActivate?
input double               range_caixa = 200;//ᅟ→ᅟRange

//input double             tk_vm = 900;                                 //ᅟ→ᅟTake Profit VM
//input double             ilotVM2                    = 2; //Tamanho do lote Tempo real 2
//input double                iDistanceVM2               = 80; //Distância para entrada Tempo real 2
//input double             ilotVM3                    = 0; //Tamanho do lote Tempo real 3
//input double                iDistanceVM3               = 0; //Distância para entrada Tempo real 3
//input double             ilotVM4                    = 0; //Tamanho do lote Tempo real 4
//input double                iDistanceVM4               = 0; //Distância para entrada Tempo real 4
//input double             ilotVM5                    = 0; //Tamanho do lote Tempo real 5
//input double                iDistanceVM5               = 0; //Distância para entrada Tempo real 5

input group                "▶▶▶   INFO PANEL"
input group                "▶ It's recommended to disable Backtests"
input BOOL                 infopanel_enable = 1;                                 //ᅟ→ᅟEnable Info Panel
input int                  infopanel_marks_font_size = 10;                       //ᅟ→ᅟFont Size
input color                infopanel_bg_color = C'10,10,10';                     //ᅟ→ᅟColor - Background
input color                infopanel_border_color = C'20,20,20';                 //ᅟ→ᅟColor - Board
input color                infopanel_title_color = C'255,255,255';               //ᅟ→ᅟColor - Title
input color                infopanel_subtitle_color = C'120,120,120';            //ᅟ→ᅟColor - Subtitle
input color                infopanel_white_color = C'220,220,220';               //ᅟ→ᅟColor - White
input color                infopanel_blue_color = C'7,123,255';                  //ᅟ→ᅟColor - Blue
input color                infopanel_red_color = C'236,28,37';                   //ᅟ→ᅟColor - Red
input color                infopanel_start_color =  C'7,123,255';                //ᅟ→ᅟColor - Start Button
input color                infopanel_pause_color = C'39,174,96';                 //ᅟ→ᅟColor - Pause Button
input color                infopanel_close_color = C'236,28,37';                 //ᅟ→ᅟColor - Reset Button
input string               trade_comment = "Handliv";                            //ᅟ→ᅟComment (Operation Text)ᅟ

input group                "???   HANDLIV API"
input string               handliv_api_url = "https://api.handliv.com/api/v1";  //? -?API Base URL
input string               handliv_api_token = "";                              //? -?MT5 API Token
input bool                 handliv_checar_conta = true;                         //? -?Check account active?
bool     ativar_media2        = true;     //ATIVAR MEDIA 2?
int      periodomedia2        = 9; //PERIODO DA MEDIA 2
ENUM_MA_METHOD    mediametodo2    = MODE_EMA; //METODO DA MEDIA 2
ENUM_APPLIED_PRICE      precomedia2          =PRICE_CLOSE; //PREÇO DA MEDIA 2
color                   cormedia2            = clrRed;      //COR DA MEDIA 2

bool     ativar_media3        = true;     //ATIVAR MEDIA 3?
int      periodomedia3        = 21; //PERIODO DA MEDIA 3
ENUM_MA_METHOD    mediametodo3    = MODE_EMA; //METODO DA MEDIA 3
ENUM_APPLIED_PRICE      precomedia3          =PRICE_CLOSE; //PREÇO DA MEDIA 3
color                   cormedia3            = clrWhite;      //COR DA MEDIA 3

//+------------------------------------------------------------------+
//|             Variáveis                                                     |
//+------------------------------------------------------------------+

// PAINEL
string panelItems[99],
       panelPosition = "--",
       panelLots = "--",
       panelResult = "--",
       panelText = "";

#define Day(T)   ((T) - ((T) % 86400))
#define Week(T)  ((T)-((T-172800)%604800 - 86400))

int tS, iS, iM, iH;
string sS, sM, sH;
HISTORY  history;

bool     ea_enable = true;
datetime candleTime = 0;
double   currentPositionResult = 0;
int      currentDayEntries = 0;
datetime lastPositionTime = 0;
long     last_candle = 0;
bool     position_in_this_candle = false;
string   utilTimeString = "";
int      rsi_handle = -1, ma_1_handle = -1, ma_2_handle = -1, stoch_handle = -1, hilo_handle = -1;
double   rsi[], ma[], stoch[], hilo[];
int      dealsTotal = 0;
bool     ea_pause = false, money_block = false;


//--- Médias Móveis
//--- RÁPIDA
//int mm_rapida_handle;
//double mm_rapida_buffer[];

//--- MÉDIA
int mm_media_handle;
double mm_media_buffer[];

//---LENTA
int mm_lenta_handle;
double mm_lenta_buffer[];

int handle_supply;

int    handle_iCustom;                       // variable for storing the handle of the iCustom indicator 

int heiken_ashi_handle;


//---SWING
int mm_swing_handle;
double mm_swing_buffer[];

double   fractalHighVal[]; // Array para armazenamento dos valores do indicador iFractals
double   fractalLowVal[];  // Array para armazenamento dos valores do indicador iFractals
int      fractalHandle;    // Handle para o indicador iFractals

double   lastHiFractal,lastHiFractalAnt;    // ultimo fractal de alta
double   lastLoFractal,lastLoFractalAnt;    // ultimo fractal de baixa

double buffer_media2[];            //Indicator buffer for media
int handle_media2=0;               //Handle for the media indicator

double buffer_media3[];            //Indicator buffer for media
int handle_media3=0;               //Handle for the media indicator

double buffer_media4[];            //Indicator buffer for media
int handle_media4=0;               //Handle for the media indicator

double buffer_volume[];            //Indicator buffer for media
int handle_volume=0;               //Handle for the media indicator

//---Customizado
//int mm_custom_handle;
//double mm_custom_buffer[];

//---ADX
//int IndicatorHandle;
//
//double adx_line[];
//double adx_plus_di[];
//double adx_minus_di[];

//---SAR
//double SAR[];
//int SAR_HANDLE;
//
////---MACD
////int macd_handle;
////double macd_buffer[];
int handlemacd, handlemarapida, handlemalenta,handlemae;
double buffermacd[], bufferhistograma[], buffermarapida[], buffermalenta[];

//--- IFR
//int ifr_Handle;           // Handle controlador para o IFR
//double ifr_Buffer[];      // Buffer para armazenamento dos dados do IFR

//--- Indice e dolar
double SL, TK;

//--- Ativo para operar
string ativoOp;

// Ponto do simbolo
//double                  PontoSimbolo             =1; 

int segundoAnterior = -1;                           

//--- velas e tick
MqlRates velas[];
MqlTick tick_;

// Renko Charts
RenkoCharts RenkoOffline();
string original_symbol, custom_symbol;

bool pode_operar = true;
//---BREAKEVEN E TS
bool beAtivo = false;
bool parAtivo = false;
bool trailing_par_ativo = false;

bool env_pos = false;

//double pts_SL              = 0;   //Stop LOSS

CTrade*    trade;

bool posAberta, ordPendente;

//Atr stop/take multiplier
int atr_Handle;
double atr_Buffer[];

bool jacomprou = false;
bool javendeu = false;

bool v_indicador = false;

double Diafechamento, DiaAbertura, DiaMax, DiaMin;

double lote = 0;

bool conta_netting;

//---
double lote_maximo;

//---
double volume_anterior_preco_medio;

//---
struct UltimaOperacao
{
   double volume;
   double preco;
   double sl;
   double tp;
   string comment;
   int tipo_posicao;

};
//---

//--- VARIAVEIS GLOBAIS
MqlCalendarCountry paises[];
MqlCalendarEvent eventos[];
MqlCalendarValue valor[];

datetime datahoraevento;
ulong eventosus;
//---

datetime ultima_entrada;

datetime candle_atual;

bool stops_ajustados;

bool ativar_heiken = true;

ENUM_ACCOUNT_TRADE_MODE contarealoudemo = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

datetime expiracao = D'30.12.2025';

int OnInit()
  {
 
  //--- Validão dos dias
   if (TimeCurrent() > expiracao)
    {
       Alert("Periodo de uso do robô expirado, contate o admin!");
       return(INIT_FAILED);
    } 
   
   //if(MQLInfoInteger(MQL_TESTER))
   //   return(INIT_FAILED);
    
   if(contarealoudemo == ACCOUNT_TRADE_MODE_REAL || contarealoudemo == ACCOUNT_TRADE_MODE_DEMO) // 
      vencimento2();
   
   if(estrategia == LIVWELL)
     {
         ChartSetSymbolPeriod(0, _Symbol, ENUM_TIMEFRAMES(PERIOD_H1));
     }   
   
      
   //---CHECK NOTICIAS
  News = new CNews;
  News.Sync(TimeCurrent(),TimeCurrent());
  
  
      
   stops_ajustados = true;
      
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
      conta_netting = true;
   else
      conta_netting = false;
      
   double volume = CalcularLote(lote);
   for(int i = 0; i < max_hedge; i++)
   {
      if(i == 0)
         lote_maximo += CalcularLote(volume * 3);
      else
      {
         lote_maximo += CalcularLote(volume * 2);
      }
   }

   //--- Template automatico 
   if(chart_colors_enable == ON && estrategia == LIVWELL)
     {
      ChartSetInteger(0, CHART_SHOW_GRID, false);
      ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
      ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrBlack);
      ChartSetInteger(0, CHART_COLOR_CHART_UP, clrBlack);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrBlack);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrBlack);
      ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
      ChartSetInteger(0, CHART_COLOR_ASK, C'255,121,198');
      ChartSetInteger(0, CHART_COLOR_BID, C'255,121,198'); 
     }
   
   if(infopanel_enable)
     {
      HistoryUpdate(magic_magico, _Symbol, history);
    
      InfoPanel_Create();
     }  
   
   
   ativoOp           = (ativoOperacao==""?_Symbol:ativoOperacao);
   
   trade = new CTrade;
   
    //--- Número mágico
   //trade.SetAsyncMode(false);
   //trade.SetDeviationInPoints(5);
   trade.SetExpertMagicNumber(magic_magico);
   trade.SetTypeFillingBySymbol(_Symbol);
   
   long filling;
   SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE, filling);
   if(filling == SYMBOL_FILLING_FOK)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(filling == SYMBOL_FILLING_IOC)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);

   
   //macd_handle       = iMACD(_Symbol,_Period,MARAPIDAMACD,MALENTAMACD,PERIODOMACD,PRICE_CLOSE);
   //--- CRIANDO INDICADOR MACD
   handlemacd = iCustom(_Symbol, PERIOD_CURRENT, "::Indicators\\macd_histogram.ex5", MARAPIDAMACD, MALENTAMACD, PERIODOMACD, TIPOPRECOMACD);
   
   //IndicatorHandle = iADX(_Symbol,PERIOD_CURRENT, 20);
   stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, stoch_period_k, stoch_period_d, stoch_slowing, stoch_method, stoch_price);
   //SAR_HANDLE = iSAR(_Symbol,PERIOD_CURRENT,0.01,0.09);
   atr_Handle = iATR(_Symbol, PERIOD_CURRENT, 14);
   
   //mm_custom_handle  = iMA(_Symbol,mm_tempo_grafico,mm_media_periodo,0,mm_metodo,mm_preco_1);
   //ifr_Handle = iRSI(_Symbol,ifr_tempo_grafico,ifr_periodo,ifr_preco);
   
   //mm_rapida_handle  = iMA(_Symbol,mm_tempo_grafico,mm_rapida_periodo,0,mm_metodo,atr_Handle);
   mm_media_handle  = iMA(_Symbol,mm_tempo_grafico,mm_media_periodo,0,mm_metodo,mm_preco_1);
   mm_lenta_handle   = iMA(_Symbol,mm_tempo_grafico,mm_lenta_periodo,0,mm_metodo,mm_preco_2);
   mm_swing_handle   = iMA(_Symbol,mm_tempo_grafico,mm_swing_periodo,0,mm_metodo,mm_preco_3);
   handle_media2 = iMA(_Symbol,PERIOD_CURRENT,periodomedia2,0,mediametodo2,precomedia2);
   handle_media3 = iMA(_Symbol,PERIOD_CURRENT,periodomedia3,0,mediametodo3,precomedia3);
   
   handle_volume = iVolumes(_Symbol,PERIOD_CURRENT, VOLUME_TICK);
   handle_media4 = iMA(_Symbol,PERIOD_CURRENT,20,0,mediametodo2,handle_volume);
   
   if(ativar_heiken)
      heiken_ashi_handle = iCustom(_Symbol,PERIOD_CURRENT,"Examples\\Heiken_Ashi");
   
   handle_supply = iCustom(_Symbol, _Period, "::Indicators\\LivWell Indicators.ex5", PERIOD_CURRENT, back_limit, history_mode, "", show_weak_zones, show_untested_zones, show_broken_zones,  zone_atr_factor, zone_merge, zone_extend, fractal_fast_factor, fractal_slow_factor);
   if(handle_supply == INVALID_HANDLE)
   {
      MessageBox("Erro ao obter informações do indicador");
      Print("Erro ao obter informações do indicador");
      return INIT_FAILED;
   }
   else
      ChartIndicatorAdd(0, 0, handle_supply);
   
   //handle_iCustom=iCustom(_Symbol,Period(),"Examples\\ZigZag");
   
   //handle_iCustom = iCustom(_Symbol,Period(),"Examples\\ZigZag");
   
   
   
   
   if(stoch_handle < 0 || mm_media_handle < 0|| mm_lenta_handle < 0 || handlemacd < 0)//|| mm_media_handle < 0 ||mm_rapida_handle < 0 || mm_lenta_handle < 0 ||  ifr_Handle < 0 || IndicatorHandle < 0 || 
     {
      Alert("Erro ao tentar criar handles para o indicador - erro: ",GetLastError());
      return(-1);
     }
   if(estrategia == LIVWELL)  
      if(!ChartIndicatorAdd(0, 0, heiken_ashi_handle))
           PrintFormat("Falha ao adicionar o indicador Heiken Ashi %d na janela do gráfico. Código de erro %d",
                       0, GetLastError());
                    
//   if(!ChartIndicatorAdd(0, 0, mm_rapida_handle))
//        PrintFormat("Falha ao adicionar o indicador MA RAPIDA %d na janela do gráfico. Código de erro %d",
//                    0, GetLastError());
//                    
//   if(!ChartIndicatorAdd(0, 0, mm_media_handle))
//        PrintFormat("Falha ao adicionar o indicador MA MÉDIA %d na janela do gráfico. Código de erro %d",
//                    0, GetLastError());
//                    
   //if(!ChartIndicatorAdd(0, 0, handle_iCustom))
   //     PrintFormat("Falha ao adicionar o indicador ZigZag %d na janela do gráfico. Código de erro %d",
   //                 0, GetLastError());
     
  CopyRates(_Symbol,_Period,0,5,velas);
  ArraySetAsSeries(velas,true);
   
//--- Ordenar os vetores de dados
   //ArraySetAsSeries(macd_buffer,true);
   //ArraySetAsSeries(mm_rapida_buffer,true);
   //ArraySetAsSeries(mm_custom_buffer,true);
   ArraySetAsSeries(mm_media_buffer,true);
   ArraySetAsSeries(mm_lenta_buffer,true);
   ArraySetAsSeries(mm_swing_buffer,true);
   //ArraySetAsSeries(ifr_Buffer,true);
   ArraySetAsSeries(stoch,true);
   //ArraySetAsSeries(fractalHighVal, true);
   //ArraySetAsSeries(fractalLowVal, true);
   ArraySetAsSeries(buffer_media2,true); 
   ArraySetAsSeries(buffer_media3,true); 
   ArraySetAsSeries(buffer_media4,true); 
   ArraySetAsSeries(buffer_volume,true); 
   
   //ArraySetAsSeries(adx_line,true);   
   //ArraySetAsSeries(adx_plus_di,true);  
   //ArraySetAsSeries(adx_minus_di,true);
   //ArraySetAsSeries(SAR, true);
   ArraySetAsSeries(atr_Buffer, true);
   
   
  
  //ChartIndicatorAdd(0,0,mm_rapida_handle);
  //ChartIndicatorAdd(0,0,mm_lenta_handle);
  //ChartIndicatorAdd(0,1,macd_handle);
  //--- Rodar no indice e no dolar
  //if(_Digits == 3)
  //  {
  //   SL = pts_SL*1000;
  //   TK = pts_TK*1000;
  //  }else
  //     {
  //      SL = pts_SL;
  //      TK = pts_TK;
  //     }
       
       
//--- Reentrada
   
   Reentrie = new CReentrie(trade, magic_magico);
   Reentrie.DistanceMode(iReentrie_type);
   if(iReentriesDistance1 > 0) Reentrie.Reentrie(iReentriesDistance1, iReentriesVolume1);
   if(iReentriesDistance2 > 0) Reentrie.Reentrie(iReentriesDistance2, iReentriesVolume2);
   if(iReentriesDistance3 > 0) Reentrie.Reentrie(iReentriesDistance3, iReentriesVolume3);
   if(iReentriesDistance4 > 0) Reentrie.Reentrie(iReentriesDistance4, iReentriesVolume4);
   if(iReentriesDistance5 > 0) Reentrie.Reentrie(iReentriesDistance5, iReentriesVolume5);
   if(iReentriesDistance6 > 0) Reentrie.Reentrie(iReentriesDistance6, iReentriesVolume6);
   if(iReentriesDistance7 > 0) Reentrie.Reentrie(iReentriesDistance7, iReentriesVolume7);
   if(iReentriesDistance8 > 0) Reentrie.Reentrie(iReentriesDistance8, iReentriesVolume8);
   if(iReentriesDistance9 > 0) Reentrie.Reentrie(iReentriesDistance9, iReentriesVolume9);
   if(iReentriesDistance10 > 0) Reentrie.Reentrie(iReentriesDistance10, iReentriesVolume10);
  
       
//--- RENKO
   if(ativa_renko == SIM_RENKO)
     {
         //Get Symbol
         if(ativoOp!="")
            original_symbol = ativoOp;
         //Check Period
         if(ChartPeriod(0) != PERIOD_M1) //RenkoWindow == RENKO_CURRENT_WINDOW && 
           {
            MessageBox("Renko must be M1 period!", __FILE__, MB_OK);
            ChartSetSymbolPeriod(0, _Symbol, PERIOD_M1);
            return(INIT_SUCCEEDED);
           }
         //Check Symbol
         if(!RenkoOffline.ValidateSymbol(original_symbol))
           {
            MessageBox("Invalid symbol error. Select a valid symbol!", __FILE__, MB_OK);
            return(INIT_FAILED);
           }
         //Setup Renko
         if(!RenkoOffline.Setup(original_symbol, RENKO_TYPE_TICKS, RenkoSize, true))
           {
            MessageBox("Renko setup error. Check error log!", __FILE__, MB_OK);
            return(INIT_FAILED);
           }
         //Create Custom Symbol
         RenkoOffline.CreateCustomSymbol();
         RenkoOffline.ClearCustomSymbol();
         custom_symbol = RenkoOffline.GetSymbolName();
         //Load History
         RenkoOffline.UpdateRates();
         RenkoOffline.ReplaceCustomSymbol();  
         //Chart Setup
         RenkoOffline.Start(RENKO_CURRENT_WINDOW);
         //if(1000>0) EventSetMillisecondTimer(1000);
     }

      return(INIT_SUCCEEDED);
 }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   //IndicatorRelease(mm_rapida_handle);
   //IndicatorRelease(mm_media_handle);
   //IndicatorRelease(mm_lenta_handle);
   //IndicatorRelease(macd_handle);
   //IndicatorRelease(handlemacd);
   //IndicatorRelease(ifr_Handle);
   //IndicatorRelease(SAR_HANDLE);
   //IndicatorRelease(IndicatorHandle);
   
   delete (trade);
   delete (Reentrie);
   //GlobalVariableDel_(Symbol());
   for(int i = 0; i < 99; i++) ObjectDelete(0, panelItems[i]);
   
   if(gerar_log == ON)
      Print("[" + trade_comment + "][Ok] Robô removido com sucesso!");
   
   if(ativa_renko == SIM_RENKO)
     {
         RenkoOffline.Stop();
     }
     
  int subwindow=(int)ChartGetInteger(0,CHART_WINDOWS_TOTAL);
   for(int j = subwindow; j>=0; j--)
   {
      int qtdeIndicators=ChartIndicatorsTotal(0, j);
      for(int i=qtdeIndicators-1; i>=0; i--)
      {
         if(!ChartIndicatorDelete(0, j,ChartIndicatorName(0, j, i)))
         {
            PrintFormat("Falha ao remover indicador do grafico, error code %d",
                        GetLastError());
         }
      }
   }
   /*
   janela.Destroy(reason);
   
   //Caso painel visível deleta os objetos   
   DeleteInfoPanel(); */
   
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  
  if(ativa_renko == SIM_RENKO)
     {
         if(!IsStopped()) RenkoOffline.Refresh();
     }

  if(infopanel_enable)
     {
        HistoryUpdate(magic_magico, _Symbol, history);
        InfoPanel_Update(); 
     }
  
  //---CHECK NOTICIAS
  News = new CNews;
  
//  //--- CALENDARIO ECONOMICO
//   CalendarCountries(paises);
//   CalendarEventByCountry("US", eventos);
//
//   CalendarValueHistory(valor, TimeCurrent(), 0, "US", NULL);
//
//   for(int i = 0; i < ArraySize(valor) - 1; i++)
//     {
//      datahoraevento = valor[i].time;
//      //Print("DATA EVENTO = ", datahoraevento);
//      //Print("");
//
//      for(int j = 0; j < ArraySize(eventos) - 1; j++)
//         eventosus =  eventos[j].importance  ;
//
//      //Print("EVENT IMPORTANCE = ", eventosus);
//      if(eventosus == 3 && datahoraevento == TimeCurrent())
//        {
//         //Print("EVENTO IMPORTANTE NO MOMENTO ATUAL");
//         //Print("");
//         Sleep(3600000); // Pausar 1 hrs
//        }
//     }
     
   if(!News.Check())
     Print("TEM NOTICIA !!!");
     
  

//---Criando a base de dados
   //CopyBuffer(macd_handle,0,0,4,macd_buffer);
   //CopyBuffer(mm_rapida_handle,0,0,4,mm_rapida_buffer);
   //CopyBuffer(mm_custom_handle,0,0,4,mm_custom_buffer);
   CopyBuffer(mm_media_handle,0,0,4,mm_media_buffer);
   CopyBuffer(mm_lenta_handle,0,0,4,mm_lenta_buffer);
   CopyBuffer(mm_swing_handle,0,0,4,mm_swing_buffer);
   //CopyBuffer(ifr_Handle,0,0,4,ifr_Buffer);
   CopyBuffer(stoch_handle,0,0,4,stoch);
   
   CopyBuffer(handle_media2,0,0,6,buffer_media2);  
   CopyBuffer(handle_media3,0,0,6,buffer_media3); 
   CopyBuffer(handle_media4,0,0,4,buffer_media4);   
   CopyBuffer(handle_volume,0,0,4,buffer_volume);
   
   //CopyBuffer(IndicatorHandle, 0, 0, 100, adx_line);
   //CopyBuffer(IndicatorHandle, 1, 0, 100, adx_plus_di);
   //CopyBuffer(IndicatorHandle, 2, 0, 100, adx_minus_di);
   //CopyBuffer(SAR_HANDLE, 0, 0, 100, SAR);
   CopyBuffer(atr_Handle, 0, 0, 100, atr_Buffer);
   
   
//--- Alimentar os Buffers das velas
   CopyRates(_Symbol,_Period,0,5,velas);
   
   
//--- Alimentar com dados do tick
   SymbolInfoTick(_Symbol,tick_);

//--- Estrategia MACD
//--- ordenra dados
  ArraySetAsSeries(buffermacd, true);
  ArraySetAsSeries(bufferhistograma, true);
  ArraySetAsSeries(buffermarapida, true);
  ArraySetAsSeries(buffermalenta, true);
  
//--- criando base de dados
  int basedadosmacd = CopyBuffer(handlemacd, 0, 0, 6, buffermacd);
  int basedadoshistograma = CopyBuffer(handlemacd, 2, 0, 6, bufferhistograma);
  int basemarapida = CopyBuffer(handlemarapida, 0, 0, 6, buffermarapida);
  int basemalenta = CopyBuffer(handlemalenta, 0, 0, 6, buffermalenta);
  
//--- verificando se deu erro
  if(basedadoshistograma == -1 || basedadosmacd == -1) {
    Print("ERRO AO OBTER A BASE DE DADOS/BUFFER DO INDICADOR MACD" + " FUNÇÃO: " + __FUNCTION__);
    pode_operar = false;
  }
  
//--- obtendo valores dos buffers
  double valorhistograma0 = NormalizeDouble(bufferhistograma[0], _Digits);
  double valorhistograma1 = NormalizeDouble(bufferhistograma[1], _Digits);
  double valorhistograma2 = NormalizeDouble(bufferhistograma[2], _Digits);
  double valorhistograma3 = NormalizeDouble(bufferhistograma[3], _Digits);
  double valorhistograma4 = NormalizeDouble(bufferhistograma[4], _Digits);
  double valorhistograma5 = NormalizeDouble(bufferhistograma[5], _Digits);

//--- Lógica de compra e venda
   //COMPRA
   //bool compra_mm_cros = mm_rapida_buffer[0] > mm_lenta_buffer[0] &&
   //                        mm_rapida_buffer[2] < mm_lenta_buffer[2];
                           
   //bool compra_macd = (valorhistograma1 > NIVELMACD && velas[0].close > mm_media_buffer[0] 
   //                     && velas[0].close > mm_rapida_buffer[0] && ifr_Buffer[0] < 70 && velas[1].close > velas[1].open &&
   //                      (valorhistograma2 < 0 || valorhistograma3 < 0 || valorhistograma4 < 0 || valorhistograma5 < 0));
   
   //bool compra_adx = adx_line[0] <= 15 && adx_plus_di[0] > adx_minus_di[0];
   
   //bool compra_sar = velas[1].close<SAR[2] && velas[1].close>SAR[1] && atr_Buffer[1] > mm_rapida_buffer[1]; //&& atr_Buffer[0] > mm_rapida_buffer[0];
   
//   double array_resultsTOP[];
//   double array_resultsFUNDO[];
//   if(!SearchZigZagExtremums(3,array_resultsFUNDO,0))//&& !SearchZigZagExtremumsTOP(3,array_resultsTOP)
//      return;
//      
//   if(!SearchZigZagExtremums(3,array_resultsTOP,1))//&& !SearchZigZagExtremumsTOP(3,array_resultsTOP)
//      return;
//
//   double room_1_FUNDO = array_resultsFUNDO[1];
//   double room_2_FUNDO = array_resultsFUNDO[2];
//   
//   double room_1_TOPO  = array_resultsTOP[1];
//   double room_2_TOPO  = array_resultsTOP[2];

//      if (CopyBuffer(fractalHandle, UPPER_LINE, 0, 4, fractalHighVal) < 0)   {
//         //StringConcatenate(logmsg, "","Erro copiando buffer do fractal superior - error:", GetLastError());
//         //logger.slog(__FILE__, __LINE__, RC_LOG_LEVEL_ERROR, logmsg);
//         ResetLastError();
//         return;
//      }
////
//      if (CopyBuffer(fractalHandle, LOWER_LINE, 0, 4, fractalLowVal) < 0)   {
//         //StringConcatenate(logmsg, "","Erro copiando buffer do fractal inferior - error:", GetLastError());
//         //logger.slog(__FILE__, __LINE__, RC_LOG_LEVEL_ERROR, logmsg);
//         ResetLastError();
//         return;
//      }
//
//      if (fractalHighVal[3] == velas[3].high)
//      {
//         lastHiFractal    = fractalHighVal[3];
//      }
//      
////      
//      if (fractalLowVal[3] == velas[3].low)
//      { 
//         lastLoFractal    = fractalLowVal[3];
//         
//      }
      
      //Comment("FUNDO: ",room_1_FUNDO,"\n","TOP: ",room_1_TOPO);//
         
   
   
   //bool compra_scalper = room_1_FUNDO > room_2_FUNDO;//pedro ifr_Buffer[2] <= sobrevendarsi && ifr_Buffer[1] >= sobrevendarsi 
   
   //bool compra_sar = mm_media_buffer[1] > mm_lenta_buffer[1] && mm_lenta_buffer[1] > mm_swing_buffer[1] && velas[1].low <= mm_media_buffer[1] && velas[1].close > mm_media_buffer[1]
                     //&& atr_Buffer[1] > mm_rapida_buffer[1] && velas[1].close > velas[1].open && velas[2].close < mm_media_buffer[2];
   
   //bool compra_scalper = ifr_Buffer[1] < 50 && ifr_Buffer[2] > 50 && velas[1].close < mm_media_buffer[1];
                           
                           //Print(NormalizeDouble(ifr_Buffer[0],_Digits)," - ",NormalizeDouble(mm_rapida_buffer[0],_Digits));
                           
   //bool compra_swing = velas[0].close < mm_lenta_buffer[0] && velas[0].close > mm_swing_buffer[0] && ifr_Buffer[0] < 10;
   //bool compra_swing = //&& velas[1].close > mm_swing_buffer[1] && ifr_Buffer[1] < 10
   
   //bool compra_nasq =  //&& ((velas[1].high <= velas[2].high && velas[1].low >= velas[2].low) || (IsHammer(1)) || (IsSolidCandle(1)));
   
   //bool compra_seguidor_tendencia =  //velas[3].low < velas[2].low && velas[1].high <= velas[2].high && velas[1].low >= velas[2].low && velas[1].close > mm_media_buffer[1] && velas[1].close > mm_lenta_buffer[1];//velas[1].close < velas[1].open && velas[1].close > mm_lenta_buffer[1] && velas[1].close > mm_media_buffer[1]; //velas[3].low > velas[2].low && velas[2].high < velas[1].high && velas[2].low > velas[1].low && velas[1].close > mm_lenta_buffer[1] && velas[1].close > mm_media_buffer[1];
   
   //bool compra_adx = velas[0].close<SAR[1] && velas[0].close>SAR[0];
   
   /*                        
   bool compra_macd = macd_buffer[1] <= 0 && macd_buffer[0] > 0;
   // Check if the current price is above the high pivot point
   if (Ask > high_pivot)
   {
      // Calculate the number of lots to trade based on the risk per trade and account balance
      double lots = balance * RISK_PER_TRADE / (Ask - low_pivot);

      // Place a long (buy) order
      OrderSend(SYMBOL, OP_BUY, lots, Ask, 3, low_pivot, high_pivot);
   }

   // Check if the current price is below the low pivot point
   else if (Ask < low_pivot)
   {
      // Calculate the number of lots to trade based on the risk per trade and account balance
      double lots = balance * RISK_PER_TRADE / (high_pivot - Ask);

      // Place a short (sell) order
      OrderSend(SYMBOL, OP_SELL, lots, Ask, 3, low_pivot, high_pivot);
   }
   */
   //VENDA
   
   //bool venda_mm_cros = mm_lenta_buffer[0] > mm_rapida_buffer[0] &&
   //                       mm_lenta_buffer[2] < mm_rapida_buffer[2]; 
   
   //bool venda_macd =(valorhistograma1 < -NIVELMACD && velas[0].close < mm_media_buffer[0] 
   //                    && velas[0].close < mm_rapida_buffer[0] && ifr_Buffer[0] > 30 && velas[1].close < velas[1].open &&
   //                     (valorhistograma2 > 0 || valorhistograma3 > 0 || valorhistograma4 > 0 || valorhistograma5 > 0));
                        
   //bool venda_adx = adx_line[0] >= 50 && adx_plus_di[0] > adx_minus_di[0];
   
   //bool venda_sar = velas[1].close>SAR[2] && velas[1].close<SAR[1] && atr_Buffer[1] < mm_rapida_buffer[1]; //&& atr_Buffer[0] < mm_rapida_buffer[0];
   //bool venda_scalper =  room_1_TOPO < room_2_TOPO;   //pedro ifr_Buffer[2] >= sobrecomprarsi && ifr_Buffer[1] <= sobrecomprarsi && 
   
   
   
   //bool venda_sar = mm_media_buffer[1] < mm_lenta_buffer[1] && mm_lenta_buffer[1] < mm_swing_buffer[1] && velas[1].high >= mm_media_buffer[1] && velas[1].close < mm_media_buffer[1]
                    //&& atr_Buffer[1] > mm_rapida_buffer[1] && velas[1].close < velas[1].open && velas[2].close > mm_media_buffer[2];
   //bool venda_scalper = ifr_Buffer[1] > 50 && ifr_Buffer[2] < 50 && velas[1].close > mm_media_buffer[1];
                          
   //bool venda_swing = velas[0].close > mm_media_buffer[0] && velas[0].close < mm_swing_buffer[0] && ifr_Buffer[0] > 90;
   //bool venda_swing = //&& velas[1].close < mm_swing_buffer[1] velas[1].close > mm_media_buffer[1]  && ifr_Buffer[1] > 90
   
   //bool venda_nasq =  //&& ((velas[1].high <= velas[2].high && velas[1].low >= velas[2].low) || (IsShootingStar(1)) || (IsSolidCandle(1)));//&& velas[1].close < mm_swing_buffer[1] velas[1].close > mm_media_buffer[1]  && ifr_Buffer[1] > 90
   
   //bool venda_seguidor_tendencia = velas[3].high < velas[2].high && velas[1].high <= velas[2].high && velas[1].low >= velas[2].low && velas[1].close < mm_media_buffer[1] && velas[1].close < mm_lenta_buffer[1];//velas[1].close > velas[1].open && velas[1].close < mm_lenta_buffer[1] && velas[1].close < mm_media_buffer[1]; //velas[3].high < velas[2].high && velas[2].low < velas[1].low && velas[2].high < velas[1].high && velas[1].close < mm_lenta_buffer[1] && velas[1].close < mm_media_buffer[1];
   
   //bool venda_adx = velas[0].close>SAR[1] && velas[0].close<SAR[0];
   
                        
   /*                        
   bool venda_macd = macd_buffer[1] >= 0 && macd_buffer[0] < 0; 
   */
   
   bool Comprar = false;
   bool Vender  = false;
   
   
   //if(estrategia == APENAS_MM)
   //  {
   //   Comprar  = compra_mm_cros;
   //   Vender   = venda_mm_cros;
   //  } else 
           if(estrategia == LIVWELL)
                     {
                       if(inverte_ordem)
                         {
                           Vender  = velas[1].open <= mm_lenta_buffer[1] && velas[1].close > velas[1].open && stoch[1] <= 20 && ((velas[1].high <= velas[2].high && velas[1].low >= velas[2].low) || (IsHammer(1)) || (IsSolidCandle(1)));
                           Comprar = velas[1].open >= mm_media_buffer[1] && velas[1].close < velas[1].open && stoch[1] >= 80 && ((velas[1].high <= velas[2].high && velas[1].low >= velas[2].low) || (IsShootingStar(1)) || (IsSolidCandle(1)));
                         } else
                             {
                              Comprar = velas[1].open <= mm_lenta_buffer[1] && velas[1].close > velas[1].open && stoch[1] <= 20 && ((velas[1].high <= velas[2].high && velas[1].low >= velas[2].low) || (IsHammer(1)) || (IsSolidCandle(1)));
                              Vender  = velas[1].open >= mm_media_buffer[1] && velas[1].close < velas[1].open && stoch[1] >= 80 && ((velas[1].high <= velas[2].high && velas[1].low >= velas[2].low) || (IsShootingStar(1)) || (IsSolidCandle(1)));
                             }
                     } else if(estrategia == LIVWELL_TENDENCIA)
                         {
                          Comprar = velas[1].open <= mm_lenta_buffer[1] && velas[1].close > velas[1].open && stoch[1] <= 20 && velas[1].close > mm_swing_buffer[1];
                          Vender  = velas[1].open >= mm_media_buffer[1] && velas[1].close < velas[1].open && stoch[1] >= 80 && velas[1].close < mm_swing_buffer[1];
                          } 
                          else if(estrategia == SUPPLY)
                              {
                                    //Garante que não seja aberta mais de uma operação no mesmo candle
                                       if(candle_atual != velas[0].time)
                                       {
                                          //Verifica se não existe nenhum ordem ou posição
                                          if(SemPosicao() && SemOrdem() && !Lucro_Diario() && !Loss_Diario())
                                          {
                                             if(FiltroCaixa())
                                             {
                                                int sinal = Estrategia_Supply();
                                    
                                                if(sinal == 1)
                                                   Compra();
                                                else if(sinal == -1)
                                                   Venda();
                                             }
                                          }
                                       } 
                              } else if(estrategia == DRAGON)
                                  {
                                    bool vComprar = velas[1].close > velas[1].open;
                                    bool vVender  = velas[1].close < velas[1].open;
                                    
                                    javendeu = false;
                                    jacomprou = false;
                                    
                                   if(posVenda())
                                     {
                                      javendeu = true;
                                     } 
                                     
                                     if(posCompra())
                                     {
                                      jacomprou = true;
                                     }

                                    if(vComprar && !jacomprou) {
                                       Compra(); 
                                       jacomprou = true;
                                       javendeu = false;
                                       }
                                    else if(vVender && !javendeu) {
                                       Venda(); 
                                       jacomprou = false;
                                       javendeu = true;
                                       }
                                       
                                  } 
                                  else if(estrategia == RENKO_OURO)
                                      {
                                        Comprar = ( buffer_media2[1] > buffer_media3[1] &&
                                        buffer_media3[1] > mm_swing_buffer[1] &&
                                        //velas[1].close > velas[1].open && velas[2].close < velas[2].open && velas[3].close < velas[3].open && velas[4].close < velas[4].open &&
                                        velas[1].close > buffer_media2[1] && velas[1].open < buffer_media2[1] && buffer_volume[1] > buffer_media4[1]);
                      
                                        Vender = (buffer_media2[1] < buffer_media3[1] &&
                                        buffer_media3[1] < mm_swing_buffer[1] &&
                                        //velas[1].close < velas[1].open && velas[2].close > velas[2].open && velas[3].close > velas[3].open && velas[4].close > velas[4].open &&
                                        velas[1].close < buffer_media2[1] && velas[1].open > buffer_media2[1] && buffer_volume[1] > buffer_media4[1]);
                                      } else
                                          {
                                             Comprar = valorhistograma1 > NIVELMACD && velas[0].close > buffer_media2[0] 
                                                       && velas[0].close > buffer_media3[0] && velas[1].close > velas[1].open &&
                                                       (valorhistograma2 < 0 || valorhistograma3 < 0 || valorhistograma4 < 0 || valorhistograma5 < 0) 
                                                       && buffer_media2[1] > buffer_media3[1] && buffer_media2[2] <= buffer_media3[2] 
                                                       && buffer_media2[3] <= buffer_media3[3] && buffer_media2[4] <= buffer_media3[4];
                                                 
                                             Vender = valorhistograma1 < -NIVELMACD && velas[0].close < buffer_media2[0] 
                                                      && velas[0].close < buffer_media3[0] && velas[1].close < velas[1].open &&
                                                      (valorhistograma2 > 0 || valorhistograma3 > 0 || valorhistograma4 > 0 || valorhistograma5 > 0)
                                                      && buffer_media2[1] < buffer_media3[1] && buffer_media2[2] >= buffer_media3[2]
                                                      && buffer_media2[3] >= buffer_media3[3] && buffer_media2[4] >= buffer_media3[4];
                                          }
                          

   
   //---Verifica Vela (Comprar na outra vela)
   bool TemosNovaVela = TemosNovaVela();
   
    posAberta = false;
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == ativoOp && magic == magic_magico)
               {  
                  posAberta = true;
                  break;
               }
         }
            
      ordPendente = false;
      for(int i = OrdersTotal()-1; i>=0; i--)
         {
            ulong ticket = OrderGetTicket(i);
            string symbol = OrderGetString(ORDER_SYMBOL);
            ulong magic = OrderGetInteger(ORDER_MAGIC);
            if(symbol == ativoOp && magic == magic_magico)
               {
                  ordPendente = true;
                  break;
               }
         }
         
      if(last_candle != iTime(_Symbol, PERIOD_CURRENT, 0)) {
            last_candle = iTime(_Symbol, PERIOD_CURRENT, 0);
            HistoryUpdate(magic_magico, _Symbol, history);
            if(CountPositions(magic_magico, _Symbol) == 0)
               position_in_this_candle = false;
         }
   
   if(v_indicador)
   {
     if(Comprar)
        desenhaLinhaVertical("Compra",velas[1].time,clrBlue);
     else if(Vender)
        desenhaLinhaVertical("Venda",velas[1].time,clrRed);
   }
   
   if(horaPodeOperar(inicio_op,fim_op) && (!entries_only_one_per_candle || !position_in_this_candle) && !Lucro_Diario() && !Loss_Diario() && !v_indicador && FiltroCaixa() && News.Check())// TemosNovaVela &&
     {
      //Condição de Compra
      if(Comprar && !posAberta  && pode_operar && (trade_mode == BUY_AND_SELL || trade_mode == BUY_ONLY) && CheckMoneyForTrade(ativoOp,entries_lot_size,ORDER_TYPE_BUY))//&& magic_magico == magic && !ordPendente
        {
         
//            if(estrategia == SEGUIDOR_TENDENCIA)
//              {
//                  //desenhaLinhaVertical("Compra",velas[1].time,clrBlue);
//                  cancelarOrdem();
//                  double StopLoss = (atr_Buffer[1] * 2);
//                  double GaingStop = (atr_Buffer[1] * 1);
//                  
//                  double sl = StopLoss != 0 ? NormalizePrice(tick_.ask - NormalizeSize(entries_stop_type, StopLoss)) : 0;
//                  double tp = NormalizePrice(tick_.ask + NormalizeSize(entries_target_type, GaingStop));
//                  if(!trade.BuyLimit(entries_lot_size,velas[1].low, ativoOp, sl, tp) )
//                  {
//                     if(gerar_log == ON)
//                         Print("[" + trade_comment + "][Erro] Não foi possível criar ordem!");     
//                  }   
//                  else {
//                     lastPositionTime = iTime(_Symbol, PERIOD_CURRENT, 0);
//                     position_in_this_candle = true;}
//
//                  
//                  beAtivo  = false;
//                  parAtivo = false;
//                  trailing_par_ativo = false;
//              } else
//                  {
                     candle_atual = velas[0].time;
                     stops_ajustados = false;
                     ultima_entrada = TimeCurrent() - 1;
                     desenhaLinhaVertical("Compra",velas[1].time,clrBlue);
                     if(ordPendente)
                        cancelarOrdem();
                     double sl,tp = 0;                                        
                     
                     if(stop_anterior)
                       {
                        sl = velas[1].low;
                        tp = NormalizePriceDS(tick_.ask + NormalizeSize(entries_target_type, entries_target_size));
                       } else if(stop_atr)
                          {
                           //double StopLoss = 2 * atr_Buffer[0];
                           //double GaingStop = 1 * atr_Buffer[0];
                           //sl = NormalizePriceDS(tick_.ask - NormalizeSize(entries_stop_type, StopLoss));
                           //tp = NormalizePriceDS(tick_.ask + NormalizeSize(entries_target_type, GaingStop));
                           sl=NormalizePriceDS((1.5==0)?0.0:tick_.ask-atr_Buffer[0]*(double)1.5);
                           tp=NormalizePriceDS((1==0)?0.0:tick_.ask+atr_Buffer[0]*(double)1);
                           //sl = tick_.ask + StopLoss * _Point;
                           //Comment("STOP: ",sl," TAKE",tp);
                          } else
                              {
                                 sl = entries_stop_size != 0 ? NormalizePriceDS(tick_.ask - NormalizeSize(entries_stop_type, entries_stop_size)) : 0;
                                 tp = NormalizePriceDS(tick_.ask + NormalizeSize(entries_target_type, entries_target_size));
                              }
                     
                     if(ativar_recovery) {
                         lote = lot();
                       } else {
                         lote = entries_lot_size;
                       }
                     
                     if(estrategia != LIVWELL)
                       {
                        env_pos = false;
                        if(!trade.Buy(entries_lot_size, ativoOp, tick_.ask, sl, tp, "[" + trade_comment + "]"))//
                        {
                           if(gerar_log == ON)
                               Print("[" + trade_comment + "][Erro] Não foi possível criar ordem!");     
                        }   
                        else {
                           lastPositionTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                           position_in_this_candle = true;}
                       } else
                           {
                            
                              
                            double alvo = velas[2].high;
                            if(velas[1].high > alvo)
                              alvo = velas[1].high; 
                              
                            
                            if(!trade.BuyLimit(NormalizeDouble(lote,2),alvo, ativoOp, sl, tp) )//|| !trade.BuyStop(NormalizeDouble(lote,2),alvo, ativoOp, sl, tp) trade.Buy(entries_lot_size, ativoOp, tick_.ask, sl, tp, "[" + trade_comment + "]")
                              {
                                 if(gerar_log == ON)
                                     Print("[" + trade_comment + "][Erro] Não foi possível criar ordem!");                 
                              }   
                              else {
                                 lastPositionTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                                 position_in_this_candle = true;}
                                 volume_anterior_preco_medio = entries_lot_size;
                           }
                     
   
                     
                     beAtivo  = false;
                     parAtivo = false;
                     trailing_par_ativo = false;
                  //}

                  
        }
        
      //Condição de Venda
      if(Vender && !posAberta  && pode_operar && (trade_mode == BUY_AND_SELL || trade_mode == SELL_ONLY) && CheckMoneyForTrade(ativoOp,entries_lot_size,ORDER_TYPE_SELL))//&& magic_magico == magic && !ordPendente
        {
         
//            if(estrategia == SEGUIDOR_TENDENCIA)
//              {
//                     //desenhaLinhaVertical("Venda",velas[1].time,clrRed);
//                     cancelarOrdem();
//                     double StopLoss = (atr_Buffer[1] * 2);
//                     double GaingStop = (atr_Buffer[1] * 1);
//                     
//                     double sl = StopLoss != 0 ? NormalizePrice(tick_.bid + NormalizeSize(entries_stop_type, StopLoss)) : 0;
//                     double tp = NormalizePrice(tick_.bid - NormalizeSize(entries_target_type, GaingStop));
//                     if(!trade.SellLimit(entries_lot_size,velas[1].high, ativoOp, sl, tp) )
//                     {
//                        if(gerar_log == ON)
//                           Print("[" + trade_comment + "][Erro] Não foi possível criar ordem!");
//                     }
//                     else {
//                           lastPositionTime = iTime(_Symbol, PERIOD_CURRENT, 0);
//                           position_in_this_candle = true;}
//           
//                     
//                     beAtivo  = false;
//                     parAtivo = false;
//                     trailing_par_ativo = false;
//              } else
//                  {
                     candle_atual = velas[0].time;
                     stops_ajustados = false;
                     ultima_entrada = TimeCurrent() - 1;
                     desenhaLinhaVertical("Venda",velas[1].time,clrRed);
                     if(ordPendente)
                        cancelarOrdem();
                     double sl,tp = 0;
                     
                     
                     if(stop_anterior)
                       {
                        sl = velas[1].high;
                       } else sl = entries_stop_size != 0 ? NormalizePriceDS(tick_.bid + NormalizeSize(entries_stop_type, entries_stop_size)) : 0;    
                           tp = NormalizePriceDS(tick_.bid - NormalizeSize(entries_target_type, entries_target_size));
                     
                     if(stop_atr)
                          {
//                           double StopLoss = (atr_Buffer[1] * 2);
//                           double GaingStop = (atr_Buffer[1]);
//                           
//                           sl = StopLoss != 0 ? NormalizePriceDS(tick_.bid + NormalizeSize(entries_stop_type, StopLoss)) : 0;
//                           tp = NormalizePriceDS(tick_.bid - NormalizeSize(entries_target_type, GaingStop));
                           sl=(1.5==0)?0.0:tick_.bid+atr_Buffer[0]*(double)1.5;
                           tp=(1==0)?0.0:tick_.bid-atr_Buffer[0]*(double)1;
                           //Comment("STOP: ",sl," TAKE",tp);
                          }
                     
                     if(ativar_recovery) {
                         lote = lot();
                       } else {
                         lote = entries_lot_size;
                       }
                       
                     if(estrategia != LIVWELL)
                       {
                        env_pos = false;
                        if(!trade.Sell(entries_lot_size, ativoOp, tick_.bid, sl, tp, "[" + trade_comment + "]"))//
                        {
                           if(gerar_log == ON)
                              Print("[" + trade_comment + "][Erro] Não foi possível criar ordem!");
                        }
                        else {
                              lastPositionTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                              position_in_this_candle = true;}
                       } else
                           {
                            
                            double alvo = velas[2].low;
                            if(velas[1].low < alvo)
                              alvo = velas[1].low;
                              
                            if(!trade.SellLimit(NormalizeDouble(lote,2),alvo, ativoOp, sl, tp)  )// || !trade.SellStop(NormalizeDouble(lote,2),alvo, ativoOp, sl, tp) trade.Sell(entries_lot_size, ativoOp, tick_.bid, sl, tp, "[" + trade_comment + "]")
                              {
                                 if(gerar_log == ON)
                                    Print("[" + trade_comment + "][Erro] Não foi possível criar ordem!");
                              }
                              else {
                                    lastPositionTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                                    position_in_this_candle = true;
                                    volume_anterior_preco_medio = entries_lot_size;}
                           }
                     
                     
            
                     
                     beAtivo  = false;
                     parAtivo = false;
                     trailing_par_ativo = false;
                  //}
                  
        }
     }
     
   
   //Fechar posição na estrategia day trade  
//   if(estrategia == APENAS_CONSERVADOR && PositionSelect(ativoOp) && TemosNovaVela)
//     {
//         if(velas[0].close > velas[0].open)
//           {
//               ClosePositions(magic_magico, ativoOp);
//           }
//           
//         if(velas[0].close < velas[0].open)
//           {
//               ClosePositions(magic_magico, ativoOp);
//           }
//     }
     

   
   //Fechar na Média oposta  
   if(out_by_ma && CountPositions(magic_magico, _Symbol) > 0) {
         int side = 0;
         for(int i = 0; i < PositionsTotal(); i++) {
            if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic_magico) continue;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) side = 1;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) side = 2;
         }

         if(side == 2) {
            //if(CopyBuffer(mm_media_handle, 0, 0, 1, ma) != 1) return;
            if(mm_lenta_buffer[0] > iClose(_Symbol, PERIOD_CURRENT, 0)) {
               if(gerar_log == ON)
                  Print("[" + trade_comment + "][OK] Fechando posições pelo toque na media!");
               ClosePositions(magic_magico, _Symbol);
            }
         } else if(side == 1) {
            //if(CopyBuffer(mm_lenta_handle, 0, 0, 1, ma) != 1) return;
            if(mm_media_buffer[0] < iClose(_Symbol, PERIOD_CURRENT, 0)) {
               if(gerar_log == ON)
                  Print("[" + trade_comment + "][OK] Fechando posições pelo toque na media!");
               ClosePositions(magic_magico, _Symbol);
            }
         }
      }
      
   
   
     
      
   //---Controle Financeiro
  //controle_financeiro_diario(ativoOp,lucro_max_dia,perda_max_dia); 
  //if(!Lucro_Diario() && !Loss_Diario())
    
      
   if(NewDay())
     {
        pode_operar = true;
        if(contarealoudemo == ACCOUNT_TRADE_MODE_REAL || contarealoudemo == ACCOUNT_TRADE_MODE_DEMO)// 
         vencimento2();
         
        if (TimeCurrent() > expiracao)
          {
             Alert("Periodo de uso do robô expirado, contate o admin!");
             ExpertRemove();
          } 
         
        News.Sync(TimeCurrent(),TimeCurrent());
        
        //--- Controle de vencimento
//        ENUM_ACCOUNT_TRADE_MODE contarealoudemo = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
//        switch(contarealoudemo) {
//        case(ACCOUNT_TRADE_MODE_DEMO):
//         if(gerar_log == ON)
//            Print("\n" +"ROBÔ PERMITIDO OPERAR");
//            
//         if (TimeCurrent() > expiracao)
//          {
//             Alert("Periodo de uso do robô expirado, contate o admin!");
//             ExpertRemove();
//          } 
//        break;
//        case(ACCOUNT_TRADE_MODE_REAL):
//         vencimento1();
//        break;
//        default:
//         if(gerar_log == ON)
//            Print("\n" + "DUVIDAS ENTRE EM CONTATO");
//         ExpertRemove();
//        }
        
//        if(estrategia == B3)
//          {
//           Diafechamento = iClose(_Symbol, PERIOD_D1, 1);
//           DiaAbertura = iOpen(_Symbol, PERIOD_D1, 1);
//           DiaMax  = iHigh(_Symbol, PERIOD_D1, 1);
//           DiaMin  =iLow(_Symbol, PERIOD_D1, 1);
//            
//           CriarLinhaH(0, 0, "LinaMAX", DiaMax,clrRed, STYLE_SOLID, 3, true, false, false, "Maxima do Dia @ +(string)DiaMax");
//           CriarLinhaH(0, 0, "LinaMIN", DiaMin,clrRed, STYLE_SOLID, 3, true, false, false, "Minima do Dia @ +(string)DiaMin");
//           CriarLinhaH(0, 0, "LinaAbertura", DiaAbertura,clrYellow, STYLE_DASHDOT, 1, true, false, false, "Abertura @ +(string)DiaAbertura");
//           CriarLinhaH(0, 0, "LinaFecamento", Diafechamento,clrYellowGreen, STYLE_SOLID, 1, true, false, false, "Fecamento @ +(string)Diafecamento");
//          }
        
         
     }
     
   if(liga_breakeven == SIM && !beAtivo)
         {
            BreakEven2();
         }
         
   //---TS
   if(liga_train == SIM_TS)
     {
         //TrailingStop(tick_.last,StartTS,StepTS);
         fTrailingDefault(magic_magico,inpTrStart,inpTrStep,inpMedidaTr,_Symbol);
     }
     
   if(liga_train_candle_candle == true)
     {
         realizartrailingstop(ativoOp,inpTrStart,velas[1].low,velas[1].high,tick_.last);
     }
   
   //---Parcial
   if(liga_par == SIM_PARCIAL && !parAtivo)
     {
         fazerParcial(nContrato,nContrato2,nContrato3,nContrato4,nContrato5,nContrato6,nContrato7,StartParcial,StartParcial2,StartParcial3,StartParcial4,StartParcial5,StartParcial6,StartParcial7,tick_.last);
     } 
     
  //--- Reentrada
  //ulong magic = PositionGetInteger(POSITION_MAGIC);
  //if(PositionSelect(_Symbol) && magic_magico == magic){
  if(CountPositions(magic_magico, _Symbol) > 0 && iReentriesDistance1 > 0) {
      Reentrie.Update();
      double median_buy = MedianPrice(magic_magico, _Symbol, POSITION_TYPE_BUY);
      double median_sell = MedianPrice(magic_magico, _Symbol, POSITION_TYPE_SELL);
      if(median_buy != -1)SetMedianTp(magic_magico, POSITION_TYPE_BUY, NormalizePriceDS(median_buy + NormalizeSize(entries_target_type, entries_target_size)), _Symbol);
      if(median_sell != -1)SetMedianTp(magic_magico, POSITION_TYPE_SELL, NormalizePriceDS(median_sell - NormalizeSize(entries_target_type, entries_target_size)), _Symbol);
      }
      
  //--- Maximo DD
  if(max_dd > 0)
    FreioBurro();
  
      
      
//Verifica se existe posição
   if(!SemPosicao() && (ativar_medio_invertido || usar_preco_medio))
   {
      //Garante que não seja aberta mais de uma posição no mesmo candle
      if(candle_atual != velas[0].time)
         candle_atual = velas[0].time;

      if(!stops_ajustados)
      {
         if(AjustarStopsIniciais())
            stops_ajustados = true;
      }

      if(usar_preco_medio)
      {
         RealizarPrecoMedio();

         VerificarGanhoPrecoMedio();
         
         //Reajusta o take proft após raalizar preço médio
//         if(distancia_medio > 0 && multiplicador_medio > 0)
//         {
//            double volume = VolumePosicao();
//
//            if(volume > volume_anterior_preco_medio)
//            {
//               if(AjustarTakeAposAumentoPosicao(entries_target_size))
//                  volume_anterior_preco_medio = volume;
//            }
//            else
//               volume_anterior_preco_medio = volume;
//         } 
//         if(PositionSelect(ativoOp) && PositionsTotal() > 1)
//           {
//               for(int i = PositionsTotal(); i >= 0; i--) {
//                   ulong ticket = PositionGetTicket(i);
//               
//                   double pos_tp     = PositionGetDouble(POSITION_TP);
//               
//                   //trade.PositionModify(ticket, GetCurrentMeanPrice(ativoOp,magic_magico), pos_tp);
//                   
//                   if(PositionGetDouble(POSITION_PRICE_CURRENT) + 100 >= GetCurrentMeanPrice(ativoOp,magic_magico) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
//                     {
//                        ClosePositions(magic_magico,ativoOp);
//                     }
//                     
//                   if(PositionGetDouble(POSITION_PRICE_CURRENT) - 100 >= GetCurrentMeanPrice(ativoOp,magic_magico) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
//                     {
//                        ClosePositions(magic_magico,ativoOp);
//                     }
//               
//               }
//           }
      }

      if(ativar_medio_invertido)
      {
         if(!conta_netting)
         {
              //controle_ganho(ativoOp,ganho_preco_medio);
              
            
            if(SemOrdem())
            {
               UltimaOperacao operacao;

               if(DadosUltimaOperacao(operacao))
               {


                  if(operacao.tipo_posicao == 1)
                  {
                     double preco = NormalizeDouble(operacao.sl + NormalizePricePrecoMedioeCaixa(entries_target_size), _Digits);
                     double tp = operacao.sl;
                     double sl = operacao.tp;
                     double lote_calculado = (operacao.volume == CalcularLote(lote)) ? CalcularLote(operacao.volume * multiplicador_medio_invertido) : CalcularLote(operacao.volume * multiplicador_medio_invertido);

                     if(lote_calculado <= lote_maximo || lote_maximo == 0)
                        SellStop(lote_calculado, preco, sl, tp);
                  }
                  else if(operacao.tipo_posicao == -1)
                  {
                     double preco = NormalizeDouble(operacao.sl - NormalizePricePrecoMedioeCaixa(entries_target_size), _Digits);
                     double tp = operacao.sl;
                     double sl = operacao.tp;
                     double lote_calculado = (operacao.volume == CalcularLote(lote)) ? CalcularLote(operacao.volume * multiplicador_medio_invertido) : CalcularLote(operacao.volume * multiplicador_medio_invertido);


                     if(lote_calculado <= lote_maximo || lote_maximo == 0)
                        BuyStop(lote_calculado, preco, sl, tp);
                  }
               }
            }
         }
         else
         {
            if(SemOrdem())
            {
               UltimaOperacao operacao;

               if(DadosUltimaOperacao(operacao))
               {
                  if(operacao.tipo_posicao == 1)
                  {
                     double preco = NormalizeDouble(operacao.preco - NormalizePricePrecoMedioeCaixa(entries_target_size), _Digits);
                     double tp = operacao.sl;
                     double sl = operacao.tp;
                     double lote_calculado = (operacao.volume == CalcularLote(lote)) ? CalcularLote((operacao.volume * multiplicador_medio_invertido) + operacao.volume) : CalcularLote((operacao.volume * multiplicador_medio_invertido) + operacao.volume);

                     if(lote_calculado <= lote_maximo || lote_maximo == 0)
                        SellStop(lote_calculado, preco, sl, tp);
                  }
                  else if(operacao.tipo_posicao == -1)
                  {

                     double preco = NormalizeDouble(operacao.preco + NormalizePricePrecoMedioeCaixa(entries_target_size), _Digits);
                     double tp = operacao.sl;
                     double sl = operacao.tp;
                     double lote_calculado = (operacao.volume == CalcularLote(lote)) ? CalcularLote((operacao.volume * multiplicador_medio_invertido) + operacao.volume) : CalcularLote((operacao.volume * multiplicador_medio_invertido) + operacao.volume);

                     if(lote_calculado <= lote_maximo || lote_maximo == 0)
                        BuyStop(lote_calculado, preco, sl, tp);
                  }
               }
            }
         }
      }
   }
   else
   {
      //Verifica se existe ordem para ser deletada já que não exite posição
      if(!SemOrdem() && estrategia != LIVWELL)
      {
         Print("Deletando Ordem... Não existe posição");
         DeletarOrdem();
      }

   }
      
  
  InverterPosicao(entries_lot_size,iDistanceVM1);
  
  
  //--- Controlar horário de limite
//  if(TimeToString(TimeCurrent(),TIME_MINUTES) >= hora_limite_fecha_op && PositionSelect(ativoOp)==true)
//    {
//     Print("Encerrar todas as posições abertas!");
//     
//     FecharPosicao();
//     pode_operar = false;
//    }
   
  }
  
bool posVenda()
{
for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == ativoOp && magic == magic_magico && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               {  
                  return true;
                  break;
               }
         }
         
         return false;
}


bool posCompra()
{
for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == ativoOp && magic == magic_magico && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {  
                  return true;
                  break;
               }
         }
         
         return false;
}

//+------------------------------------------------------------------+
void RealizarPrecoMedio()
{
   const double lote_normalizado = CalcularLote(lote);
   const double distancia_normalizada = NormalizePricePrecoMedioeCaixa(distancia_medio);
   double volume_posicao = VolumePosicao();

   if(max_lote_medio == 0 || volume_posicao < max_lote_medio)
   {
      //Verifica se é a primeira operação
      if(lote_normalizado == volume_posicao)
      {
         int tipo_posicao = TipoPosicao();
         double preco_medio = PrecoMedio();

         if(tipo_posicao == 1)
         {
            if(velas[0].close <= preco_medio - distancia_normalizada)
            {
               double lote_calculado = CalcularLote(volume_posicao * multiplicador_medio);
               if(Venda(lote_calculado, 0, 0, "Venda"))
                  RemoverStopsPosicao();
            }
         }
         else
         {


            if(velas[0].close >= preco_medio + distancia_normalizada)
            {

               double lote_calculado = CalcularLote(volume_posicao * multiplicador_medio);
               if(Compra(lote_calculado, 0, 0, "Compra"))
                  RemoverStopsPosicao();
            }
         }
      }
      else
      {
         UltimaOperacao operacao = UltimaOperacaoRealizada();


         if(operacao.preco != 0)
         {
            double volume_posicao = VolumePosicao();
            if(operacao.tipo_posicao == 1)
            {
               if(velas[0].close <= operacao.preco - distancia_normalizada)
               {
                  double lote_calculado = CalcularLote(volume_posicao * multiplicador_medio);
                  Compra(lote_calculado, 0, 0, "Compra");
               }
            }
            else if(operacao.tipo_posicao == -1)
            {
               if(velas[0].close >= operacao.preco + distancia_normalizada)
               {
                  double lote_calculado = CalcularLote(volume_posicao * multiplicador_medio);
                  Venda(lote_calculado, 0, 0, "Venda");
               }
            }
         }


      }

   }
}

//+------------------------------------------------------------------+
//|TOTAL DE LUCRO ACUMULADO                                          |
//+------------------------------------------------------------------+
double LucroAcumulado()
   {
      
      double lucro_acum = 0;
      double lucro = 0;
      
      HistorySelect(0,TimeCurrent());
      
      int tn = HistoryDealsTotal();
      
      //Print("Total de negócios = ", tn); 
      
      //Print("Negócio 2 Lucro = ", );
      
      for(int i=1;i<=tn;i++)
        {
            ulong tick_n = HistoryDealGetTicket(i);
            
            lucro = HistoryDealGetDouble(tick_n,DEAL_PROFIT);
            //Print("Negócio (",i, ") , Lucro = ",lucro );
            
            lucro_acum = lucro_acum + lucro; // lucro_acum += lucro
            
        }
   
      return lucro_acum;
   }

void controle_ganho(string ativo, double lucro_maximo_dia)
{
   if(PositionSelect(ativo))
        {
         double lucro = LucroAtual();
         
         
         Print("Lucro atual = ",lucro);
         
         if(lucro >= lucro_maximo_dia)
           {
            ClosePositions(magic_magico,ativo);
            //podeOperar = false;
            Print("Limite de ganho batido: ",lucro_maximo_dia);
           }
         
         }  
 } 

//---
void VerificarGanhoPrecoMedio()
{
   const double lote_normalizado = CalcularLote(lote);
   double volume_posicao = VolumePosicao();
   //Verifica se é a primeira operação
   if(volume_posicao > lote_normalizado)
   {
      double lucro = LucroAtual();

      if(lucro >= ganho_preco_medio && ganho_preco_medio != 0)
      {
         Print("Fechando operação lucro por operação atingido, lucro: ", lucro, ", ganho: ", ganho_preco_medio);
         FecharTodasPosicao();
      }

      const double perda = (perda_preco_medio > 0) ? perda_preco_medio * -1 : perda_preco_medio;

      if(lucro <= perda && perda != 0)
      {
         Print("Fechando operação perda por operação atingido, lucro: ", lucro, ", parâmetro: ", perda);
         FecharTodasPosicao();
      }
   }
}
//---
void FreioBurro()
{
   const double lote_normalizado = CalcularLote(lote);
   double volume_posicao = VolumePosicao();
   //Verifica se é a primeira operação
   if(volume_posicao > lote_normalizado)
   {
      double lucro = LucroAtual();

      const double perda = (max_dd > 0) ? max_dd * -1 : max_dd;

      if(lucro <= perda && perda != 0)
      {
         Print("Fechando operação perda por operação atingido, lucro: ", lucro, ", parâmetro: ", perda);
         pode_operar = false;
         FecharTodasPosicao();
      }
   }
}
//---
double LucroAtual()
{
   int total = PositionsTotal() - 1;
   double lucro = 0;

   for(int i = total; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
            lucro += PositionGetDouble(POSITION_PROFIT);
      }
   }



   return lucro;
}  

//---
double VolumePosicao()
{
   double volume_posicao = 0;

   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
            volume_posicao += PositionGetDouble(POSITION_VOLUME);
      }
   }

   return volume_posicao;
}

//---
int TipoPosicao()
{
   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               return 1;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               return -1;
         }
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RemoverStopsPosicao()
{
   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);




            double novo_sl = 0;
            double novo_tp = 0;

            //Verifica se o stop loss ou o take proft é diferente do configurado
            if(novo_sl != sl || novo_tp != tp)
            {

               if(trade.PositionModify(ticket, novo_sl, novo_tp))
               {
                  Mostre("Stops removidos com sucesso na operação de compra no " + PositionGetString(POSITION_SYMBOL) + "Sl: " + (string)novo_sl + ", Tp: " + (string)novo_tp);
               }
               else
               {
                  Mostre("Erro ao remover stops da posição de compra no " + PositionGetString(POSITION_SYMBOL) + "Sl: " + (string)sl + ", Tp: " + (string)tp + " -> Sl: " + (string)novo_sl + ", Tp: " + (string)novo_tp + " Erro: " + (string)GetLastError());

               }

            }

         }
      }
   }
 
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Compra()
{
   double preco = tick_.ask;
   double sl = ObterStopLoss(1, preco);
   double tp = ObterTakeProft(1, preco);
   double lote_calculado = CalcularLote(entries_lot_size);

   //Verifica se o stop loss ou take prfot tem um valor válido
   if((sl > tick_.bid && sl != 0) || (tp < tick_.bid && tp != 0))
      return false;
   
   if(stop_atr)
     {
      sl=NormalizePriceDS((1.5==0)?0.0:tick_.ask-atr_Buffer[0]*(double)1.5);
      tp=NormalizePriceDS((1==0)?0.0:tick_.ask+atr_Buffer[0]*(double)1);    
     }   
   
                           
   //Verifica se o stop loss ou take prfot tem um valor menor que zero
   if(sl < 0 || tp < 0)
      return false;

   double margem;
   bool margem_necessaria = MargemNecessaria(ORDER_TYPE_BUY, lote_calculado, preco, margem);
   static bool mensagem_exibida = false;

   //Verifica se tem margem para realizar esta operação
   if(margem_necessaria)
   {
      if(trade.Buy(lote_calculado, _Symbol, preco, sl, tp, "Compra"))
      {
         Mostre("Compra realizada com sucesso no " + _Symbol + ", Preço: " + (string)preco + ", Volume: " + (string)lote_calculado + ", Sl: " + (string)sl + ", TP: " + (string)tp);
//Adiciona o preço médio
//Variavél para controle de preço médio
         //Controle do candle para não abrir mais de uma operação no mesmo candle
         candle_atual = velas[0].time;
         mensagem_exibida = false;

         ultima_entrada = TimeCurrent() - 1;

         stops_ajustados = false;
         return true;

      }
      else
         Print("Erro ao enviar ordem de compra a mercado no ", _Symbol, ", Volume: ", lote_calculado, ", Ask: ", preco, ", Bid: ", tick_.bid, ", Preco atual: ", velas[0].close, "  SL: ", sl, "  TP: ", tp, "   ERRO: ", GetLastError());
   }
   else
   {
      if(!mensagem_exibida)
      {
         mensagem_exibida = true;
         Print("Erro ao realizar compra com o volume ", lote_calculado, " no ", _Symbol, ", você não possui margem suficiente para realizar esta operação, Margem Livre: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE), ", Margem necessária: ", margem);
      }
   }
   return false;
}

//---
bool Venda()
{
   double preco = tick_.bid;
   double sl = ObterStopLoss(-1, preco);
   double tp = ObterTakeProft(-1, preco);
   double lote_calculado = CalcularLote(entries_lot_size);

//Verifica se o stop loss ou take prfot tem um valor positivo
   if((sl < tick_.ask && sl != 0) || (tp > tick_.ask && tp != 0))
      return false;
      
   if(stop_atr)
     {
       sl=(1.5==0)?0.0:tick_.bid+atr_Buffer[0]*(double)1.5;
       tp=(1==0)?0.0:tick_.bid-atr_Buffer[0]*(double)1;
     }   
      
   //Verifica se o stop loss ou take prfot tem um valor menor que zero
   if(sl < 0 || tp < 0)
      return false;

   double margem;
   bool margem_necessaria = MargemNecessaria(ORDER_TYPE_SELL, lote_calculado, preco, margem);
   static bool mensagem_exibida = false;

   //Verifica se tem margem para realizar esta operação
   if(margem_necessaria)
   {
      if(trade.Sell(lote_calculado, _Symbol, preco, sl, tp, "Venda[1]"))
      {
         Mostre("Venda realizada com sucesso no " + _Symbol + ", Preço: " + (string)preco + ", Volume: " + (string)lote_calculado + ", Sl: " + (string)sl + ", TP: " + (string)tp);
//Adiciona o preço médio
//Variavél para controle de preço médio
         ;
         mensagem_exibida = false;
         //Controle do candle para não abrir mais de uma operação no mesmo candle
         candle_atual = velas[0].time;
         ultima_entrada = TimeCurrent() - 1;
         stops_ajustados = false;
         return true;

      }
      else
         Print("Erro ao enviar ordem de venda a mercado no ", _Symbol, ", Volume: ", lote_calculado, ", Ask: ", preco, ", Bid: ", tick_.bid, ", Preco atual: ", velas[0].close, "  SL: ", sl, "  TP: ", tp, "   ERRO: ", GetLastError());
   }
   else
   {
      if(!mensagem_exibida)
      {
         mensagem_exibida = true;
         Print("Erro ao realizar venda com o volume ", lote_calculado, " no ", _Symbol, ", você não possui margem suficiente para realizar esta operação, Margem Livre: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE), ", Margem necessária: ", margem);
      }
   }
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Compra(double l, double sl, double tp, string comment)
{
   double preco = tick_.ask;
   double lote_calculado = CalcularLote(l);

   //Verifica se o stop loss ou take prfot tem um valor válido
   if((sl > tick_.bid && sl != 0) || (tp < tick_.bid && tp != 0))
      return false;
   //Verifica se o stop loss ou take prfot tem um valor menor que zero
   if(sl < 0 || tp < 0)
      return false;

   double margem;
   bool margem_necessaria = MargemNecessaria(ORDER_TYPE_BUY, lote_calculado, preco, margem);
   static bool mensagem_exibida = false;

   //Verifica se tem margem para realizar esta operação
   if(margem_necessaria)
   {
      if(trade.Buy(lote_calculado, _Symbol, preco, sl, tp, comment))
      {
         Mostre("[-] Compra realizada com sucesso no " + _Symbol + ", Preço: " + (string)preco + ", Volume: " + (string)lote_calculado + ", Sl: " + (string)sl + ", TP: " + (string)tp);
         mensagem_exibida = false;
         return true;

      }
      else
         Print("[-] Erro ao enviar ordem de compra a mercado no ", _Symbol, ", Volume: ", lote_calculado, ", Ask: ", preco, ", Bid: ", tick_.bid, ", Preco atual: ", velas[0].close, "  SL: ", sl, "  TP: ", tp, "   ERRO: ", GetLastError());
   }
   else
   {
      if(!mensagem_exibida)
      {
         mensagem_exibida = true;
         Print("[-] Erro ao realizar compra com o volume ", lote_calculado, " no ", _Symbol, ", você não possui margem suficiente para realizar esta operação, Margem Livre: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE), ", Margem necessária: ", margem);
      }
   }
   return false;
}

//---
bool Venda(double l, double sl, double tp, string comment)
{
   double preco = tick_.bid;
   double lote_calculado = CalcularLote(l);

//Verifica se o stop loss ou take prfot tem um valor positivo
   if((sl < tick_.ask && sl != 0) || (tp > tick_.ask && tp != 0))
      return false;
   //Verifica se o stop loss ou take prfot tem um valor menor que zero
   if(sl < 0 || tp < 0)
      return false;

   double margem;
   bool margem_necessaria = MargemNecessaria(ORDER_TYPE_SELL, lote_calculado, preco, margem);
   static bool mensagem_exibida = false;

   //Verifica se tem margem para realizar esta operação
   if(margem_necessaria)
   {
      if(trade.Sell(lote_calculado, _Symbol, preco, sl, tp, comment))
      {
         Mostre("[-] Venda a mercado realizada com sucesso no " + _Symbol + ", Preço: " + (string)preco + ", Volume: " + (string)lote_calculado + ", Sl: " + (string)sl + ", TP: " + (string)tp);
         mensagem_exibida = false;

         return true;

      }
      else
         Print("[-] Erro ao enviar ordem de venda a mercado no ", _Symbol, ", Volume: ", lote_calculado, ", Ask: ", preco, ", Bid: ", tick_.bid, ", Preco atual: ", velas[0].close, "  SL: ", sl, "  TP: ", tp, "   ERRO: ", GetLastError());
   }
   else
   {
      if(!mensagem_exibida)
      {
         mensagem_exibida = true;
         Print("[-] Erro ao realizar venda com o volume ", lote_calculado, " no ", _Symbol, ", você não possui margem suficiente para realizar esta operação, Margem Livre: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE), ", Margem necessária: ", margem);
      }
   }
   return false;
}

int Estrategia_Supply()
{

   int total = ObjectsTotal(0);

   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i);

      if(StringFind(name, "SRRR") >= 0)
      {
         if(StringFind(name, "Verified") >= 0)
         {
            double preco_superior = ObjectGetDouble(0, name, OBJPROP_PRICE);
            double preco_inferior = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);

            bool venda = (velas[0].open < preco_inferior && velas[0].close >= preco_inferior);
            bool compra = (velas[0].open > preco_superior && velas[0].close <= preco_superior);

            if(compra)
               return 1;
            else if(venda)
               return -1;
            else
               return 0;
         }
      }
   }

   return 0;
}

//---
bool DeletarOrdem()
{
   int total = OrdersTotal() - 1;

   int qtd = 0;
   int qtd_deletada = 0;

   for(int i = total; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == magic_magico && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            qtd++;
            if(trade.OrderDelete(ticket))
            {
               Print("Ordem deletada com sucesso no ", OrderGetString(ORDER_SYMBOL), ", Ticket: ", ticket);

               qtd_deletada++;

            }
            else
               Print("Erro ao deletar ordem no ", OrderGetString(ORDER_SYMBOL), ", Ticket: ", ticket, "  Erro: ", GetLastError());
         }
      }
   }

   if(qtd == qtd_deletada)
      return true;
   else
      return false;
}

//---
bool SemPosicao()
{
   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return false;
      }

   }
   return true;
}
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AjustarStopsIniciais()
{
   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double open = Arredondar(PositionGetDouble(POSITION_PRICE_OPEN));
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);

            //Verifica se o preço de abertura é válido
            if(open == 0)
               return false;

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               double novo_sl = ObterStopLoss(1, open);
               double novo_tp = ObterTakeProft(1, open);

               //Verifica se o stop loss ou o take proft é diferente do configurado
               if(novo_sl != sl || novo_tp != tp)
               {
                  if((tick_.bid > novo_sl && tick_.bid < novo_tp) || (tick_.bid > novo_sl && novo_tp == 0) || (novo_sl == 0 && tick_.bid < novo_tp))
                  {
                     if(trade.PositionModify(ticket, novo_sl, novo_tp))
                     {
                        Mostre("Stops inciais ajustados com sucesso na operação de compra no " + PositionGetString(POSITION_SYMBOL) + ", Abertura: " + (string)open + ", Sl: " + (string)novo_sl + ", Tp: " + (string)novo_tp);
                        return true;
                     }
                     else
                     {
                        Mostre("Erro ao ajustar os stops inicias da posição de compra no " + PositionGetString(POSITION_SYMBOL) + ", Abertura: " + (string)open + "Sl: " + (string)sl + ", Tp: " + (string)tp + " -> Sl: " + (string)novo_sl + ", Tp: " + (string)novo_tp + " Erro: " + (string)GetLastError());
                        return false;
                     }
                  }
               }
               else
               {
                  return true;
               }
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               double novo_sl = ObterStopLoss(-1, open);
               double novo_tp = ObterTakeProft(-1, open);

               //Verifica se o stop loss ou o take proft é diferente do configurado
               if(novo_sl != sl || novo_tp != tp)
               {

                  if((tick_.ask < novo_sl && tick_.ask > novo_tp) || (tick_.ask < novo_sl && novo_tp == 0) || (novo_sl == 0 && tick_.ask > novo_tp))
                  {
                     if(trade.PositionModify(ticket, novo_sl, novo_tp))
                     {
                        Mostre("Stops inciais ajustados com sucesso na operação de venda no " + PositionGetString(POSITION_SYMBOL) + ", Abertura: " + (string)open + ", Sl: " + (string)novo_sl + ", Tp: " + (string)novo_tp);
                        return true;
                     }
                     else
                     {
                        Mostre("Erro ao ajustar os stops inicias da posição de venda no " + PositionGetString(POSITION_SYMBOL) + ", Abertura: " + (string)open + "Sl: " + (string)sl + ", Tp: " + (string)tp + " -> Sl: " + (string)novo_sl + ", Tp: " + (string)novo_tp + " Erro: " + (string)GetLastError());
                        return false;
                     }
                  }
               }
               else
               {
                  return true;
               }
            }
         }
      }
   }
   return false;
}

void Mostre(string texto)
{
   Print(texto);
}

//---
double ObterTakeProft(int tipo, double preco)
{
   const double take_normalizado = NormalizePricePrecoMedioeCaixa(entries_target_size);
   double tp = -1;

   //Verifica se a operação é de compra ou venda
   if(tipo == 1)
   {
      tp = (entries_target_size > 0) ? preco + take_normalizado : 0;

      //Verifica se o take proft é inválido
      if(tp < tick_.bid && tp != 0)
         return -1;
   }
   else
   {
      tp = (entries_target_size > 0) ? preco - take_normalizado : 0;

      //Verifica se o take proft é inválido
      if(tp > tick_.ask && tp != 0)
         return -1;
   }

   return NormalizeDouble(tp, _Digits);
}

//---
double ObterStopLoss(int tipo, double preco)
{
   const double stop_normalizado = NormalizePricePrecoMedioeCaixa(entries_stop_size);
   double sl = -1;

   //Verifica se a operação é de compra ou venda
   if(tipo == 1)
   {
      sl = (entries_stop_size > 0) ? preco - stop_normalizado : 0;

      //Verifica se o stop loss é inválido
      if(sl > tick_.bid && sl != 0)
         return -1;
   }
   else
   {
      sl = (entries_stop_size > 0) ? preco + stop_normalizado : 0;

      //Verifica se o stop loss é inválido
      if(sl < tick_.ask && sl != 0)
         return -1;
   }

   return NormalizeDouble(sl, _Digits);
}
  
bool FiltroCaixa()
{
   if(ativar_caixa_stop)
   {
      double lucro = 0;

      HistorySelect(ultima_entrada, TimeCurrent());
      int total = HistoryDealsTotal() - 1;

      double ultimo_preco = 0;
      for(int i = 0; i <= total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);

         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic_magico && HistoryDealGetString(ticket, DEAL_SYMBOL) == ativoOp)
         {
            //Print((datetime)HistoryDealGetInteger(ticket, DEAL_TIME));
            lucro += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
               ultimo_preco = HistoryDealGetDouble(ticket, DEAL_PRICE);
         }
      }

      if(lucro >= 0)
      {

         return true;
      }
      else
      {
         const double distancia_normalizada = NormalizePricePrecoMedioeCaixa(range_caixa);

         if(velas[1].close > ultimo_preco + distancia_normalizada || velas[1].close < ultimo_preco - distancia_normalizada)
         {

            return true;
         }
         else
           {
            
            desenhaLinhaHorizontal("Caixa 1",ultimo_preco + distancia_normalizada,clrYellow);
            desenhaLinhaHorizontal("Caixa 2",ultimo_preco - distancia_normalizada,clrYellow);
            return false;
           }
            
      }
   }
   else
      return true;
} 
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction&trans, const MqlTradeRequest&request, const MqlTradeResult&result)
{
   //Verifica se foi adicionado ou  uma nova posição
   if((trans.deal_type == DEAL_TYPE_SELL && trans.type == TRADE_TRANSACTION_DEAL_ADD) || (trans.deal_type == DEAL_TYPE_BUY && trans.type == TRADE_TRANSACTION_DEAL_ADD))
   {
      long ultimo_numero_magico = NumeroMagicoUltimaPosicao();

      if(trans.symbol == _Symbol && ultimo_numero_magico == magic_magico)
      {
         static ulong ultima_ordem;

         if(trans.order != ultima_ordem)
         {
            int qtd_posicoes = QtdPosicoes();

            //Verifica se é conta hedge para poder colocar a linha de referência do preço médio
            if(!conta_netting)
            {
               //Verifica se tem mais de uma operação, já que quando se tem mais de uma operação foi realizado o preço médio
               if(qtd_posicoes > 1)
               {
                  CriarLinhaReferencia("*Preço médio", PrecoMedio(), clrLightGray);
               }
            }


            ultima_ordem = trans.order;
         }
      }
   }
}

double PrecoMedio()
{
   double lote_total = 0;
   double preco_medio = 0;

   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            preco_medio += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
            lote_total += PositionGetDouble(POSITION_VOLUME);
         }
      }
   }
   if(lote_total == 0)
      lote_total = 1;

   return Arredondar(NormalizeDouble(preco_medio / lote_total, _Digits));
}

bool CriarLinhaReferencia(string nome_objeto, double preco, uint cor_linha)
{

   double linha_objeto = ObjectGetDouble(0, nome_objeto, OBJPROP_PRICE);

   //Verifica se não existe o objeto
   if(linha_objeto == 0)
   {
      if(ObjectCreate(0, nome_objeto, OBJ_HLINE, 0, 0, preco))
      {
         ObjectSetDouble(0, nome_objeto, OBJPROP_PRICE, preco);
         ObjectSetInteger(0, nome_objeto, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, nome_objeto, OBJPROP_COLOR, cor_linha);

         return true;
      }
   }
   else
   {
      //Verifica se o novo preço é diferente
      if(linha_objeto != preco)
         return ObjectSetDouble(0, nome_objeto, OBJPROP_PRICE, preco);
   }

   return false;

}

//---
int QtdPosicoes()
{
   int qtd = 0;

   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
            qtd++;
      }

   }
   return qtd;
}

//---
long NumeroMagicoUltimaPosicao()
{
   HistorySelect(0, TimeCurrent());

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic_magico && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
         return HistoryDealGetInteger(ticket, DEAL_MAGIC);
   }

   return 0;
}
  
//---
bool MargemNecessaria(ENUM_ORDER_TYPE tipo_ordem, double volume, double preco, double &margin)
{
   double margem;

   if(OrderCalcMargin(tipo_ordem, _Symbol, volume, preco, margem))
   {
      margin = 0;
      margin = margem;
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) > margem)
         return true;
      else
         return false;
   }
   else
      return false;

}

//---
//---
bool BuyStop(double l, double preco, double sl, double tp, string comment = "Buy Stop")
{

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

//Verifica se o preço é válido para posicionar a ordem pendente
   if(ask < preco)
   {
      double margem;
      bool margem_necessaria = MargemNecessaria(ORDER_TYPE_BUY_STOP, l, preco, margem);
      static bool mensagem_exibida = false;

      //Verifica se tem margem para realizar esta operação
      if(margem_necessaria)
      {
         if(true)
         {
            if(trade.BuyStop(l, preco, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
            {

               Print("Sucesso ao posicionar ", comment, "no ", _Symbol, " Preço ", preco, " SL: ", sl, "  TP: ", tp);
               return true;
            }
            else
            {
               Print("Erro ao posicionar ", comment, " no preço ", preco, "	   ->Ask: ", ask, "	   ->SL: ", sl, "	   ->TP: ", tp, "	   ->Erro: ", GetLastError());
               return false;
            }
         }
      }
      else
      {
         Print("Erro ao posicionar buy stop com o volume ", l, " no ", _Symbol, ", você não possui margem suficiente para realizar esta operação, Margem Livre: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE), ", Margem necessária: ", margem);
      }
   }
   return false;
} 
//---
bool SellStop(double l, double preco, double sl, double tp, string comment = "Sell Stop")
{

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

//Verifica se o preço é válido para posicionar a ordem pendente
   if(bid > preco)
   {
      double margem;
      bool margem_necessaria = MargemNecessaria(ORDER_TYPE_SELL_STOP, l, preco, margem);
      static bool mensagem_exibida = false;

      //Verifica se tem margem para realizar esta operação
      if(margem_necessaria)
      {
         if(true)
         {
            if(trade.SellStop(l, preco, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
            {

               Print("Sucesso ao posicionar ", comment, "no ", _Symbol, " Preço ", preco, " SL: ", sl, "  TP: ", tp);
               return true;
            }
            else
            {
               Print("Erro ao posicionar ", comment, " no preço ", preco, "	   ->Bid: ", bid, "	   ->SL: ", sl, "	   ->TP: ", tp, "	   ->Erro: ", GetLastError());
               return false;
            }
         }
      }
      else
      {
         Print("Erro ao posicionar sell stop com o volume ", l, " no ", _Symbol, ", você não possui margem suficiente para realizar esta operação, Margem Livre: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE), ", Margem necessária: ", margem);
      }
   }
   return false;

}
//---
double CalcularLote(double l)
{
   const double volume_minimo = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_maximo = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(volume_minimo >= 1)
   {
      //Faz com o lote seja um múltiplo ceto
      double resto = MathMod(l, volume_minimo);
      l = l - resto;
   }

   if(l >= volume_minimo && l <= volume_maximo)
      return l;
   else if(l < volume_minimo)
      return volume_minimo;
   else if(l > volume_maximo)
      return volume_maximo;
   else
      return -1;
}

//---
//+------------------------------------------------------------------+
UltimaOperacao UltimaOperacaoRealizada()
{
   UltimaOperacao operacao;
   operacao.volume = 0;
   operacao.sl = 0;
   operacao.tp = 0;
   operacao.preco = 0;
   operacao.comment = "";
   operacao.tipo_posicao = 0;

   double lucro = 0;

   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal() - 1;

   for(int i = total; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic_magico && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
      {
         if(HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BUY)
            operacao.tipo_posicao = 1;
         else
            operacao.tipo_posicao = -1;

         operacao.preco = HistoryDealGetDouble(ticket, DEAL_PRICE);
         operacao.comment = HistoryDealGetString(ticket, DEAL_COMMENT);
         return operacao;

      }
   }
   return operacao;
}
//+------------------------------------------------------------------+
bool DadosUltimaOperacao(UltimaOperacao &operacao)
{
   operacao.volume = 0;
   operacao.sl = 0;
   operacao.tp = 0;
   operacao.preco = 0;
   operacao.comment = "";
   operacao.tipo_posicao = 0;

   int total = PositionsTotal() - 1;

   for(int i = total; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);

      if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         operacao.volume = PositionGetDouble(POSITION_VOLUME);
         operacao.sl = PositionGetDouble(POSITION_SL);
         operacao.tp = PositionGetDouble(POSITION_TP);
         operacao.preco = PositionGetDouble(POSITION_PRICE_OPEN);
         operacao.comment = PositionGetString(POSITION_COMMENT);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            operacao.tipo_posicao = 1;
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            operacao.tipo_posicao = -1;

         return true;
      }
   }

   return false;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool SemOrdem()
{
   int total = OrdersTotal() - 1;

   for(int i = total; i >= 0; i--)
   {
      if(OrderSelect(OrderGetTicket(i)))
      {
         if(OrderGetInteger(ORDER_MAGIC) == magic_magico && OrderGetString(ORDER_SYMBOL) == _Symbol)
            return false;
      }
   }
   return true;
}
//+------------------------------------------------------------------+
//|CANCELAMENTO DE ORDEM                                             |
//+------------------------------------------------------------------+
void cancelarOrdem()
   {
   
      
      trade.OrderDelete(OrderGetTicket(0));
      
      if(trade.ResultRetcode() == 10009)
        {
            Print("Ordem cancelada com Sucesso!!");
        }else
           {
            Print("Erro de execução... ", GetLastError());
            ResetLastError();
           } 
   }
//+------------------------------------------------------------------+
//void vencimento1() 
//{
// string Host, User, Password, Database, Socket; // database credentials
// int Port,ClientFlag;
// int DB,Cursor,Rows; // database identifier
// //string INI;
// if(gerar_log == ON)
//   Print (MySqlVersion());
//
// //INI = TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Scripts\\MyConnection.ini";
// //Print(INI);
// 
// // reading database credentials from INI file
// Host = "168.138.126.249";
// User = "jayme";
// Password = "samsung12";
// Database = "controle_web";
// Port     = 3306;
// Socket   = "0";
// ClientFlag    = CLIENT_MULTI_STATEMENTS; //(int)StringToInteger(ReadIni(INI, "MYSQL", "ClientFlag"));  
//
//// Print ("Host: ",Host, ", User: ", User, ", Database: ",Database);
// 
// // open database connection
// if(gerar_log == ON)
//   Print ("Connecting...");
// 
// DB = MySqlConnect(Host, User, Password, Database, Port, Socket, ClientFlag);
// 
// if (DB == -1) { if(gerar_log == ON) Print ("Connection failed! Error: "+MySqlErrorDescription); } else { if(gerar_log == ON) Print ("Connected! DBID#",DB);}
// 
// string Query;
// Query = "SELECT * FROM ea_livwell WHERE codigo = " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
//// Print(Query);
// 
//Cursor = MySqlCursorOpen(DB, Query);
// 
// if (Cursor >= 0)
//   { 
//       Rows = MySqlCursorRows(Cursor);
//       //Print (Rows, " row(s) selected.");
//       if(Rows == 0)
//         {
//          if(gerar_log == ON)
//            Print("Dados não encontrado!!!");
//          ExpertRemove();
//         } else
//             {
//              if(gerar_log == ON) 
//               Print("Dados encontrado!");
//             }
//   } else
//       {
//           // Exibir uma mensagem de erro
//           if(gerar_log == ON)
//            Print("Não foi possivel conectar com o banco de dados");
//           ExpertRemove();
//       }
//}
//+------------------------------------------------------------------+
void vencimento2()
{
   //string values[];
   //StringSplit(expiracao2, ',', values);
   
   string cookie=NULL,headers;
   char   post[],result[];
   string url=handliv_api_url+"/mt5/ea/status?account="+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"&token="+handliv_api_token;
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
      
      ExpertRemove();
     }
   else
     {
      if(res==200)
        {
         //--- Successful download
         PrintFormat("Robot permetido operar, File size %d byte.",ArraySize(result));
         
CJAVal js(NULL, jtUNDEF);
         
         js.Deserialize(result);
         
         bool registered = js["registered"].ToBool();
         bool is_active  = js["is_active"].ToBool();
          
         if (!registered || !is_active)
         {
          Alert("Periodo de uso do robô expirado, contate a Handliv!");
          
          ExpertRemove();
         }
        
           
         //PrintFormat("Server headers: %s",headers);
         //--- Saving the data to a file
        // int filehandle=FileOpen("url.htm",FILE_WRITE|FILE_BIN);
        // if(filehandle!=INVALID_HANDLE)
        //   {
        //    //--- Saving the contents of the result[] array to a file
        //    FileWriteArray(filehandle,result,0,ArraySize(result));
        //    //--- Closing the file
        //    FileClose(filehandle);
        //   }
        // else
        //    Print("Error in FileOpen. Error code =",GetLastError());
        } else if(res==4014)
                 {
                  Print("Está no backtest");
                  ExpertRemove();
                 }
      else
        {
         PrintFormat("'%s' failed, error code %d",url,res);
         
         ExpertRemove();
        }
         
     }
}
//+------------------------------------------------------------------+
//| Book Event                                                       |
//+------------------------------------------------------------------+
void OnBookEvent(const string& symbol)
  {
   if(ativa_renko == SIM_RENKO)
     {
         OnTick();
     }
  }
//+------------------------------------------------------------------+
//| Timer Event (Turn off when backtesting)                          |
//+------------------------------------------------------------------+
//void OnTimer()
//  {
//   if(ativa_renko == SIM_RENKO)
//     {
//         OnTick();
//     }
//  }
//+------------------------------------------------------------------+
//| PAINEL                                                                 |
//+------------------------------------------------------------------+
   
//+------------------------------------------------------------------+
//|FECHAR POSIÇÃO EM ABERTA                                          |
//+------------------------------------------------------------------+
void FecharPosicao()
   {
   
      ulong ticket = PositionGetTicket(0);
      
      trade.PositionClose(ticket);
      
      if(trade.ResultRetcode() == 10009)
        {
            if(gerar_log == ON)
               Print("Fechamento Executado com Sucesso!!");
        }else
           {
            if(gerar_log == ON)
               Print("Erro de execução... ", GetLastError());
            ResetLastError();
           }  
   
   }
   
//Fecha todas as posições em aberto
void FecharTodasPosicao()
{

   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ResetLastError();

      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(trade.PositionClose(ticket))
            {
               Print("Sucesso ao fechar posição no ", PositionGetString(POSITION_SYMBOL), "Ticket:", ticket, "ID:", PositionGetInteger(POSITION_IDENTIFIER));

            }
            else
               Print("Erro ao fechar Posição no ", PositionGetString(POSITION_SYMBOL), "Ticket:", ticket, "ID:", PositionGetInteger(POSITION_IDENTIFIER), "  Erro: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FUNÇÕES PARA AUXILIAR NA VISUALIZAÇÃO DA ESTRATÉGIA              |
//+------------------------------------------------------------------+

void desenhaLinhaVertical(string nome, datetime dt, color cor = clrAliceBlue)
   {
      //ObjectDelete(0,nome);
      ObjectCreate(0,nome,OBJ_VLINE,0,dt,0);
      ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   } 
   
void desenhaLinhaHorizontal(string nome, double price, color cor = clrAliceBlue)
   {
      ObjectDelete(0,nome);
      ObjectCreate(0,nome,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   } 

//+------------------------------------------------------------------+
//|VERIFICAR NOVA VELA PARA ENTRADA                                  |
//+------------------------------------------------------------------+
bool TemosNovaVela()
  {
//--- memoriza o tempo de abertura da ultima barra (vela) numa variável
   static datetime last_time=0;
//--- tempo atual
   datetime lastbar_time= (datetime) SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- se for a primeira chamada da função:
   if(last_time==0)
     {
      //--- atribuir valor temporal e sair
      last_time=lastbar_time;
      return(false);
     }

//--- se o tempo estiver diferente:
   if(last_time!=lastbar_time)
     {
      //--- memorizar esse tempo e retornar true
      last_time=lastbar_time;
      return(true);
     }
//--- se passarmos desta linha, então a barra não é nova; retornar false
   return(false);
  }
 
   //+------------------------------------------------------------------+
//|   NOVO DIA                                                       |
//+------------------------------------------------------------------+
bool NewDay()
{
   static datetime PrevDay;

   if(PrevDay < iTime(NULL, PERIOD_D1, 0)) {
      PrevDay = iTime(NULL, PERIOD_D1, 0);
      if(gerar_log == ON)
         Print("Novo dia identificado");
      return(true);
   }
   else {
      return(false);
   }
}

//+------------------------------------------------------------------+
//|   Horario que pode operar                                        |
//+------------------------------------------------------------------+
bool horaPodeOperar(string inicio, string fim)
   {
      bool resp = false;
      
      datetime tc = TimeCurrent();
      
      if( TimeToString(tc,TIME_MINUTES)  >= inicio &&  TimeToString(tc,TIME_MINUTES)  <= fim )
        {
         resp = true;
         
        }else
           {
            resp = false;
           }
   
      return resp;
   }
   
//+------------------------------------------------------------------+
//| FUNÇÃO BREAKEVEN                                                 |
//+------------------------------------------------------------------+
void BreakEven(double preco, double PontoBE, double gatilhoBE)
   {
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(PositionSelect(ativoOp) && magic_magico == magic && ativoOp == symbol)
               {
                  ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
                  double PrecoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
                  double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
                  double pontosdelucrobe = NormalizeDouble(PontoBE * Normalizarmanual(), _Digits);
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                     {
                        if( preco >= (PrecoEntrada + gatilhoBE) )
                           {
                              if(trade.PositionModify(PositionTicket, PrecoEntrada + pontosdelucrobe, TakeProfitCorrente))
                                 {
                                    if(gerar_log == ON)
                                       Print("BreakEven - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                    beAtivo = true;
                                 }
                              else
                                 {  
                                    if(gerar_log == ON)
                                       Print("BreakEven - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }                           
                     }
                  else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                     {
                        if( preco <= (PrecoEntrada - gatilhoBE) )
                           {
                              if(trade.PositionModify(PositionTicket, PrecoEntrada - pontosdelucrobe, TakeProfitCorrente))
                                 {
                                    if(gerar_log == ON)
                                       Print("BreakEven - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                    beAtivo = true;
                                 }
                              else
                                 {
                                    if(gerar_log == ON)
                                       Print("BreakEven - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }
                     }
               }
         }
   }
  
//+------------------------------------------------------------------+
//|  TRAILING STOP                                                   |
//+------------------------------------------------------------------+
void realizartrailingstop(string ativo, double IniciarTS,double velaLow,double velaHigh, double tickLast)
{
        //--- STOP LOSS MÒVEL - Compra
        
        if(PositionSelect(ativo) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY )//liga_train == SIM_TS && 
          {
           
            double preco_entrada = PositionGetDouble(POSITION_PRICE_OPEN);
            double preco_sl      = PositionGetDouble(POSITION_SL);
            double preco_tp      = PositionGetDouble(POSITION_TP);
            double gatilho_ts    = NormalizeDouble(preco_entrada + IniciarTS * Normalizarmanual(),_Digits);
            long   spread        = SymbolInfoInteger(ativo, SYMBOL_SPREAD);
            

            double novo_sl       = NormalizeDouble(velaLow*_Point,_Digits);//velas[1].low
            
            
            if( tickLast >= gatilho_ts && preco_sl != novo_sl && novo_sl > preco_sl) // 
              {
                  
                  if(gerar_log == ON)
                     Print("Compra - SL atual = ", preco_sl, ", Novo = ", novo_sl, " , Preço da entrada = ", preco_entrada);
                  trade.PositionModify(PositionGetTicket(0),novo_sl,preco_tp);
                  desenhaLinhaHorizontal("TrailingStop",novo_sl,clrYellow);
                  
                  //if(liga_par == SIM_PARCIAL && !trailing_par_ativo && nContrato > 0)
                  //  {
                  //   //desenhaLinhaHorizontal("PARCIAL TRALING",tick.last,clrRed);
                  //   trade.PositionClosePartial(PositionGetTicket(0), nContrato, spread);
                  //   trailing_par_ativo = true;
                  //  } 
                  
                  
              }
           
           
          }
        
        //--- STOP LOSS MÒVEL - Venda
        
        if(PositionSelect(ativo) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL )//liga_train == SIM_TS && 
          {
           
                  double preco_entrada = PositionGetDouble(POSITION_PRICE_OPEN);
                  double preco_sl      = PositionGetDouble(POSITION_SL);
                  double preco_tp      = PositionGetDouble(POSITION_TP);
                  double gatilho_ts    = NormalizeDouble(preco_entrada - IniciarTS * Normalizarmanual(),_Digits);
                  long   spread        = SymbolInfoInteger(ativo, SYMBOL_SPREAD);
                  
                  double novo_sl       = NormalizeDouble(velaHigh*_Point,_Digits);//velas[1].high
                  
                  
                  if(  tickLast <= gatilho_ts && preco_sl != novo_sl && novo_sl < preco_sl) // 
                    {
                        if(gerar_log == ON)
                           Print("Venda - SL atual = ", preco_sl, ", Novo = ", novo_sl, " , Preço da entrada = ", preco_entrada);
                        trade.PositionModify(PositionGetTicket(0),novo_sl,preco_tp);
                        desenhaLinhaHorizontal("TrailingStop",novo_sl,clrYellow);
                        
//                        if(liga_par == SIM_PARCIAL && !trailing_par_ativo && nContrato > 0)
//                          {
//                           //desenhaLinhaHorizontal("PARCIAL TRALING",tick.last,clrRed);
//                           trade.PositionClosePartial(PositionGetTicket(0), nContrato, spread);
//                           trailing_par_ativo = true;
//                          }; 
//                        
                        
                        
                    }
            
           
          } 
}

void TrailingStop(double preco, double gatilhoTS, double stepTS)
   {
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(PositionSelect(ativoOp) && magic_magico == magic && ativoOp == symbol)
               {
                  ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
                  double StopLossCorrente = PositionGetDouble(POSITION_SL);
                  double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                     {
                        if(preco >= (StopLossCorrente + gatilhoTS) )
                           {
                              double novoSL = NormalizeDouble(StopLossCorrente + stepTS, _Digits);
                              if(trade.PositionModify(PositionTicket, novoSL, TakeProfitCorrente))
                                 {
                                    if(gerar_log == ON)
                                       Print("TrailingStop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                              else
                                 {
                                    if(gerar_log == ON)
                                       Print("TrailingStop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }
                     }
                  else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                     {
                        if(preco <= (StopLossCorrente - gatilhoTS) )
                           {
                              double novoSL = NormalizeDouble(StopLossCorrente - stepTS, _Digits);
                              if(trade.PositionModify(PositionTicket, novoSL, TakeProfitCorrente))
                                 {
                                    if(gerar_log == ON)
                                       Print("TrailingStop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                              else
                                 {
                                    if(gerar_log == ON)
                                       Print("TrailingStop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }
                     }
               }
         }
   }

//+------------------------------------------------------------------+
//|  PARCIAL                                                         |
//+------------------------------------------------------------------+
void fazerParcial(double contrato,double contrato2,double contrato3,double contrato4,double contrato5,double contrato6,double contrato7, double IniciarParcial,double IniciarParcial2,double IniciarParcial3,double IniciarParcial4,double IniciarParcial5,double IniciarParcial6,double IniciarParcial7, double tickLast)
{
   for(int i = PositionsTotal()-1; i>=0; i--)
            {
               string symbol = PositionGetSymbol(i);
               ulong magic = PositionGetInteger(POSITION_MAGIC);
               double preco_entrada = PositionGetDouble(POSITION_PRICE_OPEN);
               long   spread        = SymbolInfoInteger(ativoOp, SYMBOL_SPREAD);
               if(PositionSelect(ativoOp) && magic_magico == magic && ativoOp == symbol)
               {
                  
                  //---COMPRA PARCIAL
                  double gatilho_parcial    = NormalizeDouble(preco_entrada + IniciarParcial * Normalizarmanual(),_Digits);
                  
                  if(tickLast >= gatilho_parcial && contrato > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                  
                  //---VENDA PARCIAL  
                  gatilho_parcial    = NormalizeDouble(preco_entrada - IniciarParcial * Normalizarmanual(),_Digits);
                  
                  if(tickLast <= gatilho_parcial && contrato > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                     
                     
                 //---COMPRA PARCIAL 2
                  double gatilho_parcial2    = NormalizeDouble(preco_entrada + IniciarParcial2 * Normalizarmanual(),_Digits);
                  
                  if(tickLast >= gatilho_parcial2 && contrato2 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                  
                  //---VENDA PARCIAL 2  
                  gatilho_parcial2    = NormalizeDouble(preco_entrada - IniciarParcial2 * Normalizarmanual(),_Digits);
                  
                  if(tickLast <= gatilho_parcial2 && contrato2 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                     
                 
                 //---COMPRA PARCIAL 3
                  double gatilho_parcial3    = NormalizeDouble(preco_entrada + IniciarParcial3 * Normalizarmanual(),_Digits);
                  
                  if(tickLast >= gatilho_parcial3 && contrato3 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                  
                  //---VENDA PARCIAL 3  
                  gatilho_parcial3    = NormalizeDouble(preco_entrada - IniciarParcial3 * Normalizarmanual(),_Digits);
                  
                  if(tickLast <= gatilho_parcial3 && contrato3 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                     
                     
                     
                 //---COMPRA PARCIAL 4
                  double gatilho_parcial4    = NormalizeDouble(preco_entrada + IniciarParcial4 * Normalizarmanual(),_Digits);
                  
                  if(tickLast >= gatilho_parcial4 && contrato4 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                  
                  //---VENDA PARCIAL 4  
                  gatilho_parcial4   = NormalizeDouble(preco_entrada - IniciarParcial4 * Normalizarmanual(),_Digits);
                  
                  if(tickLast <= gatilho_parcial4 && contrato4 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                     
                     
                 //---COMPRA PARCIAL 5
                  double gatilho_parcial5    = NormalizeDouble(preco_entrada + IniciarParcial5 * Normalizarmanual(),_Digits);
                  
                  if(tickLast >= gatilho_parcial5 && contrato5 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                  
                  //---VENDA PARCIAL 5  
                  gatilho_parcial5   = NormalizeDouble(preco_entrada - IniciarParcial5 * Normalizarmanual(),_Digits);
                  
                  if(tickLast <= gatilho_parcial5 && contrato5 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                     
                     
                 
                 //---COMPRA PARCIAL 6
                  double gatilho_parcial6    = NormalizeDouble(preco_entrada + IniciarParcial6 * Normalizarmanual(),_Digits);
                  
                  if(tickLast >= gatilho_parcial6 && contrato6 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                  
                  //---VENDA PARCIAL 6  
                  gatilho_parcial6   = NormalizeDouble(preco_entrada - IniciarParcial6 * Normalizarmanual(),_Digits);
                  
                  if(tickLast <= gatilho_parcial6 && contrato6 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                     
                     
                     
                //---COMPRA PARCIAL 7
                  double gatilho_parcial7    = NormalizeDouble(preco_entrada + IniciarParcial7 * Normalizarmanual(),_Digits);
                  
                  if(tickLast >= gatilho_parcial7 && contrato7 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
                  
                  //---VENDA PARCIAL 7  
                  gatilho_parcial7   = NormalizeDouble(preco_entrada - IniciarParcial7 * Normalizarmanual(),_Digits);
                  
                  if(tickLast <= gatilho_parcial7 && contrato7 > 0 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)//liga_par == SIM_PARCIAL && !parAtivo
                     {
                        trade.PositionClosePartial(PositionGetTicket(i), contrato, spread);
                        parAtivo = true;
                     }
               }
            }             
}

//+------------------------------------------------------------------+
//|  NORMALIZAR MANUAL                                               |
//+------------------------------------------------------------------+
double Normalizarmanual() {
  double normalizadormanual = 0;
  
  if(_Digits == 5) {
    normalizadormanual = _Point;
    return(normalizadormanual);
  }
  if(_Digits == 4) {
    normalizadormanual = 10000;
    return(normalizadormanual);
  }
  if(_Digits == 3) {
    normalizadormanual = _Point * 10000;
    return(normalizadormanual);
  }
  if(_Digits == 2) {
    normalizadormanual = _Point * 10;
    return(normalizadormanual);
  }
  if(_Digits == 1) {
    normalizadormanual = 10;
    return(normalizadormanual);
  }
  if(_Digits == 0) {
    normalizadormanual = 1;
    return(normalizadormanual);
  }
  return(-1);
}

//+------------------------------------------------------------------+
//| GERENCIAMENTO DE PERDAS E GANHOS                                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Limite Lucro diario                                              |
//+------------------------------------------------------------------+
bool  Lucro_Diario()
  {
   if(LD == 0)
      return(false);
   string         tmp_x;
   double         tmp_resultado_financeiro_dia;
   int            tmp_contador;
   MqlDateTime    tmp_data_b;
   TimeCurrent(tmp_data_b);
   tmp_resultado_financeiro_dia = 0;
   tmp_x = string(tmp_data_b.year) + "." + string(tmp_data_b.mon) + "." + string(tmp_data_b.day) + " 00:00:01";
   HistorySelect(StringToTime(tmp_x), TimeCurrent());
   int      tmp_total = HistoryDealsTotal();
   ulong    tmp_ticket = 0;
   double   tmp_profit;
   string   tmp_symboll;
   long     tmp_magic;
//--- para todos os negócios
   for(tmp_contador = 0; tmp_contador < tmp_total; tmp_contador++)
     {
      //--- tentar obter ticket negócios
      if((tmp_ticket = HistoryDealGetTicket(tmp_contador)) > 0)
        {
         //--- obter as propriedades negócios
         tmp_symboll = HistoryDealGetString(tmp_ticket, DEAL_SYMBOL);
         tmp_profit = HistoryDealGetDouble(tmp_ticket, DEAL_PROFIT);
         tmp_magic = HistoryDealGetInteger(tmp_ticket, DEAL_MAGIC);
         if(tmp_symboll == Symbol())
            tmp_resultado_financeiro_dia = tmp_resultado_financeiro_dia + tmp_profit;
        }
     }
   if(tmp_resultado_financeiro_dia >= LD)
     {
     //pode_operar = false;
      //Alert("Ganho diário de R$"+DoubleToString(LD, 2)+" foi atingida. Robô Bateu a Meta!");
      if(gerar_log == ON)
      {
         Print("Ganho diário de R$"+DoubleToString(LD, 2)+" foi atingida. Robô Bateu a Neta!");
         Print("");
      }
      return(true);
     }
   return(false);
  }

bool  Loss_Diario()
  {
   if(LDN == 0)
      return(false);
   string         tmp_x;
   double         tmp_resultado_financeiro_dia;
   int            tmp_contador;
   MqlDateTime    tmp_data_b;
   TimeCurrent(tmp_data_b);
   tmp_resultado_financeiro_dia = 0;
   tmp_x = string(tmp_data_b.year) + "." + string(tmp_data_b.mon) + "." + string(tmp_data_b.day) + " 00:00:01";
   HistorySelect(StringToTime(tmp_x), TimeCurrent());
   int      tmp_total = HistoryDealsTotal();
   ulong    tmp_ticket = 0;
   double   tmp_profit;
   string   tmp_symboll;
   long     tmp_magic;
//--- para todos os negócios
   for(tmp_contador = 0; tmp_contador < tmp_total; tmp_contador++)
     {
      //--- tentar obter ticket negócios
      if((tmp_ticket = HistoryDealGetTicket(tmp_contador)) > 0)
        {
         //--- obter as propriedades negócios
         tmp_symboll = HistoryDealGetString(tmp_ticket, DEAL_SYMBOL);
         tmp_profit = HistoryDealGetDouble(tmp_ticket, DEAL_PROFIT);
         tmp_magic = HistoryDealGetInteger(tmp_ticket, DEAL_MAGIC);
         if(tmp_symboll == Symbol())
            tmp_resultado_financeiro_dia = tmp_resultado_financeiro_dia + tmp_profit;
        }
     }
   if(tmp_resultado_financeiro_dia <= LDN)
     {
      //pode_operar = false;
      //Alert("Perda diária de R$"+DoubleToString(LDN, 2)+" foi atingida. Robô stopado!");
      if(gerar_log == ON)
      {
         Print("Perda diária de R$"+DoubleToString(LDN, 2)+" foi atingida. Robô stopado!");
         Print("");
      }
      return(true);
     }
   return(false);
  }
  
// PAINEL
void OnChartEvent(const int id, const long & lparam, const double & dparam, const string & sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == "MUP-Button-Play") {
         ea_enable = true;
         ea_pause = false;
         pode_operar = true;
         ObjectText("MUP-Status", "Enabled");
         ObjectColor("MUP-Status", infopanel_blue_color);
      } else if(sparam == "MUP-Button-Stop") {
         ea_pause = true;
         pode_operar = false;
         ObjectText("MUP-Status", "Disabled");
         ObjectColor("MUP-Status", infopanel_red_color);
      } else if(sparam == "MUP-Button-Zerar") {
         ea_enable = false;
         pode_operar = false;
         ClosePositions(magic_magico, _Symbol);
      } else if(sparam == "MUP-Button-BreakEven")
         Positions_SetBreakeven();

      if(ObjectGetInteger(0, sparam, OBJPROP_TYPE) == OBJ_BUTTON) {
         Sleep(250);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, 0);
      }
   }

   if(id == CHARTEVENT_CHART_CHANGE) {
      dealsTotal = 0;
      InfoPanel_Update();
   }
}

//+------------------------------------------------------------------+
//| Painel                                                           |
//-------------------------------------------------------------------+
void InfoPanel_Update() {
   if(!infopanel_enable) return;
   long type = -1;

   if( PositionsTotal() > 0) {
      double result = 0, lots = 0;
      for(int i = 0; i < PositionsTotal(); i++) {
         if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic_magico) continue;
         result += PositionGetDouble(POSITION_PROFIT);
         lots += PositionGetDouble(POSITION_VOLUME);
         type = PositionGetInteger(POSITION_TYPE);
      }

      if(result > 0) ObjectColor("MUP-Result", infopanel_blue_color);
      else if(result < 0) ObjectColor("MUP-Result", infopanel_red_color);
      else ObjectColor("MUP-Result", infopanel_white_color);

      if(type == POSITION_TYPE_BUY) {
         panelPosition = "Bought";
         ObjectColor("MUP-Position", infopanel_blue_color);
      } else if(type == POSITION_TYPE_SELL) {
         panelPosition = "Sold";
         ObjectColor("MUP-Position", infopanel_red_color);
      } else
          {
            panelPosition = "--";
            ObjectColor("MUP-Position", infopanel_white_color);
          }

      ObjectText("MUP-Position", panelPosition);
      ObjectText("MUP-Lots", DoubleToString(lots, 2));
      ObjectText("MUP-Result", DoubleToString(result, 2));
   } else {
      ObjectText("MUP-Position", "--");
      ObjectText("MUP-Lots", "--");
      ObjectText("MUP-Result", "--");
      ObjectColor("MUP-Position", infopanel_white_color);
      ObjectColor("MUP-Lots", infopanel_white_color);
      ObjectColor("MUP-Result", infopanel_white_color);
   }

   if(dealsTotal != history.all.trades) {
      dealsTotal = history.all.trades;

      ObjectText("MUP-D-Acerto", IntegerToString(history.day.trades_win, 0) + " / " + IntegerToString(history.day.trades_loss, 0) + " (" + DoubleToString(history.day.win_rate, 2) + "%)");
      ObjectText("MUP-W-Acerto", IntegerToString(history.week.trades_win, 0) + " / " + IntegerToString(history.week.trades_loss, 0) + " (" + DoubleToString(history.week.win_rate, 2) + "%)");
      ObjectText("MUP-M-Acerto", IntegerToString(history.month.trades_win, 0) + " / " + IntegerToString(history.month.trades_loss, 0) + " (" + DoubleToString(history.month.win_rate, 2) + "%)");
      ObjectText("MUP-T-Acerto", IntegerToString(history.all.trades_win, 0) + " / " + IntegerToString(history.all.trades_loss, 0) + " (" + DoubleToString(history.all.win_rate, 2) + "%)");
      ObjectText("MUP-D-Result", DoubleToString(history.day.liquid, 2));
      ObjectText("MUP-W-Result", DoubleToString(history.week.liquid, 2));
      ObjectText("MUP-M-Result", DoubleToString(history.month.liquid, 2));
      ObjectText("MUP-T-Result", DoubleToString(history.all.liquid, 2));

      if(history.day.liquid > 0) ObjectColor("MUP-D-Result", infopanel_blue_color);
      else if(history.day.liquid == 0) ObjectColor("MUP-D-Result", infopanel_white_color);
      else ObjectColor("MUP-D-Result", infopanel_red_color);
      if(history.week.liquid > 0) ObjectColor("MUP-W-Result", infopanel_blue_color);
      else if(history.week.liquid == 0) ObjectColor("MUP-W-Result", infopanel_white_color);
      else ObjectColor("MUP-W-Result", infopanel_red_color);
      if(history.month.liquid > 0) ObjectColor("MUP-M-Result", infopanel_blue_color);
      else if(history.month.liquid == 0) ObjectColor("MUP-M-Result", infopanel_white_color);
      else ObjectColor("MUP-M-Result", infopanel_red_color);
      if(history.all.liquid > 0) ObjectColor("MUP-T-Result", infopanel_blue_color);
      else if(history.all.liquid == 0) ObjectColor("MUP-T-Result", infopanel_white_color);
      else ObjectColor("MUP-T-Result", infopanel_red_color);


   }

   tS = (int) iTime(_Symbol, Period(), 0) + PeriodSeconds() - (int) TimeCurrent();
   iS = tS % 60;
   iM = (tS - iS);
   if(iM != 0) iM /= 60;
   iM -= (iM - iM % 60);
   iH = (tS - iS - iM * 60);
   if(iH != 0) iH /= 60;
   if(iH != 0) iH /= 60;
   sS = IntegerToString(iS, 2, '0');
   sM = IntegerToString(iM, 2, '0');
   sH = IntegerToString(iH, 2, '0');

   ObjectText("MUP-LocalTime", TimeToString(TimeLocal(), TIME_SECONDS));
   ObjectText("MUP-ServerTime", TimeToString(TimeCurrent(), TIME_SECONDS));
   ObjectText("MUP-CandleTime", sH + ":" + sM + ":" + sS);
//+------------------------------------------------------------------+
   if(MQLInfoInteger(MQL_TRADE_ALLOWED) == false || TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == false) ea_enable = false;
   if(!ea_enable || ea_pause) {
      ea_pause = true;
      panelText = "Disabled";
      ObjectText("MUP-Status", "Disabled", true);
      ObjectColor("MUP-Status", infopanel_red_color);
   } else if(ea_enable && money_block) {
      ObjectText("MUP-Status", " Block $$");
      ObjectColor("MUP-Status", clrYellow);
   } else if(ea_enable && !ea_pause) {
      ea_pause = false;
      ea_enable = true;
      ObjectText("MUP-Status", "Enabled", true);
      ObjectColor("MUP-Status", infopanel_blue_color);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
void InfoPanel_Create() {
   for(int i = 0; i < 99; i++) panelItems[i] = "-1";

   ObjectCreate(0, "MUP-Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Title", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-2", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Status", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Symbol", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-3", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-4", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-5", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Position", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Lots", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Result", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-6", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-7", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-8", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-9", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-10", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-11", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-D-Acerto", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-D-Result", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-W-Acerto", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-W-Result", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-M-Acerto", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-M-Result", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-T-Acerto", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-T-Result", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-12", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-13", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Subtitle-14", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-LocalTime", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-ServerTime", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-CandleTime", OBJ_LABEL, 0, 0, 0);
   ObjectCreate(0, "MUP-Button-Play", OBJ_BUTTON, 0, 0, 0);
   ObjectCreate(0, "MUP-Button-Stop", OBJ_BUTTON, 0, 0, 0);
   ObjectCreate(0, "MUP-Button-Zerar", OBJ_BUTTON, 0, 0, 0);

   ObjectSetDefault("MUP-Background", 90);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_XDISTANCE, 5);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_YDISTANCE, 255);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_XSIZE, 350);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_YSIZE, 250);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_BGCOLOR, infopanel_bg_color);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "MUP-Background", OBJPROP_BORDER_COLOR, infopanel_border_color);


   ObjectSetDefault("MUP-Title", 99);
   ObjectSetInteger(0, "MUP-Title", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Title", OBJPROP_XDISTANCE, 177);
   ObjectSetInteger(0, "MUP-Title", OBJPROP_YDISTANCE, 240);
   ObjectSetInteger(0, "MUP-Title", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Title", OBJPROP_COLOR, infopanel_title_color);
   ObjectSetString(0, "MUP-Title", OBJPROP_FONT, "Arial Black");
   ObjectSetString(0, "MUP-Title", OBJPROP_TEXT, "[ " + trade_comment + " ]");

   ObjectSetDefault("MUP-Subtitle", 99);
   ObjectSetInteger(0, "MUP-Subtitle", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Subtitle", OBJPROP_YDISTANCE, 240);
   ObjectSetInteger(0, "MUP-Subtitle", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle", OBJPROP_TEXT, "Status");

   ObjectSetDefault("MUP-Subtitle-2", 99);
   ObjectSetInteger(0, "MUP-Subtitle-2", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-2", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-Subtitle-2", OBJPROP_YDISTANCE, 240);
   ObjectSetInteger(0, "MUP-Subtitle-2", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-2", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-2", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-2", OBJPROP_TEXT, "Symbol");

   ObjectSetDefault("MUP-Status", 99);
   ObjectSetInteger(0, "MUP-Status", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Status", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Status", OBJPROP_YDISTANCE, 225);
   ObjectSetInteger(0, "MUP-Status", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-Status", OBJPROP_COLOR, infopanel_blue_color);
   ObjectSetString(0, "MUP-Status", OBJPROP_FONT, "Arial Black");
   ObjectSetString(0, "MUP-Status", OBJPROP_TEXT, "Enabled");

   ObjectSetDefault("MUP-Symbol", 99);
   ObjectSetInteger(0, "MUP-Symbol", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Symbol", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-Symbol", OBJPROP_YDISTANCE, 225);
   ObjectSetInteger(0, "MUP-Symbol", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-Symbol", OBJPROP_COLOR, infopanel_blue_color);
   ObjectSetString(0, "MUP-Symbol", OBJPROP_FONT, "Arial Black");
   ObjectSetString(0, "MUP-Symbol", OBJPROP_TEXT, _Symbol);

   ObjectSetDefault("MUP-Subtitle-3", 99);
   ObjectSetInteger(0, "MUP-Subtitle-3", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-3", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Subtitle-3", OBJPROP_YDISTANCE, 205);
   ObjectSetInteger(0, "MUP-Subtitle-3", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-3", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-3", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-3", OBJPROP_TEXT, "Positon");

   ObjectSetDefault("MUP-Subtitle-4", 99);
   ObjectSetInteger(0, "MUP-Subtitle-4", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-4", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-Subtitle-4", OBJPROP_YDISTANCE, 205);
   ObjectSetInteger(0, "MUP-Subtitle-4", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-4", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-4", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-4", OBJPROP_TEXT, "Lots");

   ObjectSetDefault("MUP-Subtitle-5", 99);
   ObjectSetInteger(0, "MUP-Subtitle-5", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-5", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-Subtitle-5", OBJPROP_YDISTANCE, 205);
   ObjectSetInteger(0, "MUP-Subtitle-5", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-5", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-5", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-5", OBJPROP_TEXT, "Result");

   ObjectSetDefault("MUP-Position", 99);
   ObjectSetInteger(0, "MUP-Position", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Position", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Position", OBJPROP_YDISTANCE, 190);
   ObjectSetInteger(0, "MUP-Position", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-Position", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-Position", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Position", OBJPROP_TEXT, "--");

   ObjectSetDefault("MUP-Lots", 99);
   ObjectSetInteger(0, "MUP-Lots", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Lots", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-Lots", OBJPROP_YDISTANCE, 190);
   ObjectSetInteger(0, "MUP-Lots", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-Lots", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-Lots", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Lots", OBJPROP_TEXT, "--");

   ObjectSetDefault("MUP-Result", 99);
   ObjectSetInteger(0, "MUP-Result", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Result", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-Result", OBJPROP_YDISTANCE, 190);
   ObjectSetInteger(0, "MUP-Result", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-Result", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-Result", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Result", OBJPROP_TEXT, "--");

   ObjectSetDefault("MUP-Subtitle-6", 99);
   ObjectSetInteger(0, "MUP-Subtitle-6", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-6", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-Subtitle-6", OBJPROP_YDISTANCE, 170);
   ObjectSetInteger(0, "MUP-Subtitle-6", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-6", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-6", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-6", OBJPROP_TEXT, "Assertiveness");

   ObjectSetDefault("MUP-Subtitle-7", 99);
   ObjectSetInteger(0, "MUP-Subtitle-7", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-7", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-Subtitle-7", OBJPROP_YDISTANCE, 170);
   ObjectSetInteger(0, "MUP-Subtitle-7", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-7", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-7", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-7", OBJPROP_TEXT, "Result");

   ObjectSetDefault("MUP-Subtitle-8", 99);
   ObjectSetInteger(0, "MUP-Subtitle-8", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-8", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Subtitle-8", OBJPROP_YDISTANCE, 150);
   ObjectSetInteger(0, "MUP-Subtitle-8", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-8", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-8", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-8", OBJPROP_TEXT, "Day");

   ObjectSetDefault("MUP-Subtitle-9", 99);
   ObjectSetInteger(0, "MUP-Subtitle-9", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-9", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Subtitle-9", OBJPROP_YDISTANCE, 130);
   ObjectSetInteger(0, "MUP-Subtitle-9", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-9", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-9", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-9", OBJPROP_TEXT, "Week");

   ObjectSetDefault("MUP-Subtitle-10", 99);
   ObjectSetInteger(0, "MUP-Subtitle-10", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-10", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Subtitle-10", OBJPROP_YDISTANCE, 110);
   ObjectSetInteger(0, "MUP-Subtitle-10", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-10", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-10", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-10", OBJPROP_TEXT, "Month");

   ObjectSetDefault("MUP-Subtitle-11", 99);
   ObjectSetInteger(0, "MUP-Subtitle-11", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-11", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Subtitle-11", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "MUP-Subtitle-11", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "MUP-Subtitle-11", OBJPROP_COLOR, infopanel_blue_color);
   ObjectSetString(0, "MUP-Subtitle-11", OBJPROP_FONT, "Arial Black");
   ObjectSetString(0, "MUP-Subtitle-11", OBJPROP_TEXT, "Total");

   ObjectSetDefault("MUP-D-Acerto", 99);
   ObjectSetInteger(0, "MUP-D-Acerto", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-D-Acerto", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-D-Acerto", OBJPROP_YDISTANCE, 150);
   ObjectSetInteger(0, "MUP-D-Acerto", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-D-Acerto", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-D-Acerto", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-D-Acerto", OBJPROP_TEXT, "0 / 0 (0.00%)");

   ObjectSetDefault("MUP-D-Result", 99);
   ObjectSetInteger(0, "MUP-D-Result", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-D-Result", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-D-Result", OBJPROP_YDISTANCE, 150);
   ObjectSetInteger(0, "MUP-D-Result", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-D-Result", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-D-Result", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-D-Result", OBJPROP_TEXT, "0,00");

   ObjectSetDefault("MUP-W-Acerto", 99);
   ObjectSetInteger(0, "MUP-W-Acerto", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-W-Acerto", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-W-Acerto", OBJPROP_YDISTANCE, 130);
   ObjectSetInteger(0, "MUP-W-Acerto", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-W-Acerto", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-W-Acerto", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-W-Acerto", OBJPROP_TEXT, "0 / 0 (0.00%)");

   ObjectSetDefault("MUP-W-Result", 99);
   ObjectSetInteger(0, "MUP-W-Result", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-W-Result", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-W-Result", OBJPROP_YDISTANCE, 130);
   ObjectSetInteger(0, "MUP-W-Result", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-W-Result", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-W-Result", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-W-Result", OBJPROP_TEXT, "0,00");

   ObjectSetDefault("MUP-M-Acerto", 99);
   ObjectSetInteger(0, "MUP-M-Acerto", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-M-Acerto", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-M-Acerto", OBJPROP_YDISTANCE, 110);
   ObjectSetInteger(0, "MUP-M-Acerto", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-M-Acerto", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-M-Acerto", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-M-Acerto", OBJPROP_TEXT, "0 / 0 (0.00%)");

   ObjectSetDefault("MUP-M-Result", 99);
   ObjectSetInteger(0, "MUP-M-Result", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-M-Result", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-M-Result", OBJPROP_YDISTANCE, 110);
   ObjectSetInteger(0, "MUP-M-Result", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-M-Result", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-M-Result", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-M-Result", OBJPROP_TEXT, "0,00");

   ObjectSetDefault("MUP-T-Acerto", 99);
   ObjectSetInteger(0, "MUP-T-Acerto", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-T-Acerto", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-T-Acerto", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "MUP-T-Acerto", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-T-Acerto", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-T-Acerto", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-T-Acerto", OBJPROP_TEXT, "0 / 0 (0.00%)");

   ObjectSetDefault("MUP-T-Result", 99);
   ObjectSetInteger(0, "MUP-T-Result", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-T-Result", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-T-Result", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "MUP-T-Result", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-T-Result", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-T-Result", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-T-Result", OBJPROP_TEXT, "0,00");

   ObjectSetDefault("MUP-Subtitle-12", 99);
   ObjectSetInteger(0, "MUP-Subtitle-12", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-12", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-Subtitle-12", OBJPROP_YDISTANCE, 65);
   ObjectSetInteger(0, "MUP-Subtitle-12", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-12", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-12", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-12", OBJPROP_TEXT, "Local Timezone");

   ObjectSetDefault("MUP-Subtitle-13", 99);
   ObjectSetInteger(0, "MUP-Subtitle-13", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-13", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-Subtitle-13", OBJPROP_YDISTANCE, 65);
   ObjectSetInteger(0, "MUP-Subtitle-13", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-13", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-13", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-13", OBJPROP_TEXT, "Server Timezone");

   ObjectSetDefault("MUP-Subtitle-14", 99);
   ObjectSetInteger(0, "MUP-Subtitle-14", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Subtitle-14", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-Subtitle-14", OBJPROP_YDISTANCE, 65);
   ObjectSetInteger(0, "MUP-Subtitle-14", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Subtitle-14", OBJPROP_COLOR, infopanel_subtitle_color);
   ObjectSetString(0, "MUP-Subtitle-14", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Subtitle-14", OBJPROP_TEXT, "Next Candle");

   ObjectSetDefault("MUP-LocalTime", 99);
   ObjectSetInteger(0, "MUP-LocalTime", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-LocalTime", OBJPROP_XDISTANCE, 60);
   ObjectSetInteger(0, "MUP-LocalTime", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, "MUP-LocalTime", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-LocalTime", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-LocalTime", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-LocalTime", OBJPROP_TEXT, "00:00:00");

   ObjectSetDefault("MUP-ServerTime", 99);
   ObjectSetInteger(0, "MUP-ServerTime", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-ServerTime", OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, "MUP-ServerTime", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, "MUP-ServerTime", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-ServerTime", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-ServerTime", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-ServerTime", OBJPROP_TEXT, "00:00:00");

   ObjectSetDefault("MUP-CandleTime", 99);
   ObjectSetInteger(0, "MUP-CandleTime", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-CandleTime", OBJPROP_XDISTANCE, 300);
   ObjectSetInteger(0, "MUP-CandleTime", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, "MUP-CandleTime", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "MUP-CandleTime", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetString(0, "MUP-CandleTime", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-CandleTime", OBJPROP_TEXT, "00:00:00");

   ObjectSetDefault("MUP-Button-Play", 99);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_XDISTANCE, 9);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_YDISTANCE, 35);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_XSIZE, 110);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetInteger(0, "MUP-Button-Play", OBJPROP_BGCOLOR, infopanel_start_color);
   ObjectSetString(0, "MUP-Button-Play", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Button-Play", OBJPROP_TEXT, "Start");

   ObjectSetDefault("MUP-Button-Stop", 99);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_XDISTANCE, 125);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_YDISTANCE, 35);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_XSIZE, 110);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetInteger(0, "MUP-Button-Stop", OBJPROP_BGCOLOR, infopanel_pause_color);
   ObjectSetString(0, "MUP-Button-Stop", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Button-Stop", OBJPROP_TEXT, "Pause");

   ObjectSetDefault("MUP-Button-Zerar", 99);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_XDISTANCE, 240);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_YDISTANCE, 35);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_XSIZE, 110);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_COLOR, infopanel_white_color);
   ObjectSetInteger(0, "MUP-Button-Zerar", OBJPROP_BGCOLOR, infopanel_close_color);
   ObjectSetString(0, "MUP-Button-Zerar", OBJPROP_FONT, "Arial");
   ObjectSetString(0, "MUP-Button-Zerar", OBJPROP_TEXT, "Reset");

   panelItems[0] = "MUP-Background";
   panelItems[1] = "MUP-Title";
   panelItems[2] = "MUP-Subtitle";
   panelItems[3] = "MUP-Status";
   panelItems[4] = "MUP-Subtitle-2";
   panelItems[5] = "MUP-Symbol";
   panelItems[6] = "MUP-Subtitle-3";
   panelItems[7] = "MUP-Subtitle-4";
   panelItems[8] = "MUP-Subtitle-5";
   panelItems[9] = "MUP-Position";
   panelItems[10] = "MUP-Lots";
   panelItems[11] = "MUP-Result";
   panelItems[12] = "MUP-Subtitle-6";
   panelItems[13] = "MUP-Subtitle-7";
   panelItems[14] = "MUP-Subtitle-8";
   panelItems[15] = "MUP-Subtitle-9";
   panelItems[16] = "MUP-Subtitle-10";
   panelItems[17] = "MUP-Subtitle-11";
   panelItems[18] = "MUP-D-Result";
   panelItems[19] = "MUP-D-Acerto";
   panelItems[20] = "MUP-W-Result";
   panelItems[21] = "MUP-W-Acerto";
   panelItems[22] = "MUP-M-Result";
   panelItems[23] = "MUP-M-Acerto";
   panelItems[24] = "MUP-T-Result";
   panelItems[25] = "MUP-T-Acerto";
   panelItems[26] = "MUP-Subtitle-12";
   panelItems[27] = "MUP-Subtitle-13";
   panelItems[28] = "MUP-Subtitle-14";
   panelItems[29] = "MUP-LocalTime";
   panelItems[30] = "MUP-ServerTime";
   panelItems[31] = "MUP-CandleTime";
   panelItems[32] = "MUP-Button-Play";
   panelItems[33] = "MUP-Button-Stop";
   panelItems[34] = "MUP-Button-Zerar";

   ChartRedraw();
   InfoPanel_Update();
}

//+------------------------------------------------------------------+
//| Objetos                                                          |
//+------------------------------------------------------------------+
//Aplicar configurações padrões em objetos
void ObjectSetDefault(string object, int zOrder) {
   ObjectSetInteger(0, object, OBJPROP_ZORDER, zOrder);
   ObjectSetInteger(0, object, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, object, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, object, OBJPROP_SELECTED, false);
}

//Mudar cor de um Objeto
void ObjectColor(string object, color obj_color) {
   ObjectSetInteger(0, object, OBJPROP_COLOR, obj_color);
}

//Mudar texto de um Objeto
void ObjectText(string object, string text, bool panel_status = false) {
   if(panel_status) panelText = text;
   ObjectSetString(0, object, OBJPROP_TEXT, text);
}

//Esconder objeto
void ObjectHide(string object) {
   ObjectSetInteger(0, object, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, object, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetDouble(0, object, OBJPROP_PRICE, 0);
}
//Esconder objeto
void ObjectShow(string object) {
   ObjectSetInteger(0, object, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, object, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//Porcentagem
double Math_GetPercentage(bool p, double n) {
   return p ? ((100 + n) / 100) : ((100 - n)  / 100);
}

//Consertar lotes
double Math_FixLot(double l) {
   if(l > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)) {

         Print("[" + trade_comment + "][Aviso!] Volume maior que o permitido para este Ativo! (" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), 2) + ")");
         Alert("[" + trade_comment + "][Aviso!] Volume maior que o permitido para este Ativo! (" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), 2) + ")");
         return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
   }
   if(l < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {

         Print("[" + trade_comment + "][Aviso!] Volume menor que o permitido para este Ativo! (" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2) + ")");
         Alert("[" + trade_comment + "][Aviso!] Volume menor que o permitido para este Ativo! (" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2) + ")");   
         return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      
   }

   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return ((l * step) / step);
}

//+------------------------------------------------------------------+
void ClosePositions(ulong magic, string symbol) {
   for (int i = PositionsTotal(); i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))continue;
      if (PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if (PositionGetString(POSITION_SYMBOL) != symbol) continue;
      trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void HistoryUpdate(ulong magic, string symbol, HISTORY &result) {

   result.Clear();
   double   profit = 0;
   datetime setup = 0, month = iTime(_Symbol, PERIOD_MN1, 0);

   if (HistorySelect(0, TimeCurrent())) {
      for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
         ulong ticket = HistoryDealGetTicket(i);
         if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT || HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_INOUT || HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT_BY)
            if (HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic)
               if (HistoryDealGetString(ticket, DEAL_SYMBOL) == symbol) {

                  profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_FEE);
                  setup = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

                  if (setup > Day(TimeCurrent())) result.day.trades++;
                  if (setup > Week(TimeCurrent())) result.week.trades++;
                  if (setup > month) result.month.trades++;
                  result.all.trades++;

                  if (profit >= 0.0) {
                     if (setup > Day(TimeCurrent())) {
                        result.day.profit += profit;
                        result.day.trades_win++;
                     }
                     if (setup > Week(TimeCurrent())) {
                        result.week.profit += profit;
                        result.week.trades_win++;
                     }
                     if (setup > month) {
                        result.month.profit += profit;
                        result.month.trades_win++;
                     }
                     result.all.profit += profit;
                     result.all.trades_win++;
                  } else if (profit < 0.0) {
                     if (setup > Day(TimeCurrent())) result.day.loss += profit;
                     if (setup > Week(TimeCurrent())) result.week.loss += profit;
                     if (setup > month) result.month.loss += profit;
                     result.all.loss += profit;
                  }
               }
      }
      result.day.trades_loss = result.day.trades - result.day.trades_win;
      result.week.trades_loss = result.week.trades - result.week.trades_win;
      result.month.trades_loss = result.month.trades - result.month.trades_win;
      result.all.trades_loss = result.all.trades - result.all.trades_win;

      result.day.liquid = result.day.profit + result.day.loss;
      result.week.liquid = result.week.profit + result.week.loss;
      result.month.liquid = result.month.profit + result.month.loss;
      result.all.liquid = result.all.profit + result.all.loss;

      if(result.day.trades != 0) result.day.win_rate = (result.day.trades_win / (double)(result.day.trades)) * 100;
      if(result.week.trades != 0) result.week.win_rate = (result.week.trades_win / (double)(result.week.trades)) * 100;
      if(result.month.trades != 0) result.month.win_rate = (result.month.trades_win / (double)(result.month.trades)) * 100;
      if(result.all.trades != 0) result.all.win_rate = (result.all.trades_win / (double)(result.all.trades)) * 100;
   }
   
 }
 
//+------------------------------------------------------------------+
void Positions_SetBreakeven() {
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == magic_magico) {
            if(PositionGetDouble(POSITION_SL) != PositionGetDouble(POSITION_PRICE_OPEN)) {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                  if(SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID) > PositionGetDouble(POSITION_PRICE_OPEN))
                     if(!trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_TP), PositionGetDouble(POSITION_PRICE_OPEN)))
                        if(gerar_log == ON)
                           Print("[" + trade_comment + "][Erro] Não foi possível atualizar a posição em aberto!");
               } else if(SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK) < PositionGetDouble(POSITION_PRICE_OPEN))
                  if(!trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_TP), PositionGetDouble(POSITION_PRICE_OPEN)))
                     if(gerar_log == ON)
                        Print("[" + trade_comment + "][Erro] Não foi possível atualizar a posição em aberto!");
            }
         }
      }
   }
}

//+------------------------PREÇO MEDIO------------------------------------------+
double NormalizeSize(TARGET_MODE mode, double size) {
#define Bid      SymbolInfoDouble(_Symbol,SYMBOL_BID)
   switch(mode) {
   case TARGET_PERCENTAGE:
      return (size / 100) * Bid;
   case TARGET_POINTS:
      return size * _Point;
   default:
      return size;
   }
}

double MedianPrice(ulong magic, string symbol, ENUM_POSITION_TYPE type) {
   double AveragePrice = 0;
   double Count = 0;

   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket)) continue;
      if (PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if (PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if (PositionGetInteger(POSITION_TYPE) != type) continue;
      AveragePrice += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
      Count += PositionGetDouble(POSITION_VOLUME);
   }
   if (Count > 0) return NormalizePriceDS(AveragePrice / Count);
   return -1;
}

void SetMedianTp(ulong magic, ENUM_POSITION_TYPE type, double tp, string symbol) {
   double currentTp, currentPrice;
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if (PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if (PositionGetInteger(POSITION_TYPE) != type)  continue;
      currentTp = NormalizePriceDS(PositionGetDouble(POSITION_TP));
      currentPrice = NormalizePriceDS(PositionGetDouble(POSITION_PRICE_CURRENT));
      if (type == POSITION_TYPE_BUY)
         if (tp != currentTp)
            if(!trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tp))
               if(gerar_log == ON)
                  Print("[Erro] Não foi possível reposicionar o take profit da posição " + IntegerToString(ticket) + "!");
      if (type == POSITION_TYPE_SELL)
         if (tp != currentTp)
            if(!trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tp))
               if(gerar_log == ON)
                  Print("[Erro] Não foi possível reposicionar o take profit da posição " + IntegerToString(ticket) + "!");
   }
}

double NormalizePriceDS(double price) {
   static const double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return (round(price / tick) * tick);
}

double NormalizePricePrecoMedioeCaixa(double price) {
   return price * _Point;
}

   
int CountPositions(ulong magic, string symbol) {
   int sum = 0;
   for (int i = PositionsTotal(); i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))continue;
      if (PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if (PositionGetString(POSITION_SYMBOL) != symbol) continue;
      sum++;
   }
   return sum;
}




// Função para inverter uma posição existente com base no tamanho de lote e na distância em pontos
//void InverterPosicao(double tamanhoLote, double distanciaPontos)
//{
//   // Verifica se há uma posição aberta
//   if (!PositionSelect(_Symbol))
//   {
//      // Obtém os detalhes da posição atual
//      ulong ticket = PositionGetTicket(0);
//      ENUM_POSITION_TYPE type = PositionGetInteger(POSITION_TYPE);
//      double price = PositionGetDouble(POSITION_PRICE_OPEN);
//      double stopLoss = PositionGetDouble(POSITION_SL);
//      double takeProfit = PositionGetDouble(POSITION_TP);
//      ulong newTicket = 0;
//      
//      // Verifica se o tamanho de lote e a distância são diferentes de zero
//      if (tamanhoLote == 0 || distanciaPontos == 0)
//      {
//         Print("Erro: Os inputs devem estar preenchidos e diferentes de zero");
//         return;
//      }
//      
//
//      // Calcula o preço de saída com base na distância em pontos
//      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
//      double exitPrice = (type == POSITION_TYPE_BUY) ? (price - distanciaPontos * pointValue) : (price + distanciaPontos * pointValue);
//      
//      // Envia a nova ordem na direção oposta com o tamanho de lote correspondente
//      if(tick_.ask <= NormalizeDouble(exitPrice,_Digits) && type == POSITION_TYPE_BUY)
//        {
//         double sl = entries_stop_size != 0 ? NormalizePrice(tick_.bid + NormalizeSize(entries_stop_type, entries_stop_size)) : 0;
//         double tp = NormalizePrice(tick_.bid - NormalizeSize(entries_target_type, entries_target_size));
//         newTicket = trade.Sell(tamanhoLote*multiplicador_vm, ativoOp, tick_.bid, sl, tp, "[" + "Inverter Posição " + trade_comment + "]");
//         
//         beAtivo  = false;
//         parAtivo = false;
//         trailing_par_ativo = false;
//        }
//        
//      if(tick_.bid >= NormalizeDouble(exitPrice,_Digits) && type == POSITION_TYPE_SELL)
//         {
//          double sl = entries_stop_size != 0 ? NormalizePrice(tick_.ask - NormalizeSize(entries_stop_type, entries_stop_size)) : 0;
//          double tp = NormalizePrice(tick_.ask + NormalizeSize(entries_target_type, entries_target_size));
//          newTicket = trade.Buy(tamanhoLote*multiplicador_vm, ativoOp, tick_.ask, sl, tp, "[" + "Inverter Posição " + trade_comment + "]");
//          
//          beAtivo  = false;
//          parAtivo = false;
//          trailing_par_ativo = false;
//         }
//      
//      // Verifica se a nova ordem foi enviada com sucesso
//      if (newTicket > 0)
//      {
//         // Fecha a posição atual
//         if (!trade.PositionClose(ticket))
//         {
//            Print("Erro ao fechar a posição atual: ", GetLastError());
//         }
//      }
//      else
//      {
//         Print("Erro ao enviar nova ordem: ", GetLastError());
//      }
//   }
//}




void fTrailingDefault(const ulong magig, const double trail_start, const double trail_step, const eMeasure measure = points, const string symbol = NULL) {
  for(int i = PositionsTotal(); i >= 0; i--) {
    ulong ticket = PositionGetTicket(i);
    if(PositionSelectByTicket(ticket) && !trailing_par_ativo)
      if(PositionGetInteger(POSITION_MAGIC) == magig) {
        double pos_tp     = PositionGetDouble(POSITION_TP);
        double pos_sl     = PositionGetDouble(POSITION_SL);
        double pos_open   = PositionGetDouble(POSITION_PRICE_OPEN);
        double pos_current = PositionGetDouble(POSITION_PRICE_CURRENT);
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
          if(pos_current > fNormalizePrice(pos_open + fAjustSize(trail_start, measure, symbol), symbol)) {
            double new_sl = fNormalizePrice(pos_current - fAjustSize(trail_step, measure, symbol), symbol);
            if(new_sl > pos_sl) {
              trade.PositionModify(ticket, new_sl, pos_tp);
            }
          }
        } else //---
          if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
            if(pos_current < fNormalizePrice(pos_open - fAjustSize(trail_start, measure, symbol), symbol)) {
              double new_sl = fNormalizePrice(pos_current + fAjustSize(trail_step, measure, symbol), symbol);
              if(new_sl < pos_sl || pos_sl == 0) {
                trade.PositionModify(ticket, new_sl, pos_tp);
              }
            }

          }
      }
  }
}

//+------------------------------------------------------------------+
//| Normalização de preço                                            |
//+------------------------------------------------------------------+
double fNormalizePrice(double price, const string symbol = NULL, const  double tick = 0.000000) {
  static const double _tick = tick ? tick : SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
  return (round(price / _tick) * _tick);
}
//+------------------------------------------------------------------+
//| Ajusta o tamanho de acordo com a forma de medida escolhida       |
//+------------------------------------------------------------------+
double fAjustSize(const double size, const  eMeasure measure, const string symbol = NULL) {
  int    digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
  double tick     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
  double pip      = (digits == 5 || digits == 3) ? point * 10 : point;
  switch(measure) {
  case ticks :
    return size * tick;
    break;
  case pips  :
    return size * pip;
    break;
  case points :
    return size * point;
    break;
  case pontos :
    return size;
    break;
  }
  return 0.0;
}

bool jafezreversaoC = false;
bool jafezreversaoV = false;


// Função para inverter uma posição existente com base no tamanho de lote, distância em pontos e dobrar o tamanho de lote a cada reversão
void InverterPosicao(double tamanhoLote, double distanciaPontos)
{
   // Verifica se há uma posição aberta
   if (PositionSelect(_Symbol) && iUseVM )//&& !env_pos
   {
      // Obtém os detalhes da posição atual
      ulong ticket = PositionGetTicket(0);
      //ENUM_POSITION_TYPE type = PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      ulong newTicket = 0;
      
      // Verifica se o tamanho de lote e a distância são maiores que zero
      if (tamanhoLote <= 0 || distanciaPontos <= 0)
      {
         Print("Erro: O tamanho de lote e a distância devem ser maiores que zero");
         return;
      }
      
      // Calcula o novo tamanho de lote a ser usado
      tamanhoLote = NormalizeDouble(volume*multiplicador_vm,2);//+tamanhoLote
      
      
      // Calcula o preço de saída com base na distância em pontos
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double exitPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? (price - distanciaPontos * pointValue) : (price + distanciaPontos * pointValue);
      
      
      
      
//      // Envia a nova ordem na direção oposta com o tamanho de lote correspondente
      if(tick_.ask <= NormalizeDouble(exitPrice,_Digits) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && !jafezreversaoC)
        {
         double sl = entries_stop_size != 0 ? NormalizePriceDS(tick_.bid + NormalizeSize(entries_stop_type, entries_stop_size)) : 0;//stopLoss;//
         double tp = NormalizePriceDS(tick_.bid - NormalizeSize(entries_target_type, entries_target_size));//takeProfit;//
         
         
         newTicket = trade.Sell(tamanhoLote, ativoOp, tick_.bid, sl, tp, "[" + "Inverter Posição " + trade_comment + "]");
         
         jafezreversaoC = true;
         jafezreversaoV = false;
         
         beAtivo  = false;
         parAtivo = false;
         if(estrategia != LIVWELL)
            trailing_par_ativo = true;
         else trailing_par_ativo = false;
        }
        
      if(tick_.bid >= NormalizeDouble(exitPrice,_Digits) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && !jafezreversaoV)
         {
          double sl = entries_stop_size != 0 ? NormalizePriceDS(tick_.ask - NormalizeSize(entries_stop_type, entries_stop_size)) : 0;//stopLoss;//
          double tp = NormalizePriceDS(tick_.ask + NormalizeSize(entries_target_type, entries_target_size));//takeProfit;//
          
          
          newTicket = trade.Buy(tamanhoLote, ativoOp, tick_.ask, sl, tp, "[" + "Inverter Posição " + trade_comment + "]");
          
          jafezreversaoC = false;
          jafezreversaoV = true;
         
          beAtivo  = false;
          parAtivo = false;
          if(estrategia != LIVWELL)
            trailing_par_ativo = true;
          else trailing_par_ativo = false;
         }      
      
      // Verifica se a nova ordem foi enviada com sucesso
      if (newTicket > 0)
      {
         // Fecha a posição atual
         if (!trade.PositionClose(ticket))
         {
            Print("Erro ao fechar a posição atual: ", GetLastError());
         }
         
         // Chama a função InverterPosicao recursivamente com o novo tamanho de lote
         //if(!env_pos)
         //  {
         //   env_pos = true;
         
            //trade.PositionModify(ticket, stopLoss, PrecoMedioDoisLados());
            
           //}
         
      }
      else
      {
         Print("Erro ao enviar nova ordem: ", GetLastError());
      }
   }
}

double PrecoMedioDoisLados()
{
   double lote_total = 0;
   double preco_medio = 0;

   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      //ulong ticket = PositionGetTicket(i);
      //if(PositionSelectByTicket(ticket))
      //{

         //if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
         //{
            preco_medio += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
            lote_total += PositionGetDouble(POSITION_VOLUME);
         //}
      //}
   }
   if(lote_total == 0)
      lote_total = 1;

   return Arredondar(NormalizeDouble(preco_medio / lote_total, _Digits));
}

void BreakEven2()
{

   double preco_medio_compra = PrecoMedio(POSITION_TYPE_BUY);
   double preco_medio_venda = PrecoMedio(POSITION_TYPE_SELL);
   

   int qtd_posicoes = 0;
   int qtd_breakeven_realizado = 0;

   int total = PositionsTotal() - 1;

   for(int i = total; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {


         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double preco_abertura = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);

            qtd_posicoes++;

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               double distancia_normalizada = NormalizePrice2(distancia_break1, preco_medio_compra, medida_breakeven);
               double ponto_normlizado = NormalizePrice2(pontos_break1, preco_medio_compra, medida_breakeven);
               
               double preco_acionamento = preco_abertura + distancia_normalizada;
               

               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

               //Verifica se o preço é atingiu o preço de acionamento do breakeven
               if(bid >= preco_acionamento && bid > 0)
               {
                  //Verifica se o breakeven não foi realizado
                  if(sl < preco_abertura || sl == 0)
                  {
                     double novo_sl = preco_abertura + ponto_normlizado;

                     //Verifica se o novo stop é diferente do atual
                     if(novo_sl != sl)
                     {
                        //Verifica se o preço é válido para posicionar o novo stop
                        if(bid > novo_sl)
                        {
                           //Alterar o stop loss
                           if(trade.PositionModify(ticket, novo_sl, tp))
                           {
                              ObjectDelete(0, "*breakeven");
                              qtd_breakeven_realizado++;
                              
                           }
                           
                        }
                     }
                  }
               }
            }
            else
            {
               double distancia_normalizada = NormalizePrice2(distancia_break1, preco_medio_venda, medida_breakeven);
               double ponto_normlizado = NormalizePrice2(pontos_break1, preco_medio_venda, medida_breakeven);
               
               double preco_acionamento = preco_abertura - distancia_normalizada;
               


               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

               //Verifica se o preço é menor que a abertura mais o valor do array definido no OnInit(), e verifica se o array terminou caso tenha terminado valor zero
               if(ask <= preco_acionamento && ask > 0)
               {
                  //Verifica se o breakeven não foi realizado
                  if(sl > preco_abertura || sl == 0)
                  {
                     double novo_sl = preco_abertura - ponto_normlizado;

                     //Verifica se o novo stop é diferente do atual
                     if(novo_sl != sl)
                     {
                        //Verifica se o preço do novo stop é válido
                        if(ask < novo_sl)
                        {
                           if(trade.PositionModify(ticket, novo_sl, tp))
                           {
                              ObjectDelete(0, "*breakeven");
                              
                              qtd_breakeven_realizado++;
                           }
                           
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

double PrecoMedio(ENUM_POSITION_TYPE position)
{
   double lote_total = 0;
   double preco_medio = 0;

   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == _Symbol && position == PositionGetInteger(POSITION_TYPE))
         {
            preco_medio += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
            lote_total += PositionGetDouble(POSITION_VOLUME);
         }
      }
   }
   if(lote_total == 0)
      lote_total = 1;

   return Arredondar(NormalizeDouble(preco_medio / lote_total, _Digits));
}

//---Normaliza o preço
double Arredondar(double price, string symbol = NULL, double tick = 0)
{
   const double _tick = tick ? tick : SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick == 0)
      tick = 1;

   return NormalizeDouble(round(price / _tick) * _tick, _Digits);
}

double NormalizePrice2(double price, double preco, ENUM_UNIDADE_MEDIDA medida )
{
   static double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   static double valor_tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(medida == UNIDADE_PIPS)
   {
      return price * _Point;
   }
   else if(medida == UNIDADE_PONTOS)
   {  
      if(price == 0)
         return 0;
      
      //retorna o preço em pontos
      if(tick_size != 0)
         return(NormalizeDouble(MathRound(price / tick_size) * tick_size, _Digits));

      return (price * _Point);
   }
   else if(medida == UNIDADE_PORCENTAGEM)
   {
      double referencia = Arredondar(preco * (price / 100));
      return referencia;
   }
   return 0;

}

//+------------------------------------------------------------------+
//| MARTINGALE                                                       |
//+------------------------------------------------------------------+
double lot() {
  double lot = entries_lot_size;
#ifdef __MQL5__
  if(HistorySelect(0, TimeCurrent())) {
    double profit = HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal() - 1), DEAL_PROFIT);
    double LastLot = HistoryDealGetDouble(HistoryDealGetTicket(HistoryDealsTotal() - 1), DEAL_VOLUME);
    if(profit > 0)
      lot = entries_lot_size;
    if(profit < 0)
      lot = LastLot * multiplicador_recovery;
  }
#endif
  if(lot > max_lot_recovery)
    lot = entries_lot_size;
  return(lot);
}

void CriarLinhaH(const long janela,
                 const int subjanela,
                 const string nome,
                 double preco,
                 color cor,
                 const ENUM_LINE_STYLE estilo,
                 const int tamanho,
                 const bool oculto,
                 const bool fundo,
                 bool selecionavel,
                 string dica_=NULL)
  {
    if (ObjectFind(janela,nome)==-1)
    {ObjectCreate(janela,nome,OBJ_HLINE,subjanela,0,preco);}
    ObjectCreate(janela,nome,OBJ_HLINE,subjanela,0,preco);
    ObjectSetDouble(janela,nome,OBJPROP_PRICE,preco);
    ObjectSetInteger(janela,nome,OBJPROP_COLOR,cor);
    ObjectSetInteger(janela,nome,OBJPROP_STYLE,estilo);
    ObjectSetInteger(janela,nome,OBJPROP_WIDTH,tamanho);
    ObjectSetInteger(janela,nome,OBJPROP_HIDDEN,oculto);
    ObjectSetInteger(janela,nome,OBJPROP_BACK,fundo);
    ObjectSetInteger(janela,nome,OBJPROP_SELECTABLE,selecionavel);
    ObjectSetString(janela,nome,OBJPROP_TOOLTIP,dica_);
  }
  
bool SearchZigZagExtremums(const int count,double &array_results[],int buffer_num)
  {
   if(!ArrayIsDynamic(array_results))
     {
      Print("This a no dynamic array!");
      return(false);
     }
   ArrayFree(array_results);
   ArrayResize(array_results,count);
   ArraySetAsSeries(array_results,true);
   //int      buffer_num=1;           // indicator buffer number 
   double   arr_buffer[];
   ArraySetAsSeries(arr_buffer,true);
//--- reset error code 
   ResetLastError();
//--- fill a part of the iCustom array with values from the indicator buffer
   int copied=CopyBuffer(handle_iCustom,buffer_num,0,100,arr_buffer);
   if(copied<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iCustom indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false);
     }
   int elements=0;
   for(int i=0;i<copied;i++)
     {
      if(arr_buffer[i]!=0)
        {
         array_results[elements]=arr_buffer[i];
         elements++;
         if(elements==count)
            break;
        }
     }
   if(elements==count)
      return(true);
//---
   return(false);
  }
  

// Função para detectar um padrão de candle martelo (hammer)
bool IsHammer(const int index)
{
    double body = MathAbs(velas[index].open - velas[index].close);
    double upperShadow = velas[index].high - MathMax(velas[index].open, velas[index].close);
    double lowerShadow = MathMin(velas[index].open, velas[index].close) - velas[index].low;
    double totalRange = body + upperShadow + lowerShadow;
    
    // Condição para ser um martelo
    if (lowerShadow > body * 2 && upperShadow < body * 0.3 && upperShadow < totalRange * 0.1)
        return true;
    
    return false;
}

// Função para detectar um padrão de candle estrela cadente (shooting star)
bool IsShootingStar(const int index)
{
    double body = MathAbs(velas[index].open - velas[index].close);
    double upperShadow = velas[index].high - MathMax(velas[index].open, velas[index].close);
    double lowerShadow = MathMin(velas[index].open, velas[index].close) - velas[index].low;
    double totalRange = body + upperShadow + lowerShadow;
    
    // Condição para ser uma estrela cadente
    if (upperShadow > body * 2 && lowerShadow < body * 0.3 && lowerShadow < totalRange * 0.1)
        return true;
    
    return false;
}

// Função para detectar um padrão de candle sólido (corpo sólido)
bool IsSolidCandle(const int index)
{
    double body = MathAbs(velas[index].open - velas[index].close);
    double upperShadow = velas[index].high - MathMax(velas[index].open, velas[index].close);
    double lowerShadow = MathMin(velas[index].open, velas[index].close) - velas[index].low;
    double totalRange = body + upperShadow + lowerShadow;
    
    // Condição para ser um candle sólido
    if (upperShadow < totalRange * 0.05 && lowerShadow < totalRange * 0.05)
        return true;
    
    return false;
}

bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
//--- obtemos o preço de abertura
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
//--- valores da margem necessária e livre
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   //--- chamamos a função de verificação
   if(!OrderCalcMargin(type,symb,lots,price,margin))
     {
      //--- algo deu errado, informamos e retornamos false
      Print("Error in ",__FUNCTION__," code=",GetLastError());
      return(false);
     }
   //--- se não houver fundos suficientes para realizar a operação
   if(margin>free_margin)
     {
      //--- informamos sobre o erro e retornamos false
      Print("Not enough money for ",EnumToString(type)," ",lots," ",symb," Error code=",GetLastError());
      return(false);
     }
//--- a verificação foi realizada com sucesso
   return(true);
  }

double GetCurrentMeanPrice(string symbol, long magic = WRONG_VALUE)
{
   ulong  ticket    = 0;
   double volSum    = 0;
   double pvSum     = 0;
   double meanPrice = 0;

   for (int i = 0; i < PositionsTotal(); i++)
      if ((ticket = PositionGetTicket(i)) > 0)
      {
         if (PositionGetString(POSITION_SYMBOL) == symbol)
         if (PositionGetInteger(POSITION_MAGIC) == magic || magic  == WRONG_VALUE)
         {
            double price  = PositionGetDouble(POSITION_PRICE_OPEN);
            double volume = PositionGetDouble(POSITION_VOLUME);
            pvSum  += price * volume;
            volSum += volume;
            meanPrice = pvSum / volSum;
         }
      }
   return meanPrice;
}

//---
bool AjustarTakeAposAumentoPosicao(double take_ajuste)
{
   int qtd_posicoes = 0;
   int qtd_posicoes_ajustadas = 0;

   double open = PrecoMedio();

   int total = PositionsTotal() - 1;
   for(int i = total; i >= 0 ; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {

         if(PositionGetInteger(POSITION_MAGIC) == magic_magico && PositionGetString(POSITION_SYMBOL) == ativoOp)
         {
            qtd_posicoes++;

            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               //Verifica se o take proft está de um tamanho diferente do definido
               if(tp - open != NormalizePricePrecoMedioeCaixa(take_ajuste))
               {
                  double novo_tp = (take_ajuste > 0) ? open + NormalizePricePrecoMedioeCaixa(take_ajuste) : 0;

                  //Verifica se o novo take profit é diferente do atual
                  if(novo_tp != tp)
                  {
                     //Verifica se o preço do novo take profit é válido
                     if(tick_.bid < novo_tp)
                     {
                        if(trade.PositionModify(ticket, sl, novo_tp))
                        {
                           Mostre("Take profit da operação de compra reajustado com sucesso após realizar preço médio no " + (string)PositionGetString(POSITION_SYMBOL) + " Sl: " + (string)sl + ", Tp: " + (string)novo_tp + ", Volume: " + (string)PositionGetDouble(POSITION_VOLUME));
                           qtd_posicoes_ajustadas++;
                        }
                        else
                        {
                           Mostre("Erro ao ajustar o take profit da operação de compra após preço médio no " + (string)PositionGetString(POSITION_SYMBOL) + "  Sl: " + (string)sl + " Tp: " + (string)PositionGetDouble(POSITION_TP) + " -> Sl: " + (string)sl + " Tp: " + (string)novo_tp + "Erro: " + (string)GetLastError());
                        }
                     }
                  }
               }
               else if(tp > 0)
                  qtd_posicoes_ajustadas++;
            }
            else
            {
               //Verifica se o take proft está de um tamanho diferente do definido
               if(open - tp != NormalizePricePrecoMedioeCaixa(take_ajuste))
               {
                  double novo_tp = (take_ajuste > 0) ? open - NormalizePricePrecoMedioeCaixa(take_ajuste) : 0;

                  //Verifica se o novo tp é diferente do atual
                  if(novo_tp != tp)
                  {
                     //Verifica se o preço do novo tp é válido
                     if(tick_.ask > novo_tp)
                     {
                        if(trade.PositionModify(ticket, sl, novo_tp))
                        {
                           Mostre("Take profit da operação de venda reajustado com sucesso após realizar preço médio no " + (string)PositionGetString(POSITION_SYMBOL) + " Sl: " + (string)sl + ", Tp: " + (string)novo_tp + ", Volume: " + (string)PositionGetDouble(POSITION_VOLUME));
                           qtd_posicoes_ajustadas++;
                        }
                        else
                        {
                           Mostre("Erro ao ajustar o take profit da operação de venda após preço médio no " + (string)PositionGetString(POSITION_SYMBOL) + "  Sl: " + (string)sl + " Tp: " + (string)PositionGetDouble(POSITION_TP) + " -> Sl: " + (string)sl + " Tp: " + (string)novo_tp + "Erro: " + (string)GetLastError());
                        }
                     }
                  }
               }
               else if(tp > 0)
                  qtd_posicoes_ajustadas++;
            }

         }
      }
   }

   if(qtd_posicoes == qtd_posicoes_ajustadas)
      return true;
   else
      return false;
}

   //--- BOOK  
   
//   MarketBookAdd(_Symbol);
//   
//   MqlBookInfo livro[];
//   
//   bool getBook = MarketBookGet(_Symbol,livro);
//   int size = 0;
//   if(getBook)
//     {
//      size = ArraySize(livro);
//      Print("MarketBookInfo sobre ",  Symbol());
//     } else
//         {
//          Print("Falha ao resceber DOM para o símbolo ",  Symbol(), " , um total de N = ", size);
//         }
//         
//   MarketBookRelease(_Symbol);
//   
//   //for(int i=0;i<ArraySize(livro);i++)
//for(int i = ArraySize(livro)-1; i>=0; i--)
//     {    
//      for(int i=0;i<ArraySize(livro);i++){ 
//         if(livro[i].type == BOOK_TYPE_SELL)
//           { 
//            //Print("VENDA: Preço = ",livro[i].price, " - Volume: ",livro[i].volume);
//            comentv = "VENDA: Preço = "+string(livro[i].price)+" - Volume: "+string(livro[i].volume);
//           } }
//     
//        if(livro[i].type == BOOK_TYPE_BUY)
//            {
//             //Print("COMPRA: Preço = ",livro[i].price, " - Volume: ",livro[i].volume);
//             cometc = "COMPRA: Preço = "+string(livro[i].price)+" - Volume: "+string(livro[i].volume);
//            }
//            
//      Comment(cometc+"\n"+comentv);
//     }




//--- TIMES & TRADES
    
    
//    int ok = CopyTicks(_Symbol,ticks,COPY_TICKS_TRADE,TimeCurrent(),100);
//    
//    if(ok != -1)
//      {
//       for(int i=0;i<ArraySize(ticks);i++)
//         {
//          string tipo = "DIRETO";
//          if(ticks[i].flags == 312)
//            {
//             tipo = "COMPRA";
//            }
//            
//            if(ticks[i].flags == 344) tipo = "VENDA";
//            
//            Comment("Tick - Hora = ",ticks[i].time," - Flag = ",ticks[i].flags,
//                  ", Ask = ", ticks[i].ask, ", Bid = ", ticks[i].bid,", Last= ", ticks[i].last,", Tipo = ", tipo);
//              
//         }
//      }else
//         {
//          Print("Não conseguimos coletar os dados ticks.");
//         }


//+------------------------------------------------------------------+
//| Imprimir Informações MarketBook                                  |
//+------------------------------------------------------------------+
/*
void PrintMbookInfo()
  {
   Book.Refresh();                  // Atualizar os status do Depth of Market.
   //Obtém Estatísticas Básicas
   int total=Book.InfoGetInteger(MBOOK_DEPTH_TOTAL);
   int total_ask = Book.InfoGetInteger(MBOOK_DEPTH_ASK);
   int total_bid = Book.InfoGetInteger(MBOOK_DEPTH_BID);
   int best_ask = Book.InfoGetInteger(MBOOK_BEST_ASK_INDEX);
   int best_bid = Book.InfoGetInteger(MBOOK_BEST_BID_INDEX);

   printf("DEPTH OF MARKET TOTAL: "+(string)total);
   printf("NÚMERO DE NÍVEIS DOS PREÇOS PARA VENDER: "+(string)total_ask);
   printf("NÚMERO DE NÍVEIS DOS PREÇOS PARA COMPRAR: "+(string)total_bid);
   printf("ÍNDICE DO MELHOR PREÇO ASK: "+(string)best_ask);
   printf("ÍNDICE DO MELHOR PREÇO BID: "+(string)best_bid);
   
   double best_ask_price = Book.InfoGetDouble(MBOOK_BEST_ASK_PRICE);
   double best_bid_price = Book.InfoGetDouble(MBOOK_BEST_BID_PRICE);
   double last_ask = Book.InfoGetDouble(MBOOK_LAST_ASK_PRICE);
   double last_bid = Book.InfoGetDouble(MBOOK_LAST_BID_PRICE);
   double avrg_spread = Book.InfoGetDouble(MBOOK_AVERAGE_SPREAD);
   
   printf("MELHOR PREÇO ASK: " + DoubleToString(best_ask_price, Digits()));
   printf("MELHOR PREÇO BID: " + DoubleToString(best_bid_price, Digits()));
   printf("PIOR PREÇO ASK: " + DoubleToString(last_ask, Digits()));
   printf("PIOR PREÇO BID: " + DoubleToString(last_bid, Digits()));
   printf("SPREAD MÉDIO: " + DoubleToString(avrg_spread, Digits()));
  }
*/

