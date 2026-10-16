import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// One agent, laid out like a herdr sidebar entry:
//   ○ Local · workspace · title
//     agent · status
Item {
    id: delegate

    required property var modelData
    property bool grouped: false

    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.highlightColor
        opacity: delegate.modelData.focused ? 0.15 : 0
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        anchors.leftMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        StatusDot {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Math.round((firstLine.implicitHeight - height) / 2)
            status: delegate.modelData.status
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PlasmaComponents.Label {
                id: firstLine
                Layout.fillWidth: true
                textFormat: Text.StyledText
                elide: Text.ElideRight
                text: {
                    const d = delegate.modelData;
                    const parts = delegate.grouped ? [] : [htmlEscape(d.source), "<b>" + htmlEscape(d.workspace) + "</b>"];
                    if (d.title) parts.push(htmlEscape(d.title));
                    if (parts.length === 0) parts.push(htmlEscape(d.agent));
                    return parts.join(" · ");
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: [delegate.modelData.agent, delegate.modelData.status].filter(s => s).join(" · ")
            }
        }
    }

    PlasmaComponents.ToolTip.text: modelData.cwd
    PlasmaComponents.ToolTip.visible: hover.hovered && modelData.cwd !== ""
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    HoverHandler { id: hover }

    function htmlEscape(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
}
