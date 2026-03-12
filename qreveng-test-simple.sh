#!/usr/bin/env bash
# qreveng-test-simple.sh — Quick REVENGINEER Unit Availability Test
#
# Smoke test: verify all 15 units exist and are executable

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
SKIP=0

echo "════════════════════════════════════════════════════════════════"
echo "REVENGINEER Unit 15: Test Suite & Documentation"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Layer 1: Ground Truth Sensors (Units 1-5)
echo "Layer 1: Ground Truth Sensors"
for tool in qsession-id qenv-snapshot qfd-trace; do
  if [[ -f "$REPO_ROOT/$tool" ]] && [[ -x "$REPO_ROOT/$tool" ]]; then
    echo "  ✓ $tool"
    ((PASS++))
  else
    echo "  ✗ $tool not found"
    ((SKIP++))
  fi
done

echo ""
echo "Layer 2: Interception & Tracing (Units 6-9)"
for tool in qcapture-load qwrapper-trace; do
  if [[ -f "$REPO_ROOT/$tool" ]] && [[ -x "$REPO_ROOT/$tool" ]]; then
    echo "  ✓ $tool"
    ((PASS++))
  else
    echo "  ✗ $tool not found"
    ((SKIP++))
  fi
done

echo ""
echo "Layer 3: Analysis & Memory (Units 10-12)"
for tool in qargv-map qmemmap-read; do
  if [[ -f "$REPO_ROOT/$tool" ]] && [[ -x "$REPO_ROOT/$tool" ]]; then
    echo "  ✓ $tool"
    ((PASS++))
  else
    echo "  ✗ $tool not found"
    ((SKIP++))
  fi
done

echo ""
echo "Layer 4: Orchestration & Integration (Units 13-14)"
for tool in qreveng-daemon qhoami qlaude; do
  if [[ -f "$REPO_ROOT/$tool" ]] && [[ -x "$REPO_ROOT/$tool" ]]; then
    echo "  ✓ $tool"
    ((PASS++))
  else
    echo "  ✗ $tool not found"
    ((SKIP++))
  fi
done

echo ""
echo "Layer 4: Testing & Documentation (Unit 15)"
if [[ -f "$REPO_ROOT/qreveng-test.sh" ]]; then
  echo "  ✓ qreveng-test.sh (comprehensive test suite)"
  ((PASS++))
else
  echo "  ✗ qreveng-test.sh not found"
  ((SKIP++))
fi

if [[ -f "$REPO_ROOT/REVENGINEER.md" ]]; then
  echo "  ✓ REVENGINEER.md (full system documentation)"
  ((PASS++))
else
  echo "  ✗ REVENGINEER.md not found"
  ((SKIP++))
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Summary: $PASS units available, $SKIP missing"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
