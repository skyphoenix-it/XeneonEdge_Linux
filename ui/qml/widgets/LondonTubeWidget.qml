import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "🚂  Tube Times"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var lines: [{line:'Central',dest:'Epping',min:'3'},{line:'District',dest:'Richmond',min:'7'},{line:'Piccadilly',dest:'Cockfosters',min:'11'}]
        ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: parent.lines
            delegate: RowLayout { spacing: 8
                Rectangle { width: 8; height: 8; radius: 4; color: modelData.line==='Central'?'#DC241F':modelData.line==='District'?'#00782A':'#0019A8' }
                Text { text: modelData.dest; font.pixelSize: 12; color: theme.textPrimary; Layout.fillWidth: true }
                Text { text: modelData.min+' min'; font.pixelSize: 12; font.family: 'monospace'; color: parseInt(modelData.min)<5?theme.success:theme.textSecondary }
            }
        }
    }
}
