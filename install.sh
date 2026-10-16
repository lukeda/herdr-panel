#!/bin/sh
# Installs, upgrades or removes the Plasma widget for the current user.
#   sh install.sh               install or upgrade
#   sh install.sh --uninstall   remove
set -eu

cd "$(dirname "$0")"
widget_id="io.github.lukeda.herdr"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "herdr-kde: kpackagetool6 not found. This plugin needs KDE Plasma 6." >&2
    exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
    kpackagetool6 --type Plasma/Applet --remove "$widget_id"
    exit 0
fi

if kpackagetool6 --type Plasma/Applet --show "$widget_id" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade plasmoid
    echo "herdr-kde: widget upgraded. If it is already on a panel, restart Plasma to load the new version:"
    echo "  systemctl --user restart plasma-plasmashell"
else
    kpackagetool6 --type Plasma/Applet --install plasmoid
    echo "herdr-kde: widget installed. Right-click your panel → Add Widgets… → \"Herdr Agents\"."
fi
