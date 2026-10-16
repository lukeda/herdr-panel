import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string scriptPath: Qt.resolvedUrl("../code/herdr-snapshot.sh").toString().replace(/^file:\/\//, "")

    // [{key, kind: "local"|"machine", label, target}]
    property var sources: []
    // source key -> {agents: [...], workspaces: [...]} or {error: "..."}
    property var results: ({})
    property var agentRows: []
    property var sourceErrors: []
    property var counts: ({ working: 0, blocked: 0, done: 0, idle: 0, unknown: 0, total: 0 })
    property string globalError: ""

    // command line -> callback; the executable engine reports by command string.
    property var pending: ({})

    readonly property string overallStatus: counts.blocked > 0 ? "blocked"
        : counts.working > 0 ? "working"
        : counts.done > 0 ? "done"
        : counts.idle > 0 ? "idle" : "unknown"

    toolTipMainText: i18n("Herdr agents")
    toolTipSubText: globalError !== "" ? globalError
        : counts.total === 0 ? i18n("No agents running")
        : i18n("%1 working · %2 blocked · %3 done · %4 idle",
               counts.working, counts.blocked, counts.done, counts.idle)

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property int activeCount: root.counts.working + root.counts.blocked

        Layout.minimumWidth: vertical ? -1 : row.implicitWidth
        Layout.minimumHeight: vertical ? row.implicitHeight : -1
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: row
            anchors.centerIn: parent
            height: parent.height
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: height

                Kirigami.Icon {
                    anchors.fill: parent
                    source: Plasmoid.icon
                    active: compact.containsMouse
                }

                StatusDot {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: Math.max(Kirigami.Units.smallSpacing * 2, parent.width * 0.4)
                    height: width
                    status: root.overallStatus
                    visible: root.counts.total > 0
                }
            }

            PlasmaComponents.Label {
                visible: Plasmoid.configuration.showCountsInPanel && !compact.vertical && root.counts.total > 0
                text: compact.activeCount + "/" + root.counts.total
            }
        }
    }

    fullRepresentation: FullRepresentation {
        rows: root.agentRows
        errors: root.sourceErrors
        globalError: root.globalError
        onRefreshRequested: root.refreshSources()
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function run(args, callback) {
        const cmd = ["sh", scriptPath].concat(args, [Plasmoid.configuration.herdrPath]).map(shellQuote).join(" ");
        if (pending[cmd]) {
            return; // previous poll of this source is still running
        }
        pending[cmd] = callback;
        executable.connectSource(cmd);
    }

    function refreshSources() {
        run(["sources"], result => {
            if (result.error) {
                globalError = result.error;
                sources = [];
                rebuild();
                return;
            }
            globalError = "";
            const next = [];
            for (const s of (result.sessions && result.sessions.sessions) || []) {
                if (!s.running) continue;
                next.push({
                    key: "session:" + s.name,
                    kind: "local",
                    label: s.default ? i18n("Local") : i18n("Local:%1", s.name),
                    target: s.socket_path,
                });
            }
            if (Plasmoid.configuration.showRemote) {
                for (const m of result.machines || []) {
                    if (!m.enabled) continue;
                    next.push({ key: "machine:" + m.id, kind: "machine", label: m.label || m.target, target: m.id });
                }
            }
            const kept = {};
            for (const s of next) {
                if (results[s.key]) kept[s.key] = results[s.key];
            }
            results = kept;
            sources = next;
            poll("local");
            poll("machine");
        });
    }

    function poll(kind) {
        for (const src of sources) {
            if (src.kind !== kind) continue;
            run([src.kind, src.target], result => {
                const next = Object.assign({}, results);
                next[src.key] = parseSnapshot(result);
                results = next;
                rebuild();
            });
        }
    }

    // herdr's connection failures are Rust debug dumps; keep the inner message.
    function cleanError(text) {
        const s = String(text).trim();
        const inner = s.match(/error: "((?:[^"\\]|\\.)*)"/);
        return inner ? inner[1].replace(/\\"/g, '"') : s.replace(/^Error:\s*/, "");
    }

    function parseSnapshot(result) {
        if (result.machine_status) {
            const m = result.machine_status[0] || {};
            return { error: cleanError(m.error || m.status || i18n("unreachable")), status: m.status || "error" };
        }
        if (result.error) return { error: cleanError(result.error), status: "error" };
        const agents = result.agents && result.agents.result && result.agents.result.agents;
        if (!agents) {
            const err = result.agents && result.agents.error;
            return { error: (err && (err.message || err.code)) || i18n("Unexpected response from herdr") };
        }
        const workspaces = (result.workspaces && result.workspaces.result && result.workspaces.result.workspaces) || [];
        return { agents: agents, workspaces: workspaces };
    }

    function rebuild() {
        const rows = [];
        const errors = [];
        const c = { working: 0, blocked: 0, done: 0, idle: 0, unknown: 0, total: 0 };
        for (const src of sources) {
            const res = results[src.key];
            if (!res) continue;
            if (res.error) {
                errors.push({ source: src.label, kind: src.kind, status: res.status, error: res.error });
                continue;
            }
            const ws = {};
            for (const w of res.workspaces) ws[w.workspace_id] = w;
            const srcRows = res.agents.map(a => {
                const w = ws[a.workspace_id] || {};
                const status = a.agent_status || "unknown";
                c[status in c ? status : "unknown"] += 1;
                c.total += 1;
                return {
                    source: src.label,
                    workspace: w.label || a.workspace_id,
                    workspaceNumber: w.number || 0,
                    title: a.terminal_title_stripped || a.terminal_title || "",
                    agent: a.agent || "",
                    status: status,
                    cwd: a.foreground_cwd || a.cwd || "",
                    focused: !!a.focused,
                    paneId: a.pane_id,
                };
            });
            srcRows.sort((x, y) => x.workspaceNumber - y.workspaceNumber || x.paneId.localeCompare(y.paneId));
            for (const r of srcRows) {
                r.group = r.source + " · " + r.workspace;
                rows.push(r);
            }
        }
        agentRows = rows;
        sourceErrors = errors;
        counts = c;
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            const callback = root.pending[sourceName];
            delete root.pending[sourceName];
            disconnectSource(sourceName);
            if (!callback) return;
            let parsed;
            try {
                parsed = JSON.parse(data["stdout"]);
            } catch (e) {
                parsed = { error: String(data["stderr"] || data["stdout"] || i18n("No output from herdr")).trim() };
            }
            callback(parsed);
        }
    }

    Timer {
        interval: Math.max(1, Plasmoid.configuration.localInterval) * 1000
        running: true
        repeat: true
        onTriggered: root.poll("local")
    }

    Timer {
        interval: Math.max(5, Plasmoid.configuration.remoteInterval) * 1000
        running: Plasmoid.configuration.showRemote
        repeat: true
        onTriggered: root.poll("machine")
    }

    // Picks up sessions and machines that start, stop or get added.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refreshSources()
    }

    Connections {
        target: Plasmoid.configuration
        function onShowRemoteChanged() { root.refreshSources(); }
        function onHerdrPathChanged() { root.refreshSources(); }
    }

    Component.onCompleted: refreshSources()
}
