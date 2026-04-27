from openai import AzureOpenAI
from backend.config import settings

# Azure OpenAI configuration
client = AzureOpenAI(
    api_key=settings.AZURE_OPENAI_API_KEY,
    api_version="2024-12-01-preview",
    azure_endpoint="https://searchify.openai.azure.com/",
)

DEPLOYMENT = "gpt-5.4-mini"

SYSTEM_PROMPT = """
You are an expert MQL5 programmer for MetaTrader 5.
When given a trading strategy description, generate a complete, 
compilable MQL5 Expert Advisor script.

Rules:
- Always include proper #property directives at the top
- Always implement OnInit(), OnDeinit(), OnTick() functions
- Use proper MQL5 syntax — not MQL4
- Include input parameters for key strategy values
- Add basic risk management (stop loss, take profit)
- Add comments explaining the logic
- Return ONLY the raw MQL5 code, no markdown, no explanation

The script must compile with 0 errors in MetaEditor.
"""

MOCK_SCRIPT_1 = """
//+------------------------------------------------------------------+
//|                                                   Strategy 1     |
//|                                      Copyright 2026, SmartTrade  |
//+------------------------------------------------------------------+
#property copyright "SmartTrade"
#property link      ""
#property version   "1.00"

int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason) { }
void OnTick() { 
   // Basic Moving Average mock logic
}
//+------------------------------------------------------------------+
"""

MOCK_SCRIPT_2 = """
//+------------------------------------------------------------------+
//|                                                   Strategy 2     |
//|                                      Copyright 2026, SmartTrade  |
//+------------------------------------------------------------------+
#property copyright "SmartTrade"
#property link      ""
#property version   "1.00"

int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason) { }
void OnTick() { 
   // RSI Oversold mock logic
}
//+------------------------------------------------------------------+
"""

MOCK_SCRIPT_3 = """
//+------------------------------------------------------------------+
//|                                                   Strategy 3     |
//|                                      Copyright 2026, SmartTrade  |
//+------------------------------------------------------------------+
#property copyright "SmartTrade"
#property link      ""
#property version   "1.00"

int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason) { }
void OnTick() { 
   // MACD Crossover mock logic
}
//+------------------------------------------------------------------+
"""

# ── Known-broken script for error correction loop testing ─────────────
# Contains 5 deliberate MQL4/MQL5 mix-ups that MetaEditor will reject.
# Trigger: type "broken" in the frontend prompt field.
# The error correction loop will detect failures and ask the LLM to fix them.
BROKEN_TEST_SCRIPT = """
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
"""


def clean_script_content(raw: str) -> str:
    """Strip markdown code fences if the LLM wraps the output."""
    content = raw.strip()
    if content.startswith("```"):
        lines = content.split("\n")
        content = "\n".join(lines[1:])
        if content.endswith("```"):
            content = content[:-3]
        if content.startswith("mql5\n"):
            content = content[5:]
    return content.strip()


async def generate_mql5_script(user_prompt: str, job_id: str) -> tuple[str, str]:
    script_name = f"strategy_{str(job_id)[:8]}"

    clean_prompt = user_prompt.strip()

    # Mock scripts for quick testing (type "1", "2", or "3")
    if clean_prompt == "1":
        return MOCK_SCRIPT_1.strip(), f"{script_name}.mq5"
    elif clean_prompt == "2":
        return MOCK_SCRIPT_2.strip(), f"{script_name}.mq5"
    elif clean_prompt == "3":
        return MOCK_SCRIPT_3.strip(), f"{script_name}.mq5"
    elif clean_prompt == "broken":
        # Sends a known-broken script to demonstrate the error correction loop.
        # The loop will detect compile failures and ask the LLM to fix them.
        return BROKEN_TEST_SCRIPT.strip(), f"{script_name}.mq5"

    # Real LLM generation via Azure OpenAI
    response = client.chat.completions.create(
        model=DEPLOYMENT,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Generate a complete MQL5 Expert Advisor for this strategy:\n{user_prompt}\n\nScript name should be: {script_name}"}
        ],
        max_completion_tokens=16384,
    )

    script_content = clean_script_content(response.choices[0].message.content)
    return script_content, f"{script_name}.mq5"


async def fix_mql5_script(
    user_prompt: str,
    failed_script: str,
    compile_errors: str,
    attempt: int,
) -> str:
    """
    Send the failed script and its compilation errors back to the LLM
    so it can produce a corrected version.
    """
    fix_prompt = f"""The following MQL5 Expert Advisor script failed to compile in MetaEditor.
This is attempt #{attempt} to fix it.

── ORIGINAL USER REQUEST ──
{user_prompt}

── FAILED SCRIPT ──
{failed_script}

── COMPILATION ERRORS ──
{compile_errors}

── YOUR TASK ──
Carefully analyze the compilation errors above.
Fix EVERY error in the script and return the COMPLETE corrected MQL5 code.
Do NOT omit any part of the script — return the full file.
Return ONLY the raw MQL5 code, no markdown, no explanation."""

    response = client.chat.completions.create(
        model=DEPLOYMENT,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": fix_prompt},
        ],
        max_completion_tokens=16384,
    )

    return clean_script_content(response.choices[0].message.content)

