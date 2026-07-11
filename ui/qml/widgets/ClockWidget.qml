import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: widget
    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 12
    color: theme.cardBackground
    border.width: 1
    border.color: theme.cardBorder

    property int tick: 0

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            font.pixelSize: parent.parent.height < 100 ? 28 : 42
            font.bold: true
            font.family: "monospace"
            color: theme.textPrimary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(new Date(), "ddd, MMM d")
            font.pixelSize: parent.parent.height < 100 ? 10 : 14
            color: theme.textSecondary
        }
    }

    // Re-evaluate time binding when tick changes
    Binding on tick { when: tick >= 0 }
}

