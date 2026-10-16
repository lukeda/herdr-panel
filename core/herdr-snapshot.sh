#!/bin/sh
# Fetches herdr state for the Plasma widget. Prints one JSON object on stdout.
#
#   herdr-snapshot.sh sources [herdr-bin]           -> {"sessions":[...],"machines":[...]}
#   herdr-snapshot.sh local <socket> [herdr-bin]    -> {"agents":{...},"workspaces":{...}}
#   herdr-snapshot.sh machine <id> [herdr-bin]      -> {"agents":{...},"workspaces":{...}}
#   herdr-snapshot.sh focus local|machine <socket-or-id> <pane> [herdr-bin]
#                                                    -> {"focused":true,"client_pid":N|null}
#
# Failures print {"error":"..."} so the widget can show them per source.

mode="${1:-}"
if [ "$mode" = "focus" ]; then
    kind="${2:-}"
    target="${3:-}"
    pane="${4:-}"
    herdr_bin="${5:-}"
else
    target="${2:-}"
    herdr_bin="${3:-}"
fi

json_error() {
    msg=$(printf '%s' "$1" | tr '\n\t' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"error":"%s"}\n' "$msg"
    exit 0
}

# plasmashell often has a minimal PATH, so look in the usual install spots too.
if [ -z "$herdr_bin" ] || [ ! -x "$herdr_bin" ]; then
    herdr_bin=$(command -v herdr 2>/dev/null)
    for candidate in "$HOME/.local/bin/herdr" "$HOME/.cargo/bin/herdr" /usr/local/bin/herdr /usr/bin/herdr; do
        [ -n "$herdr_bin" ] && break
        [ -x "$candidate" ] && herdr_bin="$candidate"
    done
fi
[ -n "$herdr_bin" ] || json_error "herdr not found; set its path in the widget settings"

# Don't let a herdr pane's environment (if plasmashell inherited one) redirect calls.
unset HERDR_ENV HERDR_PANE_ID HERDR_WORKSPACE_ID HERDR_TAB_ID

case "$mode" in
    sources)
        sessions=$("$herdr_bin" session list --json 2>&1) || json_error "$sessions"
        machines=$("$herdr_bin" machine list --json 2>/dev/null) || machines="[]"
        [ -n "$machines" ] || machines="[]"
        printf '{"sessions":%s,"machines":%s}\n' "$sessions" "$machines"
        ;;
    local)
        [ -n "$target" ] || json_error "missing socket path"
        agents=$(HERDR_SOCKET_PATH="$target" timeout 5 "$herdr_bin" agent list 2>&1) || json_error "$agents"
        workspaces=$(HERDR_SOCKET_PATH="$target" timeout 5 "$herdr_bin" workspace list 2>&1) || json_error "$workspaces"
        printf '{"agents":%s,"workspaces":%s}\n' "$agents" "$workspaces"
        ;;
    machine)
        [ -n "$target" ] || json_error "missing machine id"
        # stdin from /dev/null so ssh can never sit waiting on a password prompt.
        if agents=$(timeout 15 "$herdr_bin" --machine "$target" agent list 2>&1 </dev/null) &&
            workspaces=$(timeout 15 "$herdr_bin" --machine "$target" workspace list 2>&1 </dev/null); then
            printf '{"agents":%s,"workspaces":%s}\n' "$agents" "$workspaces"
            exit 0
        fi
        # The fetch error is a Rust debug dump; `machine status` has a readable
        # reason. Only ask on failure since it is slow for unreachable hosts.
        machine_status=$(timeout 15 "$herdr_bin" machine status "$target" --json 2>/dev/null </dev/null)
        case "$machine_status" in
            \[*) printf '{"machine_status":%s}\n' "$machine_status" ;;
            *) json_error "${workspaces:-$agents}" ;;
        esac
        ;;
    focus)
        [ -n "$target" ] && [ -n "$pane" ] || json_error "usage: focus local|machine <target> <pane>"
        case "$kind" in
            local) out=$(HERDR_SOCKET_PATH="$target" timeout 5 "$herdr_bin" agent focus "$pane" 2>&1) || json_error "$out" ;;
            machine) out=$(timeout 15 "$herdr_bin" --machine "$target" agent focus "$pane" 2>&1 </dev/null) || json_error "$out" ;;
            *) json_error "unknown source kind: $kind" ;;
        esac
        # The herdr TUI client the user typed into most recently: its terminal's
        # atime moves on every keypress. Desktop frontends raise its window.
        best_pid=null
        best_time=0
        for pid in $(pgrep -x herdr); do
            args=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || continue
            case " $args" in
                *" server"*|*" agent "*|*" plugin "*|*" api "*|*" pane "*|*" workspace "*|*" machine "*|*" session "*) continue ;;
            esac
            tty=$(readlink "/proc/$pid/fd/0" 2>/dev/null) || continue
            case "$tty" in /dev/pts/*|/dev/tty*) ;; *) continue ;; esac
            t=$(stat -c %X "$tty" 2>/dev/null) || continue
            if [ "$t" -gt "$best_time" ]; then
                best_time=$t
                best_pid=$pid
            fi
        done
        printf '{"focused":true,"client_pid":%s}\n' "$best_pid"
        ;;
    *)
        json_error "usage: herdr-snapshot.sh sources|local <socket>|machine <id> [herdr-bin]"
        ;;
esac
