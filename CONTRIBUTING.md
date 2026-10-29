# Contributing

Thanks for helping out. Bug reports, fixes, docs and new ideas are all welcome.

## Ground rules

- **Stock macOS only.** The tool must run on a fresh Mac with nothing installed: `/bin/bash` 3.2, `osascript`, `sips`, `iconutil`, `codesign`, `plutil`. No Python, Node, jq, Homebrew or Xcode at run time.
- **Never touch Claude.app.** Profiles work through launch arguments and environment variables only, so Claude's signature and auto-updates stay intact.
- **Never delete what we didn't create.** Anything claude-profiles writes carries a `managed-by: claude-profiles` marker, and anything without it is left alone.
- **Profile files are data.** They're parsed line by line and never sourced or `eval`ed.

## Dev setup

```sh
git clone https://github.com/dav-ayman/claude-profiles
cd claude-profiles
brew install bats-core shellcheck
make lint test
```

Run the CLI straight from the checkout with `bin/claude-profiles ...`.

The tests never touch your real Claude or profiles. Each test gets a throwaway `HOME` (with a space in the path, to catch quoting bugs) and a fake `Claude.app` that logs the arguments and `CLAUDE_CONFIG_DIR` it was launched with.

## Pull requests

1. Open an issue first for bigger changes, so we can agree on the approach.
2. Add or update a test in `test/claude-profiles.bats` for any behavior change.
3. `make lint test` must pass. CI runs on macOS 14, 15 and 26 (Apple Silicon) and macOS 15 (Intel).
4. Update `README.md` and `CHANGELOG.md` when users would notice the change.

## Ideas we'd love help with

- Windows support (PowerShell launchers with `--user-data-dir`)
- A Homebrew tap
- Optional per-profile Dock icon tint while the app is running
