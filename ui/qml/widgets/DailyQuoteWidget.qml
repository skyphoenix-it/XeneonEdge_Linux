import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "💬  Daily Quote"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var quotes: ['The only way to do great work is to love what you do. - Steve Jobs','Stay hungry, stay foolish. - Steve Jobs','Code is like humor. When you have to explain it, it is bad. - Cory House','First, solve the problem. Then, write the code. - John Johnson','Simplicity is the soul of efficiency. - Austin Freeman']
        property string quote: quotes[Math.floor(Math.random()*quotes.length)]
        Text { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: parent.parent.width*0.85; text: quote; font.pixelSize: 11; color: theme.textSecondary; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 4 }
    }
}
