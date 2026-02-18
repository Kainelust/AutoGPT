#property copyright "Auto-generated template"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

enum ENUM_LOT_MODE
{
   LOT_MODE_RISK_PERCENT = 0,
   LOT_MODE_FIXED_LOT = 1
};

enum ENUM_SCALP_PRESET
{
   PRESET_CUSTOM = 0,
   PRESET_CONSERVATIVE = 1,
   PRESET_BALANCED = 2,
   PRESET_AGGRESSIVE = 3
};

// =========================
// AGGRESSIVE M1 SCALPING EA
// =========================

input string InpSymbol = "XAUUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe = PERIOD_M1;
input ENUM_SCALP_PRESET InpScalpPreset = PRESET_BALANCED;

// Fast, high-frequency signal setup
input int InpFastEmaPeriod = 5;
input int InpSlowEmaPeriod = 13;
input int InpRsiPeriod = 3;
input double InpRsiLongLevel = 50.0;
input double InpRsiShortLevel = 50.0;
input int InpAtrPeriod = 14;
input double InpMinAtrPoints = 40;          // Low threshold to keep bot active

// Execution / risk
input double InpRiskPercent = 0.8;
input ENUM_LOT_MODE InpLotMode = LOT_MODE_FIXED_LOT;
input double InpFixedLotSize = 0.01;
input double InpSL_ATR_Mult = 0.55;
input double InpTP_ATR_Mult = 0.85;
input int InpMaxSpreadPoints = 50;
input int InpSlippagePoints = 25;
input ulong InpMagic = 25021803;

// High activity controls
input int InpMaxTradesPerDay = 300;
input int InpMaxOpenPositionsTotal = 6;
input int InpMaxOpenPositionsPerSide = 3;
input int InpMinSecondsBetweenEntries = 2;

// Position management
input bool InpUseBreakEven = true;
input double InpBreakEvenATR_Mult = 0.35;
input bool InpUseTrailingStop = true;
input double InpTrailATR_Mult = 0.35;
input int InpMaxHoldMinutes = 15;
input bool InpCloseOnOppositeSignal = true;

// Session and daily guard (still needed to protect account)
input int InpStartHour = 0;
input int InpEndHour = 24;
input double InpMaxDailyLossPercent = 8.0;

int hFastEma = INVALID_HANDLE;
int hSlowEma = INVALID_HANDLE;
int hRsi = INVALID_HANDLE;
int hAtr = INVALID_HANDLE;

datetime lastBarTime = 0;
datetime lastEntryTime = 0;
double dayStartEquity = 0.0;
int currentDayOfYear = -1;
int tradesToday = 0;

bool IsNewBar();
void ResetDailyStateIfNeeded();
bool IsTradeSession();
bool IsSpreadOk();
bool IsDailyRiskOk();
bool ReadBufferValue(const int handle, const int shift, double &value);
double GetSymbolPoint();
int GetSymbolDigits();
int CountOpenPositions(bool countBuy, bool countSell);
double NormalizeVolume(double volume);
double CalculatePositionSizeLots(double slDistancePrice);
bool BuildSignal(bool &longSignal, bool &shortSignal, double &atrCurrent);
void EvaluateEntries();
void ManageOpenPositions();
void OpenBuy(double atrValue);
void OpenSell(double atrValue);
double EffRiskPercent();
double EffFixedLotSize();
double EffSLAtrMult();
double EffTPAtrMult();
int EffMaxSpreadPoints();
int EffMaxTradesPerDay();
int EffMinSecondsBetweenEntries();
int EffMaxHoldMinutes();
double EffMaxDailyLossPercent();

