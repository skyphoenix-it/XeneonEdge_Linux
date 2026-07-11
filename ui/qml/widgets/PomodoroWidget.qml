import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "⏱  Focus Timer"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property int minutes: 25; property int seconds: 0; property bool running: false
        Text { Layout.alignment: Qt.AlignHCenter; text: String(minutes).padStart(2,'0')+':'+String(seconds).padStart(2,'0'); font.pixelSize: 30; font.bold: true; font.family: 'monospace'; color: running ? theme.accent : theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: running ? 'Running...' : 'Tap to start'; font.pixelSize: 11; color: theme.textSecondary }
        Timer { id: pomoTimer; interval: 1000; repeat: true; running: parent.parent.parent.running
            onTriggered: { if(parent.parent.parent.seconds>0) parent.parent.parent.seconds--; else if(parent.parent.parent.minutes>0) { parent.parent.parent.minutes--; parent.parent.parent.seconds=59; } else parent.parent.parent.running=false; } }
        MouseArea { anchors.fill: parent; onClicked: { parent.parent.parent.running = !parent.parent.parent.running; if(!parent.parent.parent.running) { parent.parent.parent.minutes=25; parent.parent.parent.seconds=0; } } }
    }
}
