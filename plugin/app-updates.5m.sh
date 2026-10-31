#!/bin/bash
# <swiftbar.title>App Updates</swiftbar.title>
# <swiftbar.version>1.0.0</swiftbar.version>
# <swiftbar.author>Nikita Chukreev</swiftbar.author>
# <swiftbar.desc>Homebrew and Mac App Store updates in the menu bar: how many, which versions, one-click upgrade. Self-updating apps are listed separately.</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
#
# All logic lives in bin/app-updates. This file only renders the menu,
# which SwiftBar re-runs every 5 minutes from the local cache.

# Find the helper wherever it lives: a Homebrew cask puts it in
# /opt/homebrew/bin, install.sh puts it in ~/.local/bin.
HELPER=$(command -v app-updates 2>/dev/null || true)
if [ -z "${HELPER:-}" ]; then
  for c in "$HOME/.local/bin/app-updates" /opt/homebrew/bin/app-updates /usr/local/bin/app-updates; do
    [ -x "$c" ] && HELPER=$c && break
  done
fi
exec "${HELPER:-app-updates}" menu
