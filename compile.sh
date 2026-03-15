#!/bin/bash

# Ensure we are in the right folder
cd /compiler

echo "Initializing Wine environment..."
# We use 'wine' instead of 'wine64' as it's the standard wrapper in WineHQ 9.0
xvfb-run -a wine wineboot --init
sleep 3

echo "Starting MetaEditor Compilation..."

# Run compilation
# We point to the absolute path of the exe just to be 100% sure
xvfb-run -a wine /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\scripts\test_script.mq5" \
    /log:"Z:\compiler\build.log"

# Give it time to write the file
sleep 5

if [ -f "build.log" ]; then
    echo "--- COMPILATION LOG START ---"
    # Convert from UTF-16 (MetaEditor format) to UTF-8 so we can read it in Linux
    iconv -f UTF-16 -t UTF-8 build.log || cat build.log
    echo "--- COMPILATION LOG END ---"

    if grep -q "0 errors" build.log; then
        echo "RESULT: SUCCESS"
        exit 0
    else
        echo "RESULT: FAILED"
        exit 1
    fi
else
    echo "ERROR: MetaEditor failed to generate build.log"
    exit 1
fi