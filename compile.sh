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
LOG_PATH="/compiler/MT5/build.log"
rm -f "$LOG_PATH"

echo "      === BINARY VERIFICATION ==="
echo "      File type:"
file /compiler/MT5/metaeditor64.exe

echo "      First 8 bytes (MZ = valid Windows exe, else = LFS pointer or corrupt):"
xxd /compiler/MT5/metaeditor64.exe | head -1

echo "      File size:"
du -sh /compiler/MT5/metaeditor64.exe

echo "      === RUNNING METAEDITOR ==="
WINEDEBUG=err+all timeout 60 wine /compiler/MT5/metaeditor64.exe \
    /compile:"C:\MT5\MQL5\Scripts\test_script.mq5" \
    /log:"C:\MT5\build.log" \
    /portable
EXIT_CODE=$?
echo "      Exit code: $EXIT_CODE"

echo "      Files created by MetaEditor:"
find /compiler/MT5 -newer /compiler/MT5/metaeditor.ini 2>/dev/null \
    || echo "      No new files created"

echo "      Searching for any .log files:"
find /compiler /root/.wine -name "*.log" 2>/dev/null \
    || echo "      None found"

# ── 6. Parse and report ───────────────────────────────────────────────────────
echo "[6/6] Parsing build log..."

if [ ! -f "$LOG_PATH" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ERROR: build.log was never created by MetaEditor."
    echo "  MetaEditor timed out or crashed before compiling."
    echo "  Check Wine output above for clues."
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
```

# ---

# The `xxd` first line output will tell us everything. It should look like:
# ```
# 00000000: 4d5a 9000 0300 0000 ...    MZ......
# ```

# If instead it looks like:
# ```
# 00000000: 7665 7273 696f 6e20 ...    version