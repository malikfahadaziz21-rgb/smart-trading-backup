#!/bin/bash
# Strict mode: exit on error, treat unset vars as errors, pipe failures matter
set -euo pipefail

cd /compiler

# ── 1. Start a fresh Xvfb display ───────────────────────────────────────────
echo "[1/5] Starting Xvfb virtual display..."
Xvfb :99 -screen 0 1024x768x24 -ac &
XVFB_PID=$!
export DISPLAY=:99

# Wait until Xvfb is actually responding — don't trust sleep
for i in $(seq 1 15); do
    if xdpyinfo -display :99 >/dev/null 2>&1; then
        echo "      Xvfb is ready (after ${i}s)"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "ERROR: Xvfb never became ready. Aborting."
        exit 1
    fi
    sleep 1
done

# ── 2. Verify wineserver is operational ─────────────────────────────────────
echo "[2/5] Verifying Wine environment..."
wine --version
# The prefix was pre-baked in the Docker image so no wineboot needed here.
# Just ping the wineserver to make sure it's alive.
wineserver --wait 2>/dev/null || true

# ── 3. Confirm script exists before handing off to MetaEditor ───────────────
echo "[3/5] Checking source file..."
SCRIPT_PATH="/compiler/scripts/test_script.mq5"
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: $SCRIPT_PATH not found."
    echo "       Contents of /compiler/scripts/:"
    ls -la /compiler/scripts/ || echo "       (directory is empty or missing)"
    exit 1
fi
echo "      Found: $SCRIPT_PATH"

# ── 4. Run MetaEditor ────────────────────────────────────────────────────────
echo "[4/5] Running MetaEditor64..."
LOG_PATH="/compiler/build.log"

# Remove stale log from a previous run just in case
rm -f "$LOG_PATH"

wine64 /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\scripts\test_script.mq5" \
    /log:"Z:\compiler\build.log" \
    /portable || true
# We use '|| true' because MetaEditor returns non-zero exit codes
# even on successful compilation — we rely on the log content instead.

# Give MetaEditor time to flush and close the log file
sleep 8

# ── 5. Parse the log and report ─────────────────────────────────────────────
echo "[5/5] Parsing compilation log..."

if [ ! -f "$LOG_PATH" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ERROR: build.log was never created."
    echo "This usually means MetaEditor crashed before"
    echo "it could read the source file."
    echo ""
    echo "Possible causes:"
    echo "  • metaeditor64.exe path is wrong"
    echo "  • Wine prefix is corrupt"
    echo "  • Missing Visual C++ runtime (vcrun2019)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━ COMPILATION LOG ━━━━━━━━━━━━━━━━━━━━━━"
# MetaEditor writes UTF-16LE — try that first, fall back gracefully
iconv -f UTF-16LE -t UTF-8 "$LOG_PATH" 2>/dev/null \
    || iconv -f UTF-16 -t UTF-8 "$LOG_PATH" 2>/dev/null \
    || cat "$LOG_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Case-insensitive match; MetaEditor writes "0 error(s)" or "0 errors"
if iconv -f UTF-16LE -t UTF-8 "$LOG_PATH" 2>/dev/null | grep -qi "0 error"; then
    echo "✅ RESULT: COMPILATION SUCCEEDED"
    kill $XVFB_PID 2>/dev/null || true
    exit 0
else
    echo "❌ RESULT: COMPILATION FAILED — see log above"
    kill $XVFB_PID 2>/dev/null || true
    exit 1
fi