#!/usr/bin/env bash
# Stop hook: before Claude ends its turn, verify the Terraform tree is clean:
#   - every stack is formatted (terraform fmt -check)
#   - every initialised stack validates (terraform validate)
#   - no obvious credential material in tracked files
# Blocks the stop (decision: block) with the reason when something fails.
set -uo pipefail

input="$(cat)"
# Defensive loop guard: if a previous Stop hook already forced a continuation,
# do not block again.
if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
problems=()

if [ -d "$root/terraform" ]; then
  if ! terraform fmt -check -recursive "$root/terraform" >/dev/null 2>&1; then
    problems+=("terraform fmt -check failed under terraform/")
  fi
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ -d "$d/.terraform" ] && ! (cd "$d" && terraform validate >/dev/null 2>&1); then
      problems+=("terraform validate failed in ${d#"$root"/}")
    fi
  done < <(find "$root/terraform" -mindepth 1 -maxdepth 1 -type d | sort)
fi

# The hook scripts themselves contain these patterns; skip the hooks directory.
if grep -rEl --exclude-dir=.terraform --exclude-dir=.git --exclude-dir=hooks \
     -e 'AKIA[0-9A-Z]{16}' -e 'BEGIN (RSA|EC|OPENSSH) PRIVATE KEY' -e 'aws_secret_access_key[[:space:]]*=' \
     "$root" >/dev/null 2>&1; then
  problems+=("credential-looking material found in the repository")
fi

if [ "${#problems[@]}" -gt 0 ]; then
  reason="$(printf '%s; ' "${problems[@]}")"
  jq -n --arg reason "Stop blocked: ${reason%; }" \
    '{hookSpecificOutput: {hookEventName: "Stop", decision: "block", reason: $reason}}'
fi
exit 0
