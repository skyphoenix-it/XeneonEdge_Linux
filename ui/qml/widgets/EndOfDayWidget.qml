import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🏁  End of Work"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property int hours: Math.max(0,17-new Date().getHours()); property int mins: Math.max(0,60-new Date().getMinutes())
        Text { Layout.alignment: Qt.AlignHCenter; text: String(hours).padStart(2,'0')+':'+String(mins).padStart(2,'0'); font.pixelSize: 28; font.bold: true; font.family: 'monospace'; color: theme.accent }
        Text { Layout.alignment: Qt.AlignHCenter; text: hours===0&&mins===0?'🎉 Done!':'until freedom'; font.pixelSize: 11; color: theme.textSecondary }
    }
}
