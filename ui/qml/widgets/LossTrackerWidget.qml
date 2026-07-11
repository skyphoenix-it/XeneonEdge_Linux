import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "📈  Win/Loss"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property int wins: 42; property int losses: 18
        RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 16
            ColumnLayout { spacing: 2
                Text { Layout.alignment: Qt.AlignHCenter; text: 'W'; font.pixelSize: 11; color: theme.success }
                Text { Layout.alignment: Qt.AlignHCenter; text: wins; font.pixelSize: 24; font.bold: true; font.family: 'monospace'; color: theme.success }
            }
            Rectangle { width: 1; height: 40; color: theme.cardBorder }
            ColumnLayout { spacing: 2
                Text { Layout.alignment: Qt.AlignHCenter; text: 'L'; font.pixelSize: 11; color: theme.error }
                Text { Layout.alignment: Qt.AlignHCenter; text: losses; font.pixelSize: 24; font.bold: true; font.family: 'monospace'; color: theme.error }
            }
        }
        Text { Layout.alignment: Qt.AlignHCenter; text: (wins/(wins+losses)*100).toFixed(1)+'% win rate'; font.pixelSize: 10; color: theme.textSecondary }
    }
}
