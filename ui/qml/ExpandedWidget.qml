import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Full-screen overlay for expanded widget interaction.
// Animation is driven by the `shown` state (bound by the parent) so the
// overlay can be opened and closed repeatedly — not just once.
Rectangle {
    id: overlay
    anchors.fill: parent
    color: theme.backgroundColor
    z: 100

    property string widgetTitle: ""
    property var widgetContent: null
    // Parent binds this to "is a widget currently expanded?".
    property bool shown: false
    signal closeRequested()

    // Only occupy/hittest the screen while visible or animating out.
    visible: shown || opacity > 0.01

    // State-driven entrance/exit animation (re-runs every open/close).
    scale: shown ? 1.0 : 0.96
    opacity: shown ? 1.0 : 0.0
    Behavior on scale { NumberAnimation { duration: theme.motionPage; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: theme.motionFast } }

    // Back button
    Rectangle {
        id: backBtn
        anchors.left: parent.left; anchors.top: parent.top
        anchors.margins: theme.spacingLg
        width: theme.touchSecondary; height: theme.touchSecondary; radius: theme.radiusMd
        color: theme.cardBackground
        border.width: 1; border.color: theme.cardBorder
        z: 10

        Text {
            anchors.centerIn: parent
            text: "←"
            font.pixelSize: 24
            color: theme.textPrimary
        }
        MouseArea {
            anchors.fill: parent
            onClicked: overlay.closeRequested()
        }
    }

    // Title
    Text {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: theme.spacingXl
        text: widgetTitle
        font.pixelSize: theme.fontTitle + 3; font.bold: true
        color: theme.textPrimary
        z: 10
    }

    // Content area
    Item {
        anchors.top: backBtn.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: theme.spacingLg; anchors.topMargin: theme.spacingLg
        clip: true

        // Dynamically-loaded widget content. Unload while hidden to free
        // resources and guarantee a fresh instance on the next open.
        Loader {
            anchors.fill: parent
            active: overlay.shown
            sourceComponent: overlay.shown ? widgetContent : null
        }
    }
}
