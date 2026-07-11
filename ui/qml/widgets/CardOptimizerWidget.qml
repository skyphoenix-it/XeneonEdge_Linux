import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "💳  Card Benefits"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var cards: [{name:'Amex Plat',perks:'$200 travel, $200 Uber'},{name:'Chase CSR',perks:'$300 travel, DoorDash'},{name:'Apple Card',perks:'3% Apple Pay'}]
        ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: parent.cards
            delegate: Text { text: modelData.name+': '+modelData.perks; font.pixelSize: 10; color: theme.textSecondary; elide: Text.ElideRight; width: parent.width }
        }
    }
}
