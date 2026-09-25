import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Commons

Scope {
  id: root

  property bool enabled: true
  readonly property var spotifyPlayer: {
    var players = Mpris.players.values
    for (var i = 0; i < players.length; ++i) {
      var player = players[i]
      var signature = (String(player.dbusName || "") + " "
                       + String(player.desktopEntry || "") + " "
                       + String(player.identity || "")).toLowerCase()
      if (signature.indexOf("spotify") !== -1) return player
    }
    return null
  }
  readonly property bool available: enabled && spotifyPlayer !== null

  function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value))
  }

  function savePosition(panel, card) {
    var span = Math.max(0, panel.width - card.width - 16)
    state.xRatio = span > 0 ? clamp((card.x - 8) / span, 0, 1) : 0.5
  }

  FileView {
    id: stateFile
    path: Quickshell.statePath("omaux-spotify-widget.json")
    blockLoading: true
    printErrors: false
    atomicWrites: true
    onAdapterUpdated: writeAdapter()
    onLoadFailed: setText("{\"xRatio\":0.5}\n")

    JsonAdapter {
      id: state
      property real xRatio: 0.5
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.available && root.spotifyPlayer && root.spotifyPlayer.isPlaying
    onTriggered: {
      var player = root.spotifyPlayer
      if (player && player.positionSupported) player.positionChanged()
    }
  }

  component MediaButton: Rectangle {
    id: button
    property string kind: "play"
    property bool available: true
    signal activated()

    implicitWidth: 28
    implicitHeight: 28
    radius: 8
    enabled: available
    color: hover.hovered && enabled ? Util.alpha(Color.foreground, 0.11) : "transparent"
    opacity: enabled ? 1.0 : 0.30

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on opacity { NumberAnimation { duration: 100 } }

    Canvas {
      id: icon
      anchors.centerIn: parent
      width: 14
      height: 14
      property color iconColor: Color.foreground
      onIconColorChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = iconColor
        ctx.strokeStyle = iconColor
        ctx.lineWidth = 1.65
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        if (button.kind === "play") {
          ctx.beginPath()
          ctx.moveTo(4.2, 2.6)
          ctx.lineTo(11.2, 7)
          ctx.lineTo(4.2, 11.4)
          ctx.closePath()
          ctx.fill()
        } else if (button.kind === "pause") {
          ctx.fillRect(3.5, 2.7, 2.2, 8.6)
          ctx.fillRect(8.3, 2.7, 2.2, 8.6)
        } else if (button.kind === "previous") {
          ctx.fillRect(2.7, 3.0, 1.6, 8.0)
          ctx.beginPath()
          ctx.moveTo(10.9, 3.0)
          ctx.lineTo(5.0, 7.0)
          ctx.lineTo(10.9, 11.0)
          ctx.closePath()
          ctx.fill()
        } else if (button.kind === "next") {
          ctx.fillRect(9.7, 3.0, 1.6, 8.0)
          ctx.beginPath()
          ctx.moveTo(3.1, 3.0)
          ctx.lineTo(9.0, 7.0)
          ctx.lineTo(3.1, 11.0)
          ctx.closePath()
          ctx.fill()
        }
      }
    }

    HoverHandler { id: hover; cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler {
      enabled: button.enabled
      onTapped: button.activated()
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      readonly property var monitor: Hyprland.monitorFor(modelData)
      readonly property bool focusedScreen: Quickshell.screens.length <= 1 || (monitor && monitor.focused)
      readonly property var player: root.spotifyPlayer
      readonly property real progress: player && player.lengthSupported && player.length > 0
                                         ? root.clamp(player.position / player.length, 0, 1) : 0

      screen: modelData
      visible: root.available && focusedScreen
      color: "transparent"
      implicitHeight: 48
      exclusionMode: ExclusionMode.Ignore
      surfaceFormat.opaque: false
      WlrLayershell.namespace: "omaux-spotify-mini"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        top: true
        left: true
        right: true
      }

      mask: Region { item: card }

      function restorePosition() {
        if (drag.active) return
        var span = Math.max(0, width - card.width - 16)
        card.x = 8 + root.clamp(state.xRatio, 0, 1) * span
      }

      onWidthChanged: restoreTimer.restart()
      Component.onCompleted: restoreTimer.restart()

      Connections {
        target: state
        function onXRatioChanged() { panel.restorePosition() }
      }

      Timer {
        id: restoreTimer
        interval: 0
        repeat: false
        onTriggered: panel.restorePosition()
      }

      Rectangle {
        id: shadow
        x: card.x
        y: card.y + 2
        width: card.width
        height: card.height
        radius: card.radius + 1
        color: "#38000000"
        opacity: card.opacity
      }

      Rectangle {
        id: card
        y: 4
        width: 314
        height: 40
        radius: 13
        color: Util.alpha(Color.background, 0.94)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.16)
        scale: hover.hovered ? 1.01 : 1.0
        transformOrigin: Item.Center

        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        HoverHandler { id: hover }
        DragHandler {
          id: drag
          target: card
          yAxis.enabled: false
          xAxis.minimum: 8
          xAxis.maximum: Math.max(8, panel.width - card.width - 8)
          onActiveChanged: if (!active) root.savePosition(panel, card)
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 7
          anchors.rightMargin: 6
          anchors.topMargin: 4
          anchors.bottomMargin: 4
          spacing: 7

          Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            Rectangle {
              anchors.fill: parent
              radius: 8
              color: Util.alpha(Color.foreground, 0.08)
              border.width: 1
              border.color: Util.alpha(Color.foreground, 0.10)
            }

            Image {
              anchors.fill: parent
              anchors.margins: 2
              visible: panel.player && panel.player.trackArtUrl !== ""
              source: visible ? panel.player.trackArtUrl : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              smooth: true
              mipmap: true
            }

            Text {
              anchors.centerIn: parent
              visible: !panel.player || panel.player.trackArtUrl === ""
              text: "♫"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: 16
              opacity: 0.80
            }

            Rectangle {
              width: 7
              height: 7
              radius: 4
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              color: "#1DB954"
              border.width: 1
              border.color: Color.background
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: -1

            Text {
              Layout.fillWidth: true
              text: panel.player && panel.player.trackTitle ? panel.player.trackTitle : "Spotify"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Text {
              Layout.fillWidth: true
              text: panel.player && panel.player.trackArtist ? panel.player.trackArtist : "Готовий до відтворення"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: 9
              opacity: 0.58
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 20
            color: Util.alpha(Color.foreground, 0.11)
          }

          RowLayout {
            Layout.preferredWidth: 88
            spacing: 1

            MediaButton {
              kind: "previous"
              available: panel.player && panel.player.canGoPrevious
              onActivated: if (panel.player && panel.player.canGoPrevious) panel.player.previous()
            }

            MediaButton {
              kind: panel.player && panel.player.isPlaying ? "pause" : "play"
              available: panel.player && panel.player.canTogglePlaying
              onActivated: if (panel.player && panel.player.canTogglePlaying) panel.player.togglePlaying()
            }

            MediaButton {
              kind: "next"
              available: panel.player && panel.player.canGoNext
              onActivated: if (panel.player && panel.player.canGoNext) panel.player.next()
            }
          }
        }

        Rectangle {
          visible: panel.player && panel.player.lengthSupported
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: 13
          anchors.rightMargin: 13
          height: 2
          radius: 1
          color: Util.alpha(Color.foreground, 0.10)

          Rectangle {
            width: parent.width * panel.progress
            height: parent.height
            radius: parent.radius
            color: "#1DB954"
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.Linear } }
          }
        }

        TapHandler {
          acceptedButtons: Qt.MiddleButton
          onTapped: if (panel.player && panel.player.canRaise) panel.player.raise()
        }
      }
    }
  }
}
