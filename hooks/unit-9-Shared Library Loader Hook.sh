#!/bin/bash
# qwrapper-trace — Wrapper Process Tracer
# Pre/post-invoke instrumentation: argv, environ, exit code, elapsed time
# Usage: qwrapper-trace <command> [args...]

set -o pipefail

# Pre-invoke capture
_pre_invoke() {
    local -a argv=("$@")
    local cwd="$PWD"
    local timestamp_start="$(date -u +%s.%N)"

    # Build argv JSON array
    local argv_json=""
    for arg in "${argv[@]}"; do
        [[ -n "$argv_json" ]] && argv_json="${argv_json},"
        argv_json="${argv_json}\"$(printf '%s\n' "$arg" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
    done

    # Build environ JSON array (strip control chars and escape properly)
    local environ_json=""
    while IFS='=' read -r key value; do
        [[ -n "$environ_json" ]] && environ_json="${environ_json},"
        local escaped=$(printf '%s\n' "$key=$value" | sed 's/[[:cntrl:]]/\\/g; s/\\/\\\\/g; s/"/\\"/g')
        environ_json="${environ_json}\"${escaped}\""
    done < <(env | tr -d '\000-\037')

    # Emit pre-invoke JSON
    cat <<EOF
{
  "phase": "pre_invoke",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "unix_timestamp_start": ${timestamp_start},
  "command": "${argv[0]}",
  "argv": [${argv_json}],
  "argc": ${#argv[@]},
  "cwd": "$cwd",
  "user": "$USER",
  "environ_count": $(env | wc -l),
  "environ": [${environ_json}]
}
EOF
}

# Execute command and capture post-invoke data
_invoke_and_capture() {
    local -a argv=("$@")
    local timestamp_start="$(date -u +%s.%N)"
    local tmpout tmpstderr exit_code

    tmpout=$(mktemp)
    tmpstderr=$(mktemp)
    trap "rm -f '$tmpout' '$tmpstderr'" RETURN

    # Run the command
    "${argv[@]}" >"$tmpout" 2>"$tmpstderr"
    exit_code=$?

    local timestamp_end="$(date -u +%s.%N)"
    local elapsed=$(awk "BEGIN {printf \"%.6f\", $timestamp_end - $timestamp_start}")
    local stdout_lines=$(wc -l <"$tmpout")
    local stderr_lines=$(wc -l <"$tmpstderr")
    local stdout_size=$(stat -c%s "$tmpout" 2>/dev/null || stat -f%z "$tmpout" 2>/dev/null || echo 0)
    local stderr_size=$(stat -c%s "$tmpstderr" 2>/dev/null || stat -f%z "$tmpstderr" 2>/dev/null || echo 0)

    # Emit post-invoke JSON
    cat <<EOF
{
  "phase": "post_invoke",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "unix_timestamp_end": ${timestamp_end},
  "elapsed_seconds": ${elapsed},
  "exit_code": ${exit_code},
  "stdout": {
    "lines": ${stdout_lines},
    "bytes": ${stdout_size}
  },
  "stderr": {
    "lines": ${stderr_lines},
    "bytes": ${stderr_size}
  }
}
EOF

    # Pass through stdout/stderr
    cat "$tmpout"
    cat "$tmpstderr" >&2

    return $exit_code
}

# Main entry point
main() {
    [[ $# -lt 1 ]] && {
        echo "Usage: qwrapper-trace <command> [args...]" >&2
        return 1
    }

    # Emit pre-invoke instrumentation
    _pre_invoke "$@"

    # Execute command and emit post-invoke instrumentation
    _invoke_and_capture "$@"
}

main "$@"
