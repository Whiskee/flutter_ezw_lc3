#!/bin/bash

# Generate dSYM for liblc3.dylib
# This script should be run after building the dylib

DYLIB_PATH="${SRCROOT}/../Classes/framework/liblc3.dylib"
DSYM_PATH="${DYLIB_PATH}.dSYM"

if [ -f "$DYLIB_PATH" ]; then
    echo "Generating dSYM for liblc3.dylib..."
    dsymutil "$DYLIB_PATH" -o "$DSYM_PATH"
    
    if [ -d "$DSYM_PATH" ]; then
        echo "dSYM generated successfully at: $DSYM_PATH"
    else
        echo "Error: Failed to generate dSYM"
        exit 1
    fi
else
    echo "Error: liblc3.dylib not found at: $DYLIB_PATH"
    exit 1
fi