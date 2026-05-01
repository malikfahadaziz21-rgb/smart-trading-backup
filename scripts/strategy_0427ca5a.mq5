#property strict
#property copyright "Generated EA"
#property link      ""
#property version   "1.00"
#property description "PRICE_LEVEL strategy EA"
#property description "Entry: Buy when price <= level; Exit: Close when price >= level"

#include <Trade/Trade.mqh>

input string InpSymbol              = "XAUUSD";
input ENUM_TIMEFRAMES InpTimeframe   = PERIOD_H1;
input double InpLotSize             = 0.01;
input int    InpStopLossPoints      = 50;
input int    InpTakeProfitPoints    = 150;
input int    InpMaxTradesPerDay     = 3;
input double InpEntryPriceLevel     = 100.0;
input double InpExitPriceLevel      = 150.0;
input ulong  InpMagicNumber         = 4270427;
input int    InpSlippagePoints      = 20;

CTrade trade;

datetime g_lastBarTime = 0;
int g_tradesToday = 0;
int g_dayOfYear = -1;

//+------------------------------------------------------------------+
//| Utility: Normalize volume to symbol settings                     |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);

   if(step <= 0.0)
      step = 0.01;

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / step) * step;

   int digits = 2;
   if(step > 0)
   {
      double s = step;
      digits = 0;
      while(digits < 8 && MathRound(s) != s)
      {
         s *= 10.0;
         digits++;
      }
   }
   return NormalizeDouble(lots, digits);
}

//+------------------------------------------------------------------+
//| Utility: Check if new bar on selected timeframe                  |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime barTime = iTime(InpSymbol, InpTimeframe, 0);
   if(barTime == 0)
      return false;

   if(barTime != g_lastBarTime)
   {
      g_lastBarTime = barTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Utility: Reset daily trade counter                               |
//+------------------------------------------------------------------+
void UpdateDailyCounter()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   if(g_dayOfYear != tm.day_of_year)
   {
      g_dayOfYear = tm.day_of_year;
      g_tradesToday = 0;
   }
}

//+------------------------------------------------------------------+
//| Utility: Count trades opened today by this EA                    |
//+------------------------------------------------------------------+
int CountTodayTrades()
{
   int count = 0;
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(dayStart <= 0)
      dayStart = (datetime)(TimeCurrent() - (TimeCurrent() % 86400));

   HistorySelect(dayStart, TimeCurrent());

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      string sym = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

      if(sym == InpSymbol && (ulong)magic == InpMagicNumber && entry == DEAL_ENTRY_IN)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Utility: Find if there is an open position for this EA           |
//+------------------------------------------------------------------+
bool GetOurPosition(ulong &ticket)
{
   ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong posTicket = PositionGetTicket(i);
      if(posTicket == 0)
         continue;

      if(PositionSelectByTicket(posTicket))
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         long magic = PositionGetInteger(POSITION_MAGIC);

         if(sym == InpSymbol && (ulong)magic == InpMagicNumber)
         {
            ticket = posTicket;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Utility: Close position by ticket                                |
//+------------------------------------------------------------------+
bool ClosePositionByTicket(ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   string sym = PositionGetString(POSITION_SYMBOL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   long type = PositionGetInteger(POSITION_TYPE);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   if(type == POSITION_TYPE_BUY)
      return trade.PositionClose(sym, volume);
   else if(type == POSITION_TYPE_SELL)
      return trade.PositionClose(sym, volume);

   return false;
}

//+------------------------------------------------------------------+
//| Utility: Open buy position                                       |
//+------------------------------------------------------------------+
bool OpenBuy()
{
   double lots = NormalizeLots(InpLotSize);
   if(lots <= 0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(InpSymbol, tick))
      return false;

   double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);

   double ask = tick.ask;
   double sl = ask - InpStopLossPoints * point;
   double tp = ask + InpTakeProfitPoints * point;

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   return trade.Buy(lots, InpSymbol, ask, sl, tp, "PRICE_LEVEL BUY");
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!SymbolSelect(InpSymbol, true))
      return INIT_FAILED;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   UpdateDailyCounter();
   g_tradesToday = CountTodayTrades();
   g_lastBarTime = iTime(InpSymbol, InpTimeframe, 0);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // No special cleanup required
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(_Symbol != InpSymbol)
      return;

   UpdateDailyCounter();

   MqlTick tick;
   if(!SymbolInfoTick(InpSymbol, tick))
      return;

   double bid = tick.bid;
   double ask = tick.ask;

   ulong posTicket = 0;
   bool hasPosition = GetOurPosition(posTicket);

   // Exit logic: close BUY if price >= exit level
   if(hasPosition)
   {
      if(PositionSelectByTicket(posTicket))
      {
         long posType = PositionGetInteger(POSITION_TYPE);
         if(posType == POSITION_TYPE_BUY && bid >= InpExitPriceLevel)
         {
            ClosePositionByTicket(posTicket);
         }
      }
      return;
   }

   // Entry logic only on new bar and respecting daily trade limit
   if(!IsNewBar())
      return;

   if(g_tradesToday >= InpMaxTradesPerDay)
      return;

   // Entry condition: BUY when price <= entry level
   if(bid <= InpEntryPriceLevel)
   {
      if(OpenBuy())
      {
         g_tradesToday++;
      }
   }
}