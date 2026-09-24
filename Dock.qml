import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: true
  readonly property var appLibrary: shell ? shell.appLibrary : null
  property var minimizedCounts: ({})
  property string statePath: Quickshell.env("HOME") + "/.local/state/omaux/minimized.json"
  property string pinStatePath: Quickshell.env("HOME") + "/.config/omaux/pins.json"
  property var pinnedApps: []

  function helperPath(name) {
    var u = Qt.resolvedUrl("bin/" + name).toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }
  function canonical(value) { return String(value || "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]+/g, "") }
  ListModel { id: dockModel }

  FileView {
    id: pinStateFile
    path: root.pinStatePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      var parsed = JSON.parse(String(text() || "{}")); root.pinnedApps = Array.isArray(parsed.pins) ? parsed.pins : []; refreshTimer.restart()
    }
    onFileChanged: reload()
  }

  Timer { id: refreshTimer; interval: 80; repeat: false; onTriggered: root.refreshDock() }

  function refreshDock() {
    dockModel.clear()
    for (var i=0; i<root.pinnedApps.length; i++) {
      var p=root.pinnedApps[i] || ({}); var key=String(p.key || canonical(p.desktop || ""));
      if (!key) continue
      var icon=Quickshell.iconPath(String(p.icon || "application-x-executable"), true)
      dockModel.append({appKey:key,desktopId:String(p.desktop||""),label:String(p.name||key),iconSource:icon})
    }
  }

  function clickApp(key, desktopId) {
    Quickshell.execDetached(["bash", root.helperPath("omaux-dock-window"), "click", String(key), String(desktopId || "")])
  }

  function open() { root.opened = true }
  function close() { root.opened = false }

  component DockButton: Item {
    id: buttonRoot
    property string labelText: ""
    property url imageSource: ""
    property string glyph: ""
    signal activated()
    width: 36; height: 43
    Rectangle {
      id:hoverPlate; width:34; height:34; anchors.centerIn:parent; radius:9
      color: mouse.containsMouse ? Util.alpha(Color.foreground,0.09) : "transparent"
      scale: mouse.containsMouse ? 1.10 : 1.0
      Behavior on scale { NumberAnimation { duration:135; easing.type:Easing.OutCubic } }
      Image { visible:buttonRoot.glyph===""; anchors.centerIn:parent; width:24; height:24; source:buttonRoot.imageSource; fillMode:Image.PreserveAspectFit }
      Text { visible:buttonRoot.glyph!==""; anchors.centerIn:parent; text:buttonRoot.glyph; color:Color.foreground; font.family:Style.font.family; font.pixelSize:24 }
    }
    MouseArea { id:mouse; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onClicked:buttonRoot.activated() }
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen:modelData; visible:root.opened; color:"transparent"; implicitHeight:58
      exclusionMode:ExclusionMode.Auto; surfaceFormat.opaque:false
      WlrLayershell.namespace:"omaux-dock"; WlrLayershell.layer:WlrLayer.Top; WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
      anchors { bottom:true; left:true; right:true }
      Rectangle {
        id:dockCard; width:dockRow.implicitWidth+17; height:46; anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:6
        radius:14; color:Util.alpha(Color.background,0.91); border.width:1; border.color:Util.alpha(Color.foreground,0.16)
        Row {
          id:dockRow; anchors.centerIn:parent; spacing:5
          DockButton { labelText:"Apps"; glyph:"󰀻"; onActivated:Quickshell.execDetached(["omarchy-menu","toggle","apps"]) }
          Rectangle { width:1; height:27; anchors.verticalCenter:parent.verticalCenter; color:Util.alpha(Color.foreground,0.16) }
          Repeater {
            model:dockModel
            DockButton {
              required property string appKey; required property string desktopId; required property string label; required property string iconSource
              labelText:label; imageSource:iconSource; onActivated:root.clickApp(appKey,desktopId)
            }
          }
        }
      }
    }
  }
}
