import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder

    property var metrics: ({})

    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "📊  Sensors"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'CPU: '+((metrics.cpu_usage_percent||0).toFixed(0))+'%'; font.pixelSize: 16; font.bold: true; font.family: 'monospace'; color: theme.textPrimary }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'RAM: '+((metrics.ram_usage_percent||0).toFixed(0))+'%'; font.pixelSize: 15; font.family: 'monospace'; color: theme.textSecondary }
        Text { Layout.alignment: Qt.AlignHCenter; visible: (metrics.cpu_temp_celsius||-1)>0; text: 'Temp: '+(metrics.cpu_temp_celsius||0).toFixed(0)+'°C'; font.pixelSize: 14; color: theme.textSecondary }
    }
}
