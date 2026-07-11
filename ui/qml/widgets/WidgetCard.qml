import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Premium widget card with tap-to-expand
Rectangle {
    id: card
    radius: 14
    color: theme.cardBackground
    border.width: 1
    border.color: theme.cardBorder

    property string title: ""
    property string icon: ""
    property bool expandable: true
    signal tapped()

    // Default property for inline content (compact preview)
    default property alias inlineContent: contentHost.data

    // Glass effect overlay
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1,1,1,0.03) }
            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.05) }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        // Header row
        RowLayout {
            visible: title !== "" || icon !== ""
            Layout.fillWidth: true
            spacing: 6
            Layout.preferredHeight: 16

            Text {
                visible: icon !== ""
                text: icon
                font.pixelSize: 13
            }

            Text {
                text: title
                font.pixelSize: 9
                font.weight: Font.Medium
                color: theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Expand indicator
            Text {
                visible: expandable
                text: "↗"
                font.pixelSize: 11
                color: theme.accent
                opacity: 0.5
            }
        }

        // Content area — fill remaining space
        Item {
            id: contentHost
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }
    }

    // Tap indicator
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.05)
        opacity: tapArea.pressed || tapArea.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        id: tapArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (expandable) card.tapped()
        }
    }
}
