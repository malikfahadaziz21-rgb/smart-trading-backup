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

# ── 3. Wine version confirmation ─────────────────────────────────────────────
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

# Ensure terminal.ini exists to suppress broker login and auto-update
if [ -f "/compiler/MT5/config/terminal.ini" ]; then
    echo "      terminal.ini found."
else
    echo "      Creating terminal.ini..."
    cat > /compiler/MT5/config/terminal.ini << 'EOF'
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
EOF
fi

# Ensure metaeditor.ini exists
if [ -f "/compiler/MT5/metaeditor.ini" ]; then
    echo "      metaeditor.ini found."
else
    echo "      Creating metaeditor.ini..."
    cat > /compiler/MT5/metaeditor.ini << 'EOF'
[Common]
NewsEnable=0
AutoUpdate=0
CommunityLogin=
CommunityPassword=
[StartUp]
AutoUpdate=0
EOF
fi

echo "      MT5 directory contents:"
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
echo "      Script staged at: /compiler/MT5/MQL5/Scripts/test_script.mq5"

# ── 6. Start terminal64 and wait for it to be ready ──────────────────────────
echo "[6/7] Starting terminal64.exe..."

TERMINAL_LOG="/compiler/MT5/logs/terminal.log"
rm -f "$TERMINAL_LOG"

# Start terminal in background — /portable means use exe dir as data root
wine /compiler/MT5/terminal64.exe /portable > /compiler/MT5/terminal_wine.log 2>&1 &
TERMINAL_PID=$!

echo "      Waiting for terminal64 to initialize..."
TERMINAL_READY=0
for i in $(seq 1 60); do
    # Terminal writes terminal.log when it starts up
    if [ -f "$TERMINAL_LOG" ]; then
        echo "      Terminal log appeared after ${i}s — terminal is initializing"
        TERMINAL_READY=1
        break
    fi
    # Also check if terminal process died early
    if ! kill -0 $TERMINAL_PID 2>/dev/null; then
        echo "      WARNING: terminal64 process died after ${i}s"
        echo "      Terminal Wine log:"
        cat /compiler/MT5/terminal_wine.log 2>/dev/null || true
        break
    fi
    sleep 1
done

# Give terminal extra time to fully initialize after log appears
echo "      Giving terminal extra 15s to fully initialize..."
sleep 15

echo "      Terminal status:"
if kill -0 $TERMINAL_PID 2>/dev/null; then
    echo "      terminal64 is running (PID: $TERMINAL_PID)"
else
    echo "      WARNING: terminal64 is not running"
    echo "      Terminal Wine log tail:"
    tail -20 /compiler/MT5/terminal_wine.log 2>/dev/null || true
fi

# Show terminal log if it exists
if [ -f "$TERMINAL_LOG" ]; then
    echo "      Terminal log contents:"
    cat "$TERMINAL_LOG" 2>/dev/null || true
fi

# ── 7. Run MetaEditor ─────────────────────────────────────────────────────────
echo "[7/7] Running MetaEditor64..."

LOG_PATH="/compiler/MT5/MQL5/Logs/build.log"
rm -f "$LOG_PATH"

touch /tmp/before_compile

# Run MetaEditor — terminal64 is running so it can accept compile jobs
timeout 120 wine /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\MT5\MQL5\Scripts\test_script.mq5" \
    /log:"Z:\compiler\MT5\MQL5\Logs\build.log" \
    /portable > /compiler/MT5/metaeditor_wine.log 2>&1 || true

EXIT_CODE=$?
echo "      MetaEditor exit code: $EXIT_CODE"

# Show MetaEditor Wine log
echo "      MetaEditor Wine log:"
cat /compiler/MT5/metaeditor_wine.log 2>/dev/null || echo "      (empty)"

# Find any new files created during compilation
echo "      New files created during compilation:"
find /compiler/MT5 -newer /tmp/before_compile -type f 2>/dev/null \
    | grep -v "metaeditor_wine.log" \
    || echo "      None found"

# Poll for build log
echo "      Waiting for build log..."
for i in $(seq 1 20); do
    if [ -f "$LOG_PATH" ]; then
        echo "      Build log appeared after ${i}s"
        break
    fi
    sleep 1
done
sleep 3

# Kill terminal now that compilation is done
echo "      Shutting down terminal64..."
kill $TERMINAL_PID 2>/dev/null || true
wineserver -k 2>/dev/null || true

# Copy logs to output volume for artifact upload
cp /compiler/MT5/metaeditor_wine.log /output/metaeditor_wine.log 2>/dev/null || true
cp /compiler/MT5/terminal_wine.log /output/terminal_wine.log 2>/dev/null || true
cp "$LOG_PATH" /output/build.log 2>/dev/null || true

# ── Parse and report ──────────────────────────────────────────────────────────
echo "[Done] Parsing build log..."

if [ ! -f "$LOG_PATH" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━