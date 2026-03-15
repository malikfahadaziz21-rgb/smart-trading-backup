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

# ── 4. Verify source file exists ─────────────────────────────────────────────
echo "[4/6] Checking source file..."
SCRIPT_PATH="/compiler/scripts/test_script.mq5"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: Source file not found at $SCRIPT_PATH"
    echo "       Contents of /compiler/scripts/:"
    ls -la /compiler/scripts/ 2>/dev/null || echo "       (directory missing)"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi
echo "      Found: $SCRIPT_PATH"

# ── 5. Run MetaEditor ─────────────────────────────────────────────────────────
echo "[5/6] Running MetaEditor64..."
LOG_PATH="/compiler/build.log"
rm -f "$LOG_PATH"

wine /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\scripts\test_script.mq5" \
    /log:"Z:\compiler\build.log" \
    /portable 2>/dev/null || true

echo "      Waiting for MetaEditor to write log..."
for i in $(seq 1 20); do
    if [ -f "$LOG_PATH" ]; then
        echo "      Log appeared after ${i}s"
        break
    fi
    sleep 1
done
sleep 3

# ── 6. Parse and report ───────────────────────────────────────────────────────
echo "[6/6] Parsing build log..."

if [ ! -f "$LOG_PATH" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ERROR: build.log was never created by MetaEditor."
    echo ""
    echo "  MetaEditor crashed before it could compile anything."
    echo "  Most common causes:"
    echo "    1. metaeditor64.exe path wrong — check /compiler/MT5/"
    echo "    2. Wine prefix init failed in step 2 above"
    echo "    3. Missing vcrun2019 runtime"
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