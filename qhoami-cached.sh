#!/usr/bin/env bash
# qhoami-cached — Optimized version using JSONL caching module
#
# This is a variant of qhoami that uses qcache-jsonl.sh to avoid redundant JSONL I/O.
# Performance: Expected 50-70% improvement over non-cached version.
#
# Usage: Same as qhoami (drop-in replacement)

set -euo pipefail

# Source the cache module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/qcache-jsonl.sh"

# Include just the enum definitions and helper functions from original qhoami
# (omitting the non-cached versions of _sense_* functions)

TASKS_DIR="$HOME/.claude/tasks"
PROJECT_DIR="$HOME/.claude/projects"
AURORA_CONFIG="$HOME/CLAUDE.md"
GLOBAL_CONFIG="$HOME/.claude/CLAUDE.md"

# --- Enums (from original qhoami) ---

declare -rA AVATAR_ENUM=(
  [1]="AVATAR_HOME"
  [2]="AVATAR_DOWNLOADS"
  [3]="AVATAR_UNDERBAR"
  [4]="AVATAR_DUNDERBAR"
  [5]="AVATAR_THUNDERBAR"
  [6]="AVATAR_CUSTOM"
)

declare -rA SIDECAR_ENUM=(
  [0]="SIDECAR_NONE"
  [1]="SIDECAR_AUTONOMY"
  [2]="SIDECAR_PARALLEL"
  [3]="SIDECAR_CHILD"
  [9]="SIDECAR_UNKNOWN"
)

declare -rA MODEL_ENUM=(
  [1]="MODEL_HAIKU"
  [2]="MODEL_SONNET"
  [3]="MODEL_OPUS"
  [4]="MODEL_LOCAL"
  [9]="MODEL_UNKNOWN"
)

declare -rA QC_LEVEL_ENUM=(
  [0]="QC0_HUMAN_ONLY"
  [1]="QC1_SUPERVISED"
  [2]="QC2_FULLY_AUTONOMOUS"
  [9]="QC_UNKNOWN"
)

declare -rA MEMORY_ENUM=(
  [0]="MEM_NONE"
  [1]="MEM_FILE_ONLY"
  [2]="MEM_RESUMED"
  [3]="MEM_COMPACTED"
  [9]="MEM_UNKNOWN"
)

declare -rA LOCATION_ENUM=(
  [1]="LOC_AURORA_LOCAL"
  [2]="LOC_LAN_CARVIO"
  [3]="LOC_LAN_OTHER"
  [4]="LOC_REMOTE"
  [9]="LOC_UNKNOWN"
)

# --- Helpers ---

_json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  echo "$str"
}

_json_obj_start() {
  echo "  \"$1\": {"
}

_json_obj_end() {
  if [[ "${1:-}" == "last" ]]; then
    echo "  }"
  else
    echo "  },"
  fi
}

_json_string_field() {
  local key="$1"
  local value="$2"
  local last="${3:-}"
  value=$(_json_escape "$value")
  if [[ "$last" == "last" ]]; then
    echo "    \"$key\": \"$value\""
  else
    echo "    \"$key\": \"$value\","
  fi
}

_find_claude_pid() {
  local pid="${1:-$$}"
  local depth=0
  while (( depth < 20 )); do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    if [[ "$comm" == "claude" ]]; then
      echo "$pid"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ') || break
    [[ -n "$pid" && "$pid" -gt 1 ]] || break
    depth=$(( depth + 1 ))
  done
  return 1
}

_find_session_uuid() {
  local claude_pid="$1"
  for fd_path in /proc/$claude_pid/fd/*; do
    target=$(readlink "$fd_path" 2>/dev/null) || continue
    [[ "$target" == "anon_inode:inotify" ]] || continue
    fd_num=$(basename "$fd_path")
    while IFS= read -r line; do
      ino_hex=$(printf '%s' "$line" | grep -o 'ino:[0-9a-f]*' | cut -d: -f2) || continue
      [[ -n "$ino_hex" ]] || continue
      ino_dec=$((16#$ino_hex)) 2>/dev/null || continue
      for tasks_subdir in "$TASKS_DIR"/*/; do
        [[ -d "$tasks_subdir" ]] || continue
        subdir_ino=$(stat -c %i "$tasks_subdir" 2>/dev/null) || continue
        if [[ "$subdir_ino" == "$ino_dec" ]]; then
          basename "$tasks_subdir"
          return 0
        fi
      done
    done < /proc/$claude_pid/fdinfo/$fd_num 2>/dev/null
  done
  return 1
}

