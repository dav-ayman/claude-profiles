#!/usr/bin/env bats

load helpers/common

setup() { setup_sandbox; }
teardown() { teardown_sandbox; }

# ---------------------------------------------------------------- basics

@test "version and help" {
  run "$CLI" version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^claude-profiles\ [0-9]+\.[0-9]+\.[0-9]+$ ]]

  run "$CLI" help
  [ "$status" -eq 0 ]
  assert_contains "$output" "claude-profiles add <name>"
}

@test "unknown command fails" {
  run "$CLI" frobnicate
  [ "$status" -ne 0 ]
  assert_contains "$output" "unknown command"
}

@test "runs under the stock macOS bash 3.2" {
  run /bin/bash "$CLI" version
  [ "$status" -eq 0 ]
}

@test "list with no profiles explains how to start" {
  run "$CLI" list
  [ "$status" -eq 0 ]
  assert_contains "$output" "No profiles yet"
}

# ---------------------------------------------------------------- validation

@test "rejects unsafe or malformed profile names" {
  for bad in "" "Work" "../x" "a b" "-x" "x-" "1abc" "a/b" 'x;rm' "abcdefghijklmnopqrstuvwxyzabcde"; do
    run "$CLI" add "$bad" --no-desktop
    [ "$status" -ne 0 ] || { echo "accepted: '$bad'"; false; }
  done
  [ ! -d "$XDG_CONFIG_HOME/claude-profiles/profiles" ] || [ -z "$(ls "$XDG_CONFIG_HOME/claude-profiles/profiles")" ]
}

@test "rejects bad badge letters, colors and labels" {
  run "$CLI" add p1 --letter AB;          [ "$status" -ne 0 ]
  run "$CLI" add p1 --letter '!';         [ "$status" -ne 0 ]
  run "$CLI" add p1 --color 12345;        [ "$status" -ne 0 ]
  run "$CLI" add p1 --color GGGGGG;       [ "$status" -ne 0 ]
  run "$CLI" add p1 --label 'a/b';        [ "$status" -ne 0 ]
  run "$CLI" add p1 --label ' lead';      [ "$status" -ne 0 ]
  run "$CLI" add p1 --data-dir relative;  [ "$status" -ne 0 ]
  run "$CLI" add p1 --data-dir /;         [ "$status" -ne 0 ]
  run "$CLI" add p1 --config-dir "~";     [ "$status" -ne 0 ]
}

@test "only one profile may use the default folders" {
  run "$CLI" add work --default
  [ "$status" -eq 0 ]
  run "$CLI" add home --default
  [ "$status" -ne 0 ]
  assert_contains "$output" "already uses the default folders"
}

@test "non-default profiles cannot point at the stock folders" {
  run "$CLI" add sneaky --data-dir "$HOME/Library/Application Support/Claude"
  [ "$status" -ne 0 ]
  run "$CLI" add sneaky --config-dir "~/.claude"
  [ "$status" -ne 0 ]
}

@test "two profiles cannot share folders or labels" {
  run "$CLI" add one --data-dir "$HOME/shared"
  [ "$status" -eq 0 ]
  run "$CLI" add two --data-dir "$HOME/shared"
  [ "$status" -ne 0 ]
  run "$CLI" add three --label One
  [ "$status" -ne 0 ]
}

@test "duplicate profile name is refused" {
  run "$CLI" add personal --no-desktop
  [ "$status" -eq 0 ]
  run "$CLI" add personal --no-desktop
  [ "$status" -ne 0 ]
  assert_contains "$output" "already exists"
}

@test "damaged profile files are rejected, never executed" {
  mkdir -p "$XDG_CONFIG_HOME/claude-profiles/profiles"
  printf 'label=$(touch %s/pwned)\nletter=P\ncolor=16A34A\ndata_dir=%s/d\nconfig_dir=%s/c\n' \
    "$SANDBOX" "$HOME" "$HOME" > "$XDG_CONFIG_HOME/claude-profiles/profiles/evil.conf"
  run "$CLI" list
  [ "$status" -ne 0 ]
  assert_contains "$output" "damaged"
  [ ! -e "$SANDBOX/pwned" ]
}

# ---------------------------------------------------------------- add

