#!/bin/bash
# Monitor background agent progress

AGENTS=(
  "ad2a0bf699daebd19:Unit 6 (LD_PRELOAD)"
  "a81dcf275d3210a63:Unit 10 (Daemon)"
  "af8847fbed4bb5ebd:Unit 11 (Integration)"
  "a546b2b2521796718:Unit 13 (Tests)"
  "aea255aa623744f72:Unit 14 (Integration 2)"
  "a48d157b16f42bf3c:Unit 15 (Documentation)"
)

echo "=================================================="
echo "BATCH 2 & 3 AGENT MONITORING"
echo "=================================================="
echo "Time: $(date)"
echo ""

for agent_info in "${AGENTS[@]}"; do
  agent_id="${agent_info%:*}"
  unit_name="${agent_info#*:}"
  output_file="/tmp/claude-1000/-home-aurora-repo-staging-claude-code-control/tasks/${agent_id}.output"
  
  if [ -f "$output_file" ]; then
    lines=$(wc -l < "$output_file")
    last_line=$(tail -1 "$output_file")
    
    # Check if output contains "PR:" indicating completion
    if grep -q "^PR:" "$output_file" 2>/dev/null; then
      pr_url=$(grep "^PR:" "$output_file" | head -1)
      echo "✅ $unit_name — COMPLETE"
      echo "   $pr_url"
    else
      echo "🟡 $unit_name — IN PROGRESS"
      echo "   Lines: $lines | Last update: $(stat -c %y "$output_file" 2>/dev/null | cut -d' ' -f1-2)"
    fi
  else
    echo "⚫ $unit_name — NO OUTPUT YET"
  fi
  echo ""
done

echo "=================================================="
echo "Next check in 5 minutes or manually with:"
echo "  bash .agent-monitor.sh"
echo "=================================================="
