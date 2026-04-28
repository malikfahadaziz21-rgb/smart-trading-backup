//+------------------------------------------------------------------+
//|                                                strategy_fixed.mq5 |
//|                        Copyright 2026, SmartTrade                |
//+------------------------------------------------------------------+
#property copyright "SmartTrade"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input double         InpLotSize            = 0.10;
input int            InpMAPeriod           = 20;
input int            InpRSIPeriod          = 14;
input ENUM_TIMEFRAMES InpTimeframe         = PERIOD_H1;
input double         InpStopLossPoints     = 500;
input double         InpTakeProfitPoints   = 1000;
input int            InpRSIBuyLevel        = 30;
input int            InpRSISellLevel       = 70;
input ulong          InpMagicNumber        = 12345;
input int            InpDeviationPoints    = 3;
input bool           InpSignalConfirmed    = true;

int maHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   maHandle = iMA(_Symbol, InpTimeframe, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);

   if(maHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
      return(INIT_FAILED);

   trade.SetExpertMagicNumber((int)InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(maHandle != INVALID_HANDLE)
      IndicatorRelease(maHandle);

   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Check if there is already a position for this symbol/magic       |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return(true);
         }
      }
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpSignalConfirmed)
      return;

   if(HasOpenPosition())
      return;

   double maBuffer[3];
   double rsiBuffer[3];
   ArraySetAsSeries(maBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);

   if(CopyBuffer(maHandle, 0, 0, 3, maBuffer) < 1)
      return;

   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) < 1)
      return;

   double currentMA  = maBuffer[0];
   double currentRSI = rsiBuffer[0];
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(ask <= 0.0 || bid <= 0.0)
      return;

   double point = _Point;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double slBuy = NormalizeDouble(ask - InpStopLossPoints * point, digits);
   double tpBuy = NormalizeDouble(ask + InpTakeProfitPoints * point, digits);
   double slSell = NormalizeDouble(bid + InpStopLossPoints * point, digits);
   double tpSell = NormalizeDouble(bid - InpTakeProfitPoints * point, digits);

   if(ask > currentMA && currentRSI < InpRSIBuyLevel)
   {
      trade.Buy(InpLotSize, _Symbol, ask, slBuy, tpBuy, "BuySignal");
   }
   else if(bid < currentMA && currentRSI > InpRSISellLevel)
   {
      trade.Sell(InpLotSize, _Symbol, bid, slSell, tpSell, "SellSignal");
   }
}
//+------------------------------------------------------------------+