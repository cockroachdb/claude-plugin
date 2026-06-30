#!/usr/bin/env bash
# Regression tests for the CockroachDB safety hooks.
#
# Runs the actual commands from hooks/hooks.json (with ${CLAUDE_PLUGIN_ROOT}
# substituted) and asserts the contract:
#
#   - dangerous SQL is blocked            (PreToolUse permissionDecision: deny)
#   - anti-patterns emit a warning        (systemMessage)
#   - safe SQL and non-SQL file edits     produce no user-visible block
#   - a missing or UNSUBSTITUTED plugin   root fails open: exit 0, no block
#
# The last case is the regression for issue #20 (path exceeds MAX_PATH) and
# issue #23 (${CLAUDE_PLUGIN_ROOT} not substituted by the host). In both, the
# interpreter cannot open the script; the hook must still exit 0 so the editor
# is never interrupted.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/hooks/hooks.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

# Extract a hook command from hooks.json and substitute the plugin root token.
hook_cmd() { # $1=event  $2=root
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"][sys.argv[2]][0]["hooks"][0]["command"].replace("${CLAUDE_PLUGIN_ROOT}", sys.argv[3]))' "$HOOKS" "$1" "$2"
}

# check: desc, event, root, stdin, expected_rc, mode(empty|contains), substr
check() {
  local desc="$1" event="$2" root="$3" stdin="$4" want_rc="$5" mode="$6" substr="${7:-}"
  local cmd out rc ok=1
  cmd="$(hook_cmd "$event" "$root")"
  out="$(printf '%s' "$stdin" | sh -c "$cmd" 2>/dev/null)"; rc=$?
  [ "$rc" = "$want_rc" ] || ok=0
  case "$mode" in
    empty)    [ -z "$out" ] || ok=0 ;;
    contains) printf '%s' "$out" | grep -q "$substr" || ok=0 ;;
  esac
  if [ "$ok" = 1 ]; then
    echo "ok   - $desc"
  else
    echo "FAIL - $desc (rc=$rc, out=${out:-<empty>})"
    fails=$((fails + 1))
  fi
}

printf 'CREATE TABLE t (id SERIAL PRIMARY KEY);\n' > "$TMP/a.sql"
printf '# just markdown, not sql\n' > "$TMP/a.md"

# --- PreToolUse (validate-sql.py), plugin root resolved ---
check "blocks DROP DATABASE"            PreToolUse "$ROOT" '{"tool_input":{"sql":"DROP DATABASE x"}}'            0 contains '"permissionDecision": "deny"'
check "blocks TRUNCATE"                 PreToolUse "$ROOT" '{"tool_input":{"sql":"TRUNCATE TABLE t"}}'           0 contains '"permissionDecision": "deny"'
check "warns on SERIAL"                 PreToolUse "$ROOT" '{"tool_input":{"sql":"CREATE TABLE t (id SERIAL)"}}' 0 contains 'systemMessage'
check "safe SQL produces no block"      PreToolUse "$ROOT" '{"tool_input":{"sql":"SELECT 1"}}'                   0 empty

# --- PostToolUse (check-sql-files.py), plugin root resolved ---
check "lints SERIAL in a .sql file"     PostToolUse "$ROOT" "{\"tool_input\":{\"file_path\":\"$TMP/a.sql\"}}"    0 contains 'CockroachDB lint'
check "non-SQL edit produces no block"  PostToolUse "$ROOT" "{\"tool_input\":{\"file_path\":\"$TMP/a.md\"}}"     0 empty

# --- regression: plugin root NOT substituted / missing (issues #20, #23) ---
# Pass the literal token as the "root" so the substitution is a no-op, exactly
# reproducing a host that does not expand ${CLAUDE_PLUGIN_ROOT}.
check "PreToolUse fails open on unsubstituted root"  PreToolUse  '${CLAUDE_PLUGIN_ROOT}' '{"tool_input":{"sql":"DROP DATABASE x"}}'                0 empty
check "PostToolUse fails open on unsubstituted root" PostToolUse '${CLAUDE_PLUGIN_ROOT}' "{\"tool_input\":{\"file_path\":\"$TMP/a.sql\"}}"        0 empty

echo
if [ "$fails" -eq 0 ]; then
  echo "All hook regression tests passed."
else
  echo "$fails test(s) failed."
  exit 1
fi
