import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "⌚  Tourbillon"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatTime(new Date(),'HH:mm:ss'); font.pixelSize: 24; font.bold: true; font.family: 'monospace'; color: theme.accent }
        Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(new Date(),'yyyy-MM-dd'); font.pixelSize: 10; color: theme.textSecondary }
    }
}
