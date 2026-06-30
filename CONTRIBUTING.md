# Contributing to CockroachDB Plugin for Claude Code

Thank you for your interest in contributing! This guide covers the plugin itself — agents, hooks, MCP configuration, and tooling. For contributing **skills**, see the [cockroachdb-skills CONTRIBUTING.md](https://github.com/cockroachlabs/cockroachdb-skills/blob/main/CONTRIBUTING.md) instead; skills are maintained upstream and synced here automatically.

## Getting Started

### Prerequisites

- [Claude Code](https://code.claude.com/) installed
- [MCP Toolbox for Databases](https://github.com/googleapis/mcp-toolbox) v1.0.0+ (`brew install mcp-toolbox`)
- Python 3 (for hook scripts — no external dependencies)
- A running CockroachDB instance (local or cloud)

### Setup

```bash
git clone --recurse-submodules https://github.com/cockroachdb/claude-plugin.git
cd claude-plugin
```

Set your connection environment variables:

```bash
export COCKROACHDB_HOST=localhost
export COCKROACHDB_PORT=26257
export COCKROACHDB_USER=root
export COCKROACHDB_PASSWORD=
export COCKROACHDB_DATABASE=defaultdb
export COCKROACHDB_SSLMODE=disable
```

Test the plugin locally:

```bash
claude --plugin-dir .
```

Validate the plugin manifest:

```bash
claude plugin validate .
```

## Project Structure

```
.claude-plugin/
  plugin.json              # Plugin manifest (version managed by Release Please)
  marketplace.json         # Marketplace catalog entry
.mcp.json                  # MCP server definitions (stdio, HTTP, Cloud)
tools.yaml                 # MCP Toolbox source and tool definitions
agents/                    # Agent markdown files (auto-discovered)
hooks/
  hooks.json               # Hook triggers and matchers
scripts/
  validate-sql.py          # PreToolUse: blocks dangerous SQL patterns
  check-sql-files.py       # PostToolUse: lints files for anti-patterns
skills/                    # Copied from cockroachdb-skills submodule (do not edit directly)
submodules/
  cockroachdb-skills/      # Upstream skills submodule
```

## What You Can Contribute

| Area | Examples |
|------|----------|
| **Agents** | New agent personas, improved prompts, better tool references |
| **Hooks** | New safety checks, additional SQL anti-pattern detection |
| **MCP config** | New backend integrations, connection improvements |
| **Tools** | New tool definitions in `tools.yaml` |
| **Bug fixes** | Path handling, env var defaults, config issues |
| **Documentation** | README improvements, inline comments |

### What belongs elsewhere

- **New skills** → [cockroachdb-skills](https://github.com/cockroachlabs/cockroachdb-skills) repo
- **Toolbox bugs** → [MCP Toolbox](https://github.com/googleapis/mcp-toolbox) repo
- **Claude Code bugs** → [Claude Code](https://github.com/anthropics/claude-code) repo

## Development Workflow

1. **Fork** the repository and create a feature branch:
   ```bash
   git checkout -b fix/describe-your-change
   ```

2. **Make your changes** — match the existing code style and conventions.

3. **Test locally** — run the plugin with `claude --plugin-dir .` and verify your change works.

4. **Test hook scripts** (if modified):
   ```bash
   # validate-sql.py — expects JSON on stdin
   echo '{"tool_input":{"sql":"SELECT 1"}}' | python3 scripts/validate-sql.py

   # check-sql-files.py — expects JSON on stdin
   echo '{"tool_input":{"file_path":"test.sql"}}' | python3 scripts/check-sql-files.py
   ```

   Run the full hook regression suite (also runs in CI):
   ```bash
   bash scripts/test-hooks.sh
   ```

5. **Commit** using [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "fix: quote CLAUDE_PLUGIN_ROOT for paths with spaces"
   git commit -m "feat: add new hook to validate index definitions"
   git commit -m "docs: clarify Cloud MCP setup in README"
   ```

6. **Open a Pull Request** against `main`.

## Commit Conventions

This repo uses [Release Please](https://github.com/googleapis/release-please) for automated versioning and changelogs. Your commit prefix determines what happens:

| Prefix | Effect | Example |
|--------|--------|---------|
| `fix:` | Patch release (0.1.x) | `fix: handle empty SQL in validate hook` |
| `feat:` | Minor release (0.x.0) | `feat: add index validation hook` |
| `docs:` | No release | `docs: update README with new backend` |
| `chore:` | No release | `chore: update submodule reference` |

**Important:**
- Never bump the version in `plugin.json` or `.release-please-manifest.json` manually — Release Please owns these files.
- Use `fix:` or `feat:` only for changes that should appear in the changelog and trigger a release.

## Guidelines

### Agents

- Agent files live in `agents/` and are auto-discovered by Claude Code.
- Use markdown format with clear role descriptions.
- Reference MCP tools by their full names (e.g., `cockroachdb-execute-sql`, `list_clusters`).
- Do not add restrictive `tools:` frontmatter — agents need access to all MCP tools.

### Hooks

- Hook scripts must be Python 3 with **no external dependencies** (stdlib only).
- Read JSON from stdin, write JSON to stdout.
- Exit code 0 = allow/continue; exit code 2 = block the tool call.
- Load hook scripts through the long-path-safe bootstrap below instead of passing the script path straight to `python3`. On Windows, `${CLAUDE_PLUGIN_ROOT}` resolves to a deeply nested cache path that can exceed the 260-character `MAX_PATH` limit; passing the path directly makes Python fail to open the script and error on every matched tool call (see issue #20). The bootstrap loads the script with `runpy`, prefixing the path with the `\\?\` long-path escape on Windows, keeps it inside single quotes so paths with spaces still work, and uses `; exit 0` so a failed bootstrap never disrupts editing:
  ```json
  "command": "python3 -c 'import sys, os, runpy; p = os.path.normpath(r\"${CLAUDE_PLUGIN_ROOT}/scripts/your-script.py\"); p = (\"\\\\?\\\\\" + p) if os.name == \"nt\" else p; runpy.run_path(p, run_name=\"__main__\")'; exit 0"
  ```

### MCP Configuration

- `.mcp.json` defines MCP server backends.
- Use `${ENV_VAR}` syntax for environment variable references.
- The `tools.yaml` file uses Toolbox v1.1.0 map-based format with `${VAR:default}` syntax for defaults.

### Skills

Skills are synced from the upstream [cockroachdb-skills](https://github.com/cockroachlabs/cockroachdb-skills) submodule by a [weekly CI workflow](.github/workflows/update-skills.yml). Do not edit files in `skills/` directly — changes will be overwritten. Contribute new skills to the upstream repo instead.

## Reporting Issues

- Use [GitHub Issues](https://github.com/cockroachdb/claude-plugin/issues) for bugs and feature requests.
- Include your plugin version (`plugin.json` → `version`), Claude Code version, and OS.
- For connection issues, include the MCP backend you're using (Toolbox, Cloud MCP, or ccloud).

## License

By contributing, you agree that your contributions will be licensed under the [Apache-2.0 License](LICENSE).
