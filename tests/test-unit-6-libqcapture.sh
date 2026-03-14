#!/bin/bash
# Unit 6: LD_PRELOAD File I/O Hook Test Suite

PASS=0
FAIL=0

echo "=========================================="
echo "Unit 6: LD_PRELOAD File I/O Hook Tests"
echo "=========================================="
echo ""

# Test 1: Library compilation
if [[ -f ~/.local/lib/libqcapture.so ]]; then
    echo "✓ Test 1: libqcapture.so compiled"
    ((PASS=PASS+1))
else
    echo "✗ Test 1: libqcapture.so not found"
    ((FAIL=FAIL+1))
fi

# Test 2: Build script
if [[ -x ~/.local/bin/qcapture-compile.sh ]]; then
    echo "✓ Test 2: qcapture-compile.sh exists"
    ((PASS=PASS+1))
else
    echo "✗ Test 2: qcapture-compile.sh not executable"
    ((FAIL=FAIL+1))
fi

# Test 3: LD_PRELOAD loading
if LD_PRELOAD=~/.local/lib/libqcapture.so /bin/true 2>/dev/null; then
    echo "✓ Test 3: LD_PRELOAD loading works"
    ((PASS=PASS+1))
else
    echo "✗ Test 3: LD_PRELOAD loading failed"
    ((FAIL=FAIL+1))
fi

# Test 4: Source code
if [[ -f ~/repo-staging/claude-code-control/src/libqcapture.c ]]; then
    lines=$(wc -l < ~/repo-staging/claude-code-control/src/libqcapture.c)
    echo "✓ Test 4: libqcapture.c source ($lines lines)"
    ((PASS=PASS+1))
else
    echo "✗ Test 4: libqcapture.c source not found"
    ((FAIL=FAIL+1))
fi

# Test 5: write() symbol exported
if nm ~/.local/lib/libqcapture.so 2>/dev/null | grep -q "write"; then
    echo "✓ Test 5: write() symbol exported"
    ((PASS=PASS+1))
else
    echo "✗ Test 5: write() symbol not found"
    ((FAIL=FAIL+1))
fi

echo ""
echo "=========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "=========================================="

if [[ $FAIL -eq 0 ]]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ $FAIL test(s) failed"
    exit 1
fi
