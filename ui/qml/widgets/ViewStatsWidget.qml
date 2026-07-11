import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder

    property var metrics: ({})

    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "📊  System Stats"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: '📈 '+((metrics.cpu_usage_percent||0).toFixed(0))+'% CPU'; font.pixelSize: 13; font.family: 'monospace'; color: theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: '🧠 '+((metrics.ram_usage_percent||0).toFixed(0))+'% RAM'; font.pixelSize: 13; font.family: 'monospace'; color: theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: '🖥 '+(metrics.cpu_core_count||1)+' cores'; font.pixelSize: 13; font.family: 'monospace'; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; visible: (metrics.cpu_temp_celsius||-1)>0; text: '🌡 '+(metrics.cpu_temp_celsius||0).toFixed(0)+'°C'; font.pixelSize: 12; color: theme.warning }
    }
}
