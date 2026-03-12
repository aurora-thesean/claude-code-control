#!/usr/bin/env bash
# qcapture-compile.sh — Build script for qcapture LD_PRELOAD library
#
# Compiles qcapture.c into a shared library for interception of file I/O syscalls.
#
# Usage:
#   bash qcapture-compile.sh               # Build in current directory
#   bash qcapture-compile.sh /path/to/dir # Build and install to /path/to/dir
#
# Output:
#   - libqcapture.so (shared library)
#   - compile report (JSON on stdout)
#
# Exit codes: 0=success, 1=compilation error, 2=missing dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${1:-.}"

# Check for required tools
if ! command -v gcc &> /dev/null; then
    echo "{
  \"type\": \"build-report\",
  \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",
  \"unit\": \"6\",
  \"status\": \"error\",
  \"message\": \"gcc not found in PATH\",
  \"source\": \"GROUND_TRUTH\",
  \"error\": \"Missing dependency: gcc\"
}" >&1
    exit 2
fi

# Build the shared library
OUTPUT_FILE="$BUILD_DIR/libqcapture.so"
SOURCE_FILE="$SCRIPT_DIR/qcapture.c"

# Create build directory
mkdir -p "$BUILD_DIR" || {
    echo "{
  \"type\": \"build-report\",
  \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",
  \"unit\": \"6\",
  \"status\": \"error\",
  \"message\": \"Cannot create build directory: $BUILD_DIR\",
  \"source\": \"GROUND_TRUTH\",
  \"error\": \"Permission denied\"
}" >&1
    exit 1
}

# Verify source exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "{
  \"type\": \"build-report\",
  \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",
  \"unit\": \"6\",
  \"status\": \"error\",
  \"message\": \"Source file not found: $SOURCE_FILE\",
  \"source\": \"GROUND_TRUTH\",
  \"error\": \"File not found\"
}" >&1
    exit 1
fi

# Compile
if ! gcc -shared -fPIC -ldl -pthread -o "$OUTPUT_FILE" "$SOURCE_FILE" 2>&1; then
    echo "{
  \"type\": \"build-report\",
  \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",
  \"unit\": \"6\",
  \"status\": \"error\",
  \"message\": \"Compilation failed\",
  \"source\": \"GROUND_TRUTH\",
  \"error\": \"gcc returned non-zero exit code\"
}" >&1
    exit 1
fi

# Verify output
if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "{
  \"type\": \"build-report\",
  \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",
  \"unit\": \"6\",
  \"status\": \"error\",
  \"message\": \"Output file not created: $OUTPUT_FILE\",
  \"source\": \"GROUND_TRUTH\",
  \"error\": \"Compilation produced no output\"
}" >&1
    exit 1
fi

# Get file size and permissions
FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo "0")

# Emit success report
echo "{
  \"type\": \"build-report\",
  \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",
  \"unit\": \"6\",
  \"status\": \"success\",
  \"data\": {
    \"output_file\": \"$OUTPUT_FILE\",
    \"file_size\": $FILE_SIZE,
    \"source_file\": \"$SOURCE_FILE\",
    \"compiler\": \"gcc\",
    \"flags\": \"-shared -fPIC -ldl -pthread\"
  },
  \"source\": \"GROUND_TRUTH\",
  \"error\": null
}"

exit 0
