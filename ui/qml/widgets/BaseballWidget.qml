import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "⚾  Baseball"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'LAD  5 - 3  SFG'; font.pixelSize: 20; font.bold: true; font.family: 'monospace'; color: theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'Q3 - 8:42'; font.pixelSize: 11; color: theme.accent }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'Standings: 1st in Division'; font.pixelSize: 10; color: theme.textSecondary }
    }
}
