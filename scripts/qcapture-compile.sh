#!/bin/bash
#
# qcapture-compile.sh — Build LD_PRELOAD File I/O Hook Library
# Compiles src/libqcapture.c → ~/.local/lib/libqcapture.so
# Zero dependencies except gcc and standard C lib
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_FILE="$REPO_ROOT/src/libqcapture.c"
DEST_DIR="$HOME/.local/lib"
OUTPUT_FILE="$DEST_DIR/libqcapture.so"

# Verify source exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "ERROR: Source file not found: $SOURCE_FILE" >&2
    exit 1
fi

# Create destination directory if needed
mkdir -p "$DEST_DIR"

# Compile: shared library, position-independent code, link dl (for dlsym)
echo "Compiling libqcapture.so..."
gcc -shared -fPIC -ldl "$SOURCE_FILE" -o "$OUTPUT_FILE"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "ERROR: Compilation failed" >&2
    exit 1
fi

echo "✓ Built: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"

# Verify it's loadable
if ! ldd "$OUTPUT_FILE" 2>/dev/null | grep -q "libc"; then
    echo "ERROR: Library verification failed" >&2
    exit 1
fi

echo "✓ Library verification passed"
exit 0