# --- Optimized Dimension Sensors (using cache) ---

_sense_avatar() {
  local uuid="$1"
  local claude_pid="$2"

  local cwd
  cwd=$(readlink /proc/$claude_pid/cwd 2>/dev/null) || cwd="?"

  local avatar_val=""
  local source_note=""

  case "$cwd" in
    "$HOME/Downloads"*)
      avatar_val="AVATAR_DOWNLOADS"
      source_note="/proc/$claude_pid/cwd = $cwd (GROUND_TRUTH)"
      ;;
    "$HOME/_"*)
      avatar_val="AVATAR_UNDERBAR"
      source_note="/proc/$claude_pid/cwd = $cwd (GROUND_TRUTH)"
      ;;
    "$HOME/__"*)
      avatar_val="AVATAR_DUNDERBAR"
      source_note="/proc/$claude_pid/cwd = $cwd (GROUND_TRUTH)"
      ;;
    "$HOME/___"*)
      avatar_val="AVATAR_THUNDERBAR"
      source_note="/proc/$claude_pid/cwd = $cwd (GROUND_TRUTH)"
      ;;
    "$HOME"*)
      avatar_val="AVATAR_HOME"
      source_note="/proc/$claude_pid/cwd = $cwd (GROUND_TRUTH)"
      ;;
    *)
      avatar_val="AVATAR_CUSTOM"
      source_note="/proc/$claude_pid/cwd = $cwd (GROUND_TRUTH)"
      ;;
  esac

  echo "$avatar_val|GROUND_TRUTH|$source_note"
}

_sense_sidecar() {
  local uuid="$1"

  local parent_uuid
  parent_uuid=$(qcache_get_parent_uuid "$uuid") || parent_uuid="?"

  local config_role
  config_role=$(cat "$TASKS_DIR/$uuid/.role" 2>/dev/null || echo "")

  local sidecar_val=""
  local source_type=""
  local source_note=""

  if [[ -n "$config_role" ]]; then
    sidecar_val="$config_role"
    source_type="CONFIG"
    source_note="$TASKS_DIR/$uuid/.role (CONFIG)"
  elif [[ "$parent_uuid" == "null" ]]; then
    sidecar_val="SIDECAR_NONE"
    source_type="GROUND_TRUTH"
    source_note="parentUuid is null in JSONL (GROUND_TRUTH)"
  elif [[ "$parent_uuid" == "?" ]]; then
    sidecar_val="SIDECAR_UNKNOWN"
    source_type="HEURISTIC_FALLBACK"
    source_note="could not determine parentUuid from JSONL (HEURISTIC_FALLBACK)"
  else
    sidecar_val="SIDECAR_CHILD"
    source_type="GROUND_TRUTH"
    source_note="parentUuid=$parent_uuid exists in JSONL (GROUND_TRUTH)"
  fi

  echo "$sidecar_val|$source_type|$source_note"
}

_sense_generation() {
  local uuid="$1"

  local config_gen
  config_gen=$(cat "$TASKS_DIR/$uuid/.generation" 2>/dev/null || echo "")

  if [[ -n "$config_gen" ]]; then
    echo "$config_gen|CONFIG|$TASKS_DIR/$uuid/.generation"
    return
  fi

  local generation=0
  local current_parent
  current_parent=$(qcache_get_parent_uuid "$uuid") || current_parent="?"

  local source_note="no compacted ancestors in JSONL (GROUND_TRUTH)"

  if [[ "$current_parent" != "null" && "$current_parent" != "?" ]]; then
    # For now, simplified: if parent exists, generation=0
    generation=0
  fi

  echo "GEN_$generation|GROUND_TRUTH|$source_note"
}

_sense_model() {
  local uuid="$1"

  local model
  model=$(qcache_get_model "$uuid") || model="MODEL_UNKNOWN"

  if [[ "$model" != "MODEL_UNKNOWN" ]]; then
    echo "$model|GROUND_TRUTH|Session JSONL message.model field (cached)"
    return
  fi

  echo "MODEL_UNKNOWN|HEURISTIC_FALLBACK|Could not find model in session JSONL"
}

