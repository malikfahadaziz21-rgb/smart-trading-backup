#property strict
#property version   "1.00"
#property description "Strategy 2396d916 - PRICE_LEVEL EA"
#property description "Buys when price <= entry level and closes when price >= exit level"

#include <Trade/Trade.mqh>

input string          InpSymbol              = "XAUUSD";
input ENUM_TIMEFRAMES InpTimeframe            = PERIOD_H1;
input double          InpLotSize              = 0.01;
input int             InpStopLossPoints       = 10;
input int             InpTakeProfitPoints     = 50;
input int             InpMaxTradesPerDay       = 3;
input double          InpEntryPriceLevel      = 100.0;
input double          InpExitPriceLevel       = 50.0;
input ulong           InpMagicNumber          = 2396;
input bool            InpOnePositionAtATime   = true;

CTrade trade;
datetime g_lastBarTime = 0;
int g_tradesToday = 0;
int g_dayKey = -1;

//+------------------------------------------------------------------+
//| Normalize volume to symbol constraints                           |
//+------------------------------------------------------------------+
double NormalizeVolume(double vol)
{
   double minVol = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);

   if(step <= 0.0)
      step = 0.01;

   vol = MathMax(minVol, MathMin(maxVol, vol));
   vol = MathFloor(vol / step) * step;

   int digits = 2;
   if(step < 0.1) digits = 3;
   if(step < 0.01) digits = 4;
   if(step < 0.001) digits = 5;

   return NormalizeDouble(vol, digits);
}

//+------------------------------------------------------------------+
//| Get current day key                                             |
//+------------------------------------------------------------------+
int GetDayKey(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
}

//+------------------------------------------------------------------+
//| Count today's entries by magic and symbol                        |
//+------------------------------------------------------------------+
int CountTodayTrades()
{
   int count = 0;
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   if(!HistorySelect(dayStart, now))
      return 0;

   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      string sym = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      ulong magic = (ulong)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

      if(sym == InpSymbol && magic == InpMagicNumber && entryType == DEAL_ENTRY_IN)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if there is an open position for this EA                   |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) == InpSymbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close positions for this EA on the symbol                        |
//+------------------------------------------------------------------+
void CloseOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);

      if(sym == InpSymbol && magic == InpMagicNumber)
      {
         trade.PositionClose(sym);
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!SymbolSelect(InpSymbol, true))
   {
      Print("Failed to select symbol: ", InpSymbol);
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(InpSymbol);

   g_dayKey = GetDayKey(TimeCurrent());
   g_tradesToday = CountTodayTrades();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Nothing special to clean up
}

//+------------------------------------------------------------------+
//| Tick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(_Symbol != InpSymbol)
   {
      // EA can run on any chart, but only trades the configured symbol
   }

   int currentDay = GetDayKey(TimeCurrent());
   if(currentDay != g_dayKey)
   {
      g_dayKey = currentDay;
      g_tradesToday = 0;
   }

   // Count trades from history if not yet initialized correctly
   if(g_tradesToday < 0)
      g_tradesToday = CountTodayTrades();

   if(g_tradesToday >= InpMaxTradesPerDay)
      return;

   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   // Entry condition: price <= 100 -> BUY
   bool entrySignal = (ask <= InpEntryPriceLevel);

   // Exit condition: price >= 50 -> CLOSE
   bool exitSignal = (bid >= InpExitPriceLevel);

   if(HasOpenPosition())
   {
      if(exitSignal)
         CloseOpenPositions();
      return;
   }

   if(entrySignal && g_tradesToday < InpMaxTradesPerDay)
   {
      double volume = NormalizeVolume(InpLotSize);
      if(volume <= 0.0)
         return;

      double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);

      double sl = 0.0;
      double tp = 0.0;

      if(InpStopLossPoints > 0)
         sl = NormalizeDouble(ask - InpStopLossPoints * point, digits);
      if(InpTakeProfitPoints > 0)
         tp = NormalizeDouble(ask + InpTakeProfitPoints * point, digits);

      if(trade.Buy(volume, InpSymbol, ask, sl, tp, "PRICE_LEVEL BUY"))
      {
         g_tradesToday++;
      }
      else
      {
         Print("Buy failed. Retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      }
   }
}