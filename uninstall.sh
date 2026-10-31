#!/bin/bash
# Removes app-updates. Pass --purge to delete the cache and config as well.
set -euo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/app-updates"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/Library/Caches}/app-updates"
PLUGIN_DIR="${PLUGIN_DIR:-$HOME/Library/Application Support/SwiftBar/Plugins}"

rm -f "$BIN_DIR/app-updates" "$PLUGIN_DIR/app-updates.5m.sh"
rm -rf "$CACHE_DIR"

if [ "${1:-}" = "--purge" ]; then
  rm -rf "$CONF_DIR"
  printf 'Removed the plugin, the cache and the config.\n'
else
  printf 'Removed the plugin and the cache. Config kept in %s (use --purge to delete).\n' "$CONF_DIR"
fi

open -g "swiftbar://refreshallplugins" 2>/dev/null || true
