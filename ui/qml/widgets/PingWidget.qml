import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder

    property var metrics: ({})

    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "📡  Ping Monitor"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: '● Online'; font.pixelSize: 16; font.bold: true; color: theme.success }
        Text { Layout.alignment: Qt.AlignHCenter; text: '8.8.8.8'; font.pixelSize: 12; color: theme.textSecondary }
        Rectangle { Layout.preferredWidth: parent.parent.width*0.8; Layout.preferredHeight: 24; Layout.alignment: Qt.AlignHCenter; radius: 4; color: theme.cardBorder
            Canvas { anchors.fill: parent; onPaint: { var ctx=getContext('2d'); ctx.strokeStyle=theme.accent; ctx.lineWidth=2; ctx.beginPath(); for(var i=0;i<30;i++){ var x=i*width/29; var y=height/2+Math.sin(i*0.6+Date.now()*0.001)*8; i===0?ctx.moveTo(x,y):ctx.lineTo(x,y); } ctx.stroke(); } }
            Timer { interval: 200; running: true; repeat: true; onTriggered: parent.children[0].requestPaint() }
        }
        Text { Layout.alignment: Qt.AlignHCenter; text: '~15ms'; font.pixelSize: 10; color: theme.textSecondary }
    }
}
