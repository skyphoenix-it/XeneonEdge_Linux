import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🚗  Commute"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: '🏠 → 🏢'; font.pixelSize: 16; color: theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: '25 min'; font.pixelSize: 28; font.bold: true; font.family: 'monospace'; color: theme.accent }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'Moderate traffic'; font.pixelSize: 10; color: theme.warning }
    }
}
