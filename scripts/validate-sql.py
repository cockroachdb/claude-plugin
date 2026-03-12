#!/usr/bin/env python3
"""Pre-execution SQL validation for CockroachDB.
Blocks dangerous patterns before they reach the database.
Receives JSON on stdin from Claude Code PreToolUse hook.
Exit 0 = allow, exit 2 = block.
"""

import json
import re
import sys


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    sql = tool_input.get("sql", "") or tool_input.get("statement", "")
    if not sql:
        sys.exit(0)

    sql_upper = sql.upper()

    # Block DROP DATABASE
    if re.search(r"DROP\s+DATABASE", sql_upper):
        json.dump({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason":
                    "DROP DATABASE is blocked by CockroachDB plugin safety hook. "
                    "Use DROP TABLE for individual tables instead."
            }
        }, sys.stdout)
        sys.exit(0)

    # Block TRUNCATE (data loss risk)
    if re.search(r"^\s*TRUNCATE\s", sql_upper, re.MULTILINE):
        json.dump({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason":
                    "TRUNCATE is blocked by CockroachDB plugin safety hook. "
                    "Use DELETE with a WHERE clause for targeted row removal."
            }
        }, sys.stdout)
        sys.exit(0)

    # Warn about SERIAL (anti-pattern — causes hotspots)
    if re.search(r"\b(SERIAL|BIGSERIAL)\b", sql_upper):
        json.dump({
            "systemMessage":
                "WARNING: SERIAL/BIGSERIAL creates sequential IDs that cause write "
                "hotspots in CockroachDB. Use UUID with gen_random_uuid() instead: "
                "id UUID PRIMARY KEY DEFAULT gen_random_uuid()"
        }, sys.stdout)
        sys.exit(0)

    # Warn about multiple DDL in one transaction
    ddl_count = len(re.findall(
        r"(CREATE|ALTER|DROP)\s+(TABLE|INDEX|VIEW|SEQUENCE|TYPE|SCHEMA)",
        sql_upper
    ))
    if ddl_count > 1:
        json.dump({
            "systemMessage":
                "WARNING: Multiple DDL statements detected. CockroachDB supports "
                "only one DDL per transaction. Split into separate statements or "
                "use SET autocommit_before_ddl = true."
        }, sys.stdout)
        sys.exit(0)

    sys.exit(0)


if __name__ == "__main__":
    main()
