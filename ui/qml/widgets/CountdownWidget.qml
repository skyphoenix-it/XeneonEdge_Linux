import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true
    radius: 12; color: theme.cardBackground; border.width: 1; border.color: theme.cardBorder
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; text: "⏳  Countdown"; font.pixelSize: 12; font.bold: true; color: theme.textSecondary }
        property date target: new Date(2026,11,25)
        property var diff: { var d=target.getTime()-Date.now(); if(d<0) return {d:0,h:0,m:0,s:0}; return {d:Math.floor(d/86400000),h:Math.floor((d%86400000)/3600000),m:Math.floor((d%3600000)/60000),s:Math.floor((d%60000)/1000)} }
        Text { Layout.alignment: Qt.AlignHCenter; text: diff.d+'d '+diff.h+'h '+diff.m+'m'; font.pixelSize: 22; font.bold: true; font.family: 'monospace'; color: theme.accent }
        Text { Layout.alignment: Qt.AlignHCenter; text: 'Dec 25, 2026'; font.pixelSize: 11; color: theme.textSecondary }
    }
}
