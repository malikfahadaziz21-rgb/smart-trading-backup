#!/bin/bash

echo "running compile.sh"
echo "Current directory: $(pwd)"
# Start a virtual screen (MetaEditor won't run without one)
xvfb-run -a wine64 /compiler/MT5/metaeditor64.exe \
    /compile:"Z:\compiler\scripts\test_script.mq5" \
    /log:"Z:\compiler\build.log"

echo "Compilation process completed. Checking logs..."    

# Wait a few seconds for the file to write
sleep 2

# Show the log in the terminal
cat build.log

# Check if there are errors
if grep -q "0 errors" build.log; then
    echo "SUCCESS: No errors found!"
    exit 0
else
    echo "ERROR: Compilation failed. See logs above."
    exit 1
fi