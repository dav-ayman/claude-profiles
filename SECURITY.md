# Security

## Reporting a vulnerability

Please report security issues privately through [GitHub security advisories](https://github.com/dav-ayman/claude-profiles/security/advisories/new). Don't open a public issue for them. You'll get a reply within a few days.

## What claude-profiles does and doesn't do

- Runs as your user. It never asks for `sudo` and never changes system files.
- Doesn't modify, re-sign or patch `Claude.app`. It starts the app you already have with `--user-data-dir` and `CLAUDE_CONFIG_DIR`.
- Never reads, copies or sends your sign-in tokens. Each profile signs in on its own, inside Claude.
- Makes no network calls at run time. Only `install.sh` downloads, and only from this GitHub repo.
- Stores profile settings as plain `key=value` files under `~/.config/claude-profiles` and never executes them.
- Leaves files it didn't create alone, and refuses to delete Claude's default folders.

Launchers are signed ad hoc (`codesign -s -`) on your Mac, so macOS treats them like apps you built yourself.
