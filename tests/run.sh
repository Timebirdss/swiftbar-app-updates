#!/bin/bash
# Smoke tests for app-updates. No Homebrew required: everything runs on fixtures.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/bin/app-updates"
FIX="$ROOT/tests/fixtures"

fails=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fails=$((fails + 1)); }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }
contains() {
  case "$3" in
    *"$2"*) ok "$1" ;;
    *) bad "$1" "contains: $2" "$3" ;;
  esac
}
missing() {
  case "$3" in
    *"$2"*) bad "$1" "must not contain: $2" "$3" ;;
    *) ok "$1" ;;
  esac
}

command -v jq >/dev/null || {
  echo "jq is required to run the tests"
  exit 1
}

echo "== parse-brew"
out=$("$BIN" parse-brew <"$FIX/brew.json")
check "formulae count" 2 "$(printf '%s' "$out" | jq '.formulae | length')"
check "casks count" 3 "$(printf '%s' "$out" | jq '.casks | length')"
check "formula shape" "brotli|1.2.0|1.2.1" \
  "$(printf '%s' "$out" | jq -r '.formulae[0] | "\(.name)|\(.from[0])|\(.to)"')"
check "cask auto defaults to false" "false" \
  "$(printf '%s' "$out" | jq -r '.casks[0].auto')"

echo "== parse-brew: empty input"
out=$("$BIN" parse-brew <"$FIX/brew-empty.json")
check "empty formulae" 0 "$(printf '%s' "$out" | jq '.formulae | length')"
check "empty casks" 0 "$(printf '%s' "$out" | jq '.casks | length')"

echo "== parse-mas"
out=$("$BIN" parse-mas <"$FIX/mas.jsonl")
check "mas count" 2 "$(printf '%s' "$out" | jq 'length')"
check "mas shape" "747648890|Telegram|13.1.0|13.2" \
  "$(printf '%s' "$out" | jq -r '.[0] | "\(.id)|\(.name)|\(.from)|\(.to)"')"

echo "== filter (IGNORE + SKIP)"
out=$("$BIN" filter "electerm zed" "" "$FIX/brew.json")
check "ignore drops casks" 1 "$(printf '%s' "$out" | jq '.casks | length')"
check "ignore keeps formulae" 2 "$(printf '%s' "$out" | jq '.formulae | length')"

out=$("$BIN" filter "" "git=2.48.1" "$FIX/brew.json")
check "skip drops exact version" 1 "$(printf '%s' "$out" | jq '.formulae | length')"

out=$("$BIN" filter "" "git=9.9.9" "$FIX/brew.json")
check "skip keeps other versions" 2 "$(printf '%s' "$out" | jq '.formulae | length')"

out=$("$BIN" filter "" "git=" "$FIX/brew.json")
check "skip without version drops forever" 1 "$(printf '%s' "$out" | jq '.formulae | length')"

echo "== menu"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
now=$(date +%s)
jq -n --argjson ts "$now" '
  {version: "1.0.0", ts: $ts,
   brew: {ok: true,
     formulae: [{name: "brotli", from: ["1.2.0"], to: "1.2.1"}],
     casks: [{name: "dbeaver-community", from: ["26.2.1"], to: "26.2.3", auto: false},
             {name: "zed", from: ["1.22.0"], to: "1.26.2", auto: true}]},
   mas: {ok: true, apps: [{id: 747648890, name: "Telegram", from: "13.1.0", to: "13.2"}]},
   installed: {formulae: 100, casks: 12, mas: 1},
   error: ""}' >"$tmp/state.json"

menu=$(APP_UPDATES_STATE="$tmp/state.json" APP_UPDATES_CACHE="$tmp" "$BIN" menu)

first=$(printf '%s\n' "$menu" | head -n 1)
check "menu bar shows the real count" "3" "${first%% |*}"
contains "header counts only real updates" "**Updates: 3**" "$menu"
contains "formula group" "Homebrew · formulae · 1" "$menu"
contains "cask group" "Homebrew · applications · 1" "$menu"
contains "self-updating group" "Self-updating · 1" "$menu"
contains "app store group" "App Store · 1" "$menu"
contains "per-app upgrade action" "param1=upgrade param2=formula param3=brotli" "$menu"
contains "cask opens terminal wrapper" "param1=term param2=upgrade param3=cask" "$menu"
contains "skip is an alternate action" "alternate=true bash=" "$menu"
contains "cleanup action" "param1=cleanup" "$menu"
contains "every action disables Terminal" "terminal=false" "$menu"
missing "no bare terminal flag" "terminal=true" "$menu"

echo "== empty state"
jq -n --argjson ts "$now" '{version: "1.0.0", ts: $ts,
  brew: {ok: true, formulae: [], casks: []}, mas: {ok: true, apps: []},
  installed: {formulae: 100, casks: 12, mas: 1}, error: ""}' >"$tmp/state.json"
menu=$(APP_UPDATES_STATE="$tmp/state.json" APP_UPDATES_CACHE="$tmp" "$BIN" menu)
contains "empty state says up to date" "**Everything is up to date**" "$menu"
first=$(printf '%s\n' "$menu" | head -n 1)
case "$first" in
  "| "*) ok "empty state has no number" ;;
  *) bad "empty state has no number" "| sfimage=…" "$first" ;;
esac

echo "== error state"
jq -n --argjson ts "$now" '{version: "1.0.0", ts: $ts,
  brew: {ok: false, formulae: [], casks: []}, mas: {ok: false, apps: []},
  installed: {formulae: 0, casks: 0, mas: 0}, error: "brew outdated failed. "}' >"$tmp/state.json"
menu=$(APP_UPDATES_STATE="$tmp/state.json" APP_UPDATES_CACHE="$tmp" "$BIN" menu)
contains "error is shown" "Check was incomplete" "$menu"
contains "error text" "brew outdated failed." "$menu"

echo
if [ "$fails" -eq 0 ]; then
  echo "All tests passed."
  exit 0
fi
printf '%s test(s) failed.\n' "$fails"
exit 1
