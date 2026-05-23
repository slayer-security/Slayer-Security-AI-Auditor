#!/usr/bin/env bash
set -euo pipefail

# Print the first literal SOLODIT_API_KEY found.
# Resolution order:
# 1. Current environment
# 2. ~/.zshrc
# 3. ~/.bashrc
# 4. ~/.bash_profile
# 5. ~/.profile
#
# The parser is intentionally static. It only accepts literal assignments and
# ignores shell expansions like $(...), backticks, or variable interpolation.

trim_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

is_literal_value() {
  local value="$1"
  [[ "$value" != *'$('* ]] || return 1
  [[ "$value" != *'`'* ]] || return 1
  [[ "$value" != *'${'* ]] || return 1
  [[ "$value" != *'$SOLODIT_API_KEY'* ]] || return 1
  return 0
}

extract_from_file() {
  local file="$1"
  [[ -f "$file" ]] || return 1

  local raw
  raw="$({
    grep -E '^[[:space:]]*(export[[:space:]]+)?SOLODIT_API_KEY=' "$file" || true
  } | tail -n 1 | sed -E 's/^[[:space:]]*(export[[:space:]]+)?SOLODIT_API_KEY=//' | sed -E 's/[[:space:]]+#.*$//')"

  [[ -n "$raw" ]] || return 1
  raw="$(trim_quotes "$raw")"
  [[ -n "$raw" ]] || return 1
  is_literal_value "$raw" || return 1

  printf '%s\n' "$raw"
  return 0
}

if [[ -n "${SOLODIT_API_KEY:-}" ]]; then
  printf '%s\n' "$SOLODIT_API_KEY"
  exit 0
fi

for file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  if extract_from_file "$file"; then
    exit 0
  fi
done

exit 1
