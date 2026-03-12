#!/usr/bin/env bash
# qlaude-audit.sh — JSONL audit trail management for qlaude motor
#
# Exports:
#   _audit_log(action, target, decision, qc_level, loa_cap, reason)
#   _read_audit_trail(filter_action) → reads and parses JSONL
#   _audit_stats(action) → returns approval/rejection counts
#   _ensure_aurora_agent_dir()
#
# Appends to:
#   ~/.aurora-agent/.qlaude-audit.jsonl
#   ~/.aurora-agent/qreveng.jsonl (unified stream)

set -eo pipefail

# Configuration paths
AURORA_AGENT_DIR="${AURORA_AGENT_DIR:-$HOME/.aurora-agent}"
QLAUDE_AUDIT_LOG="$AURORA_AGENT_DIR/.qlaude-audit.jsonl"
QREVENG_LOG="$AURORA_AGENT_DIR/qreveng.jsonl"

# Utility logging
_log() {
  echo "[qlaude] $*" >&2
}

# Ensure aurora agent directory exists
_ensure_aurora_agent_dir() {
  mkdir -p "$AURORA_AGENT_DIR" 2>/dev/null || true
}

# Write audit log entry (JSONL format) to both .qlaude-audit.jsonl and qreveng.jsonl
_audit_log() {
  local action="$1"
  local target="$2"
  local decision="$3"
  local qc_level="$4"
  local loa_cap="$5"
  local reason="${6:-}"

  _ensure_aurora_agent_dir

  # Build JSON object using environment variables to avoid arg passing issues
  local json
  json=$(AUDIT_ACTION="$action" AUDIT_TARGET="$target" AUDIT_DECISION="$decision" \
         AUDIT_QC_LEVEL="$qc_level" AUDIT_LOA_CAP="$loa_cap" AUDIT_REASON="$reason" \
         python3 << 'PYJSON'
import json
import os
from datetime import datetime, timezone

entry = {
    "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "action": os.environ.get("AUDIT_ACTION", ""),
    "target": os.environ.get("AUDIT_TARGET", ""),
    "decision": os.environ.get("AUDIT_DECISION", ""),
    "qc_level": os.environ.get("AUDIT_QC_LEVEL", ""),
    "loa_cap": int(os.environ.get("AUDIT_LOA_CAP", "0")),
    "reason": os.environ.get("AUDIT_REASON", "")
}

print(json.dumps(entry, separators=(",", ":")))
PYJSON
  )

  # Append to both audit logs atomically
  echo "$json" >> "$QLAUDE_AUDIT_LOG" 2>/dev/null || true
  echo "$json" >> "$QREVENG_LOG" 2>/dev/null || true
}

# Read audit trail entries, optionally filtered by action
_read_audit_trail() {
  local filter_action="${1:-}"

  if [[ ! -f "$QLAUDE_AUDIT_LOG" ]]; then
    return 0
  fi

  if [[ -z "$filter_action" ]]; then
    cat "$QLAUDE_AUDIT_LOG"
  else
    grep -F "\"action\":\"$filter_action\"" "$QLAUDE_AUDIT_LOG" || true
  fi
}

# Get audit statistics for a specific action
_audit_stats() {
  local action="$1"

  if [[ ! -f "$QLAUDE_AUDIT_LOG" ]]; then
    echo "APPROVED: 0, REJECTED: 0"
    return 0
  fi

  local approved rejected
  approved=$(grep -c "\"action\":\"$action\".*\"decision\":\"APPROVED\"" "$QLAUDE_AUDIT_LOG" || echo 0)
  rejected=$(grep -c "\"action\":\"$action\".*\"decision\":\"REJECTED\"" "$QLAUDE_AUDIT_LOG" || echo 0)

  echo "APPROVED: $approved, REJECTED: $rejected"
}