@test "add creates a signed launcher with badge icon, launch script and marker" {
  run "$CLI" add personal
  [ "$status" -eq 0 ]
  app="$HOME/Applications/Claude Personal.app"
  [ -d "$app" ]
  [ -f "$app/Contents/Resources/claude-profiles.marker" ]
  [ -x "$app/Contents/Resources/launch.sh" ]
  [ -s "$app/Contents/Resources/applet.icns" ]
  codesign --verify "$app"
  run /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Contents/Info.plist"
  [ "$output" = "io.github.dav-ayman.claude-profiles.personal" ]
  run /usr/libexec/PlistBuddy -c "Print :CFBundleName" "$app/Contents/Info.plist"
  [ "$output" = "Claude Personal" ]
  /bin/bash -n "$app/Contents/Resources/launch.sh"
}

@test "badge icon is a real multi-size icns" {
  "$CLI" add personal
  icns="$HOME/Applications/Claude Personal.app/Contents/Resources/applet.icns"
  out="$SANDBOX/check.iconset"
  iconutil -c iconset "$icns" -o "$out"
  [ -f "$out/icon_512x512@2x.png" ]
  [ -f "$out/icon_16x16.png" ]
  run sips -g pixelWidth "$out/icon_512x512@2x.png"
  assert_contains "$output" "pixelWidth: 1024"
}

@test "icon renderer works in both bleed and tile styles" {
  for style in bleed tile; do
    run osascript -l JavaScript "$REPO_ROOT/lib/icon.js" "$FAKE_APP" "$SANDBOX/$style.png" Q 9333EA "$style"
    [ "$status" -eq 0 ]
    run sips -g pixelWidth -g pixelHeight "$SANDBOX/$style.png"
    assert_contains "$output" "pixelWidth: 1024"
    assert_contains "$output" "pixelHeight: 1024"
  done
  run osascript -l JavaScript "$REPO_ROOT/lib/icon.js" "$FAKE_APP" "$SANDBOX/x.png" Q 9333EA sideways
  [ "$status" -ne 0 ]
}

@test "named profile gets its own folders and a CLI wrapper that sets CLAUDE_CONFIG_DIR" {
  run "$CLI" add personal
  [ "$status" -eq 0 ]
  wrapper="$HOME/.local/bin/claude-personal"
  [ -x "$wrapper" ]
  printf '#!/bin/sh\nprintf "cfg=%%s args=%%s\\n" "${CLAUDE_CONFIG_DIR-<unset>}" "$*"\n' > "$SANDBOX/fake-claude"
  chmod +x "$SANDBOX/fake-claude"
  CLAUDE_CONFIG_DIR=/wrong run env CLAUDE_PROFILES_CLAUDE_BIN="$SANDBOX/fake-claude" "$wrapper" -p "hi there"
  [ "$status" -eq 0 ]
  [ "$output" = "cfg=$HOME/.claude-personal args=-p hi there" ]
}

@test "default profile wrapper clears an inherited CLAUDE_CONFIG_DIR" {
  "$CLI" add work --default
  printf '#!/bin/sh\nprintf "cfg=%%s\\n" "${CLAUDE_CONFIG_DIR-<unset>}"\n' > "$SANDBOX/fake-claude"
  chmod +x "$SANDBOX/fake-claude"
  run env CLAUDE_CONFIG_DIR=/leaked CLAUDE_PROFILES_CLAUDE_BIN="$SANDBOX/fake-claude" "$HOME/.local/bin/claude-work"
  [ "$output" = "cfg=<unset>" ]
}

@test "wrapper quotes paths with quotes and spaces safely" {
  run "$CLI" add odd --no-desktop --config-dir "$HOME/it's a dir"
  [ "$status" -eq 0 ]
  printf '#!/bin/sh\nprintf "%%s\\n" "$CLAUDE_CONFIG_DIR"\n' > "$SANDBOX/fake-claude"
  chmod +x "$SANDBOX/fake-claude"
  run env CLAUDE_PROFILES_CLAUDE_BIN="$SANDBOX/fake-claude" "$HOME/.local/bin/claude-odd"
  [ "$output" = "$HOME/it's a dir" ]
}

@test "--no-desktop and --no-cli skip their parts" {
  run "$CLI" add cli-only --no-desktop
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/Applications/Claude Cli-only.app" ]
  [ -x "$HOME/.local/bin/claude-cli-only" ]

  run "$CLI" add app-only --no-cli
  [ "$status" -eq 0 ]
  [ -d "$HOME/Applications/Claude App-only.app" ]
  [ ! -e "$HOME/.local/bin/claude-app-only" ]

  run "$CLI" add nothing --no-cli --no-desktop
  [ "$status" -ne 0 ]
}

