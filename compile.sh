#!/bin/bash
cd /compiler

echo "Step 1: Initializing Windows Environment (Wineboot)..."
# We run wineboot once to create the C: drive and internal DLL links
xvfb-run -a wine wineboot --init
sleep 5

echo "Step 2: Starting MetaEditor Compilation..."
# We use 'wine64' directly here to be absolute
xvfb-run -a wine64 /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\scripts\test_script.mq5" \
    /log:"Z:\compiler\build.log"

# Wait for the file to be written
sleep 5

if [ -f "build.log" ]; then
    echo "--- COMPILATION LOG START ---"
    # Convert UTF-16 to UTF-8 so GitHub can display it
    iconv -f UTF-16 -t UTF-8 build.log || cat build.log
    echo "--- COMPILATION LOG END ---"

    if grep -q "0 errors" build.log; then
        echo "RESULT: SUCCESS (0 errors)"
        exit 0
    else
        echo "RESULT: FAILED (Errors found)"
        exit 1
    fi
else
    echo "ERROR: MetaEditor failed to create build.log. Check if scripts/test_script.mq5 exists."
    exit 1
fi