//+------------------------------------------------------------------+
//|                                                   TestScript.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//--- input parameters
input string   Greeting = "Hello from MetaEditor!";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Print a message to the "Experts" tab in the Toolbox
   Print("System message: ", Greeting);
   
   // Display a pop-up alert on the terminal
   Alert("Script executed successfully on ", _Symbol);
   
   // Get current account information
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("Current Account Balance: ", balance);
}
//+------------------------------------------------------------------+
