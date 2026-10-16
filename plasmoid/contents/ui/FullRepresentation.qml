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

    signal refreshRequested()

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
                text: i18n("agents")
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
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Refresh")
                onClicked: full.refreshRequested()
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        Repeater {
            model: full.globalError !== "" ? [{ source: i18n("herdr"), error: full.globalError }] : full.errors

            PlasmaComponents.Label {
                required property var modelData
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                text: modelData.source + ": " + modelData.error
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

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
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: list.count === 0 && full.globalError === ""
                    iconName: "utilities-terminal"
                    text: i18n("No agents running")
                }
            }
        }
    }
}
