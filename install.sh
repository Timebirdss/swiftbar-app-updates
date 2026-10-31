#!/bin/bash
# Installs app-updates: the helper into ~/.local/bin and the plugin into SwiftBar.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/app-updates"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/Library/Caches}/app-updates"

if [ -z "${PLUGIN_DIR:-}" ]; then
  PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
fi
if [ -z "${PLUGIN_DIR:-}" ]; then
  PLUGIN_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"
fi

command -v jq >/dev/null 2>&1 || {
  printf 'jq is required: brew install jq\n' >&2
  exit 1
}

mkdir -p "$BIN_DIR" "$PLUGIN_DIR" "$CONF_DIR" "$CACHE_DIR"
install -m 755 "$ROOT/bin/app-updates" "$BIN_DIR/app-updates"
install -m 755 "$ROOT/plugin/app-updates.5m.sh" "$PLUGIN_DIR/app-updates.5m.sh"

if [ ! -f "$CONF_DIR/config" ]; then
  cat >"$CONF_DIR/config" <<'CONF'
# app-updates configuration. This file is sourced as bash, so keep the quotes.

# Proxy for brew and mas (empty = direct connection).
# brew does not use the system SOCKS proxy even when a VPN sets one, so if your
# downloads stall, point it at the proxy explicitly:
# PROXY="socks5h://127.0.0.1:10808"
PROXY=""

# Packages that are never offered (space separated).
IGNORE=""

# Versions to skip (space separated "name=version"). "name=" skips forever.
SKIP=""

# Apps that update through a Sparkle feed and are not managed by Homebrew are
# found automatically ("auto"). Set "off" to ignore them.
SPARKLE="auto"

# Tools installed by hand from GitHub releases: "owner/repo=installed-version".
# GITHUB="cli/cli=2.40.0 owner/tool=1.2.3"
GITHUB=""

# How often the plugin re-checks, in seconds. Default: 6 hours.
# TTL=21600
CONF
fi

"$BIN_DIR/app-updates" refresh --quiet || true
open -g "swiftbar://refreshplugin?name=app-updates" 2>/dev/null || true

printf 'Installed app-updates\n'
printf '  helper: %s\n' "$BIN_DIR/app-updates"
printf '  plugin: %s\n' "$PLUGIN_DIR/app-updates.5m.sh"
printf '  config: %s\n' "$CONF_DIR/config"
printf '\nLook for the arrow icon in your menu bar. If it is not there, open\n'
printf 'SwiftBar and enable the plugin in its menu.\n'
