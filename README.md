# CockroachDB Plugin for Claude Code

[![Release Please](https://github.com/cockroachdb/claude-plugin/actions/workflows/release-please.yml/badge.svg)](https://github.com/cockroachdb/claude-plugin/actions/workflows/release-please.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Connect [Claude Code](https://code.claude.com/) directly to your CockroachDB clusters for hands-on database work — explore schemas, write optimized SQL, debug queries, and manage distributed database clusters. This plugin provides tools across MCP backends (self-hosted MCP Toolbox and managed CockroachDB Cloud MCP Server), specialized agents (DBA, Developer, Operator), skills across operational domains, and built-in safety hooks.

## Installation

Install from the [Claude Marketplace](https://claude.com/plugins/cockroachdb), or in Claude Code run:

```
/plugin install cockroachdb@claude-plugins-official
```

To install from this repository's own marketplace instead:

```
/plugin marketplace add cockroachdb/claude-plugin
/plugin install cockroachdb@cockroachdb-claude-plugin
```

### Local development

```bash
claude --plugin-dir /path/to/claude-plugin
```

### Prerequisites

The skills, agents, and hooks work without any setup. Each of the plugin's MCP servers needs its own:

- **`cockroachdb-toolbox`** (any self-hosted or Cloud cluster) needs [MCP Toolbox for Databases](https://github.com/googleapis/mcp-toolbox) v1.0.0 or later on your `PATH`, and a running CockroachDB cluster it can reach. Toolbox connects when the session starts, so without a reachable cluster this server fails to start. If you don't run a cluster, [turn the server off](#turn-off-a-server-you-dont-use).
- **`cockroachdb-cloud`** (CockroachDB Cloud) needs a CockroachDB Cloud account. Run `/mcp` and select the server to sign in.

#### Install MCP Toolbox

macOS or Linux:

```bash
brew install mcp-toolbox
```

Windows: download `toolbox.exe` into a folder on your `PATH`. In PowerShell, set the version to the latest one on the [Toolbox releases page](https://github.com/googleapis/mcp-toolbox/releases), and use `windows/arm64` in the URL on Arm devices:

```powershell
$VERSION = "1.14.0"
curl.exe -o toolbox.exe "https://storage.googleapis.com/mcp-toolbox-for-databases/v$VERSION/windows/amd64/toolbox.exe"
```

Restart Claude after changing your `PATH`, then confirm the install with `toolbox --version`. For other platforms, the container image, and building from source, see [Install Toolbox](https://github.com/googleapis/mcp-toolbox#install-toolbox).

## Configuration

### Self-hosted clusters (MCP Toolbox)

The `cockroachdb-toolbox` server reads its connection settings from environment variables. Each one is optional, and an unset variable falls back to its default:

| Variable               | Default     | Notes                                                                        |
|------------------------|-------------|------------------------------------------------------------------------------|
| `COCKROACHDB_HOST`     | `localhost` |                                                                              |
| `COCKROACHDB_PORT`     | `26257`     |                                                                              |
| `COCKROACHDB_USER`     | `root`      |                                                                              |
| `COCKROACHDB_PASSWORD` | (empty)     |                                                                              |
| `COCKROACHDB_DATABASE` | `defaultdb` |                                                                              |
| `COCKROACHDB_SSLMODE`  | `require`   | Use `disable` for a local `--insecure` cluster, `verify-full` for production |

Set them in the environment Claude starts from. On macOS or Linux, add them to your shell profile:

```bash
export COCKROACHDB_HOST="your-cluster-host"
export COCKROACHDB_PORT="26257"
export COCKROACHDB_USER="your-user"
export COCKROACHDB_PASSWORD="your-password"
export COCKROACHDB_DATABASE="your-database"
export COCKROACHDB_SSLMODE="verify-full"
```

On Windows, set them as user environment variables, for example `setx COCKROACHDB_HOST "your-cluster-host"`, then restart Claude.

For a CockroachDB Cloud cluster, find the connection details in the [Cloud Console](https://cockroachlabs.cloud/).

Toolbox runs in read-only mode: `SELECT`, `SHOW`, and `EXPLAIN` work, and writes and schema changes are rejected. To allow writes, run Toolbox with your own copy of [`tools.yaml`](tools.yaml) that sets `enableWriteMode: true`, configured as your own MCP server, and turn off the plugin's `cockroachdb-toolbox` server.

### CockroachDB Cloud

The `cockroachdb-cloud` server connects to the [managed MCP server](https://www.cockroachlabs.com/docs/cockroachcloud/connect-to-the-cockroachdb-cloud-mcp-server) that Cockroach Labs hosts. Run `/mcp`, select `cockroachdb-cloud`, and sign in. The consent screen asks you to grant read access, write access, or both.

By default the connection can reach every cluster your CockroachDB Cloud role allows. To limit it to one cluster, set `COCKROACHDB_CLUSTER_ID` to that cluster's ID.

### Turn off a server you don't use

Claude Code starts both MCP servers in every session. If you only use one of them, open `/mcp`, select the other, and disable it. Claude Code remembers the choice for each project.

### Alternative MCP Backends

The plugin ships with the **MCP Toolbox** (stdio) and **CockroachDB Cloud MCP** backends active by default. To add another backend, put its entry in your own MCP configuration (for example a project `.mcp.json`) or add it with `claude mcp add`:

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

Or via CLI: `claude mcp add --transport http cockroachdb-toolbox-http http://your-toolbox-host:5000/mcp`

Run Toolbox in HTTP mode: `toolbox --config tools.yaml --address 0.0.0.0 --port 5000`

Run Toolbox with the built-in web UI: `toolbox --config tools.yaml --ui --port 5000` (opens at `http://127.0.0.1:5000/ui`)

> **Note:** Toolbox must successfully connect to CockroachDB on startup. If the database is unreachable (wrong host/port, env vars not set), the server will hang during initialization and the UI will be stuck on "Fetching tools...". Make sure your `COCKROACHDB_*` environment variables are set and the database is accessible before starting.
</details>

<details>
<summary><strong>CockroachDB MCP Server</strong> (first-party, self-hosted)</summary>

[CockroachDB MCP Server](https://github.com/cockroachdb/cockroachdb-mcp-server) is Cockroach Labs' own MCP server for clusters you run yourself. By default it registers only read-only tools, such as `list_databases`, `list_tables`, `get_table_schema`, `select_query`, `explain_query`, `show_statement`, and `show_running_queries`. Setting `CRDB_MCP_ENABLE_WRITE_QUERIES=true` adds `create_database`, `create_table`, `insert_rows`, `update_rows`, and `delete_rows`, and the server refuses an `UPDATE` or `DELETE` without a `WHERE` clause.

**Install:** `go install github.com/cockroachdb/cockroachdb-mcp-server@latest` (Go 1.26+). Linux and Windows binaries and a Docker image are listed on the [releases page](https://github.com/cockroachdb/cockroachdb-mcp-server/releases). There are no prebuilt macOS binaries, so on macOS use `go install` or Docker.

**Configure** with certificate authentication (recommended):
```json
{
  "mcpServers": {
    "cockroachdb-mcp-server": {
      "command": "cockroachdb-mcp-server",
      "env": {
        "CRDB_HOST": "your-cluster-host",
        "CRDB_USERNAME": "ai_agent",
        "CRDB_SSL_MODE": "verify-full",
        "CRDB_SSL_CA_PATH": "/certs/ca.crt",
        "CRDB_SSL_CERTFILE": "/certs/client.ai_agent.crt",
        "CRDB_SSL_KEYFILE": "/certs/client.ai_agent.key"
      }
    }
  }
}
```

For a local `--insecure` development cluster:

```bash
claude mcp add cockroachdb-mcp-server -e CRDB_DATABASE_URL="postgresql://root@localhost:26257/defaultdb?sslmode=disable" -e CRDB_MCP_ALLOW_INSECURE_DB=true -- cockroachdb-mcp-server
```

Password authentication is off unless you set `CRDB_MCP_ALLOW_PASSWORD_AUTH=true`. Desktop apps may not search `~/go/bin`, so give the binary's absolute path as the `command` if the server doesn't start. The plugin's SQL safety hook applies to the bundled Toolbox server; this server enforces its own guardrails. See the [server's README](https://github.com/cockroachdb/cockroachdb-mcp-server#configuration) for every setting.
</details>

<details>
<summary><strong>ccloud CLI</strong> (cluster lifecycle, backups, DR, networking)</summary>

The [`ccloud` CLI](https://www.cockroachlabs.com/blog/cockroachdb-ai-agents-cli-database-automation/) is an agent-ready command-line tool for full cluster lifecycle management. AI agents call ccloud directly via shell commands (not MCP protocol) -- every command supports `-o json` for structured output.

**Install:** `brew install cockroachdb/tap/ccloud`

**Authenticate (interactive):** `ccloud auth login` (opens browser; supports SSO via OIDC/SAMLv2)

**Authenticate (org-scoped):** `ccloud auth login --org {organization-label}`

**Authenticate (headless/CI):** `ccloud auth login --no-redirect` or use a service account API key as a bearer token.

**Example agent commands:**
```bash
# Provision
ccloud cluster create serverless my-cluster us-east-1 --cloud AWS -o json
ccloud cluster database create my-cluster myapp -o json

# Connect
ccloud cluster connection-string my-cluster --database myapp --sql-user maxroach -o json
# Composable: pipe into jq + psql
ccloud cluster connection-string my-cluster --database myapp --sql-user maxroach -o json \
  | jq -r '.connection_url' | xargs -I{} psql {} -c "SELECT count(*) FROM users"

# Operate
ccloud cluster list -o json
ccloud cluster info my-cluster -o json
ccloud cluster backup config update my-cluster --frequency 60 --retention 60

# Observe
ccloud audit list --limit 10 -o json
ccloud cluster versions -o json
ccloud cluster cmek get my-cluster -o json

# Scale & DR
ccloud replication create --primary-cluster prod-east --standby-cluster dr-west
ccloud cluster networking allowlist list <cluster-id> -o json

# Organize
ccloud folder create Production -o json
ccloud folder contents <folder-id> -o json

# Test resilience
ccloud cluster disruption set my-cluster --region us-east-1 --whole-region
```

**Coverage:** Provision, Connect, Operate, Observe, Scale & DR, Organize, Test resilience. See the [ccloud reference](https://www.cockroachlabs.com/docs/cockroachcloud/ccloud-reference) for full command list.
</details>

<details>
<summary><strong>CockroachDB Cloud MCP Server</strong> (OAuth/API key)</summary>

The official [managed MCP server](https://www.cockroachlabs.com/blog/cockroachdb-ai-agents-managed-mcp-server/) is hosted by Cockroach Labs and requires no infrastructure setup. The plugin already includes it as `cockroachdb-cloud`; use these snippets to configure it yourself, for example with a service account API key. With OAuth 2.1 (PKCE), the consent screen asks you to grant read access, write access, or both (scopes `mcp:read` and `mcp:write`).

**OAuth (recommended, opens a browser for consent):**
```json
{
  "mcpServers": {
    "cockroachdb-cloud": {
      "type": "http",
      "url": "https://cockroachlabs.cloud/mcp"
    }
  }
}
```

**API key (headless or autonomous agents):**
```json
{
  "mcpServers": {
    "cockroachdb-cloud": {
      "type": "http",
      "url": "https://cockroachlabs.cloud/mcp",
      "headers": {
        "Authorization": "Bearer {your-service-account-api-key}"
      }
    }
  }
}
```

Without an `mcp-cluster-id` header, a connection can reach every cluster your user or service account can access. To limit it to one cluster, add `"mcp-cluster-id": "{your-cluster-id}"` to `headers`.

Or via CLI: `claude mcp add --transport http cockroachdb-cloud https://cockroachlabs.cloud/mcp`, adding `--header "mcp-cluster-id: {your-cluster-id}"` to limit the connection to one cluster.

See the [quickstart guide](https://www.cockroachlabs.com/docs/cockroachcloud/connect-to-the-cockroachdb-cloud-mcp-server) for detailed setup.
</details>

## What's Included

### MCP Backends

| Backend                    | Status      | Transport       | Use Case                                                                                                                          |
|----------------------------|-------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `cockroachdb-toolbox`      | Active      | stdio           | Any CockroachDB cluster via [MCP Toolbox](https://github.com/googleapis/mcp-toolbox)                                            |
| `cockroachdb-cloud`        | Active      | Streamable HTTP | [Managed MCP Server](https://www.cockroachlabs.com/blog/cockroachdb-ai-agents-managed-mcp-server/) — CockroachDB Cloud (OAuth/API key) |
| `cockroachdb-toolbox-http` | Available   | HTTP            | MCP Toolbox remote/multi-user via HTTP (not shipped; add it yourself, see Alternative MCP Backends)                               |
| `cockroachdb-mcp-server`   | Available   | stdio, HTTPS    | First-party server for self-hosted clusters (not shipped; add it yourself, see Alternative MCP Backends)                          |

### CLI Tools

| Tool              | Status | Use Case                                                                                                                                           |
|-------------------|--------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| `ccloud`          | Active | [Agent-ready CLI](https://www.cockroachlabs.com/blog/cockroachdb-ai-agents-cli-database-automation/) — cluster lifecycle, backups, DR, networking, audit. Agents call directly via shell. |

### Tools

**MCP Toolbox** (self-hosted, any cluster):

| Tool                       | Description                                      |
|----------------------------|--------------------------------------------------|
| `cockroachdb-execute-sql`  | Run SQL (read-only unless write mode is enabled) |
| `cockroachdb-list-schemas` | List all schemas in the database                 |
| `cockroachdb-list-tables`  | List tables with columns, types, and constraints |

**CockroachDB Cloud MCP** (managed, read tools):

| Tool                    | Description                                 |
|-------------------------|---------------------------------------------|
| `list_clusters`         | List all accessible clusters                |
| `get_cluster`           | Get detailed cluster information            |
| `list_databases`        | List databases in the cluster               |
| `list_tables`           | List tables in a database                   |
| `get_table_schema`      | Get detailed schema for a table             |
| `select_query`          | Execute a SELECT statement                  |
| `explain_query`         | Execute an EXPLAIN statement                |
| `show_running_queries`  | List currently executing queries            |

**CockroachDB Cloud MCP** (managed, write tools — requires write consent):

| Tool                    | Description                                 |
|-------------------------|---------------------------------------------|
| `create_database`       | Create a new database                       |
| `create_table`          | Create a new table                          |
| `insert_rows`           | Insert rows into a table                    |

### Skills

Skills are sourced from the [`cockroachdb-skills`](https://github.com/cockroachlabs/cockroachdb-skills) submodule via symlinks — a single source of truth shared across CockroachDB agent integrations. A [weekly CI workflow](.github/workflows/update-skills.yml) auto-detects upstream changes and opens a PR to update.

| Domain                             | Examples                                                     |
|------------------------------------|--------------------------------------------------------------|
| **Query & Schema Design**          | cockroachdb-sql                                              |
| **Observability & Diagnostics**    | profiling-statement-fingerprints, triaging-live-sql-activity |
| **Security & Governance**          | auditing-cloud-cluster-security, hardening-user-privileges   |
| **Onboarding & Migrations**        | molt-fetch, molt-verify, molt-replicator                     |
| **Operations & Lifecycle**         | managing-cluster-capacity, upgrading-cluster-version         |

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

**Windows note:** the hooks invoke `python3`, so make sure a `python3` is on your `PATH`. The python.org installer creates `python.exe` and the `py` launcher but **not** `python3.exe`; on those installs the hooks safely no-op (they never block editing, but the safety checks won't run). Installing Python from the Microsoft Store — or adding a `python3` alias — enables them. You do **not** need to turn on Windows long-path support: the hooks load their scripts through the `\\?\` long-path prefix, so they work no matter how deep the plugin cache path is.

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
  plugin.json                  # Plugin manifest with component declarations
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
skills/                        # Skills copied from cockroachdb-skills submodule
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
- [Managed MCP Server Blog Post](https://www.cockroachlabs.com/blog/cockroachdb-ai-agents-managed-mcp-server/)
- [Cloud MCP Quickstart Guide](https://www.cockroachlabs.com/docs/cockroachcloud/connect-to-the-cockroachdb-cloud-mcp-server)
- [ccloud CLI for AI Agents Blog Post](https://www.cockroachlabs.com/blog/cockroachdb-ai-agents-cli-database-automation/)
- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins)
- [Plugin Marketplace Docs](https://code.claude.com/docs/en/plugin-marketplaces)
- [ccloud CLI](https://www.cockroachlabs.com/docs/cockroachcloud/ccloud-get-started)
- [MCP Toolbox for Databases](https://github.com/googleapis/mcp-toolbox)
- [Report Issues](https://github.com/cockroachdb/claude-plugin/issues)

## License

[Apache-2.0](LICENSE)