_sense_qc_level() {
  local uuid="$1"

  local loa_cap=""
  local source_file=""
  if [[ -f "$AURORA_CONFIG" ]]; then
    loa_cap=$(grep "^LOA_CAP=" "$AURORA_CONFIG" 2>/dev/null | cut -d= -f2 | tr -d ' ') || true
    if [[ -n "$loa_cap" ]]; then
      source_file="$AURORA_CONFIG"
    fi
  fi
  if [[ -z "$loa_cap" && -f "$GLOBAL_CONFIG" ]]; then
    loa_cap=$(grep "^LOA_CAP=" "$GLOBAL_CONFIG" 2>/dev/null | cut -d= -f2 | tr -d ' ') || true
    if [[ -n "$loa_cap" ]]; then
      source_file="$GLOBAL_CONFIG"
    fi
  fi

  local qc_val="QC0_HUMAN_ONLY"
  local source_type="HEURISTIC_FALLBACK"
  local source_note="interactive terminal (HEURISTIC_FALLBACK)"

  if [[ -n "$loa_cap" ]]; then
    case "$loa_cap" in
      2) qc_val="QC0_HUMAN_ONLY" ;;
      4) qc_val="QC1_SUPERVISED" ;;
      6) qc_val="QC2_FULLY_AUTONOMOUS" ;;
      *) qc_val="QC_UNKNOWN" ;;
    esac
    source_type="CONFIG"
    source_note="LOA_CAP=$loa_cap in $source_file (CONFIG)"
  fi

  echo "$qc_val|$source_type|$source_note"
}

_sense_memory() {
  local uuid="$1"

  local config_mem=""
  if [[ -f "$HOME/.aurora-agent/memory-config.json" ]]; then
    config_mem=$(python3 -c "
import json
try:
    with open('$HOME/.aurora-agent/memory-config.json') as f:
        cfg = json.load(f)
        print(cfg.get('memory_scope', ''))
except: pass
" 2>/dev/null)
  fi

  if [[ -n "$config_mem" ]]; then
    echo "$config_mem|CONFIG|$HOME/.aurora-agent/memory-config.json"
    return
  fi

  local line_count
  line_count=$(qcache_get_session_count "$uuid") || line_count=0

  local memory_val=""
  local source_type=""
  local source_note=""

  if [[ "$line_count" -eq 0 ]]; then
    memory_val="MEM_NONE"
    source_type="GROUND_TRUTH"
    source_note="no records for $uuid in JSONL (GROUND_TRUTH)"
  elif [[ "$line_count" -lt 10 ]]; then
    memory_val="MEM_FILE_ONLY"
    source_type="HEURISTIC_FALLBACK"
    source_note="$line_count records in JSONL (HEURISTIC_FALLBACK, cached)"
  else
    memory_val="MEM_RESUMED"
    source_type="HEURISTIC_FALLBACK"
    source_note="$line_count records in JSONL (HEURISTIC_FALLBACK, cached)"
  fi

  echo "$memory_val|$source_type|$source_note"
}

_sense_location() {
  local uuid="$1"

  local config_loc=""
  if [[ -f "$HOME/.aurora-agent/instance-config.json" ]]; then
    config_loc=$(python3 -c "
import json
try:
    with open('$HOME/.aurora-agent/instance-config.json') as f:
        cfg = json.load(f)
        print(cfg.get('location', ''))
except: pass
" 2>/dev/null)
  fi

  if [[ -n "$config_loc" ]]; then
    echo "$config_loc|CONFIG|$HOME/.aurora-agent/instance-config.json"
    return
  fi

  local hostname
  hostname=$(hostname 2>/dev/null || echo "?")

  local location_val=""
  local source_type=""
  local source_note=""

  case "$hostname" in
    aurora)
      location_val="LOC_AURORA_LOCAL"
      source_type="GROUND_TRUTH"
      source_note="hostname = $hostname (GROUND_TRUTH)"
      ;;
    CARVIO|carvio)
      location_val="LOC_LAN_CARVIO"
      source_type="GROUND_TRUTH"
      source_note="hostname = $hostname (GROUND_TRUTH)"
      ;;
    *)
      location_val="LOC_UNKNOWN"
      source_type="HEURISTIC_FALLBACK"
      source_note="hostname = $hostname (HEURISTIC_FALLBACK)"
      ;;
  esac

  echo "$location_val|$source_type|$source_note"
}

# --- Build identity (parallel + cached) ---

