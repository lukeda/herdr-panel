#!/bin/sh
# Fetches herdr state for the Plasma widget. Prints one JSON object on stdout.
#
#   herdr-snapshot.sh sources [herdr-bin]           -> {"sessions":[...],"machines":[...]}
#   herdr-snapshot.sh local <socket> [herdr-bin]    -> {"agents":{...},"workspaces":{...}}
#   herdr-snapshot.sh machine <id> [herdr-bin]      -> {"agents":{...},"workspaces":{...}}
#
# Failures print {"error":"..."} so the widget can show them per source.

mode="${1:-}"
target="${2:-}"
herdr_bin="${3:-}"

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
        agents=$(timeout 15 "$herdr_bin" --machine "$target" agent list 2>&1 </dev/null) || json_error "$agents"
        workspaces=$(timeout 15 "$herdr_bin" --machine "$target" workspace list 2>&1 </dev/null) || json_error "$workspaces"
        printf '{"agents":%s,"workspaces":%s}\n' "$agents" "$workspaces"
        ;;
    *)
        json_error "usage: herdr-snapshot.sh sources|local <socket>|machine <id> [herdr-bin]"
        ;;
esac
