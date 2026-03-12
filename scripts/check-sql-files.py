#!/usr/bin/env python3
"""Post-edit check for CockroachDB anti-patterns in SQL and code files.
Receives JSON on stdin from Claude Code PostToolUse hook.
"""

import json
import os
import re
import sys


SQL_EXTENSIONS = {".sql", ".go", ".py", ".js", ".ts", ".java", ".rb"}


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not file_path:
        sys.exit(0)

    ext = os.path.splitext(file_path)[1]
    if ext not in SQL_EXTENSIONS:
        sys.exit(0)

    if not os.path.isfile(file_path):
        sys.exit(0)

    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except OSError:
        sys.exit(0)

    warnings = []

    if re.search(r"\b(SERIAL|BIGSERIAL)\b", content, re.IGNORECASE):
        warnings.append(
            "SERIAL/BIGSERIAL detected — causes write hotspots in CockroachDB, "
            "use UUID with gen_random_uuid() instead."
        )

    if re.search(r"SELECT\s+\*\s+FROM", content, re.IGNORECASE):
        warnings.append(
            "SELECT * detected — enumerate columns explicitly for CockroachDB "
            "to enable covering index optimizations."
        )

    # Check for missing transaction retry logic in Go files
    if ext == ".go":
        if re.search(r"\bBEGIN\b|sql\.Tx", content):
            if not re.search(r"crdb\.ExecuteTx|retry|40001", content, re.IGNORECASE):
                warnings.append(
                    "Transaction without retry logic detected — CockroachDB requires "
                    "retry on SQLSTATE 40001 (serialization_failure). "
                    "Use crdb.ExecuteTx from cockroach-go."
                )

    # Check for missing retry in Java files
    if ext == ".java":
        if re.search(r"\bBEGIN\b|connection\.setAutoCommit", content):
            if not re.search(r"retry|40001|RetryableExecutor", content, re.IGNORECASE):
                warnings.append(
                    "Transaction without retry logic detected — CockroachDB requires "
                    "retry on SQLSTATE 40001. "
                    "Use cockroachdb-jdbc-wrapper RetryableExecutor."
                )

    if warnings:
        json.dump({
            "systemMessage": "CockroachDB lint: " + " ".join(warnings)
        }, sys.stdout)

    sys.exit(0)


if __name__ == "__main__":
    main()
