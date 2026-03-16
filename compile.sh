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

WINE_DEBUG_LOG="/compiler/MT5/wine_debug.log"
rm -f "$WINE_DEBUG_LOG"

# Record timestamp so we can find files created by this run
touch /tmp/before_run

echo "      Running MetaEditor..."
# Remove /log flag — let MetaEditor write to its default location
# We'll find it by searching for new files after the run
timeout 120 wine /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\MT5\MQL5\Scripts\test_script.mq5" \
    /portable \
    > "$WINE_DEBUG_LOG" 2>&1 || true

EXIT_CODE=$?
echo "      MetaEditor exit code: $EXIT_CODE"

echo "      === WINE DEBUG LOG ==="
cat "$WINE_DEBUG_LOG" 2>/dev/null || echo "      (empty — good, means no Wine errors)"

echo "      === ALL NEW FILES CREATED SINCE RUN STARTED ==="
find / -newer /tmp/before_run -type f 2>/dev/null \
    | grep -v /proc \
    | grep -v /sys \
    | grep -v /tmp/before_run \
    | grep -v "$WINE_DEBUG_LOG"

echo "      === SEARCHING FOR .ex5 COMPILED OUTPUT ==="
find / -name "*.ex5" -newer /tmp/before_run 2>/dev/null | grep -v /proc || echo "      No .ex5 files created"

echo "      === SEARCHING FOR ANY NEW .log FILES ==="
find / -name "*.log" -newer /tmp/before_run 2>/dev/null | grep -v /proc || echo "      No new .log files"

# Copy everything to output volume
cp "$WINE_DEBUG_LOG" /output/wine_debug.log 2>/dev/null || true
find / -name "*.log" -newer /tmp/before_run 2>/dev/null \
    | grep -v /proc \
    | xargs -I{} cp {} /output/ 2>/dev/null || true
find / -name "*.ex5" -newer /tmp/before_run 2>/dev/null \
    | grep -v /proc \
    | xargs -I{} cp {} /output/ 2>/dev/null || true

sleep 5
# ── 6. Parse and report ───────────────────────────────────────────────────────
echo "[6/6] Parsing build log..."

# MetaEditor default log locations to check
POSSIBLE_LOGS=(
    "/compiler/MT5/MQL5/Logs/build.log"
    "/compiler/MT5/logs/build.log"
    "/compiler/MT5/MQL5/Scripts/test_script.log"
    "/root/.wine/drive_c/MT5/MQL5/Logs/build.log"
)

LOG_PATH=""
for path in "${POSSIBLE_LOGS[@]}"; do
    if [ -f "$path" ]; then
        echo "      Found log at: $path"
        LOG_PATH="$path"
        break
    fi
done

# Also check any newly created log file
if [ -z "$LOG_PATH" ]; then
    LOG_PATH=$(find / -name "*.log" -newer /tmp/before_run 2>/dev/null \
        | grep -v /proc \
        | grep -v wine_debug \
        | grep -v winetricks \
        | grep -v vcredist \
        | head -1)
fi

if [ -z "$LOG_PATH" ] || [ ! -f "$LOG_PATH" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ERROR: No build log found anywhere."
    echo "  MetaEditor ran cleanly (exit 0, no Wine errors)"
    echo "  but wrote no output files."
    echo "  Check the NEW FILES list above to find where it wrote."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

echo "      Using log: $LOG_PATH"
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