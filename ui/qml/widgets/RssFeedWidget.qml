import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "📰  RSS Feed"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property var items: ['Linux 6.12 released with new features','Qt 6.8 brings improved rendering','Xeneon Edge SDK updated to v2']
        ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: parent.items
            delegate: Text { text: '• '+modelData; font.pixelSize: 11; color: theme.textSecondary; elide: Text.ElideRight; width: parent.width }
        }
    }
}
