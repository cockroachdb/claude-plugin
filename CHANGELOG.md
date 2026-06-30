# Changelog

## [0.1.10](https://github.com/cockroachdb/claude-plugin/compare/v0.1.9...v0.1.10) (2026-06-30)


### Bug Fixes

* make hooks work on Windows by loading scripts long-path-safe ([#21](https://github.com/cockroachdb/claude-plugin/issues/21)) ([81f29eb](https://github.com/cockroachdb/claude-plugin/commit/81f29eb855cbce189b326b2f3724c8f7a8396205))

## [0.1.9](https://github.com/cockroachdb/claude-plugin/compare/v0.1.8...v0.1.9) (2026-05-03)


### Features

* add setup-cockroachdb.sh for local 3-node cluster provisioning ([7858cde](https://github.com/cockroachdb/claude-plugin/commit/7858cdee4e12151b87fdda2816c4c4502220e4d6))

## [0.1.8](https://github.com/cockroachdb/claude-plugin/compare/v0.1.7...v0.1.8) (2026-04-23)


### Bug Fixes

* quote CLAUDE_PLUGIN_ROOT in hooks.json for paths with spaces ([#11](https://github.com/cockroachdb/claude-plugin/issues/11)) ([582031c](https://github.com/cockroachdb/claude-plugin/commit/582031c5ee7adf3d8b4e7931cd9a3c92253a7359))

## [0.1.7](https://github.com/cockroachdb/claude-plugin/compare/v0.1.6...v0.1.7) (2026-04-22)


### Bug Fixes

* migrate toolbox config to v1.1.0 map-based format ([7270ff6](https://github.com/cockroachdb/claude-plugin/commit/7270ff641284a26e4a0a33f8d2ccd4bf247e6b7e))

## [0.1.6](https://github.com/cockroachdb/claude-plugin/compare/v0.1.5...v0.1.6) (2026-04-21)


### Bug Fixes

* update author to Cockroach Labs for marketplace consistency ([ef2d8b3](https://github.com/cockroachdb/claude-plugin/commit/ef2d8b370e4d844e640700a552ec3287e1e479cf))

## [0.1.5](https://github.com/cockroachdb/claude-plugin/compare/v0.1.4...v0.1.5) (2026-04-10)


### Bug Fixes

* add explicit skills paths to plugin.json for marketplace discovery ([e427948](https://github.com/cockroachdb/claude-plugin/commit/e4279485261053ef9839e578cc0d81b74943e11f))

## [0.1.4](https://github.com/cockroachdb/claude-plugin/compare/v0.1.3...v0.1.4) (2026-04-09)


### Bug Fixes

* restructure skills to match upstream category hierarchy ([572e840](https://github.com/cockroachdb/claude-plugin/commit/572e840cd0f2adea6500d15f88d8d55e13b5c1a2))

## [0.1.3](https://github.com/cockroachdb/claude-plugin/compare/v0.1.2...v0.1.3) (2026-03-26)


### Features

* add Cloud MCP and ccloud CLI GA support across all backends and agents ([c222245](https://github.com/cockroachdb/claude-plugin/commit/c222245827582cd4146d2139a91398b3831e58b4))

## [0.1.2](https://github.com/cockroachdb/claude-plugin/compare/v0.1.1...v0.1.2) (2026-03-24)


### Features

* add marketplace.json and update README ([966724e](https://github.com/cockroachdb/claude-plugin/commit/966724e47060b20a94c77c4c0c880471447eb1e5))


### Bug Fixes

* flatten skill symlinks, add SSLMODE, remove agent tool restrictions ([a6aceb4](https://github.com/cockroachdb/claude-plugin/commit/a6aceb4e6ee6040ce19889ff131ba02a82b245fd))
* remove agents field from plugin.json to fix manifest validation ([54bf488](https://github.com/cockroachdb/claude-plugin/commit/54bf4888e13c3cc3b16b2edcdd9ab3013aac52a0))
* replace skill symlinks with real directories for marketplace compatibility ([ffdef52](https://github.com/cockroachdb/claude-plugin/commit/ffdef52b1f14de224b5bad95d300079e9def742d))

## [0.1.1](https://github.com/cockroachdb/claude-plugin/compare/v0.1.0...v0.1.1) (2026-03-17)


### Features

* initial CockroachDB plugin for Claude Code ([91891ef](https://github.com/cockroachdb/claude-plugin/commit/91891ef5daa37a39c57d0ee3fb84e02bde672378))

## Changelog
