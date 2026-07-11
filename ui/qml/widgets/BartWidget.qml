import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🚇  BART Times"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var trains: [{dest:'SFO',min:'5'},{dest:'Daly City',min:'12'},{dest:'Richmond',min:'18'}]
        ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: parent.trains
            delegate: RowLayout { spacing: 8
                Text { text: modelData.dest; font.pixelSize: 13; font.bold: true; color: theme.textPrimary; Layout.fillWidth: true }
                Text { text: modelData.min+' min'; font.pixelSize: 13; font.family: 'monospace'; color: parseInt(modelData.min)<10?theme.success:theme.textSecondary }
            }
        }
    }
}
