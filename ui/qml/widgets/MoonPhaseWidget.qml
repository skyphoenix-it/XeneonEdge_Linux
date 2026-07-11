import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🌙  Moon Phase"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property real phase: { var lp=2551443; var nd=new Date().getTime()/1000-947116800; var np=parseInt(nd/lp); var nm=Math.abs(nd-np*lp)/lp; return nm>0.5?2*(1-nm):2*nm; }
        Text { Layout.alignment: Qt.AlignHCenter; text: phase<0.02?'🌑':phase<0.25?'🌒':phase<0.48?'🌓':phase<0.52?'🌕':phase<0.75?'🌖':'🌗'; font.pixelSize: 36 }
        Text { Layout.alignment: Qt.AlignHCenter; text: (phase*100).toFixed(0)+'% illuminated'; font.pixelSize: 11; color: theme.textSecondary }
    }
}
