#!/bin/bash
# Installer for claude-profiles. No sudo, installs into ~/.local by default.
#
#   curl -fsSL https://raw.githubusercontent.com/dav-ayman/claude-profiles/main/install.sh | bash
#
# Options (environment variables):
#   CLAUDE_PROFILES_PREFIX   install prefix          (default: ~/.local)
#   CLAUDE_PROFILES_REF      git tag or branch to get (default: latest release, else main)
#
# Uninstall the tool (your profiles stay):  bash install.sh --uninstall
#
# SPDX-License-Identifier: MIT

set -Eeuo pipefail
USER_PATH="${PATH:-}"
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
umask 022

REPO="dav-ayman/claude-profiles"
PREFIX="${CLAUDE_PROFILES_PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin/claude-profiles"
SHARE="$PREFIX/share/claude-profiles"

say()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "claude-profiles runs on macOS only"
[ "$(id -u)" != 0 ] || die "do not run this installer as root"
case "$PREFIX" in /*) ;; *) die "CLAUDE_PROFILES_PREFIX must be an absolute path" ;; esac

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$BIN"
  rm -rf "$SHARE"
  say "Removed claude-profiles from $PREFIX."
  say "Launchers, claude-<name> commands and profile data were left in place."
  say "Run 'claude-profiles remove <name>' before uninstalling to clean those up."
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/claude-profiles-install.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Install from this checkout when run as ./install.sh, otherwise download.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$here/bin/claude-profiles" ] && [ -f "$here/lib/icon.js" ] && SRC="$here"
fi

if [ -z "$SRC" ]; then
  REF="${CLAUDE_PROFILES_REF:-}"
  if [ -z "$REF" ]; then
    REF="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 || true)"
    [ -n "$REF" ] || REF="main"
  fi
  case "$REF" in *[!A-Za-z0-9._/-]*) die "invalid CLAUDE_PROFILES_REF: $REF" ;; esac
  say "Downloading claude-profiles ($REF)..."
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" -o "$WORK/src.tgz" \
    || die "download failed for $REF"
  mkdir "$WORK/src"
  tar -xzf "$WORK/src.tgz" -C "$WORK/src" --strip-components 1
  SRC="$WORK/src"
  [ -f "$SRC/bin/claude-profiles" ] && [ -f "$SRC/lib/icon.js" ] || die "download looks incomplete"
fi

mkdir -p "$PREFIX/bin" "$SHARE"
install -m 0755 "$SRC/bin/claude-profiles" "$BIN.tmp"
install -m 0644 "$SRC/lib/icon.js" "$SHARE/icon.js"
mv -f "$BIN.tmp" "$BIN"

"$BIN" version >/dev/null || die "installed binary does not run"
say "Installed $("$BIN" version) to $BIN"

case ":$USER_PATH:" in
  *":$PREFIX/bin:"*) ;;
  *)
  say ""
  say "Add $PREFIX/bin to your PATH, for example in ~/.zshrc:"
  say "  export PATH=\"$PREFIX/bin:\$PATH\""
  ;;
esac
say ""
say "Get started:"
say "  claude-profiles add work --default   # your current Claude becomes \"Claude Work\""
say "  claude-profiles add personal         # a second, separate profile"