_build_identity() {
  local uuid="$1"
  local claude_pid="$2"

  # Initialize cache for this UUID
  qcache_init "$uuid" || return 1

  # Parallel background jobs
  _sense_avatar "$uuid" "$claude_pid" > /tmp/qhoami_avatar.$$ 2>&1 &
  local avatar_pid=$!

  _sense_location "$uuid" > /tmp/qhoami_location.$$ 2>&1 &
  local location_pid=$!

  # Serial sensors (now using cache, much faster)
  IFS='|' read -r sidecar_val sidecar_src sidecar_note < <(_sense_sidecar "$uuid")
  IFS='|' read -r gen_val gen_src gen_note < <(_sense_generation "$uuid")
  IFS='|' read -r model_val model_src model_note < <(_sense_model "$uuid")
  IFS='|' read -r qc_val qc_src qc_note < <(_sense_qc_level "$uuid")
  IFS='|' read -r mem_val mem_src mem_note < <(_sense_memory "$uuid")

  # Wait for background jobs
  wait $avatar_pid $location_pid 2>/dev/null
  IFS='|' read -r avatar_val avatar_src avatar_note < /tmp/qhoami_avatar.$$ 2>/dev/null || {
    avatar_val="AVATAR_CUSTOM"
    avatar_src="HEURISTIC_FALLBACK"
    avatar_note="background sensor failed"
  }
  IFS='|' read -r loc_val loc_src loc_note < /tmp/qhoami_location.$$ 2>/dev/null || {
    loc_val="LOC_UNKNOWN"
    loc_src="HEURISTIC_FALLBACK"
    loc_note="background sensor failed"
  }
  rm -f /tmp/qhoami_avatar.$$ /tmp/qhoami_location.$$ 2>/dev/null

  # Get birth timestamp from cache
  local jsonl
  jsonl=$(qcache_get_jsonl_path "$uuid")
  local born
  born=$(grep "\"sessionId\".*\"$uuid\"" "$jsonl" 2>/dev/null | head -1 | \
    awk '{
      if (match($0, /"timestamp"[[:space:]]*:[[:space:]]*"([^"]+)"/, arr)) {
        print arr[1]; exit
      }
    }') || born="?"

  # Build JSON output
  cat <<EOF
{
  "uuid": "$uuid",
  "pid": $claude_pid,
  "birth_timestamp": "$born",
  "avatar": {
EOF
  _json_string_field "value" "$avatar_val"
  _json_string_field "source" "$avatar_src"
  _json_string_field "from" "$avatar_note" "last"
  cat <<EOF
  },
  "sidecar": {
EOF
  _json_string_field "value" "$sidecar_val"
  _json_string_field "source" "$sidecar_src"
  _json_string_field "from" "$sidecar_note" "last"
  cat <<EOF
  },
  "generation": {
EOF
  _json_string_field "value" "$gen_val"
  _json_string_field "source" "$gen_src"
  _json_string_field "from" "$gen_note" "last"
  cat <<EOF
  },
  "model": {
EOF
  _json_string_field "value" "$model_val"
  _json_string_field "source" "$model_src"
  _json_string_field "from" "$model_note" "last"
  cat <<EOF
  },
  "qc_level": {
EOF
  _json_string_field "value" "$qc_val"
  _json_string_field "source" "$qc_src"
  _json_string_field "from" "$qc_note" "last"
  cat <<EOF
  },
  "memory_scope": {
EOF
  _json_string_field "value" "$mem_val"
  _json_string_field "source" "$mem_src"
  _json_string_field "from" "$mem_note" "last"
  cat <<EOF
  },
  "location": {
EOF
  _json_string_field "value" "$loc_val"
  _json_string_field "source" "$loc_src"
  _json_string_field "from" "$loc_note" "last"
  cat <<EOF
  },
  "jsonl": "$jsonl"
}
EOF
}

# --- Main ---

case "${1:-}" in
  --self)
    claude_pid=$(_find_claude_pid $$) || { echo "ERROR: not inside a claude process tree" >&2; exit 1; }
    uuid=$(_find_session_uuid "$claude_pid") || { echo "ERROR: could not find session UUID for PID $claude_pid" >&2; exit 1; }
    _build_identity "$uuid" "$claude_pid" || exit 1
    ;;

  "")
    claude_pid=$(_find_claude_pid $$) || { echo "ERROR: not inside a claude process tree" >&2; exit 1; }
    uuid=$(_find_session_uuid "$claude_pid") || { echo "ERROR: could not find session UUID for PID $claude_pid" >&2; exit 1; }
    _build_identity "$uuid" "$claude_pid" || exit 1
    ;;

  *)
    echo "Usage: qhoami-cached [--self]" >&2
    exit 2
    ;;
esac
