//+------------------------------------------------------------------+
//|                                   ErrorCorrectionTest.mq5        |
//|                                      Copyright 2026, SmartTrade  |
//+------------------------------------------------------------------+
#property copyright "SmartTrade"
#property link      ""
#property version   "1.00"
#property strict


int OnInit()
{
   maHandle = iMA(_Symbol, PERIOD_H1, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_H1, RSIPeriod, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
      return(INIT_FAILED);
   return(INIT_SUCCEEDED);
}

void OnDeinit(int reason)
{
   IndicatorRelease(maHandle);
   IndicatorRelease(rsiHandle);
}

void OnTick()
{
   double maBuffer[];
   double rsiBuffer[];
   ArraySetAsSeries(maBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   CopyBuffer(maHandle, 0, 0, 3, maBuffer);
   CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer);

   double currentMA  = maBuffer[0];
   double currentRSI = rsiBuffer[0];
   double Ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(Ask > currentMA && currentRSI < 30 && signalConfirmed == true)
   {
      OrderSend(_Symbol, OP_BUY, LotSize, Ask, 3, Ask - 50*Point, Ask + 100*Point, "BuySignal", 12345, 0, Green);
   }
   
   if(Bid < currentMA && currentRSI > 70)
   {
      OrderSend(_Symbol, OP_SELL, LotSize, Bid, 3, Bid + 50*Point, Bid - 100*Point, "SellSignal", 12345, 0, Red);
   }
}
//+------------------------------------------------------------------+