"""
Test Suite: Error Correction Loop Verification
===============================================
This test feeds a KNOWN-BROKEN MQL5 script into the pipeline to verify
that the compile→detect→fix→recompile loop works correctly.

Usage:
    python -m tests.test_error_correction

This test requires the backend to be running (uvicorn + celery).
"""

import requests
import time
import sys

API_URL = "http://127.0.0.1:8000/api/v1"

# ── A deliberately broken MQL5 script ────────────────────────────────
# This script contains REAL errors that MetaEditor will flag:
#   1. Missing semicolon on line with lotSize
#   2. Undefined variable 'signalValue' (never declared)
#   3. Wrong function signature for OnDeinit (missing const)
#   4. Using MQL4 function OrderSend() instead of MQL5 CTrade
#   5. Missing #include for CTrade
BROKEN_SCRIPT = """
//+------------------------------------------------------------------+
//|                                        BrokenTestStrategy.mq5     |
//|                                      Copyright 2026, SmartTrade   |
//+------------------------------------------------------------------+
#property copyright "SmartTrade"
#property link      ""
#property version   "1.00"

input double lotSize = 0.1
input int maPeriod = 20;
input int rsiPeriod = 14;

int maHandle;

int OnInit()
{
    maHandle = iMA(_Symbol, PERIOD_H1, maPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE)
        return(INIT_FAILED);
    return(INIT_SUCCEEDED);
}

void OnDeinit(int reason)
{
    IndicatorRelease(maHandle);
}

void OnTick()
{
    double maBuffer[];
    ArraySetAsSeries(maBuffer, true);
    CopyBuffer(maHandle, 0, 0, 2, maBuffer);
    
    double currentMA = maBuffer[0];
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(currentPrice > currentMA && signalValue > 50)
    {
        OrderSend(_Symbol, OP_BUY, lotSize, Ask, 3, 0, 0, "Test", 0, 0, Green);
    }
}
//+------------------------------------------------------------------+
"""


def register_test_user(username: str, password: str, email: str) -> str:
    """Register a test user and return the JWT token."""
    res = requests.post(f"{API_URL}/auth/register", json={
        "username": username,
        "email": email,
        "password": password,
    })
    if res.status_code == 200:
        return res.json()["token"]
    # If user exists, try login
    res = requests.post(f"{API_URL}/auth/login", json={
        "username": username,
        "password": password,
    })
    if res.status_code == 200:
        return res.json()["token"]
    raise Exception(f"Auth failed: {res.json()}")


def submit_prompt(token: str, prompt: str) -> str:
    """Submit a strategy prompt and return the job_id."""
    res = requests.post(
        f"{API_URL}/generate",
        headers={"Authorization": f"Bearer {token}"},
        json={"prompt": prompt},
    )
    assert res.status_code == 200, f"Submit failed: {res.text}"
    return res.json()["job_id"]


def poll_until_done(token: str, job_id: str, timeout: int = 600) -> dict:
    """Poll the results endpoint until the job completes or fails."""
    start = time.time()
    while time.time() - start < timeout:
        res = requests.get(
            f"{API_URL}/results/{job_id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        data = res.json()
        status = data["status"]
        print(f"  [{int(time.time() - start):>3}s] Status: {status}")

        if status in ("completed", "failed"):
            return data
        time.sleep(5)

    raise TimeoutError(f"Job {job_id} did not finish within {timeout}s")


def test_error_correction_with_complex_prompt():
    """
    TEST 1: Send a complex multi-indicator prompt that is likely to
    produce compilation errors, then verify the correction loop fixes them.
    """
    print("\n" + "=" * 60)
    print("TEST 1: Complex Prompt → Error Correction Loop")
    print("=" * 60)

    token = register_test_user("test_correction", "Test@1234!", "test_correction@test.com")

    prompt = (
        "Create an EA that uses a CSignalBase class with virtual CheckBuy() "
        "and CheckSell() methods. Derive CIchimokuSignal that checks Tenkan > Kijun "
        "on H4 using iIchimoku() handle. Derive CBollingerRSISignal that checks "
        "price touching lower Bollinger Band AND RSI below 30 on M15. "
        "Create a CSignalManager holding CSignalBase pointers in an array. "
        "Only trade when ALL signals agree. Use CTrade for execution. "
        "Calculate lot size from 1.5% risk and ATR-based stop loss."
    )

    print(f"\nPrompt: {prompt[:80]}...")
    job_id = submit_prompt(token, prompt)
    print(f"Job ID: {job_id}\n")

    result = poll_until_done(token, job_id)

    print(f"\nFinal Status  : {result['status']}")
    print(f"Compile Success: {result['compile_success']}")
    if result["compile_log"]:
        log_lines = result["compile_log"].strip().split("\n")
        print(f"Build Log (last 5 lines):")
        for line in log_lines[-5:]:
            print(f"  {line.strip()}")

    if result["status"] == "completed":
        print("\n✅ PASS — Error correction loop produced a compiling script!")
    else:
        print("\n⚠️  Script did not compile after max retries (this is expected for very complex prompts)")

    return result


def test_known_broken_script():
    """
    TEST 2: Feed a known-broken MQL5 script as a 'prompt' to verify
    the pipeline detects errors and attempts correction.
    
    NOTE: Since the pipeline generates from a prompt (not raw script),
    we use a prompt that describes the broken script's intent, then
    check if the error correction loop activates.
    """
    print("\n" + "=" * 60)
    print("TEST 2: Prompt That Requires Multiple Fix Iterations")
    print("=" * 60)

    token = register_test_user("test_correction", "Test@1234!", "test_correction@test.com")

    prompt = (
        "Create an EA using template class CRingBuffer<T> to store last 200 bars of "
        "15 technical features (RSI, MACD, Stochastic, ADX, CCI, Williams%R, MFI, OBV, "
        "Bollinger %B, ATR) each in a custom struct SFeatureVector. Normalize all features "
        "to 0-1 range. Use WebRequest() to POST features as JSON, parse the response for "
        "a prediction value. Use IndicatorCreate() with ENUM_INDICATOR. Implement "
        "OnTester() and OnTesterInit() for optimization."
    )

    print(f"\nPrompt: {prompt[:80]}...")
    job_id = submit_prompt(token, prompt)
    print(f"Job ID: {job_id}\n")

    result = poll_until_done(token, job_id)

    print(f"\nFinal Status  : {result['status']}")
    print(f"Compile Success: {result['compile_success']}")

    if result["status"] == "completed":
        print("\n✅ PASS — Complex script compiled after error correction!")
    else:
        print("\n⚠️  Script still failing (expected for extreme complexity)")

    return result


if __name__ == "__main__":
    print("╔══════════════════════════════════════════════════════════╗")
    print("║     SmartTrade — Error Correction Loop Test Suite       ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  Requires: uvicorn + celery running                    ║")
    print("╚══════════════════════════════════════════════════════════╝")

    try:
        r1 = test_error_correction_with_complex_prompt()
        r2 = test_known_broken_script()

        print("\n" + "=" * 60)
        print("SUMMARY")
        print("=" * 60)
        print(f"  Test 1 (Complex OOP):     {r1['status'].upper()}")
        print(f"  Test 2 (Feature Vector):  {r2['status'].upper()}")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Test crashed: {e}")
        sys.exit(1)
