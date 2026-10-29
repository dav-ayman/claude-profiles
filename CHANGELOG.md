# Changelog

All notable changes are listed here. This project uses [Semantic Versioning](https://semver.org).

## [1.0.0] - 2026-10-29

### Added

- `claude-profiles add|list|open|refresh|remove|doctor`.
- One Desktop launcher per profile (`~/Applications/Claude <Label>.app`) with its own data folder, a badge icon and single-window focus.
- One Claude Code command per profile (`claude-<name>`) with its own `CLAUDE_CONFIG_DIR`.
- A `--default` profile that keeps Claude's normal folders and sign-in.
- Desktop's Code tab follows the profile's Claude Code folder.
- Badge icons drawn on your Mac from your own Claude icon, including full-bleed icons for macOS 26.
- `install.sh` with no sudo, plus `--uninstall`.
- A bats test suite run in CI on macOS 14, 15 and 26 (Apple Silicon) and macOS 15 (Intel).
