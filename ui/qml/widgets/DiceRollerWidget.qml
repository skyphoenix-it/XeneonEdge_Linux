import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🎲  Dice Roller"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property int lastRoll: 0; property int sides: 6
        Text { Layout.alignment: Qt.AlignHCenter; text: lastRoll>0?'🎲 '+lastRoll:'Tap to roll d'+sides; font.pixelSize: lastRoll>0?30:16; font.bold: true; color: theme.textPrimary }
        RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 4
            Repeater { model: [4,6,8,10,12,20]
                Rectangle { width: 24; height: 24; radius: 6; color: parent.parent.parent.sides===modelData?theme.accent:theme.cardBorder
                    Text { anchors.centerIn: parent; text: 'd'+modelData; font.pixelSize: 8; color: parent.parent.parent.sides===modelData?'#000':theme.textSecondary }
                    MouseArea { anchors.fill: parent; onClicked: { parent.parent.parent.sides=modelData; parent.parent.parent.lastRoll=0; } }
                }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: { parent.parent.parent.lastRoll = Math.floor(Math.random()*parent.parent.parent.sides)+1; } }
    }
}
