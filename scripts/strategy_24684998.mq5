//+------------------------------------------------------------------+
//|                                         ErrorCorrectionTest.mq5   |
//|                                      Copyright 2026, SmartTrade  |
//+------------------------------------------------------------------+
#property copyright "SmartTrade"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input double         LotSize           = 0.10;
input int            MAPeriod          = 50;
input int            RSIPeriod         = 14;
input ENUM_TIMEFRAMES SignalTimeframe   = PERIOD_H1;
input double         StopLossPoints     = 50;
input double         TakeProfitPoints   = 100;
input ulong          MagicNumber        = 12345;
input bool           RequireConfirm     = true;

int maHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
CTrade trade;

int OnInit()
{
   maHandle = iMA(_Symbol, SignalTimeframe, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, SignalTimeframe, RSIPeriod, PRICE_CLOSE);

   if(maHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
      return(INIT_FAILED);

   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(maHandle != INVALID_HANDLE)
      IndicatorRelease(maHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
}

void OnTick()
{
   if(Bars(_Symbol, SignalTimeframe) < MathMax(MAPeriod, RSIPeriod) + 5)
      return;

   double maBuffer[3];
   double rsiBuffer[3];
   ArraySetAsSeries(maBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);

   if(CopyBuffer(maHandle, 0, 0, 3, maBuffer) <= 0)
      return;
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) <= 0)
      return;

   double currentMA  = maBuffer[0];
   double currentRSI = rsiBuffer[0];
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point      = _Point;
   int digits        = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   bool signalConfirmed = true;
   if(RequireConfirm)
      signalConfirmed = (maBuffer[0] != maBuffer[1] || rsiBuffer[0] != rsiBuffer[1]);

   if(!signalConfirmed)
      return;

   bool haveBuyPosition = false;
   bool haveSellPosition = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
         {
            long type = PositionGetInteger(POSITION_TYPE);
            if(type == POSITION_TYPE_BUY)
               haveBuyPosition = true;
            else if(type == POSITION_TYPE_SELL)
               haveSellPosition = true;
         }
      }
   }

   if(ask > currentMA && currentRSI < 30.0 && !haveBuyPosition)
   {
      double sl = NormalizeDouble(ask - StopLossPoints * point, digits);
      double tp = NormalizeDouble(ask + TakeProfitPoints * point, digits);
      trade.Buy(LotSize, _Symbol, ask, sl, tp, "BuySignal");
   }

   if(bid < currentMA && currentRSI > 70.0 && !haveSellPosition)
   {
      double sl = NormalizeDouble(bid + StopLossPoints * point, digits);
      double tp = NormalizeDouble(bid - TakeProfitPoints * point, digits);
      trade.Sell(LotSize, _Symbol, bid, sl, tp, "SellSignal");
   }
}
//+------------------------------------------------------------------+