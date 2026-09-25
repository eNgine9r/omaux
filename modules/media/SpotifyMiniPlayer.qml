import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool expanded: hover.hovered
    property bool available: false
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    implicitWidth: expanded ? 330 : 190
    implicitHeight: expanded ? 286 : 34
    visible: available

    Behavior on implicitWidth { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: expanded ? 20 : 17
        color: expanded ? "#e61c1c1e" : "#cc242426"
        border.color: "#35ffffff"
        border.width: 1

        Behavior on radius { NumberAnimation { duration: 180 } }

        Image {
            id: artwork
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: expanded ? 10 : 4
            width: expanded ? parent.width - 20 : 26
            height: expanded ? 170 : 26
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        Column {
            anchors.left: expanded ? parent.left : artwork.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: expanded ? 14 : 7
            anchors.leftMargin: expanded ? 14 : 8
            spacing: expanded ? 7 : 1

            Text { width: parent.width; text: root.title || "Spotify"; color: "white"; font.pixelSize: expanded ? 16 : 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { width: parent.width; visible: expanded; text: root.artist; color: "#b8ffffff"; font.pixelSize: 12; elide: Text.ElideRight }

            RowLayout {
                visible: expanded
                width: parent.width
                spacing: 18
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [{i:"‹",a:"previous"},{i: root.playbackStatus === "Playing" ? "Ⅱ" : "▶",a:"play-pause"},{i:"›",a:"next"}]
                    delegate: Text {
                        required property var modelData
                        text: modelData.i; color: "white"; font.pixelSize: 22
                        TapHandler { onTapped: root.command(modelData.a) }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    HoverHandler { id: hover }

    Process {
        id: follow
        command: [Quickshell.env("HOME") + "/.local/bin/omaux-spotify-mpris", "follow"]
        stdout: SplitParser { onRead: data => root.consume(data) }
        onExited: restartTimer.restart()
    }
    Timer { id: restartTimer; interval: 1200; onTriggered: follow.running = true }
    Component.onCompleted: follow.running = true

    function consume(line) {
        try {
            const d = JSON.parse(line)
            available = d.available === true
            title = d.title || ""
            artist = d.artist || ""
            artUrl = d.artUrl || ""
            playbackStatus = d.status || "Stopped"
        } catch (_) { }
    }
    function command(action) { actionProcess.command = [Quickshell.env("HOME") + "/.local/bin/omaux-spotify-mpris", action]; actionProcess.running = true }
    Process { id: actionProcess }
}
