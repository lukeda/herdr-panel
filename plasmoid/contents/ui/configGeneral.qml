import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_herdrPath: herdrPath.text
    property alias cfg_localInterval: localInterval.value
    property alias cfg_remoteInterval: remoteInterval.value
    property alias cfg_showRemote: showRemote.checked
    property alias cfg_groupByWorkspace: groupByWorkspace.checked
    property alias cfg_showCountsInPanel: showCountsInPanel.checked

    Kirigami.FormLayout {
        QQC2.TextField {
            id: herdrPath
            Kirigami.FormData.label: i18n("herdr binary:")
            placeholderText: i18n("Auto-detect (PATH, ~/.local/bin, ~/.cargo/bin)")
        }

        QQC2.SpinBox {
            id: localInterval
            Kirigami.FormData.label: i18n("Local refresh (s):")
            from: 1
            to: 60
        }

        QQC2.CheckBox {
            id: showRemote
            Kirigami.FormData.label: i18n("SSH machines:")
            text: i18n("Include agents on saved machines")
        }

        QQC2.SpinBox {
            id: remoteInterval
            Kirigami.FormData.label: i18n("Remote refresh (s):")
            enabled: showRemote.checked
            from: 5
            to: 600
        }

        QQC2.CheckBox {
            id: groupByWorkspace
            Kirigami.FormData.label: i18n("List:")
            text: i18n("Group by workspace")
        }

        QQC2.CheckBox {
            id: showCountsInPanel
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("Show active/total counts")
        }
    }
}
