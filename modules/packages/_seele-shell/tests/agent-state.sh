#!/usr/bin/env bash
set -euo pipefail

agent_state=${1:?agent-state path required}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/state/seele-shell"

printf '#!%s\n' "$BASH" >"$work/codexbar"
cat >>"$work/codexbar" <<'SCRIPT'
set -euo pipefail

case $1 in
  usage)
    printf '[]\n'
    ;;
  cost)
    count_file=$FAKE_CODEXBAR_STATE/cost-count
    count=$(($(cat "$count_file" 2>/dev/null || printf 0) + 1))
    printf '%s\n' "$count" >"$count_file"
    claude_cost=0
    ((count > 1)) && claude_cost=7
    jq -nc --argjson claude_cost "$claude_cost" '[
      {
        provider: "codex",
        daily: [{date: "2026-08-28", totalTokens: 20, totalCost: 2, modelBreakdowns: [{modelName: "codex-model", totalTokens: 20, cost: 2}]}],
        last30DaysTokens: 20,
        last30DaysCostUSD: 2
      },
      {
        provider: "claude",
        daily: [{date: "2026-08-28", totalTokens: 70, totalCost: $claude_cost, modelBreakdowns: [{modelName: "claude-model", totalTokens: 70, cost: $claude_cost}]}],
        last30DaysTokens: 70,
        last30DaysCostUSD: $claude_cost
      }
    ]'
    ;;
esac
SCRIPT
chmod +x "$work/codexbar"

XDG_STATE_HOME="$work/state" \
FAKE_CODEXBAR_STATE="$work" \
SEELE_SHELL_CODEXBAR="$work/codexbar" \
  bash "$agent_state" >"$work/result.json"

jq -e '
  .local.totalTokens == 90
  and .local.totalCost == 9
  and any(.local.models[]; .name == "claude-model" and .tokens == 70 and .cost == 7)
' "$work/result.json" >/dev/null

test "$(<"$work/cost-count")" -eq 2
printf 'agent state tests passed\n'
