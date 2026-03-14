#!/bin/bash
# Compile libqcapture.so LD_PRELOAD library

set -euo pipefail

SOURCE="${1:-$HOME/repo-staging/claude-code-control/src/libqcapture.c}"
OUTPUT_DIR="$HOME/.local/lib"
OUTPUT_FILE="$OUTPUT_DIR/libqcapture.so"

# Verify source exists
if [[ ! -f "$SOURCE" ]]; then
    echo "Error: Source file not found: $SOURCE" >&2
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Compiling libqcapture.so..."
echo "Source: $SOURCE"
echo "Output: $OUTPUT_FILE"
echo ""

# Compile with gcc
if gcc -shared -fPIC -o "$OUTPUT_FILE" "$SOURCE" -lpthread -ldl 2>&1; then
    echo "✓ Compilation successful"
    echo "✓ Output: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
    exit 0
else
    echo "✗ Compilation failed" >&2
    exit 1
fi
