# Agent instructions for claude-plugin

Guidance for AI coding assistants (and new contributors) working in this repo. It complements [CONTRIBUTING.md](./CONTRIBUTING.md); read that first for setup and the full workflow.

## What this repo is

The CockroachDB plugin for Claude Code: MCP backends (`.mcp.json` + `tools.yaml`), agents (`agents/`), skills (`skills/`), and safety hooks (`hooks/hooks.json` + `scripts/`).

## Rules that prevent breakage

- **Never edit `skills/` by hand.** Skills are synced from the [cockroachdb-skills](https://github.com/cockroachlabs/cockroachdb-skills) submodule by a weekly workflow that also regenerates the `skills` array in `.claude-plugin/plugin.json`. Changes there get overwritten. Contribute skills upstream instead.
- **Never bump versions by hand.** Release Please owns `version` in `.claude-plugin/plugin.json`, `.release-please-manifest.json`, and `CHANGELOG.md`. Use conventional commits: `fix:`/`feat:` cut a release, `chore:`/`docs:` do not (and that is fine, because installs pull from git, not release tarballs).
- **Keep the hook command pattern.** Hook commands load their script through a `runpy` bootstrap with a `\\?\` long-path prefix on Windows and a trailing `; exit 0`. This is load-bearing: it survives plugin cache paths past Windows MAX_PATH (issue #20) and hosts that fail to substitute `${CLAUDE_PLUGIN_ROOT}` (issue #23). A hook must never surface an error on every edit; when the interpreter cannot even open the script, it must fail open. The exact pattern is documented in CONTRIBUTING.
- **Hook scripts are Python 3 stdlib only**, read JSON on stdin, write JSON on stdout, and always exit 0 (blocking is signaled via `hookSpecificOutput.permissionDecision`, not exit codes).
- **No counts in descriptions.** Do not write "three agents" or "33 skills" anywhere; counts go stale. Name the things instead.

## Testing

Run the hook regression suite before touching anything under `hooks/` or `scripts/`:

```bash
bash scripts/test-hooks.sh
```

CI runs the same suite on any PR that touches those paths. It covers the deny/warn/lint cases plus the fail-open regressions for #20 and #23 (missing or unsubstituted plugin root must exit 0 with no output).

## Writing style

Commit messages and PR bodies in a plain human voice: conventional-commit prefixes, no AI attribution trailers, plain punctuation. Reference issues with closing keywords per issue (`Fixes #20. Fixes #23.`), since GitHub only links the number directly after each keyword.
