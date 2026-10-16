import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

PlasmaExtras.Representation {
    id: full

    property var rows: []
    property var errors: []
    property string globalError: ""
    readonly property bool grouped: Plasmoid.configuration.groupByWorkspace

    property bool errorsExpanded: false

    signal refreshRequested()
    signal agentActivated(var row)

    function errorSummary() {
        const machines = errors.filter(e => e.kind === "machine").length;
        const sessions = errors.length - machines;
        const parts = [];
        if (machines > 0) parts.push(i18np("%1 machine couldn't connect", "%1 machines couldn't connect", machines));
        if (sessions > 0) parts.push(i18np("%1 session couldn't be read", "%1 sessions couldn't be read", sessions));
        return parts.join(" · ");
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 10
    Layout.preferredHeight: Kirigami.Units.gridUnit * 24

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                level: 1
                text: i18n("herdr panel")
            }

            PlasmaComponents.ToolButton {
                text: full.grouped ? i18n("grouped") : i18n("flat")
                checkable: true
                checked: full.grouped
                onToggled: Plasmoid.configuration.groupByWorkspace = checked
                PlasmaComponents.ToolTip.text: i18n("Group by workspace")
                PlasmaComponents.ToolTip.visible: hovered
            }

            PlasmaComponents.ToolButton {
                readonly property bool recent: Plasmoid.configuration.sortOrder === "recent"
                text: recent ? i18n("recent") : i18n("default")
                checkable: true
                checked: recent
                onToggled: Plasmoid.configuration.sortOrder = checked ? "recent" : "herdr"
                PlasmaComponents.ToolTip.text: recent ? i18n("Latest status change first") : i18n("Same order as herdr's sidebar")
                PlasmaComponents.ToolTip.visible: hovered
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Refresh")
                onClicked: full.refreshRequested()
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
            }
        }
    }

    footer: PlasmaExtras.PlasmoidHeading {
        visible: full.errors.length > 0
        position: PlasmaComponents.ToolBar.Footer

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                Layout.fillWidth: true
                text: full.errorSummary()
                font: Kirigami.Theme.smallFont
                onClicked: full.errorsExpanded = !full.errorsExpanded
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: "data-warning"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: full.errorSummary()
                        font: Kirigami.Theme.smallFont
                        opacity: 0.8
                        elide: Text.ElideRight
                    }
                    Kirigami.Icon {
                        source: full.errorsExpanded ? "arrow-down" : "arrow-up"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.6
                    }
                }
            }

            Repeater {
                model: full.errorsExpanded ? full.errors : []

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: 0

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        StatusDot { status: "blocked" }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: modelData.source + " · " + (modelData.status || "error")
                            font.bold: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: modelData.error
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            contentItem: ListView {
                id: list
                model: full.rows
                clip: true
                reuseItems: true
                spacing: Kirigami.Units.smallSpacing

                section.property: full.grouped ? "group" : ""
                section.delegate: Kirigami.ListSectionHeader {
                    required property string section
                    width: ListView.view.width
                    label: section
                }

                delegate: AgentDelegate {
                    width: ListView.view.width
                    grouped: full.grouped
                    onActivated: full.agentActivated(modelData)
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: list.count === 0
                    iconName: full.globalError !== "" ? "dialog-warning" : "utilities-terminal"
                    text: full.globalError !== "" ? i18n("Can't reach herdr") : i18n("No agents running")
                    explanation: full.globalError
                }
            }
        }
    }
}