@test "never overwrites a launcher or command it did not create" {
  mkdir -p "$HOME/Applications/Claude Personal.app"
  run "$CLI" add personal
  [ "$status" -ne 0 ]
  assert_contains "$output" "not made by claude-profiles"
  [ ! -f "$XDG_CONFIG_HOME/claude-profiles/profiles/personal.conf" ]

  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho mine\n' > "$HOME/.local/bin/claude-mine"
  run "$CLI" add mine --no-desktop
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.local/bin/claude-mine")" = "$(printf '#!/bin/sh\necho mine')" ]
}

@test "warns when the bin folder is not on PATH" {
  run env PATH="/usr/bin:/bin" "$CLI" add personal --no-desktop
  [ "$status" -eq 0 ]
  assert_contains "$output" 'export PATH="$HOME/.local/bin:$PATH"'
}

@test "fails clearly when Claude Desktop is missing" {
  run env CLAUDE_APP="$SANDBOX/nope.app" "$CLI" add personal
  [ "$status" -ne 0 ]
  assert_contains "$output" "does not exist"
}

# ---------------------------------------------------------------- launching

@test "named launcher starts Claude with its data dir and config dir, ignoring the caller's env" {
  "$CLI" add personal
  CLAUDE_CONFIG_DIR=/leaked run "$CLI" open personal
  [ "$status" -eq 0 ]
  wait_for_launches 1
  logs="$(launch_logs)"
  assert_contains "$logs" "args=--user-data-dir=$HOME/Library/Application Support/Claude-personal"
  assert_contains "$logs" "cfg=$HOME/.claude-personal"
}

@test "default launcher starts Claude with no overrides and clears a leaked CLAUDE_CONFIG_DIR" {
  "$CLI" add work --default
  CLAUDE_CONFIG_DIR=/leaked run "$CLI" open work
  [ "$status" -eq 0 ]
  wait_for_launches 1
  logs="$(launch_logs)"
  assert_contains "$logs" "args="$'\n'
  assert_contains "$logs" "cfg=<unset>"
  assert_not_contains "$logs" "--user-data-dir"
}

@test "opening a running profile focuses it instead of starting a second copy" {
  "$CLI" add personal
  "$CLI" open personal
  wait_for_launches 1
  [ "$(fake_count)" = 1 ]
  "$CLI" open personal
  sleep 2
  [ "$(fake_count)" = 1 ]
}

@test "profiles run side by side and are told apart correctly" {
  "$CLI" add work --default
  "$CLI" add personal
  "$CLI" add personal2
  "$CLI" open personal
  wait_for_launches 1
  "$CLI" open work
  wait_for_launches 2
  "$CLI" open personal2
  wait_for_launches 3
  [ "$(fake_count)" = 3 ]
  "$CLI" open work
  "$CLI" open personal
  "$CLI" open personal2
  sleep 2
  [ "$(fake_count)" = 3 ]
}

@test "the launcher app itself starts the profile" {
  "$CLI" add personal
  open "$HOME/Applications/Claude Personal.app"
  wait_for_launches 1
  assert_contains "$(launch_logs)" "cfg=$HOME/.claude-personal"
}

@test "launcher keeps working after claude-profiles is gone" {
  "$CLI" add personal
  run env -i HOME="$HOME" /bin/bash "$HOME/Applications/Claude Personal.app/Contents/Resources/launch.sh"
  [ "$status" -eq 0 ]
  wait_for_launches 1
}

@test "doctor reports a running profile and its config dir" {
  [ "$FAKE_IS_BINARY" = 1 ] || skip "needs a C compiler to build the fake app"
  "$CLI" add personal
  "$CLI" open personal
  wait_for_launches 1
  run env PATH="$HOME/.local/bin:/usr/bin:/bin" "$CLI" doctor
  assert_contains "$output" "Claude Desktop 9.9.9"
  assert_contains "$output" "running (pid"
  assert_contains "$output" "Code tab uses ~/.claude-personal"
  [ "$status" -eq 0 ]
}

@test "doctor flags a broken launcher" {
  "$CLI" add personal
  rm -rf "$HOME/Applications/Claude Personal.app"
  run env PATH="$HOME/.local/bin:/usr/bin:/bin" "$CLI" doctor
  [ "$status" -ne 0 ]
  assert_contains "$output" "launcher missing or broken"
}

# ---------------------------------------------------------------- list / refresh / remove

