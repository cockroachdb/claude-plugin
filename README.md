# CockroachDB Plugin for Claude Code

[![Release Please](https://github.com/cockroachdb/claude-plugin/actions/workflows/release-please.yml/badge.svg)](https://github.com/cockroachdb/claude-plugin/actions/workflows/release-please.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

The CockroachDB plugin for [Claude Code](https://code.claude.com/) gives your AI coding agent direct access to CockroachDB databases — explore schemas, write optimized SQL, debug queries, and manage distributed clusters.

## Installation

### From the CockroachDB marketplace

Add the marketplace and install the plugin:

```
/plugin marketplace add cockroachdb/claude-plugin
/plugin install cockroachdb@cockroachdb-claude-plugin
```

### Local development

```bash
claude --plugin-dir /path/to/claude-plugin
```

### Prerequisites

This plugin connects to CockroachDB via MCP (Model Context Protocol) using [MCP Toolbox for Databases](https://github.com/googleapis/genai-toolbox) (v0.27.0+):

```bash
brew install mcp-toolbox
```

## Configuration

Set environment variables for your CockroachDB connection:

```bash
export COCKROACHDB_HOST="your-cluster-host"
export COCKROACHDB_PORT="26257"
export COCKROACHDB_USER="your-user"
export COCKROACHDB_PASSWORD="your-password"
export COCKROACHDB_DATABASE="your-database"
export COCKROACHDB_SSLMODE="verify-full"
```

For CockroachDB Cloud, find connection details in the [Cloud Console](https://cockroachlabs.cloud/).

### Alternative MCP Backends

The plugin ships with the **MCP Toolbox** (stdio) backend active by default. To use a different backend, replace the contents of `.mcp.json`:

<details>
<summary><strong>MCP Toolbox via HTTP</strong> (remote/multi-user)</summary>

```json
{
  "mcpServers": {
    "cockroachdb-toolbox-http": {
      "type": "http",
      "url": "http://your-toolbox-host:5000/mcp"
    }
  }
}
```

Run Toolbox in HTTP mode: `toolbox --tools-file tools.yaml --address 0.0.0.0:5000`
</details>

<details>
<summary><strong>ccloud CLI</strong> (cluster lifecycle, backups, DR) — Coming soon</summary>

```json
{
  "mcpServers": {
    "ccloud": {
      "command": "ccloud",
      "args": ["mcp"],
      "env": {
        "CCLOUD_API_KEY": "${CCLOUD_API_KEY}"
      }
    }
  }
}
```

Requires [ccloud CLI](https://www.cockroachlabs.com/docs/cockroachcloud/ccloud-get-started).
</details>

<details>
<summary><strong>CockroachDB Cloud MCP Server</strong> (OAuth/API key) — Coming soon</summary>

```json
{
  "mcpServers": {
    "cockroachdb-cloud": {
      "type": "http",
      "url": "https://mcp.cockroachlabs.cloud"
    }
  }
}
```
</details>

## What's Included

### MCP Backends

| Backend                    | Status      | Transport       | Use Case                                                                                                                          |
|----------------------------|-------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `cockroachdb-toolbox`      | Active      | stdio           | Any CockroachDB cluster via [MCP Toolbox](https://github.com/googleapis/genai-toolbox)                                            |
| `cockroachdb-toolbox-http` | Available   | Streamable HTTP | Same as above, remote/multi-user via HTTP                                                                                         |
| `ccloud`                   | Coming soon | stdio           | Cluster lifecycle, backups, DR, networking via [ccloud CLI](https://www.cockroachlabs.com/docs/cockroachcloud/ccloud-get-started) |
| `cockroachdb-cloud`        | Coming soon | HTTP            | CockroachDB Cloud MCP Server (OAuth/API key)                                                                                      |

### Tools

| Tool                       | Description                                      |
|----------------------------|--------------------------------------------------|
| `cockroachdb-execute-sql`  | Execute SQL statements (SELECT, DDL, DML)        |
| `cockroachdb-list-schemas` | List all schemas in the database                 |
| `cockroachdb-list-tables`  | List tables with columns, types, and constraints |

### Skills

22 skills from [cockroachdb-skills](https://github.com/cockroachlabs/cockroachdb-skills) across multiple operational domains:

| Domain                             | Skills | Examples                                                     |
|------------------------------------|--------|--------------------------------------------------------------|
| **Query & Schema Design**          | 1      | cockroachdb-sql                                              |
| **Observability & Diagnostics**    | 7      | profiling-statement-fingerprints, triaging-live-sql-activity |
| **Security & Governance**          | 11     | auditing-cloud-cluster-security, hardening-user-privileges   |
| **Onboarding & Migrations**        | 3      | molt-fetch, molt-verify, molt-replicator                     |

Skills are sourced from the [`cockroachdb-skills`](https://github.com/cockroachlabs/cockroachdb-skills) submodule via symlinks — a single source of truth shared across CockroachDB agent integrations.

### Agents

| Agent                    | Description                                                                          |
|--------------------------|--------------------------------------------------------------------------------------|
| `cockroachdb-dba`        | CockroachDB DBA expert — performance tuning, schema review, cluster diagnostics      |
| `cockroachdb-developer`  | Application developer expert — ORM config, retry logic, transaction patterns         |
| `cockroachdb-operator`   | Operator/SRE expert — cluster operations, monitoring, backups, scaling, incidents    |

Agents are auto-discovered from the `agents/` directory. Claude invokes them automatically based on task context, or you can reference them directly (e.g., "ask the cockroachdb-dba agent to review this schema").

### Hooks

| Hook              | Trigger               | What It Does                                                                         |
|-------------------|-----------------------|--------------------------------------------------------------------------------------|
| `validate-sql`    | Before SQL execution  | Blocks DROP DATABASE, TRUNCATE; warns on SERIAL, multi-DDL transactions              |
| `check-sql-files` | After file Write/Edit | Scans SQL/code files for CockroachDB anti-patterns (SERIAL, SELECT *, missing retry) |

Hooks run as Python scripts (Python 3, no external dependencies) and provide automated safety guardrails.

## Development

Clone the repository:

```bash
git clone --recurse-submodules https://github.com/cockroachdb/claude-plugin.git
cd claude-plugin
```

Test locally:

```bash
claude --plugin-dir .
```

Validate the plugin:

```bash
claude plugin validate .
```

### Project Structure

```
.claude-plugin/
  plugin.json                  # Plugin manifest (metadata only)
  marketplace.json             # Marketplace catalog for distribution
.mcp.json                      # MCP server configuration
tools.yaml                     # Toolbox source & tool definitions
agents/
  cockroachdb-dba.md           # DBA agent
  cockroachdb-developer.md     # Developer agent
  cockroachdb-operator.md      # Operator agent
hooks/
  hooks.json                   # Hook configuration
scripts/
  validate-sql.py              # SQL validation hook
  check-sql-files.py           # Anti-pattern linter hook
skills/                        # 22 symlinks to cockroachdb-skills submodule
submodules/
  cockroachdb-skills/          # Shared skills submodule
assets/
  logo.svg                     # Plugin logo
```

## Releasing

This repo uses [Release Please](https://github.com/googleapis/release-please) for automated releases.

1. Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`) on `main`
2. Release Please opens a Release PR with version bump and changelog
3. Merge the Release PR to publish

## Links

- [CockroachDB Documentation](https://www.cockroachlabs.com/docs/)
- [CockroachDB Cloud Console](https://cockroachlabs.cloud/)
- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins)
- [Plugin Marketplace Docs](https://code.claude.com/docs/en/plugin-marketplaces)
- [ccloud CLI](https://www.cockroachlabs.com/docs/cockroachcloud/ccloud-get-started)
- [MCP Toolbox for Databases](https://github.com/googleapis/genai-toolbox)
- [Report Issues](https://github.com/cockroachdb/claude-plugin/issues)

## License

[Apache-2.0](LICENSE)
