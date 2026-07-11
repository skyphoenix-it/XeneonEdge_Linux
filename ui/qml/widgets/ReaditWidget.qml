import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "📱  Reddit Feed"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var posts: [{title:'r/linux: Kernel 6.12 released',score:'1.2k'},{title:'r/programming: New Rust pattern',score:'892'},{title:'r/unixporn: My desktop setup',score:'3.4k'}]
        ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: parent.posts
            delegate: RowLayout { spacing: 6
                Text { text: '⬆'+modelData.score; font.pixelSize: 9; color: theme.accent; Layout.preferredWidth: 40 }
                Text { text: modelData.title; font.pixelSize: 11; color: theme.textSecondary; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }
}
