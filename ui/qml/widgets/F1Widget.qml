import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🏎️  F1 Next Race"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'Monaco GP'; font.pixelSize: 18; font.bold: true; color: theme.accent }
        Text { Layout.alignment: Qt.AlignHCenter; text: '5d 12h 34m'; font.pixelSize: 20; font.bold: true; font.family: 'monospace'; color: theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'Circuit de Monaco'; font.pixelSize: 10; color: theme.textSecondary }
    }
}
