import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    property var metrics: ({})

    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "🖥 CPU"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: ((metrics.cpu_usage_percent || 0)).toFixed(1) + "%"
            font.pixelSize: parent.parent.height < 100 ? 24 : 32; font.bold: true; font.family: "monospace"
            color: { var p = metrics.cpu_usage_percent || 0; return p > 80 ? theme.error : p > 50 ? theme.warning : theme.accent }
        }
        Rectangle {
            Layout.preferredWidth: parent.parent.width * 0.7; Layout.preferredHeight: 4; Layout.alignment: Qt.AlignHCenter
            radius: 2; color: theme.cardBorder
            Rectangle {
                height: parent.height; radius: 2
                width: parent.width * Math.min(((metrics.cpu_usage_percent || 0)) / 100, 1.0)
                color: { var p = metrics.cpu_usage_percent || 0; return p > 80 ? theme.error : p > 50 ? theme.warning : theme.accent }
            }
        }
        Text { Layout.alignment: Qt.AlignHCenter; visible: (metrics.cpu_temp_celsius || -1) > 0; text: (metrics.cpu_temp_celsius || 0).toFixed(0) + "°C"; font.pixelSize: 11; color: theme.textSecondary }
    }
}