int OnInit()
{
   if(!SymbolSelect(InpSymbol, true))
   {
      Print("Failed to select symbol: ", InpSymbol);
      return INIT_FAILED;
   }

   hFastEma = iMA(InpSymbol, InpSignalTimeframe, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hSlowEma = iMA(InpSymbol, InpSignalTimeframe, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hRsi = iRSI(InpSymbol, InpSignalTimeframe, InpRsiPeriod, PRICE_CLOSE);
   hAtr = iATR(InpSymbol, InpSignalTimeframe, InpAtrPeriod);

   if(hFastEma == INVALID_HANDLE || hSlowEma == INVALID_HANDLE || hRsi == INVALID_HANDLE || hAtr == INVALID_HANDLE)
   {
      Print("Indicator handle initialization failed.");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber((long)InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   currentDayOfYear = dt.day_of_year;
   dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   tradesToday = 0;

   Print("Initialized aggressive XAUUSD M1 scalper. Preset=", (int)InpScalpPreset);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hFastEma != INVALID_HANDLE) IndicatorRelease(hFastEma);
   if(hSlowEma != INVALID_HANDLE) IndicatorRelease(hSlowEma);
   if(hRsi != INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAtr != INVALID_HANDLE) IndicatorRelease(hAtr);
}

void OnTick()
{
   ResetDailyStateIfNeeded();

   // Always manage open positions on each tick
   ManageOpenPositions();

   // Entries run once per bar to avoid over-spam and duplicate orders
   if(!IsNewBar()) return;
   if(!IsTradeSession()) return;
   if(!IsSpreadOk()) return;
   if(!IsDailyRiskOk()) return;

   if(tradesToday >= EffMaxTradesPerDay())
   {
      Print("Daily max trades reached.");
      return;
   }

   EvaluateEntries();
}

void ResetDailyStateIfNeeded()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.day_of_year != currentDayOfYear)
   {
      currentDayOfYear = dt.day_of_year;
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      tradesToday = 0;
      Print("Daily counters reset.");
   }
}

bool IsNewBar()
{
   datetime times[];
   if(CopyTime(InpSymbol, InpSignalTimeframe, 0, 2, times) < 2)
      return false;

   if(times[0] != lastBarTime)
   {
      lastBarTime = times[0];
      return true;
   }

   return false;
}

bool IsTradeSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(InpStartHour == 0 && InpEndHour == 24)
      return true;

   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

bool IsSpreadOk()
{
   double point = GetSymbolPoint();
   if(point <= 0.0) return false;

   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double spread = (ask - bid) / point;

   if(spread > EffMaxSpreadPoints())
   {
      Print("Spread too high: ", DoubleToString(spread, 1));
      return false;
   }

   return true;
}

bool IsDailyRiskOk()
{
   if(dayStartEquity <= 0.0) return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = ((dayStartEquity - equity) / dayStartEquity) * 100.0;

   if(drawdown >= EffMaxDailyLossPercent())
   {
      Print("Daily loss limit reached: ", DoubleToString(drawdown, 2), "%");
      return false;
   }

   return true;
}

bool ReadBufferValue(const int handle, const int shift, double &value)
{
   double arr[];
   if(CopyBuffer(handle, 0, shift, 1, arr) < 1)
      return false;

   value = arr[0];
   return true;
}

double GetSymbolPoint()
{
   return SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
}

int GetSymbolDigits()
{
   return (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
}

int CountOpenPositions(bool countBuy, bool countSell)
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      long type = PositionGetInteger(POSITION_TYPE);

      if(symbol != InpSymbol || magic != InpMagic)
         continue;

      if((countBuy && type == POSITION_TYPE_BUY) || (countSell && type == POSITION_TYPE_SELL))
         count++;
   }

   return count;
}

double NormalizeVolume(double volume)
{
   double minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = minLot;

   double normalized = MathFloor(volume / step) * step;
   normalized = MathMax(minLot, MathMin(maxLot, normalized));

   int digits = 2;
   if(step == 1.0) digits = 0;
   else if(step == 0.1) digits = 1;

   return NormalizeDouble(normalized, digits);
}

