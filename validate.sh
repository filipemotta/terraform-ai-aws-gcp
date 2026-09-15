#!/usr/bin/env bash
# Static validation for this repository: every Terraform stack in both clouds
# (fmt -check, init -backend=false, validate), every shell script (bash -n and
# the shell linter), every JSON file (jq), GitHub workflows if any (actionlint).
# Run from the repository root: bash validate.sh
# Exits non-zero if any validation fails. No cloud credentials needed.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

FAILURES=0
fail()  { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
ok()    { echo "  [ok] $1"; }
skip()  { echo "  [skipped] $1 (missing tool: install with 'brew install $2')"; }
run()   { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi; }

echo "== validate.sh — $(date '+%Y-%m-%d %H:%M') =="

# --- Shell scripts (hooks, helpers) ---
while IFS= read -r s; do
  [ -n "$s" ] || continue
  run "bash -n $s" bash -n "$s"
  if command -v shellcheck >/dev/null; then
    run "shellcheck $s" shellcheck "$s"
  else skip "shellcheck $s" shellcheck; fi
done < <(find . -name '*.sh' -not -path '*/.terraform/*' | sort)

# --- JSON (hook settings, MCP config, IAM policies) ---
while IFS= read -r j; do
  [ -n "$j" ] || continue
  if command -v jq >/dev/null; then
    run "jq $j" jq -e . "$j"
  else skip "jq $j" jq; fi
done < <(find . -name '*.json' -not -path '*/.terraform/*' -not -name '.terraform.lock.hcl' | sort)

# --- Terraform: every stack directory under aws/terraform and gcp/terraform ---
if command -v terraform >/dev/null; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if (cd "$d" \
      && terraform fmt -check >/dev/null \
      && terraform init -backend=false -input=false >/dev/null \
      && terraform validate >/dev/null); then
      ok "terraform fmt+init+validate in $d"
    else fail "terraform in $d"; fi
  done < <(find . -name '*.tf' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)
else skip "terraform" terraform; fi

# --- GitHub Actions workflows (none shipped today; kept for forks) ---
while IFS= read -r w; do
  [ -n "$w" ] || continue
  if command -v actionlint >/dev/null; then
    run "actionlint $w" actionlint "$w"
  else skip "actionlint $w" actionlint; fi
done < <(find . -path '*/.github/workflows/*.y*ml' | sort)

echo "== result: $FAILURES failure(s) =="
[ "$FAILURES" -eq 0 ]
