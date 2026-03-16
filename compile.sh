#!/bin/bash
# Temporarily remove pipefail to prevent SIGPIPE from killing script
set -eo pipefail

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

# ── 2. Start Wine server ──────────────────────────────────────────────────────
echo "[2/6] Starting Wine server..."
wineboot 2>/dev/null || true
wineserver --wait 2>/dev/null || true
echo "      Wine server ready."

# ── 3. Wine version confirmation ─────────────────────────────────────────────
echo "[3/6] Wine version: $(wine --version)"

# ── 4. Setup folder structure + stage script ─────────────────────────────────
echo "[4/6] Setting up folder structure and source file..."

mkdir -p /compiler/MT5/MQL5/Scripts
mkdir -p /compiler/MT5/MQL5/Experts
mkdir -p /compiler/MT5/MQL5/Indicators
mkdir -p /compiler/MT5/MQL5/Libraries
mkdir -p /compiler/MT5/MQL5/Include
mkdir -p /compiler/MT5/MQL5/Files
mkdir -p /compiler/MT5/logs
mkdir -p /compiler/MT5/config

if [ -f "/compiler/MT5/metaeditor.ini" ]; then
    echo "      metaeditor.ini found — auto-update disabled."
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

SCRIPT_SRC="/compiler/scripts/test_script.mq5"
if [ ! -f "$SCRIPT_SRC" ]; then
    echo "ERROR: Source file not found at $SCRIPT_SRC"
    ls -la /compiler/scripts/ 2>/dev/null || echo "       (directory missing)"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

cp "$SCRIPT_SRC" /compiler/MT5/MQL5/Scripts/test_script.mq5
echo "      Script staged at: /compiler/MT5/MQL5/Scripts/test_script.mq5"

# ── 5. Run MetaEditor ─────────────────────────────────────────────────────────
echo "[5/6] Running MetaEditor64..."

mkdir -p /compiler/MT5/MQL5/Logs
LOG_PATH="/compiler/MT5/MQL5/Logs/build.log"
rm -f "$LOG_PATH"

WINE_DEBUG_LOG="/compiler/MT5/wine_debug.log"
rm -f "$WINE_DEBUG_LOG"

echo "      Running MetaEditor..."
WINEDEBUG=err+all timeout 120 wine /compiler/MT5/metaeditor64.exe \
    /compile:"C:\MT5\MQL5\Scripts\test_script.mq5" \
    /log:"C:\MT5\MQL5\Logs\build.log" \
    /portable \
    > "$WINE_DEBUG_LOG" 2>&1 || true

EXIT_CODE=$?
echo "      MetaEditor exit code: $EXIT_CODE"

# Print wine debug log directly to stdout so we can see it in Actions
echo "      === FULL WINE DEBUG LOG ==="
cat "$WINE_DEBUG_LOG" 2>/dev/null || echo "      (wine_debug.log is empty)"

echo "      === ALL FILES IN MT5 AFTER RUN ==="
find /compiler/MT5 -type f 2>/dev/null

# Copy logs to mounted output volume
cp "$WINE_DEBUG_LOG" /output/wine_debug.log 2>/dev/null || true
cp "$LOG_PATH" /output/build.log 2>/dev/null || true

echo "      Waiting for build log..."
for i in $(seq 1 20); do
    if [ -f "$LOG_PATH" ]; then
        echo "      Build log appeared after ${i}s"
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
    echo "  MetaEditor ran (exit 0) but produced no output."
    echo "  See WINE DEBUG LOG above for exact reason."
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