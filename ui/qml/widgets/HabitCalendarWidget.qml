import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "📅  Habit Calendar"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var days: {
            var d=new Date(); var m=d.getMonth(); var y=d.getFullYear();
            var first=new Date(y,m,1).getDay(); var total=new Date(y,m+1,0).getDate(); var a=[];
            for(var i=0;i<first;i++) a.push('');
            for(var i=1;i<=total;i++) a.push(i);
            return a;
        }
        GridLayout { Layout.fillWidth: true; columns: 7; columnSpacing: 2; rowSpacing: 2
            Repeater { model: ['S','M','T','W','T','F','S']
                Text { text: modelData; font.pixelSize: 9; color: theme.textSecondary; Layout.alignment: Qt.AlignHCenter }
            }
            Repeater { model: parent.parent.days
                Rectangle { width: 18; height: 18; radius: 4; color: modelData ? theme.cardBackground : 'transparent'; border.width: modelData?1:0; border.color: modelData?theme.cardBorder:'transparent'
                    Text { anchors.centerIn: parent; text: modelData||''; font.pixelSize: 9; color: (modelData===new Date().getDate())?theme.accent:theme.textSecondary }
                }
            }
        }
    }
}
