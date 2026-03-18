#!/bin/bash
set -eo pipefail

cd /compiler

# ── 1. Start Xvfb ────────────────────────────────────────────────────────────
echo "[1/7] Starting Xvfb virtual display on :99..."
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

# ── 2. Start Wine server ──────────────────────────────────────────────────────
echo "[2/7] Starting Wine server..."
wineboot 2>/dev/null || true
wineserver --wait 2>/dev/null || true
echo "      Wine server ready."

# ── 3. Wine version ───────────────────────────────────────────────────────────
echo "[3/7] Wine version: $(wine --version)"

# ── 4. Setup folder structure ─────────────────────────────────────────────────
echo "[4/7] Setting up folder structure..."

mkdir -p /compiler/MT5/MQL5/Scripts
mkdir -p /compiler/MT5/MQL5/Experts
mkdir -p /compiler/MT5/MQL5/Indicators
mkdir -p /compiler/MT5/MQL5/Libraries
mkdir -p /compiler/MT5/MQL5/Include
mkdir -p /compiler/MT5/MQL5/Files
mkdir -p /compiler/MT5/MQL5/Logs
mkdir -p /compiler/MT5/MQL5/Images
mkdir -p /compiler/MT5/MQL5/Services
mkdir -p /compiler/MT5/logs
mkdir -p /compiler/MT5/config
mkdir -p /compiler/MT5/Bases
mkdir -p /compiler/MT5/temp
mkdir -p /compiler/MT5/Tester

# Write terminal.ini in BOTH locations terminal might look
# 1. config subfolder (standard MT5 data dir location)
# 2. directly next to exe (some /portable builds look here)
cat > /compiler/MT5/config/terminal.ini << 'INIEOF'
[Common]
Login=0
Server=
NewsEnable=0
AutoUpdate=0
CommunityLogin=
CommunityPassword=
[StartUp]
AutoUpdate=0
ExpertEnable=0
INIEOF

cp /compiler/MT5/config/terminal.ini /compiler/MT5/terminal.ini
echo "      terminal.ini written to both locations."

# Write metaeditor.ini
cat > /compiler/MT5/metaeditor.ini << 'INIEOF'
[Common]
NewsEnable=0
AutoUpdate=0
CommunityLogin=
CommunityPassword=
[StartUp]
AutoUpdate=0
INIEOF
echo "      metaeditor.ini written."

echo "      MT5 directory:"
ls -lh /compiler/MT5/

# ── 5. Stage script ───────────────────────────────────────────────────────────
echo "[5/7] Staging source file..."
SCRIPT_SRC="/compiler/scripts/test_script.mq5"

if [ ! -f "$SCRIPT_SRC" ]; then
    echo "ERROR: Source file not found at $SCRIPT_SRC"
    ls -la /compiler/scripts/ 2>/dev/null || echo "       (directory missing)"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

cp "$SCRIPT_SRC" /compiler/MT5/MQL5/Scripts/test_script.mq5
echo "      Script staged."

# ── 6. Start terminal64 and wait until ready ──────────────────────────────────
echo "[6/7] Starting terminal64.exe..."

TERMINAL_LOG="/compiler/MT5/logs/terminal.log"
rm -f "$TERMINAL_LOG"

wine /compiler/MT5/terminal64.exe /portable > /compiler/MT5/terminal_wine.log 2>&1 &
TERMINAL_PID=$!
echo "      terminal64 started with PID: $TERMINAL_PID"

# Wait for terminal.log to appear — this means terminal has started loading
echo "      Waiting for terminal.log to appear (up to 60s)..."
for i in $(seq 1 60); do
    if [ -f "$TERMINAL_LOG" ]; then
        echo "      terminal.log appeared after ${i}s"
        break
    fi
    if ! kill -0 $TERMINAL_PID 2>/dev/null; then
        echo "      ERROR: terminal64 died after ${i}s"
        echo "      Terminal Wine log:"
        cat /compiler/MT5/terminal_wine.log 2>/dev/null || true
        kill $XVFB_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Show terminal log content so we know what state it is in
echo "      terminal.log content:"
cat "$TERMINAL_LOG" 2>/dev/null || echo "      (empty)"

# Give terminal extra time to fully load MQL5 engine
# 30 seconds is safer than 15 — terminal needs to load all modules
echo "      Waiting 30s for terminal MQL5 engine to fully load..."
sleep 30

# Confirm terminal is still running
if kill -0 $TERMINAL_PID 2>/dev/null; then
    echo "      terminal64 still running after wait — good."
else
    echo "      WARNING: terminal64 exited during wait."
    echo "      Terminal Wine log tail:"
    tail -30 /compiler/MT5/terminal_wine.log 2>/dev/null || true
fi

# Show updated terminal log
echo "      terminal.log after wait:"
cat "$TERMINAL_LOG" 2>/dev/null || echo "      (empty)"

# ── 7. Run MetaEditor ─────────────────────────────────────────────────────────
echo "[7/7] Running MetaEditor64..."

LOG_PATH="/compiler/MT5/MQL5/Logs/build.log"
rm -f "$LOG_PATH"

touch /tmp/before_compile

timeout 120 wine /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\MT5\MQL5\Scripts\test_script.mq5" \
    /log:"Z:\compiler\MT5\MQL5\Logs\build.log" \
    /portable > /compiler/MT5/metaeditor_wine.log 2>&1 || true

EXIT_CODE=$?
echo "      MetaEditor exit code: $EXIT_CODE"

echo "      MetaEditor Wine log:"
cat /compiler/MT5/metaeditor_wine.log 2>/dev/null || echo "      (empty)"

echo "      New files after MetaEditor ran:"
find /compiler/MT5 -newer /tmp/before_compile -type f 2>/dev/null \
    | grep -v "metaeditor_wine.log" \
    || echo "      None found"

# Poll for build log
echo "      Polling for build log (up to 20s)..."
for i in $(seq 1 20); do
    if [ -f "$LOG_PATH" ]; then
        echo "      Build log appeared after ${i}s"
        break
    fi
    sleep 1
done
sleep 3

# Shutdown
echo "      Shutting down terminal64..."
kill $TERMINAL_PID 2>/dev/null || true
wineserver -k 2>/dev/null || true

# Copy all logs to output volume
cp /compiler/MT5/metaeditor_wine.log /output/metaeditor_wine.log 2>/dev/null || true
cp /compiler/MT5/terminal_wine.log /output/terminal_wine.log 2>/dev/null || true
cp "$TERMINAL_LOG" /output/terminal.log 2>/dev/null || true
cp "$LOG_PATH" /output/build.log 2>/dev/null || true

# ── Parse and report ──────────────────────────────────────────────────────────
echo "[Done] Parsing build log..."

if [ ! -f "$LOG_PATH" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ERROR: build.log was never created by MetaEditor."
    echo "  Check metaeditor_wine.log and terminal_wine.log above."
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
    echo "SUCCESS: COMPILATION SUCCEEDED"
    exit 0
else
    echo "FAILED: COMPILATION FAILED - see log above"
    exit 1
fi