double CalculatePositionSizeLots(double slDistancePrice)
{
   if(InpLotMode == LOT_MODE_FIXED_LOT)
      return NormalizeVolume(EffFixedLotSize());

   if(slDistancePrice <= 0.0) return 0.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (EffRiskPercent() / 100.0);
   if(riskMoney <= 0.0) return 0.0;

   double tickSize = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0) return 0.0;

   double lossPerLot = (slDistancePrice / tickSize) * tickValue;
   if(lossPerLot <= 0.0) return 0.0;

   double rawLots = riskMoney / lossPerLot;
   return NormalizeVolume(rawLots);
}

bool BuildSignal(bool &longSignal, bool &shortSignal, double &atrCurrent)
{
   longSignal = false;
   shortSignal = false;

   double fastNow, slowNow, rsiNow, rsiPrev;
   if(!ReadBufferValue(hFastEma, 1, fastNow)) return false;
   if(!ReadBufferValue(hSlowEma, 1, slowNow)) return false;
   if(!ReadBufferValue(hRsi, 1, rsiNow)) return false;
   if(!ReadBufferValue(hRsi, 2, rsiPrev)) return false;
   if(!ReadBufferValue(hAtr, 1, atrCurrent)) return false;

   double point = GetSymbolPoint();
   if(point <= 0.0) return false;

   double atrPoints = atrCurrent / point;
   if(atrPoints < InpMinAtrPoints)
      return true;

   bool trendUp = fastNow > slowNow;
   bool trendDown = fastNow < slowNow;

   // aggressive midpoint RSI crossings for high trade frequency
   longSignal = trendUp && (rsiPrev <= InpRsiLongLevel && rsiNow > InpRsiLongLevel);
   shortSignal = trendDown && (rsiPrev >= InpRsiShortLevel && rsiNow < InpRsiShortLevel);

   return true;
}

void EvaluateEntries()
{
   if((TimeCurrent() - lastEntryTime) < EffMinSecondsBetweenEntries())
      return;

   int openBuys = CountOpenPositions(true, false);
   int openSells = CountOpenPositions(false, true);
   int openTotal = openBuys + openSells;

   if(openTotal >= InpMaxOpenPositionsTotal)
      return;

   bool longSignal, shortSignal;
   double atrCurrent;

   if(!BuildSignal(longSignal, shortSignal, atrCurrent))
      return;

   if(longSignal && openBuys < InpMaxOpenPositionsPerSide)
      OpenBuy(atrCurrent);

   if(shortSignal && openSells < InpMaxOpenPositionsPerSide)
      OpenSell(atrCurrent);
}

void ManageOpenPositions()
{
   bool longSignal = false;
   bool shortSignal = false;
   double atrCurrent = 0.0;
   bool signalOk = BuildSignal(longSignal, shortSignal, atrCurrent);

   double point = GetSymbolPoint();
   int digits = GetSymbolDigits();
   if(point <= 0.0 || digits <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      long type = PositionGetInteger(POSITION_TYPE);

      if(symbol != InpSymbol || magic != InpMagic)
         continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
      double current = (type == POSITION_TYPE_BUY) ? bid : ask;

      // 1) Hard timeout
      if(EffMaxHoldMinutes() > 0)
      {
         int held = (int)((TimeCurrent() - openTime) / 60);
         if(held >= EffMaxHoldMinutes())
         {
            trade.PositionClose(ticket);
            continue;
         }
      }

      // 2) Opposite signal exit
      if(InpCloseOnOppositeSignal && signalOk)
      {
         bool closeBuy = (type == POSITION_TYPE_BUY && shortSignal);
         bool closeSell = (type == POSITION_TYPE_SELL && longSignal);
         if(closeBuy || closeSell)
         {
            trade.PositionClose(ticket);
            continue;
         }
      }

      // if ATR unavailable, skip dynamic stop updates
      if(!signalOk || atrCurrent <= 0.0)
         continue;

      // 3) Break-even
      if(InpUseBreakEven)
      {
         double beMove = atrCurrent * InpBreakEvenATR_Mult;

         if(type == POSITION_TYPE_BUY && (current - entry) >= beMove)
         {
            double beSL = NormalizeDouble(entry + (2.0 * point), digits);
            if(sl < beSL)
               trade.PositionModify(ticket, beSL, tp);
         }
         else if(type == POSITION_TYPE_SELL && (entry - current) >= beMove)
         {
            double beSL = NormalizeDouble(entry - (2.0 * point), digits);
            if(sl == 0.0 || sl > beSL)
               trade.PositionModify(ticket, beSL, tp);
         }
      }

      // 4) ATR trailing
      if(InpUseTrailingStop)
      {
         double trailDist = atrCurrent * InpTrailATR_Mult;

         if(type == POSITION_TYPE_BUY)
         {
            double trailSL = NormalizeDouble(current - trailDist, digits);
            if(trailSL > sl)
               trade.PositionModify(ticket, trailSL, tp);
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double trailSL = NormalizeDouble(current + trailDist, digits);
            if(sl == 0.0 || trailSL < sl)
               trade.PositionModify(ticket, trailSL, tp);
         }
      }
   }
}


