#!/bin/bash
set -euo pipefail

cd /compiler

# ── 1. Start Xvfb ────────────────────────────────────────────────────────────
echo "[1/6] Starting Xvfb virtual display on :99..."
Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset &
XVFB_PID=$!

READY=0
for i in $(seq 1 20); do
    if xdpyinfo -display :99 >/dev/null 2>&1; then
        echo "      Xvfb ready after ${i}s"
        READY=1
        break
    fi
    sleep 1
done

if [ $READY -eq 0 ]; then
    echo "ERROR: Xvfb never became ready after 20s. Aborting."
    exit 1
fi

# ── 2. Initialize Wine prefix ─────────────────────────────────────────────────
echo "[2/6] Initializing Wine prefix..."

if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "      First run — creating Wine prefix..."
    wineboot
    wineserver --wait

    # Disable crash dialogs and popups that block headless execution
    wine reg add "HKCU\\Software\\Wine\\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f 2>/dev/null || true
    wine reg add "HKCU\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f 2>/dev/null || true
    wineserver --wait

    echo "      Installing Visual C++ runtime and fonts..."
    winetricks -q corefonts vcrun2019
    wineserver --wait
    echo "      Wine prefix ready."
else
    echo "      Prefix exists — skipping init."
    wineboot 2>/dev/null || true
    wineserver --wait 2>/dev/null || true
fi

# ── 3. Wine version confirmation ─────────────────────────────────────────────
echo "[3/6] Wine version: $(wine --version)"
# ── 4. Verify source file and stage into MetaEditor's Scripts folder ──────────
echo "[4/6] Setting up source file..."
SCRIPT_SRC="/compiler/scripts/test_script.mq5"

if [ ! -f "$SCRIPT_SRC" ]; then
    echo "ERROR: Source file not found at $SCRIPT_SRC"
    ls -la /compiler/scripts/ 2>/dev/null || echo "       (directory missing)"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

# Copy into MetaEditor's own Scripts folder — this is where it natively compiles from
# /compiler/MT5 is mapped as C:\MT5 via the /portable flag
cp "$SCRIPT_SRC" /compiler/MT5/MQL5/Scripts/test_script.mq5
echo "      Script staged at: /compiler/MT5/MQL5/Scripts/test_script.mq5"
# ── 5. Run MetaEditor ─────────────────────────────────────────────────────────
echo "[5/6] Running MetaEditor64..."
LOG_PATH="/compiler/MT5/build.log"
rm -f "$LOG_PATH"

# /portable makes MetaEditor treat its own exe directory as the MT5 data folder
# so C:\MT5 = /compiler/MT5 inside the container
timeout 120 wine /compiler/MT5/metaeditor64.exe \
    /compile:"C:\MT5\MQL5\Scripts\test_script.mq5" \
    /log:"C:\MT5\build.log" \
    /portable || true

# ── 6. Parse and report ───────────────────────────────────────────────────────
echo "[6/6] Parsing build log..."

if [ ! -f "$LOG_PATH" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ERROR: build.log was never created by MetaEditor."
    echo ""
    echo "  Possible causes:"
    echo "    1. MetaEditor is hanging on auto-update check"
    echo "    2. MetaEditor can't find metaeditor64.exe dependencies"
    echo "    3. /portable flag not suppressing first-launch dialog"
    echo ""
    echo "  Check the Wine stderr output above this message for clues."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

DECODED_LOG=$(iconv -f UTF-16LE -t UTF-8 "$LOG_PATH" 2>/dev/null \
    || iconv -f UTF-16 -t UTF-8 "$LOG_PATH" 2>/dev/null \
    || cat "$LOG_PATH")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━ COMPILATION LOG ━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$DECODED_LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

kill $XVFB_PID 2>/dev/null || true

if echo "$DECODED_LOG" | grep -qi "0 error"; then
    echo "✅  RESULT: COMPILATION SUCCEEDED"
    exit 0
else
    echo "❌  RESULT: COMPILATION FAILED — see log above"
    exit 1
fi