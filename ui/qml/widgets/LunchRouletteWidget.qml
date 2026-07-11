import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🍔  Lunch Roulette"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var options: ['🍕 Pizza','🍣 Sushi','🌮 Tacos','🍜 Ramen','🥗 Salad','🍔 Burger','🥙 Gyro','🍛 Curry']
        property string selected: ''
        Text { Layout.alignment: Qt.AlignHCenter; text: selected||'Spin for lunch!'; font.pixelSize: selected?20:14; font.bold: true; color: selected?theme.accent:theme.textSecondary }
        Button { Layout.alignment: Qt.AlignHCenter; text: '🎰 Spin'; flat: true; font.pixelSize: 12
            onClicked: { var i=Math.floor(Math.random()*parent.parent.parent.options.length); parent.parent.parent.selected=parent.parent.parent.options[i]; } }
    }
}