@test "list shows profiles, badges and signed-in CLI account" {
  "$CLI" add work --default
  "$CLI" add personal --color 00aa55
  mkdir -p "$HOME/.claude-personal"
  printf '{"oauthAccount":{"emailAddress":"me@example.com"}}' > "$HOME/.claude-personal/.claude.json"
  run "$CLI" list
  [ "$status" -eq 0 ]
  assert_contains "$output" "work *"
  assert_contains "$output" "Claude Personal"
  assert_contains "$output" "P #00AA55"
  assert_contains "$output" "me@example.com"
}

@test "refresh rebuilds a deleted launcher and wrapper" {
  "$CLI" add personal
  rm -rf "$HOME/Applications/Claude Personal.app" "$HOME/.local/bin/claude-personal"
  run "$CLI" refresh personal
  [ "$status" -eq 0 ]
  [ -d "$HOME/Applications/Claude Personal.app" ]
  [ -x "$HOME/.local/bin/claude-personal" ]
}

@test "remove deletes launcher, command and profile but keeps data" {
  "$CLI" add personal
  mkdir -p "$HOME/Library/Application Support/Claude-personal" "$HOME/.claude-personal"
  run "$CLI" remove personal
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/Applications/Claude Personal.app" ]
  [ ! -e "$HOME/.local/bin/claude-personal" ]
  [ ! -e "$XDG_CONFIG_HOME/claude-profiles/profiles/personal.conf" ]
  [ -d "$HOME/Library/Application Support/Claude-personal" ]
  [ -d "$HOME/.claude-personal" ]
}

@test "remove --purge deletes data only with --yes when not interactive" {
  "$CLI" add personal
  mkdir -p "$HOME/Library/Application Support/Claude-personal" "$HOME/.claude-personal"
  run "$CLI" remove personal --purge < /dev/null
  [ "$status" -ne 0 ]
  [ -d "$HOME/.claude-personal" ]
  run "$CLI" remove personal --purge --yes
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/Library/Application Support/Claude-personal" ]
  [ ! -e "$HOME/.claude-personal" ]
}

@test "remove --purge refuses to touch the default folders" {
  "$CLI" add work --default
  mkdir -p "$HOME/.claude"
  run "$CLI" remove work --purge --yes
  [ "$status" -ne 0 ]
  [ -d "$HOME/.claude" ]
  [ -f "$XDG_CONFIG_HOME/claude-profiles/profiles/work.conf" ]
}

@test "remove leaves files it did not create alone" {
  "$CLI" add personal --no-desktop
  printf '#!/bin/sh\necho mine\n' > "$HOME/.local/bin/claude-personal"
  run "$CLI" remove personal
  [ "$status" -eq 0 ]
  [ -f "$HOME/.local/bin/claude-personal" ]
}

# ---------------------------------------------------------------- installer

@test "install.sh installs a working copy that finds its icon renderer" {
  prefix="$SANDBOX/prefix dir"
  run env CLAUDE_PROFILES_PREFIX="$prefix" "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -x "$prefix/bin/claude-profiles" ]
  [ -f "$prefix/share/claude-profiles/icon.js" ]
  run "$prefix/bin/claude-profiles" add personal
  [ "$status" -eq 0 ]
  [ -s "$HOME/Applications/Claude Personal.app/Contents/Resources/applet.icns" ]
  assert_not_contains "$output" "could not draw"
}

@test "installed copy works through a symlink" {
  prefix="$SANDBOX/prefix"
  env CLAUDE_PROFILES_PREFIX="$prefix" "$REPO_ROOT/install.sh" >/dev/null
  mkdir -p "$SANDBOX/links"
  ln -s "$prefix/bin/claude-profiles" "$SANDBOX/links/claude-profiles"
  run "$SANDBOX/links/claude-profiles" add personal
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "could not draw"
}

@test "install.sh --uninstall removes the tool but keeps profiles" {
  prefix="$SANDBOX/prefix"
  env CLAUDE_PROFILES_PREFIX="$prefix" "$REPO_ROOT/install.sh" >/dev/null
  "$prefix/bin/claude-profiles" add personal --no-desktop
  run env CLAUDE_PROFILES_PREFIX="$prefix" "$REPO_ROOT/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$prefix/bin/claude-profiles" ]
  [ ! -e "$prefix/share/claude-profiles" ]
  [ -f "$XDG_CONFIG_HOME/claude-profiles/profiles/personal.conf" ]
  [ -x "$HOME/.local/bin/claude-personal" ]
}

@test "install.sh refuses a relative prefix" {
  run env CLAUDE_PROFILES_PREFIX="relative/dir" "$REPO_ROOT/install.sh"
  [ "$status" -ne 0 ]
}
