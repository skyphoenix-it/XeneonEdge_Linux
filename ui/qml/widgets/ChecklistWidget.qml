import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "✅  Checklist"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var items: ['Review PRs', 'Update docs', 'Standup notes']; property var checked: [false,false,false]
        ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: parent.items
            delegate: RowLayout { spacing: 6
                Rectangle { width: 16; height: 16; radius: 4; color: parent.parent.parent.checked[index] ? theme.accent : theme.cardBorder
                    Text { anchors.centerIn: parent; visible: parent.parent.parent.checked[index]; text: '✓'; font.pixelSize: 10; color: '#000' } }
                Text { text: modelData; font.pixelSize: 12; color: parent.parent.parent.checked[index] ? theme.textSecondary : theme.textPrimary }
                MouseArea { anchors.fill: parent; onClicked: { var c = parent.parent.parent.checked; c[index] = !c[index]; parent.parent.parent.checked = c; } }
            }
        }
    }
}
