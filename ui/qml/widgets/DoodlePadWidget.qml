import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "✏️  Doodle Pad"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Canvas { Layout.fillWidth: true; Layout.fillHeight: true; id: doodleCanvas
            property var points: []
            onPaint: { var ctx=getContext('2d'); ctx.clearRect(0,0,width,height); if(points.length<2)return; ctx.strokeStyle=theme.accent; ctx.lineWidth=3; ctx.beginPath(); ctx.moveTo(points[0].x,points[0].y); for(var i=1;i<points.length;i++)ctx.lineTo(points[i].x,points[i].y); ctx.stroke(); }
            MouseArea { anchors.fill: parent; onPressed: parent.points=[]; onPositionChanged: function(mouse){ parent.points.push({x:mouse.x,y:mouse.y}); parent.requestPaint(); } }
        }
    }
}
