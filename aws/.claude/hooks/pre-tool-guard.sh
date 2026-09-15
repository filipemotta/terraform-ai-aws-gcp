#!/usr/bin/env bash
# PreToolUse guard for the Bash tool (Claude Code hooks, command type).
# Reads the hook input JSON from stdin and denies state-changing Terraform
# commands that the pack forbids:
#   1. `terraform destroy` without an explicit -target
#   2. `terraform apply -auto-approve` (never, in any workspace)
#   3. apply / destroy / state mv / state rm / import when the active
#      workspace of the target directory is "production"
# Decision is returned as JSON (hookSpecificOutput.permissionDecision), per
# https://code.claude.com/docs/en/hooks. Everything else is allowed.
set -uo pipefail

input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

[ -n "$command" ] || exit 0
printf '%s' "$command" | grep -qE '(^|[[:space:];&|])terraform([[:space:]]|$)' || exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# 1. destroy without -target
if printf '%s' "$command" | grep -qE 'terraform[[:space:]]+destroy' \
   && ! printf '%s' "$command" | grep -qE -- '-target[= ]'; then
  deny "Blocked: 'terraform destroy' without -target. Humans run destroy, outside the agent."
fi

# 2. apply -auto-approve, anywhere
if printf '%s' "$command" | grep -qE 'terraform[[:space:]]+apply' \
   && printf '%s' "$command" | grep -qE -- '-auto-approve'; then
  deny "Blocked: 'terraform apply -auto-approve'. Plan, then hand the apply to a human."
fi

# 3. state-changing verbs on the production workspace
if printf '%s' "$command" | grep -qE 'terraform[[:space:]]+(apply|destroy|import|state[[:space:]]+(mv|rm))'; then
  # Resolve the directory the command runs in: honour a leading `cd <dir> &&`.
  dir="$cwd"
  if printf '%s' "$command" | grep -qE '^[[:space:]]*cd[[:space:]]+[^[:space:];&|]+'; then
    rel="$(printf '%s' "$command" | sed -E 's/^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+).*/\1/')"
    case "$rel" in /*) dir="$rel" ;; *) dir="$cwd/$rel" ;; esac
  fi
  workspace=""
  if [ -d "$dir" ]; then
    workspace="$(cd "$dir" && terraform workspace show 2>/dev/null || true)"
  fi
  if [ "$workspace" = "production" ]; then
    deny "Blocked: workspace is 'production' in $dir. Production is plan-only for the agent (terraform-plan-readonly role)."
  fi
fi

exit 0
