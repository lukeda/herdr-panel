#!/bin/sh
# Brings the terminal running a herdr client to the front on KDE Plasma.
#
#   raise.sh <client-pid>
#
# Yakuake and Konsole also get the right tab selected over D-Bus; any other
# terminal just has its window activated through a KWin script.

client="${1:-}"
[ -n "$client" ] && [ -d "/proc/$client" ] || exit 0

qdbus=$(command -v qdbus6 || command -v qdbus) || exit 0

# Ancestors of the client, nearest first: shell, terminal, ...
ancestors=""
shell=""
terminal=""
pid=$client
while :; do
    ppid=$(awk '/^PPid:/ { print $2 }' "/proc/$pid/status" 2>/dev/null)
    [ -n "$ppid" ] && [ "$ppid" -gt 1 ] || break
    comm=$(cat "/proc/$ppid/comm" 2>/dev/null)
    case "$comm" in
        systemd|plasmashell|kwin_wayland|kwin_x11|startplasma*) break ;;
    esac
    ancestors="$ancestors $ppid"
    if [ -z "$terminal" ]; then
        case "$comm" in
            yakuake|konsole) terminal=$ppid; shell=$pid ;;
        esac
    fi
    pid=$ppid
done

# Konsole-part session (/Sessions/N) whose shell is $shell, as "N".
konsole_session() {
    for path in $("$qdbus" "$1" 2>/dev/null | grep '^/Sessions/[0-9]*$'); do
        if [ "$("$qdbus" "$1" "$path" processId 2>/dev/null)" = "$shell" ]; then
            echo "${path#/Sessions/}"
            return
        fi
    done
}

if [ -n "$terminal" ]; then
    case "$(cat "/proc/$terminal/comm")" in
        yakuake)
            svc=org.kde.yakuake
            # Yakuake numbers tabs separately from its Konsole sessions, but
            # both count up in creation order, so match them by rank.
            ksession=$(konsole_session $svc)
            if [ -n "$ksession" ]; then
                rank=$("$qdbus" $svc 2>/dev/null | grep '^/Sessions/[0-9]*$' | sed 's#/Sessions/##' | sort -n | grep -n "^$ksession\$" | cut -d: -f1)
                terminal_id=$("$qdbus" $svc /yakuake/sessions sessionIdList 2>/dev/null | tr ',' '\n' | while read -r s; do
                    "$qdbus" $svc /yakuake/sessions terminalIdsForSessionId "$s" | tr ',' '\n'
                done | sort -n | sed -n "${rank}p")
                if [ -n "$terminal_id" ]; then
                    yk_session=$("$qdbus" $svc /yakuake/sessions sessionIdForTerminalId "$terminal_id")
                    "$qdbus" $svc /yakuake/sessions raiseSession "$yk_session" >/dev/null
                fi
            fi
            if [ "$("$qdbus" $svc /yakuake/MainWindow_1 org.qtproject.Qt.QWidget.visible 2>/dev/null)" != "true" ]; then
                "$qdbus" $svc /yakuake/window toggleWindowState >/dev/null
            fi
            ;;
        konsole)
            for svc in $("$qdbus" 2>/dev/null | grep -E '^ *org\.kde\.konsole'); do
                [ "$(busctl --user status "$svc" 2>/dev/null | sed -n 's/^PID=//p')" = "$terminal" ] || continue
                ksession=$(konsole_session "$svc")
                [ -n "$ksession" ] || continue
                for win in $("$qdbus" "$svc" 2>/dev/null | grep '^/Windows/[0-9]*$'); do
                    if "$qdbus" "$svc" "$win" sessionList 2>/dev/null | grep -qx "$ksession"; then
                        "$qdbus" "$svc" "$win" setCurrentSession "$ksession" >/dev/null
                    fi
                done
            done
            ;;
    esac
fi

# Activate the window of the nearest ancestor KWin knows about.
script=$(mktemp --suffix=.js)
name="herdr-panel-raise-$$"
trap 'rm -f "$script"; "$qdbus" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$name" >/dev/null 2>&1' EXIT
pids=$(echo "$ancestors" | sed 's/^ *//; s/ \+/, /g')
cat > "$script" <<EOF
const pids = [$pids];
const windows = workspace.windowList();
for (const pid of pids) {
    const w = windows.find(w => w.pid === pid && w.normalWindow) || windows.find(w => w.pid === pid);
    if (w) {
        if (w.minimized) w.minimized = false;
        workspace.activeWindow = w;
        break;
    }
}
EOF
id=$("$qdbus" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$script" "$name" 2>/dev/null) || exit 0
"$qdbus" org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null 2>&1
sleep 0.3
