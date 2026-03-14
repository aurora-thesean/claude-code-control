#!/bin/bash
set -x

cd "$(dirname "$0")"

rm -f ~/.aurora-agent/qreveng.jsonl

# Run daemon with short duration
./qreveng-daemon --duration 1 --interval 0.3 2>&1

# Check result
echo ""
echo "=== Result ==="
if [[ -f ~/.aurora-agent/qreveng.jsonl ]]; then
  echo "File created!"
  wc -l ~/.aurora-agent/qreveng.jsonl
  head -3 ~/.aurora-agent/qreveng.jsonl
else
  echo "File NOT created"
fi
