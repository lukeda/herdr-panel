#!/bin/sh
# Installs, upgrades or removes the panel widget for each desktop it finds.
#   sh install.sh               install or upgrade
#   sh install.sh --uninstall   remove
#
# Each frontend lives in its own directory and gets core/herdr-snapshot.sh
# copied in at install time, so the data script has a single source.
set -eu

cd "$(dirname "$0")"
action="${1:-install}"
installed=0

say() { echo "herdr-panel: $*"; }

# --- KDE Plasma 6 -----------------------------------------------------------
kde_id="io.github.lukeda.herdr"

kde() {
    if [ "$action" = "--uninstall" ]; then
        if kpackagetool6 --type Plasma/Applet --show "$kde_id" >/dev/null 2>&1; then
            kpackagetool6 --type Plasma/Applet --remove "$kde_id"
        fi
        return
    fi

    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' EXIT
    cp -R kde/. "$stage/"
    mkdir -p "$stage/contents/code"
    cp core/herdr-snapshot.sh "$stage/contents/code/"

    if kpackagetool6 --type Plasma/Applet --show "$kde_id" >/dev/null 2>&1; then
        kpackagetool6 --type Plasma/Applet --upgrade "$stage"
        say "KDE widget upgraded. If it is already on a panel, restart Plasma to load it:"
        say "  kquitapp6 plasmashell && systemctl --user start plasma-plasmashell"
    else
        kpackagetool6 --type Plasma/Applet --install "$stage"
        say "KDE widget installed. Right-click your panel → Add Widgets… → \"Herdr Panel\"."
    fi
}

if command -v kpackagetool6 >/dev/null 2>&1; then
    kde
    installed=1
fi

if [ "$installed" = 0 ] && [ "$action" != "--uninstall" ]; then
    say "no supported panel found. Supported today: KDE Plasma 6 (needs kpackagetool6)." >&2
    exit 1
fi
