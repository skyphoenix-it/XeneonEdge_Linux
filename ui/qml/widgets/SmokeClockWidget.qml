import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🕐  Analog Clock"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Canvas { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 80; Layout.preferredHeight: 80
            onPaint: {
                var ctx=getContext('2d'); var w=width,h=height; var cx=w/2,cy=h/2,r=Math.min(w,h)/2-8;
                ctx.clearRect(0,0,w,h);
                ctx.strokeStyle=theme.cardBorder; ctx.lineWidth=2; ctx.beginPath(); ctx.arc(cx,cy,r,0,Math.PI*2); ctx.stroke();
                var d=new Date(); var hh=d.getHours()%12*30+d.getMinutes()*0.5; var mm=d.getMinutes()*6+d.getSeconds()*0.1; var ss=d.getSeconds()*6;
                ctx.strokeStyle=theme.textPrimary; ctx.lineWidth=2; ctx.beginPath(); ctx.moveTo(cx,cy); ctx.lineTo(cx+Math.sin(hh*Math.PI/180)*r*0.5,cy-Math.cos(hh*Math.PI/180)*r*0.5); ctx.stroke();
                ctx.strokeStyle=theme.accent; ctx.lineWidth=1.5; ctx.beginPath(); ctx.moveTo(cx,cy); ctx.lineTo(cx+Math.sin(mm*Math.PI/180)*r*0.7,cy-Math.cos(mm*Math.PI/180)*r*0.7); ctx.stroke();
                ctx.fillStyle=theme.error; ctx.beginPath(); ctx.arc(cx,cy,3,0,Math.PI*2); ctx.fill();
            }
            Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.requestPaint() }
        }
    }
}
