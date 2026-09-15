#!/usr/bin/env bash
# PostToolUse hook for Edit|Write: when a .tf file is written, format it and
# run `terraform validate` in its stack directory. Validation errors are sent
# back to Claude via exit code 2 + stderr (documented PostToolUse behaviour).
# Reads the hook input JSON from stdin (tool_input.file_path).
set -uo pipefail

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"

[ -n "$file" ] || exit 0
case "$file" in *.tf) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0

dir="$(dirname "$file")"
terraform fmt "$file" >/dev/null 2>&1 || true

# Providers must be present for validate; initialise without a backend if needed.
if [ ! -d "$dir/.terraform" ]; then
  (cd "$dir" && terraform init -backend=false -input=false >/dev/null 2>&1) || true
fi

if out="$(cd "$dir" && terraform validate -no-color 2>&1)"; then
  jq -n --arg ctx "terraform fmt + validate OK in $dir" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
  exit 0
fi

printf 'terraform validate FAILED in %s\n%s\n' "$dir" "$out" >&2
exit 2
