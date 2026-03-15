#!/bin/bash

echo "Initializing Wine environment..."
# Silently initialize wine without a UI
xvfb-run -a wineboot --init

echo "Starting Compilation..."

# Run MetaEditor
# /log MUST be a Windows path. Z: is the Linux root in Wine.
xvfb-run -a wine64 /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\scripts\test_script.mq5" \
    /log:"Z:\compiler\build.log"

# Give it 5 seconds to finish writing the file
sleep 5

if [ -f "build.log" ]; then
    echo "--- COMPILATION LOG START ---"
    cat build.log
    echo "--- COMPILATION LOG END ---"

    if grep -q "0 errors" build.log; then
        echo "RESULT: SUCCESS"
        exit 0
    else
        echo "RESULT: FAILED"
        exit 1
    fi
else
    echo "ERROR: MetaEditor crashed or build.log was not created."
    exit 1
fi