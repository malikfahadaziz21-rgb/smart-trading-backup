#property strict
#property version   "1.00"
#property description "Strategy EA: PRICE_LEVEL for XAUUSD on H1"
#property description "Generated script: strategy_a45ce40d"

#include <Trade/Trade.mqh>

input string         InpTradeSymbol              = "XAUUSD";
input ENUM_TIMEFRAMES InpTradeTimeframe           = PERIOD_H1;

input double         InpLotSize                  = 0.01;
input int            InpStopLossPoints           = 50;
input int            InpTakeProfitPoints         = 150;
input int            InpTrailingStopPoints       = 100;
input int            InpSlippagePoints           = 30;

input int            InpEntryPriceLevel          = 100;
input int            InpExitPriceLevel           = 150;

input int            InpMaxTradesPerDay          = 3;
input double         InpMaxDrawdownPercent       = 5.0;
input int            InpMaxConsecutiveLosses     = 3;

input ulong          InpMagicNumber              = 45004045;

CTrade trade;

datetime g_lastBarTime = 0;
int      g_tradesToday = 0;
int      g_consecutiveLosses = 0;
double   g_peakEquity = 0.0;
int      g_dayOfYear = -1;

//--- utility: normalize volume to symbol limits
double NormalizeVolume(const string symbol, double lots)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   if(step > 0.0)
      lots = MathFloor(lots / step) * step;

   int volDigits = 2;
   if(step > 0.0)
      volDigits = (int)MathRound(-MathLog10(step));
   if(volDigits < 0) volDigits = 2;

   return NormalizeDouble(lots, volDigits);
}

//--- utility: get today's day-of-year
int CurrentDayOfYear()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day_of_year;
}

//--- utility: reset daily counters if new day
void ResetDailyCountersIfNeeded()
{
   int doy = CurrentDayOfYear();
   if(doy != g_dayOfYear)
   {
      g_dayOfYear = doy;
      g_tradesToday = 0;
   }
}

//--- utility: count current positions on symbol
int CountPositionsBySymbol(const string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionSelectByTicket(ticket))
      {
         string psym = PositionGetString(POSITION_SYMBOL);
         if(psym == symbol)
            count++;
      }
   }
   return count;
}

//--- utility: close all positions for symbol
void CloseAllPositionsBySymbol(const string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionSelectByTicket(ticket))
      {
         string psym = PositionGetString(POSITION_SYMBOL);
         if(psym != symbol)
            continue;

         trade.PositionClose(ticket);
      }
   }
}

//--- utility: check drawdown protection
bool DrawdownProtectionTriggered()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_peakEquity <= 0.0)
      g_peakEquity = equity;

   if(equity > g_peakEquity)
      g_peakEquity = equity;

   if(g_peakEquity <= 0.0)
      return false;

   double ddPercent = 100.0 * (g_peakEquity - equity) / g_peakEquity;
   return (ddPercent >= InpMaxDrawdownPercent);
}

//--- utility: get H1 bar open time
datetime GetCurrentBarTime(const string symbol, ENUM_TIMEFRAMES tf)
{
   return iTime(symbol, tf, 0);
}

//--- trailing stop management
void ManageTrailingStops(const string symbol)
{
   if(InpTrailingStopPoints <= 0)
      return;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      string psym = PositionGetString(POSITION_SYMBOL);
      if(psym != symbol)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      if(type == POSITION_TYPE_BUY)
      {
         double newSL = bid - InpTrailingStopPoints * point;
         if(newSL > openPrice && (sl == 0.0 || newSL > sl + point))
         {
            newSL = NormalizeDouble(newSL, digits);
            trade.PositionModify(ticket, newSL, tp);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double newSL = ask + InpTrailingStopPoints * point;
         if(newSL < openPrice && (sl == 0.0 || newSL < sl - point))
         {
            newSL = NormalizeDouble(newSL, digits);
            trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//--- detect exit condition and close
void CheckExitCondition(const string symbol)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   bool exitSignal = false;
   if(bid >= InpExitPriceLevel || ask >= InpExitPriceLevel)
      exitSignal = true;

   if(exitSignal)
      CloseAllPositionsBySymbol(symbol);
}

//--- entry logic
void CheckEntryCondition(const string symbol)
{
   if(g_tradesToday >= InpMaxTradesPerDay)
      return;

   if(g_consecutiveLosses >= InpMaxConsecutiveLosses)
      return;

   if(CountPositionsBySymbol(symbol) > 0)
      return;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price = bid;

   if(price <= InpEntryPriceLevel)
   {
      double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double lots   = NormalizeVolume(symbol, InpLotSize);

      if(lots <= 0.0)
         return;

      double sl = 0.0;
      double tp = 0.0;

      if(InpStopLossPoints > 0)
         sl = NormalizeDouble(ask - InpStopLossPoints * point, digits);
      if(InpTakeProfitPoints > 0)
         tp = NormalizeDouble(ask + InpTakeProfitPoints * point, digits);

      trade.SetDeviationInPoints(InpSlippagePoints);
      trade.SetExpertMagicNumber(InpMagicNumber);

      if(trade.Buy(lots, symbol, ask, sl, tp, "PRICE_LEVEL BUY"))
      {
         g_tradesToday++;
      }
   }
}

//--- update consecutive losses from history on deinit/init and periodically
void UpdateConsecutiveLosses()
{
   g_consecutiveLosses = 0;

   datetime fromTime = TimeCurrent() - 86400 * 30;
   datetime toTime = TimeCurrent();
   if(!HistorySelect(fromTime, toTime))
      return;

   int totalDeals = HistoryDealsTotal();
   for(int i = totalDeals - 1; i >= 0; --i)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      string sym = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);

      if(sym != InpTradeSymbol || magic != (long)InpMagicNumber)
         continue;

      if(entryType == DEAL_ENTRY_OUT)
      {
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                       + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                       + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

         if(profit < 0.0)
            g_consecutiveLosses++;
         else
            break;

         if(g_consecutiveLosses >= InpMaxConsecutiveLosses)
            break;
      }
   }
}

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayOfYear = CurrentDayOfYear();
   g_tradesToday = 0;
   UpdateConsecutiveLosses();

   if(!SymbolSelect(InpTradeSymbol, true))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   string symbol = InpTradeSymbol;
   if(_Symbol != symbol)
   {
      if(!SymbolSelect(symbol, true))
         return;
   }

   ResetDailyCountersIfNeeded();

   if(DrawdownProtectionTriggered())
   {
      CloseAllPositionsBySymbol(symbol);
      return;
   }

   ManageTrailingStops(symbol);

   CheckExitCondition(symbol);

   datetime currentBar = GetCurrentBarTime(symbol, InpTradeTimeframe);
   if(currentBar == 0)
      return;

   if(currentBar == g_lastBarTime)
      return;

   g_lastBarTime = currentBar;

   CheckEntryCondition(symbol);
}