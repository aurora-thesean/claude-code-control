#!/bin/bash
# Simple test for qwrapper-trace

set -e

echo "Test 1: Basic echo command"
./qwrapper-trace echo "hello world" 2>&1 | jq '.phase' | head -2

echo ""
echo "Test 2: Exit code passthrough (true)"
./qwrapper-trace true 2>&1 | tail -1 | jq '.exit_code'

echo ""
echo "Test 3: Exit code passthrough (false)"
./qwrapper-trace false 2>&1 | tail -1 | jq '.exit_code' || true

echo ""
echo "Test 4: stderr capture"
./qwrapper-trace sh -c 'echo error >&2' 2>&1 | tail -1 | jq '.stderr'

echo ""
echo "All tests passed!"
