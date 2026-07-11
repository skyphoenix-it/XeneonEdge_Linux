import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder

    property var metrics: ({})

    function fmt(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + ' GB'
        if (b >= 1048576) return (b / 1048576).toFixed(1) + ' MB'
        return (b / 1024).toFixed(0) + ' KB'
    }

    ColumnLayout {
        anchors.centerIn: parent; spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "🧠 RAM"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: ((metrics.ram_usage_percent || 0)).toFixed(1) + '%'
            font.pixelSize: parent.parent.height < 100 ? 24 : 32; font.bold: true; font.family: 'monospace'
            color: {
                var p = metrics.ram_usage_percent || 0
                return p > 90 ? theme.error : p > 70 ? theme.warning : theme.accent
            }
        }
        Rectangle {
            Layout.preferredWidth: parent.parent.width * 0.7; Layout.preferredHeight: 4
            Layout.alignment: Qt.AlignHCenter; radius: 2; color: theme.cardBorder
            Rectangle {
                height: parent.height; radius: 2
                width: parent.width * Math.min(((metrics.ram_usage_percent || 0)) / 100, 1.0)
                color: {
                    var p = metrics.ram_usage_percent || 0
                    return p > 90 ? theme.error : p > 70 ? theme.warning : theme.accent
                }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: fmt(metrics.ram_used_bytes || 0) + ' / ' + fmt(metrics.ram_total_bytes || 0)
            font.pixelSize: 10; color: theme.textSecondary
        }
    }
}
