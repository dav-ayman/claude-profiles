# shellcheck shell=bash disable=SC2034  # variables are used by the .bats files
# Shared setup for the bats suite.
#
# Every test gets a throwaway HOME (with a space in its path, to catch quoting
# bugs) and a fake Claude.app whose executable is a small bash script. The fake
# app logs the arguments and CLAUDE_CONFIG_DIR it was started with, then idles,
# so launch behaviour can be checked without touching the real Claude Desktop.

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
CLI="$REPO_ROOT/bin/claude-profiles"

setup_sandbox() {
  SANDBOX="$(mktemp -d "${BATS_TMPDIR:-/tmp}/cp test.XXXXXX")"
  export HOME="$SANDBOX/home dir"
  export XDG_CONFIG_HOME="$HOME/.config"
  export CLAUDE_PROFILES_APPS_DIR="$HOME/Applications"
  export CLAUDE_PROFILES_BIN_DIR="$HOME/.local/bin"
  export NO_COLOR=1
  unset CLAUDE_CONFIG_DIR CLAUDE_PROFILES_ICON_STYLE
  mkdir -p "$HOME"
  make_fake_claude
}

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

teardown_sandbox() {
  stop_fake_claude
  # Unregister everything the test created so LaunchServices keeps no stale entries.
  if [ -n "${SANDBOX:-}" ]; then
    "$LSREGISTER" -dump 2>/dev/null | sed -n 's/^path: *\(.*\) (0x[0-9a-f]*)$/\1/p' | grep -F "$SANDBOX/" \
      | while IFS= read -r app; do "$LSREGISTER" -u "$app" >/dev/null 2>&1 || true; done
  fi
  [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}

make_fake_claude() {
  FAKE_APP="$SANDBOX/apps/Claude.app"
  LAUNCH_LOG="$SANDBOX/launches"
  mkdir -p "$FAKE_APP/Contents/MacOS" "$FAKE_APP/Contents/Resources" "$LAUNCH_LOG"
  cat > "$FAKE_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Claude</string>
<key>CFBundleIdentifier</key><string>test.claude-profiles.fake.$$.$RANDOM</string>
<key>CFBundleName</key><string>Claude</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>9.9.9</string>
<key>CFBundleIconFile</key><string>electron</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
  # A compiled stand-in behaves like the real (Mach-O) Claude; ps -E can read
  # its environment. Fall back to a script when no C compiler is installed.
  local bin="${BATS_RUN_TMPDIR:-$SANDBOX}/fake-claude-bin"
  if [ -x "$bin" ] || cc -O -o "$bin" "$REPO_ROOT/test/helpers/fake-claude.c" 2>/dev/null; then
    cp "$bin" "$FAKE_APP/Contents/MacOS/Claude"
    FAKE_IS_BINARY=1
  else
    cat > "$FAKE_APP/Contents/MacOS/Claude" <<'EOF'
#!/bin/bash
log="$(cd "$(dirname "$0")/../../../.." && pwd)/launches/$$.log"
{ printf 'args=%s\n' "$*"; printf 'cfg=%s\n' "${CLAUDE_CONFIG_DIR-<unset>}"; } > "$log"
while :; do sleep 1; done
EOF
    FAKE_IS_BINARY=0
  fi
  chmod +x "$FAKE_APP/Contents/MacOS/Claude"
  cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns \
    "$FAKE_APP/Contents/Resources/electron.icns"
  export CLAUDE_APP="$FAKE_APP"
}

fake_pids() { pgrep -f "$FAKE_APP/Contents/MacOS/Claude" || true; }
fake_count() { fake_pids | grep -c . || true; }

stop_fake_claude() {
  [ -n "${FAKE_APP:-}" ] || return 0
  pkill -f "$FAKE_APP/Contents/MacOS/Claude" 2>/dev/null || true
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(fake_count)" = 0 ] && return 0
    sleep 0.3
  done
}

# Wait until the fake app has written N launch logs.
wait_for_launches() {
  local want="$1" i n
  for i in $(seq 1 40); do
    n=$(find "$LAUNCH_LOG" -name '*.log' | grep -c . || true)
    [ "$n" -ge "$want" ] && return 0
    sleep 0.25
  done
  echo "expected $want launch(es), saw $n" >&2
  return 1
}

launch_logs() { cat "$LAUNCH_LOG"/*.log 2>/dev/null || true; }

assert_contains() {
  case "$1" in *"$2"*) return 0 ;; esac
  printf 'expected to find:\n  %s\nin:\n%s\n' "$2" "$1" >&2
  return 1
}

assert_not_contains() {
  case "$1" in *"$2"*) printf 'did not expect:\n  %s\nin:\n%s\n' "$2" "$1" >&2; return 1 ;; esac
  return 0
}
