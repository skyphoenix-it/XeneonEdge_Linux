import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🖼️  Image Feed"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: '🖼️  r/pics'; font.pixelSize: 14; font.bold: true; color: theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'Beautiful sunset over Golden Gate'; font.pixelSize: 11; color: theme.textSecondary }
        Rectangle { Layout.preferredWidth: parent.parent.width*0.8; Layout.preferredHeight: 50; Layout.alignment: Qt.AlignHCenter; radius: 8; color: Qt.rgba(1,0.6,0.2,0.3)
            Text { anchors.centerIn: parent; text: '🖼️'; font.pixelSize: 30 }
        }
        Text { Layout.alignment: Qt.AlignHCenter; text: '⬅️ Swipe for more'; font.pixelSize: 9; color: theme.textSecondary }
    }
}
