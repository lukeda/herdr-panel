import QtQuick
import org.kde.kirigami as Kirigami

// Mirrors the herdr sidebar: hollow ring when the agent is waiting on you
// (idle/unknown), filled when something is happening or needs attention.
Rectangle {
    id: dot

    property string status: "unknown"
    readonly property bool hollow: status === "idle" || status === "unknown" || status === ""
    readonly property color statusColor: {
        switch (status) {
        case "working": return Kirigami.Theme.neutralTextColor;
        case "blocked": return Kirigami.Theme.negativeTextColor;
        case "done": return Kirigami.Theme.highlightColor;
        case "idle": return Kirigami.Theme.positiveTextColor;
        default: return Kirigami.Theme.disabledTextColor;
        }
    }

    implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.6)
    implicitHeight: implicitWidth
    radius: width / 2
    color: hollow ? "transparent" : statusColor
    border.width: Math.max(1, Math.round(width / 6))
    border.color: statusColor

    SequentialAnimation on opacity {
        running: dot.status === "working"
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
    }
}
