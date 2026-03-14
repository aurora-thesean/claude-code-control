#!/usr/bin/env bash
# qhoami-model.sh — MODEL dimension sensor
#
# Claude version detection: HAIKU, SONNET, OPUS, LOCAL, UNKNOWN
# Ground truth: message.model field in session JSONL
# Uses Unit 5: qjsonl-truth for sessionId filtering
# Public interface: sense_model UUID
#
# Output format: VALUE|SOURCE_TYPE|SOURCE_NOTE

set -euo pipefail

# Source common helpers
source "${QHOAMI_COMMON:-$(dirname "$0")/qhoami-common.sh}"

# MODEL enum values

# Sense Claude model from JSONL message.model field
# Uses Unit 5: qjsonl-truth for sessionId filtering and model detection
sense_model() {
  local uuid="$1"

  # Ground truth: Use Unit 5 (qjsonl-truth) to parse JSONL with sessionId filtering
  if [[ -n "$uuid" ]]; then
    local jsonl_file
    jsonl_file=$(find "$HOME/.claude/projects" -name "${uuid}.jsonl" -type f 2>/dev/null | head -1)

    if [[ -n "$jsonl_file" ]]; then
      # Call qjsonl-truth to get filtered records
      local truth_output
      truth_output=$(qjsonl-truth "$jsonl_file" "$uuid" 2>/dev/null) || truth_output=""

      if [[ -n "$truth_output" ]]; then
        # Parse JSON result from qjsonl-truth
        local model
        model=$(echo "$truth_output" | python3 << 'PYSCRIPT'
import json
import sys

try:
    result = json.load(sys.stdin)
    models = result.get('data', {}).get('models_found', [])
    if models:
        # Return the last (most recent) model found
        print(models[-1])
except:
    pass
PYSCRIPT
        )

        if [[ -n "$model" ]]; then
          echo "$model|GROUND_TRUTH|Unit 5 qjsonl-truth (sessionId=$uuid, models_found)"
          return 0
        fi
      fi
    fi
  fi

  # Fallback: Unable to determine from session logs
  echo "MODEL_UNKNOWN|HEURISTIC_FALLBACK|Unit 5 qjsonl-truth could not find model in session JSONL"
}

# Export for use by wrapper
export -f sense_model
