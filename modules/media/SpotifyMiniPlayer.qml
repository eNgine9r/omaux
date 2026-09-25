import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool expanded: hover.hovered || interaction.hovered
    property bool available: false
    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string playbackStatus: "Stopped"
    property real lengthUs: 0
    property real positionSeconds: 0
    property real volume: 0
    readonly property real durationSeconds: Math.max(0, lengthUs / 1000000)
    readonly property real progress: durationSeconds > 0 ? Math.min(1, positionSeconds / durationSeconds) : 0
    implicitWidth: expanded ? 330 : 190
    implicitHeight: expanded ? 302 : 34
    visible: available

    Behavior on implicitWidth { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent; radius: expanded ? 20 : 17
        color: expanded ? "#ed1c1c1e" : "#d6242426"
        border.color: "#35ffffff"; border.width: 1
        Behavior on radius { NumberAnimation { duration: 180 } }

        Rectangle {
            id: artFallback
            anchors.left: parent.left; anchors.top: parent.top
            anchors.margins: expanded ? 10 : 4
            width: expanded ? parent.width - 20 : 26; height: expanded ? 170 : 26
            radius: expanded ? 13 : 8; color: "#343438"
            Text { anchors.centerIn: parent; text: "♫"; color: "#8affffff"; font.pixelSize: expanded ? 42 : 14 }
            Image {
                anchors.fill: parent; source: root.artUrl; fillMode: Image.PreserveAspectCrop
                asynchronous: true; cache: true; sourceSize.width: expanded ? 620 : 64; sourceSize.height: expanded ? 340 : 64
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }

        Column {
            anchors.left: expanded ? parent.left : artFallback.right
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: expanded ? 14 : 7; anchors.leftMargin: expanded ? 14 : 8
            spacing: expanded ? 7 : 1
            Text { width: parent.width; text: root.title || "Spotify"; color: "white"; font.pixelSize: expanded ? 16 : 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { width: parent.width; visible: expanded; text: root.artist; color: "#b8ffffff"; font.pixelSize: 12; elide: Text.ElideRight }

            Rectangle {
                visible: expanded; width: parent.width; height: 4; radius: 2; color: "#38ffffff"
                Rectangle { width: parent.width * root.progress; height: parent.height; radius: 2; color: "#e8ffffff" }
                TapHandler { onTapped: eventPoint => root.seekFraction(eventPoint.position.x / width) }
            }

            RowLayout {
                visible: expanded; width: parent.width; spacing: 16
                Text { text: root.formatTime(root.positionSeconds); color: "#8fffffff"; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [{i:"‹",a:"previous"},{i: root.playbackStatus === "Playing" ? "Ⅱ" : "▶",a:"play-pause"},{i:"›",a:"next"}]
                    delegate: Text {
                        required property var modelData
                        text: modelData.i; color: "white"; font.pixelSize: 21
                        TapHandler { onTapped: root.command(modelData.a) }
                    }
                }
                Item { Layout.fillWidth: true }
                Text { text: root.formatTime(root.durationSeconds); color: "#8fffffff"; font.pixelSize: 10 }
            }
        }
    }

    HoverHandler { id: hover }
    HoverHandler { id: interaction; margin: 4 }

    Process {
        id: follow
        command: [Quickshell.env("HOME") + "/.local/bin/omaux-spotify-mpris", "follow"]
        stdout: SplitParser { onRead: data => root.consume(data) }
        onExited: restartTimer.restart()
    }
    Timer { id: restartTimer; interval: 1600; repeat: false; onTriggered: if (!follow.running) follow.running = true }
    Timer {
        interval: 1000; repeat: true; running: root.available && root.playbackStatus === "Playing"
        onTriggered: root.positionSeconds = Math.min(root.durationSeconds || Infinity, root.positionSeconds + 1)
    }
    Component.onCompleted: follow.running = true

    function consume(line) {
        try {
            const d = JSON.parse(line)
            available = d.available === true; title = d.title || ""; artist = d.artist || ""; album = d.album || ""
            artUrl = d.artUrl || ""; playbackStatus = d.status || "Stopped"
            lengthUs = Number(d.length) || 0; positionSeconds = Number(d.position) || 0; volume = Number(d.volume) || 0
        } catch (_) { }
    }
    function command(action, arg) {
        actionProcess.command = arg === undefined ? [Quickshell.env("HOME") + "/.local/bin/omaux-spotify-mpris", action] : [Quickshell.env("HOME") + "/.local/bin/omaux-spotify-mpris", action, String(arg)]
        if (!actionProcess.running) actionProcess.running = true
    }
    function seekFraction(f) { if (durationSeconds > 0) { positionSeconds = Math.max(0, Math.min(durationSeconds, durationSeconds * f)); command("position", positionSeconds.toFixed(3)) } }
    function formatTime(v) { const s=Math.max(0,Math.floor(v||0)); return Math.floor(s/60)+":"+String(s%60).padStart(2,"0") }
    Process { id: actionProcess }
}
