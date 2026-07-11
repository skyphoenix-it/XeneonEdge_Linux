import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Full-screen overlay for expanded widget interaction
Rectangle {
    id: overlay
    anchors.fill: parent
    color: theme.backgroundColor
    z: 100

    property string widgetTitle: ""
    property var widgetContent: null
    signal closeRequested()

    // Slide-in animation
    scale: 0.95
    opacity: 0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Component.onCompleted: {
        scale = 1.0
        opacity = 1.0
    }

    // Back button
    Rectangle {
        id: backBtn
        anchors.left: parent.left; anchors.top: parent.top
        anchors.margins: 16
        width: 40; height: 40; radius: 10
        color: theme.cardBackground
        border.width: 1; border.color: theme.cardBorder
        z: 10

        Text {
            anchors.centerIn: parent
            text: "←"
            font.pixelSize: 20
            color: theme.textPrimary
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                overlay.scale = 0.95
                overlay.opacity = 0
                closeTimer.start()
            }
        }
    }

    // Title
    Text {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        text: widgetTitle
        font.pixelSize: 18; font.bold: true
        color: theme.textPrimary
        z: 10
    }

    // Content area
    Item {
        anchors.top: backBtn.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 12; anchors.topMargin: 12
        clip: true

        // Dynamically-loaded widget content
        Loader {
            anchors.fill: parent
            sourceComponent: widgetContent
        }
    }

    Timer {
        id: closeTimer
        interval: 250
        onTriggered: overlay.closeRequested()
    }
}

