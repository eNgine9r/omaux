import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: root

  property var dockRoot: null
  property var hostWindow: null
  property var dockCardItem: null

  property string appKey: ""
  property string appLabel: ""
  property url iconSource: ""
  property var previewWindows: []
  property int totalWindowCount: 0
  property real anchorCenterX: 0
  readonly property string uiFontFamily: "Noto Sans"

  property bool mounted: false
  property bool shown: false
  property bool popupHovered: false
  property string hoveredAppKey: ""

  property string pendingAppKey: ""
  property string pendingLabel: ""
  property url pendingIconSource: ""
  property real pendingCenterX: 0

  readonly property real availableWidth: root.hostWindow ? root.hostWindow.width : root.width
  readonly property int previewColumns: {
    var count = root.previewWindows.length
    if (count <= 1) return 1
    if (count === 3 && root.availableWidth >= 900) return 3
    return 2
  }
  readonly property int previewRows: Math.max(1, Math.ceil(previewWindows.length / previewColumns))
  readonly property int previewCellWidth: previewColumns === 1
                                            ? Math.min(340, Math.max(240, availableWidth - 36))
                                            : (previewColumns === 3 ? 250 : 286)
  readonly property int previewCellHeight: previewColumns === 3 ? 190 : 198
  readonly property int previewGap: 8
  readonly property int outerWidth: previewColumns * previewCellWidth + (previewColumns - 1) * previewGap + 20
  readonly property int extraWindowHeight: totalWindowCount > 4 ? 24 : 0
  readonly property int outerHeight: 46 + previewRows * previewCellHeight + (previewRows - 1) * previewGap + 16 + extraWindowHeight

  screen: root.hostWindow ? root.hostWindow.screen : null
  visible: root.mounted
  color: "transparent"
  implicitHeight: Math.max(1, root.outerHeight + 70)
  exclusionMode: ExclusionMode.Ignore
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omaux-dock-preview"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    bottom: true
    left: true
    right: true
  }

  mask: Region { item: previewHitArea }

  function centerForButton(button) {
    if (!button || !root.dockCardItem) return root.width / 2
    try {
      var point = button.mapToItem(root.dockCardItem, button.width / 2, 0)
      return root.dockCardItem.x + point.x
    } catch (e) {
      return root.width / 2
    }
  }

  function windowsFor(key) {
    if (!root.dockRoot || !key) return []
    try { return root.dockRoot.windowsForKey(key) || [] }
    catch (e) { return [] }
  }

  function enterApp(button, key, label, source) {
    if (!key) return
    root.hoveredAppKey = String(key)
    closeDelay.stop()
    unmountDelay.stop()

    root.pendingAppKey = String(key)
    root.pendingLabel = String(label || key)
    root.pendingIconSource = source || ""
    root.pendingCenterX = centerForButton(button)

    if (root.mounted) {
      openDelay.stop()
      commitPending()
    } else {
      openDelay.restart()
    }
  }

  function leaveApp(key) {
    if (root.hoveredAppKey === String(key || "")) root.hoveredAppKey = ""
    if (!root.mounted && root.pendingAppKey === String(key || "")) openDelay.stop()
    scheduleClose()
  }

  function scheduleClose() {
    if (root.popupHovered || root.hoveredAppKey !== "") return
    closeDelay.restart()
  }

  function setPopupHovered(value) {
    root.popupHovered = value === true
    if (root.popupHovered) {
      closeDelay.stop()
      unmountDelay.stop()
      if (root.mounted) root.shown = true
    } else {
      scheduleClose()
    }
  }

  function commitPending() {
    var key = root.pendingAppKey
    if (!key || root.hoveredAppKey !== key) return

    var all = windowsFor(key)
    if (!all || all.length === 0) {
      dismiss()
      return
    }

    var wasMounted = root.mounted
    root.appKey = key
    root.appLabel = root.pendingLabel
    root.iconSource = root.pendingIconSource
    root.anchorCenterX = root.pendingCenterX
    root.totalWindowCount = all.length
    root.previewWindows = all.slice(0, 4)
    root.mounted = true

    if (wasMounted) {
      root.shown = true
    } else {
      root.shown = false
      Qt.callLater(function() {
        if (root.mounted && root.appKey === key) root.shown = true
      })
    }
  }

  function activateSelectedWindow(top) {
    if (!top || !root.dockRoot) return
    root.dockRoot.activatePreviewWindow(top)
    root.dismiss()
  }

  function refreshWindows() {
    if (!root.mounted || !root.appKey) return
    var all = windowsFor(root.appKey)
    if (!all || all.length === 0) {
      dismiss()
      return
    }
    root.totalWindowCount = all.length
    root.previewWindows = all.slice(0, 4)
  }

  function beginClose() {
    if (!root.mounted) return
    root.shown = false
    unmountDelay.restart()
  }

  function dismiss() {
    openDelay.stop()
    closeDelay.stop()
    root.hoveredAppKey = ""
    root.popupHovered = false
    beginClose()
  }

  Timer {
    id: openDelay
    interval: 280
    repeat: false
    onTriggered: root.commitPending()
  }

  Timer {
    id: closeDelay
    interval: 160
    repeat: false
    onTriggered: {
      if (!root.popupHovered && root.hoveredAppKey === "") root.beginClose()
    }
  }

  Timer {
    id: unmountDelay
    interval: 145
    repeat: false
    onTriggered: {
      if (root.popupHovered || root.hoveredAppKey !== "") {
        root.shown = true
        return
      }
      root.mounted = false
      root.shown = false
      root.previewWindows = []
      root.totalWindowCount = 0
      root.appKey = ""
    }
  }

  Timer {
    id: refreshAfterClose
    interval: 120
    repeat: false
    onTriggered: root.refreshWindows()
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() {
      if (root.mounted) Qt.callLater(function() { root.refreshWindows() })
    }
  }

  Item {
    id: previewHitArea
    width: Math.min(root.outerWidth, Math.max(1, root.width - 16))
    height: root.outerHeight
    x: Math.max(8, Math.min(root.width - width - 8, root.anchorCenterX - width / 2))
    y: Math.max(4, root.height - height - 64)
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1.0 : 0.965
    transformOrigin: Item.Bottom

    Behavior on opacity { NumberAnimation { duration: 125; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    HoverHandler {
      onHoveredChanged: root.setPopupHovered(hovered)
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -4
      radius: 22
      color: Util.alpha(Color.background, 0.32)
      z: -2
    }

    Rectangle {
      id: previewSurface
      anchors.fill: parent
      radius: 18
      color: Util.alpha(Color.background, 0.965)
      border.width: 1
      border.color: Util.alpha(Color.foreground, 0.17)
      clip: true

      Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Item {
          width: parent.width
          height: 28

          Image {
            id: appIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }

          Text {
            anchors.left: appIcon.right
            anchors.leftMargin: 8
            anchors.right: windowCountLabel.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.appLabel
            color: Color.foreground
            font.family: root.uiFontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          Text {
            id: windowCountLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.totalWindowCount > 1 ? String(root.totalWindowCount) + " вік." : ""
            color: Util.alpha(Color.foreground, 0.58)
            font.family: root.uiFontFamily
            font.pixelSize: 10
          }
        }

        Grid {
          id: previewGrid
          columns: root.previewColumns
          spacing: root.previewGap

          Repeater {
            model: root.previewWindows

            Rectangle {
              id: previewCard
              required property var modelData
              width: root.previewCellWidth
              height: root.previewCellHeight
              radius: 13
              color: cardMouse.containsMouse ? Util.alpha(Color.foreground, 0.075)
                                                 : Util.alpha(Color.foreground, 0.035)
              border.width: modelData && modelData.activated ? 1 : 0
              border.color: Color.accent
              clip: true

              Behavior on color { ColorAnimation { duration: 100 } }

              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activateSelectedWindow(previewCard.modelData)
              }

              Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 5

                Item {
                  width: parent.width
                  height: 27

                  Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: previewCard.modelData && previewCard.modelData.activated ? Color.accent
                                                                                    : Util.alpha(Color.foreground, 0.34)
                  }

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.right: closeButton.left
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    text: previewCard.modelData ? String(previewCard.modelData.title || root.appLabel) : root.appLabel
                    color: Color.foreground
                    font.family: root.uiFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    id: closeButton
                    width: 20
                    height: 20
                    radius: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeMouse.containsMouse ? "#ff5f57" : Util.alpha(Color.foreground, 0.075)
                    opacity: cardMouse.containsMouse || closeMouse.containsMouse ? 1.0 : 0.66
                    z: 4

                    Behavior on color { ColorAnimation { duration: 90 } }
                    Behavior on opacity { NumberAnimation { duration: 90 } }

                    Text {
                      anchors.centerIn: parent
                      text: "×"
                      color: closeMouse.containsMouse ? "#5b1410" : Util.alpha(Color.foreground, 0.72)
                      font.family: root.uiFontFamily
                      font.pixelSize: 14
                      font.weight: Font.DemiBold
                    }

                    MouseArea {
                      id: closeMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: function(mouse) {
                        mouse.accepted = true
                        if (!previewCard.modelData) return
                        var wasLast = root.totalWindowCount <= 1
                        previewCard.modelData.close()
                        if (wasLast) root.dismiss()
                        else refreshAfterClose.restart()
                      }
                    }
                  }

                  MouseArea {
                    id: headerActivateMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: closeButton.left
                    anchors.rightMargin: 5
                    z: 3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                      mouse.accepted = true
                      root.activateSelectedWindow(previewCard.modelData)
                    }
                  }
                }

                Item {
                  id: previewViewport
                  width: parent.width
                  height: parent.height - 32

                  Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Util.alpha(Color.foreground, 0.028)
                    border.width: 1
                    border.color: Util.alpha(Color.foreground, 0.08)
                  }

                  Image {
                    anchors.centerIn: parent
                    width: 42
                    height: 42
                    source: root.iconSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    opacity: screencopy.hasContent && !screencopy.captureStopped ? 0 : 0.30
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                  }

                  ScreencopyView {
                    id: screencopy
                    property bool captureStopped: false
                    anchors.centerIn: parent
                    captureSource: root.mounted ? previewCard.modelData : null
                    live: root.mounted && root.shown
                    paintCursor: false
                    constraintSize: Qt.size(Math.max(1, previewViewport.width - 8), Math.max(1, previewViewport.height - 8))
                    opacity: hasContent && !captureStopped ? 1.0 : 0.0

                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    onStopped: captureStopped = true
                    onCaptureSourceChanged: captureStopped = false
                  }

                  MouseArea {
                    id: previewActivateMouse
                    anchors.fill: parent
                    z: 5
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                      mouse.accepted = true
                      root.activateSelectedWindow(previewCard.modelData)
                    }
                  }
                }
              }
            }
          }
        }

        Text {
          visible: root.totalWindowCount > 4
          width: parent.width
          height: visible ? 16 : 0
          text: "+" + String(root.totalWindowCount - 4) + " вік."
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          color: Util.alpha(Color.foreground, 0.54)
          font.family: root.uiFontFamily
          font.pixelSize: 10
        }
      }
    }
  }
}
