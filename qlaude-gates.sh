#!/usr/bin/env bash
# qlaude-gates.sh — Approval gate logic for qlaude motor
#
# Exports:
#   _gate_auto_approve(action, target, qc_level, loa_cap)
#   _gate_confirm(action, target, qc_level, loa_cap)
#   _check_qc_level() → returns QC_LEVEL int
#   _qc_level_name(int) → returns string name
#
# Dependencies: qlaude-audit.sh for _audit_log()

set -eo pipefail

# QC_LEVEL enum
readonly QC0_HUMAN_ONLY=0
readonly QC1_SUPERVISED_LOOP=1
readonly QC2_FULLY_AUTONOMOUS=2

# Configuration paths
CLAUDE_GLOBAL_MD="${CLAUDE_GLOBAL_MD:-$HOME/.claude/CLAUDE.md}"

# Utility logging (matches parent qlaude)
_log() {
  echo "[qlaude] $*" >&2
}

_error() {
  echo "ERROR: $*" >&2
  exit 1
}

# Get QC_LEVEL from CLAUDE.md LOA_CAP (immutable, never trust env)
_check_qc_level() {
  local loa
  loa=$(grep "^LOA_CAP=" "$CLAUDE_GLOBAL_MD" 2>/dev/null | cut -d= -f2) || {
    _log "WARNING: Could not read LOA_CAP from $CLAUDE_GLOBAL_MD, defaulting to QC0"
    echo "$QC0_HUMAN_ONLY"
    return
  }

  case "$loa" in
    2) echo "$QC0_HUMAN_ONLY" ;;
    4) echo "$QC1_SUPERVISED_LOOP" ;;
    6) echo "$QC2_FULLY_AUTONOMOUS" ;;
    *)
      _log "WARNING: Unknown LOA_CAP value '$loa', defaulting to QC0"
      echo "$QC0_HUMAN_ONLY"
      ;;
  esac
}

# Convert QC_LEVEL int to string name
_qc_level_name() {
  local qc_level="$1"
  case "$qc_level" in
    0) echo "QC0_HUMAN_ONLY" ;;
    1) echo "QC1_SUPERVISED_LOOP" ;;
    2) echo "QC2_FULLY_AUTONOMOUS" ;;
    *) echo "UNKNOWN" ;;
  esac
}

# Pattern 1: Human Confirmation (QC0 only)
# Requires: _audit_log() from qlaude-audit.sh
_gate_confirm() {
  local action="$1"
  local target="${2:-}"
  local qc_level="${3:-0}"
  local loa_cap="${4:-2}"

  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║                     APPROVAL GATE (QC0)                    ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Action: $action"
  if [[ -n "$target" ]]; then
    echo "  Target: $target"
  fi
  echo ""
  echo "Type 'yes' to approve, or press Ctrl-C to cancel:"
  echo ""

  local confirm
  read -r confirm || {
    echo ""
    _audit_log "$action" "$target" "REJECTED" "$(_qc_level_name "$qc_level")" "$loa_cap" "User cancelled (Ctrl-C)"
    _error "Cancelled by user"
  }

  if [[ "$confirm" != "yes" ]]; then
    _audit_log "$action" "$target" "REJECTED" "$(_qc_level_name "$qc_level")" "$loa_cap" "User denied confirmation (expected 'yes', got '$confirm')"
    _error "Cancelled by user (expected 'yes', got '$confirm')"
  fi

  _audit_log "$action" "$target" "APPROVED" "$(_qc_level_name "$qc_level")" "$loa_cap" "Human confirmation provided"
  _log "$action approved by human"
}

# Pattern 2: Auto-Approve with Log (QC1/QC2)
# Requires: _audit_log() from qlaude-audit.sh
_gate_auto_approve() {
  local action="$1"
  local target="${2:-}"
  local qc_level="$3"
  local loa_cap="${4:-}"

  # Infer LOA_CAP from QC_LEVEL if not provided
  if [[ -z "$loa_cap" ]]; then
    case "$qc_level" in
      0) loa_cap=2 ;;
      1) loa_cap=4 ;;
      2) loa_cap=6 ;;
      *) loa_cap=2 ;;
    esac
  fi

  local reason=""
  case "$qc_level" in
    1) reason="Auto-approved: QC1_SUPERVISED_LOOP (rate-limited)" ;;
    2) reason="Auto-approved: QC2_FULLY_AUTONOMOUS" ;;
    *) reason="Auto-approved" ;;
  esac

  _audit_log "$action" "$target" "APPROVED" "$(_qc_level_name "$qc_level")" "$loa_cap" "$reason"
  _log "[APPROVED] $action $([ -n "$target" ] && echo "$target" || echo "")(QC=$(_qc_level_name "$qc_level"))"
}
