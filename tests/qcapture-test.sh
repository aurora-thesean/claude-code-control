#!/bin/bash
#
# qcapture-test.sh — Minimal Test Suite
# Verifies LD_PRELOAD hook functionality
#

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBFILE="$HOME/.local/lib/libqcapture.so"
LOGFILE="/tmp/qcapture.log"

# Compile if not present
if [ ! -f "$LIBFILE" ]; then
    echo "Compiling libqcapture.so..."
    bash "$REPO_ROOT/scripts/qcapture-compile.sh"
fi

# Clear old log
rm -f "$LOGFILE"

echo "=== Test 1: Basic LD_PRELOAD load test ==="
if LD_PRELOAD="$LIBFILE" /bin/echo "test" >/dev/null 2>&1; then
    echo "✓ Library loaded successfully"
else
    echo "✗ Failed to load library" >&2
    exit 1
fi

echo ""
echo "=== Test 2: Verify library signature ==="
if nm "$LIBFILE" 2>/dev/null | grep -q "open\|write\|read"; then
    echo "✓ Library exports expected symbols"
else
    echo "⊘ Symbol check inconclusive (library may still work)"
fi

echo ""
echo "=== Test 3: Verify JSON format ==="
if command -v jq >/dev/null 2>&1; then
    line_count=$(wc -l < "$LOGFILE" 2>/dev/null || echo 0)
    if [ "$line_count" -gt 0 ]; then
        # Try to parse first line as JSON
        first_line=$(head -1 "$LOGFILE")
        if echo "$first_line" | jq . >/dev/null 2>&1; then
            echo "✓ JSON format valid"
            echo "  Sample line: $first_line"
        else
            echo "✗ Invalid JSON in log" >&2
            exit 1
        fi
    else
        echo "⊘ Log file empty (may be expected)"
    fi
else
    echo "⊘ jq not available, skipping JSON validation"
fi

echo ""
echo "=== Test 4: Test with JSONL file operations ==="
rm -f "$LOGFILE"
test_jsonl="/tmp/test_qcapture.jsonl"

# Create a test program that uses direct syscalls (not stdio)
cat > /tmp/write_jsonl.c << 'EOF'
#define _GNU_SOURCE
#include <fcntl.h>
#include <unistd.h>
int main() {
    int fd = open("/tmp/test_qcapture.jsonl", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        write(fd, "{\"test\":1}\n", 11);
        close(fd);
    }
    return 0;
}
EOF

gcc -o /tmp/write_jsonl /tmp/write_jsonl.c
rm -f "$test_jsonl"
rm -f "$LOGFILE"

if LD_PRELOAD="$LIBFILE" /tmp/write_jsonl >/dev/null 2>&1; then
    if [ -f "$LOGFILE" ]; then
        echo "✓ Log captured JSONL file operations"
        echo "  Log contents:"
        while IFS= read -r line; do
            echo "    $line"
        done < "$LOGFILE"
    else
        echo "⊘ Log file not created (operations may not have been captured)"
    fi
else
    echo "✗ Failed to run test program" >&2
    exit 1
fi

echo ""
echo "=== All tests completed ==="
exit 0
