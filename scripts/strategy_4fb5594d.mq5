#property strict
#property version   "1.00"
#property description "Price level strategy EA for XAUUSD on H1"

#include <Trade/Trade.mqh>

input string InpSymbol                = "XAUUSD";
input ENUM_TIMEFRAMES InpTimeframe     = PERIOD_H1;
input double InpLotSize               = 0.06;
input int    InpStopLossPoints        = 50;
input int    InpTakeProfitPoints      = 600;
input int    InpMaxTradesPerDay       = 2;
input double InpEntryPriceLevel       = 100.0;
input double InpExitPriceLevel        = 50.0;
input int    InpDeviationPoints       = 20;
input ulong  InpMagicNumber           = 4555944;

CTrade trade;
datetime lastBarTime = 0;

// Track daily trade count
int tradesToday = 0;
int lastDayOfYear = -1;

//+------------------------------------------------------------------+
//| Normalize volume to symbol constraints                           |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minLot  = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);

   if(volume < minLot) volume = minLot;
   if(volume > maxLot) volume = maxLot;

   if(stepLot > 0)
      volume = MathFloor(volume / stepLot) * stepLot;

   return NormalizeDouble(volume, 2);
}

//+------------------------------------------------------------------+
//| Count open positions for symbol and magic                         |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionSelectByTicket(ticket))
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
         if(sym == InpSymbol && magic == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Close all positions for symbol and magic                          |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionSelectByTicket(ticket))
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
         if(sym == InpSymbol && magic == InpMagicNumber)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Reset daily trade counter                                         |
//+------------------------------------------------------------------+
void UpdateDailyCounter()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.day_of_year != lastDayOfYear)
   {
      lastDayOfYear = dt.day_of_year;
      tradesToday = 0;
   }
}

//+------------------------------------------------------------------+
//| Check if a new bar formed on the chosen timeframe                 |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(InpSymbol, InpTimeframe, 0);
   if(currentBarTime == 0)
      return false;

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get current bid/ask price                                         |
//+------------------------------------------------------------------+
double GetCurrentPrice()
{
   double bid = 0.0;
   if(!SymbolInfoDouble(InpSymbol, SYMBOL_BID, bid))
      return 0.0;
   return bid;
}

//+------------------------------------------------------------------+
//| Check entry condition                                              |
//+------------------------------------------------------------------+
bool CheckEntryCondition()
{
   double price = GetCurrentPrice();
   if(price <= 0.0)
      return false;

   // Strategy: Buy when PRICE <= 100
   return (price <= InpEntryPriceLevel);
}

//+------------------------------------------------------------------+
//| Check exit condition                                               |
//+------------------------------------------------------------------+
bool CheckExitCondition()
{
   double price = GetCurrentPrice();
   if(price <= 0.0)
      return false;

   // Strategy: Close when PRICE >= 50
   return (price >= InpExitPriceLevel);
}

//+------------------------------------------------------------------+
//| Open buy position                                                  |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = 0.0;
   if(!SymbolInfoDouble(InpSymbol, SYMBOL_ASK, ask))
      return;

   double volume = NormalizeVolume(InpLotSize);
   if(volume <= 0.0)
      return;

   double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);

   double sl = ask - (InpStopLossPoints * point);
   double tp = ask + (InpTakeProfitPoints * point);

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);

   if(trade.Buy(volume, InpSymbol, ask, sl, tp, "Price level buy"))
   {
      tradesToday++;
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!SymbolSelect(InpSymbol, true))
      return INIT_FAILED;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);

   lastBarTime = iTime(InpSymbol, InpTimeframe, 0);
   UpdateDailyCounter();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(_Symbol != InpSymbol)
      return;

   UpdateDailyCounter();

   // Only process once per new bar on H1
   if(!IsNewBar())
      return;

   // Exit logic: close existing buy positions when price >= exit level
   if(CountOpenPositions() > 0)
   {
      if(CheckExitCondition())
         CloseAllPositions();
      return;
   }

   // Entry logic: buy when price <= entry level and daily trade limit not reached
   if(tradesToday < InpMaxTradesPerDay && CheckEntryCondition())
   {
      OpenBuy();
   }
}