double EffRiskPercent()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 0.4;
   if(InpScalpPreset == PRESET_BALANCED) return 0.8;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 1.2;
   return InpRiskPercent;
}

double EffFixedLotSize()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 0.01;
   if(InpScalpPreset == PRESET_BALANCED) return 0.02;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 0.03;
   return InpFixedLotSize;
}

double EffSLAtrMult()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 0.70;
   if(InpScalpPreset == PRESET_BALANCED) return 0.55;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 0.45;
   return InpSL_ATR_Mult;
}

double EffTPAtrMult()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 1.00;
   if(InpScalpPreset == PRESET_BALANCED) return 0.85;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 0.75;
   return InpTP_ATR_Mult;
}

int EffMaxSpreadPoints()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 35;
   if(InpScalpPreset == PRESET_BALANCED) return 50;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 60;
   return InpMaxSpreadPoints;
}

int EffMaxTradesPerDay()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 120;
   if(InpScalpPreset == PRESET_BALANCED) return 300;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 500;
   return InpMaxTradesPerDay;
}

int EffMinSecondsBetweenEntries()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 8;
   if(InpScalpPreset == PRESET_BALANCED) return 2;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 1;
   return InpMinSecondsBetweenEntries;
}

int EffMaxHoldMinutes()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 20;
   if(InpScalpPreset == PRESET_BALANCED) return 15;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 10;
   return InpMaxHoldMinutes;
}

double EffMaxDailyLossPercent()
{
   if(InpScalpPreset == PRESET_CONSERVATIVE) return 4.0;
   if(InpScalpPreset == PRESET_BALANCED) return 8.0;
   if(InpScalpPreset == PRESET_AGGRESSIVE) return 10.0;
   return InpMaxDailyLossPercent;
}

void OpenBuy(double atrValue)
{
   int digits = GetSymbolDigits();
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);

   double slDistance = atrValue * EffSLAtrMult();
   double tpDistance = atrValue * EffTPAtrMult();

   double sl = NormalizeDouble(ask - slDistance, digits);
   double tp = NormalizeDouble(ask + tpDistance, digits);
   double lots = CalculatePositionSizeLots(slDistance);

   if(lots <= 0.0)
      return;

   if(trade.Buy(lots, InpSymbol, 0.0, sl, tp, "XAU M1 scalp buy"))
   {
      tradesToday++;
      lastEntryTime = TimeCurrent();
   }
}

void OpenSell(double atrValue)
{
   int digits = GetSymbolDigits();
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);

   double slDistance = atrValue * EffSLAtrMult();
   double tpDistance = atrValue * EffTPAtrMult();

   double sl = NormalizeDouble(bid + slDistance, digits);
   double tp = NormalizeDouble(bid - tpDistance, digits);
   double lots = CalculatePositionSizeLots(slDistance);

   if(lots <= 0.0)
      return;

   if(trade.Sell(lots, InpSymbol, 0.0, sl, tp, "XAU M1 scalp sell"))
   {
      tradesToday++;
      lastEntryTime = TimeCurrent();
   }
}
