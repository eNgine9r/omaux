import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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
  property var minimizedWindows: ({})
  property string statePath: Quickshell.env("HOME") + "/.local/state/omaux/minimized.json"
  property string pinStatePath: Quickshell.env("HOME") + "/.config/omarchy/dock-pins.json"
  property var pinnedApps: []

  // Pins are user state, not code: menu pin actions update this file and the
  // FileView below refreshes the dock immediately.
  function loadPins(raw) {
    var next = []
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      var pins = Array.isArray(parsed.pins) ? parsed.pins : []
      for (var i = 0; i < pins.length; i++) {
        var pin = pins[i] || ({})
        var key = String(pin.key || canonical(pin.desktop || ""))
        if (!key) continue
        next.push({
          key: key,
          desktop: String(pin.desktop || ""),
          name: String(pin.name || pin.desktop || key),
          icon: String(pin.icon || "")
        })
      }
    } catch (e) { }
    root.pinnedApps = next
    refreshTimer.restart()
  }

  ListModel { id: dockModel }

  function helperPath(name) {
    return Quickshell.env("HOME") + "/.local/bin/" + String(name || "")
  }

  function canonical(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]+/g, "")
  }

  function allEntries() {
    try { return root.appLibrary ? root.appLibrary.sortedEntries("") : [] }
    catch (e) { return [] }
  }

  function webAppHostSignature(execString) {
    var match = String(execString || "").match("https?:\/\/([^\s\/\"']+)")
    return match && match.length > 1 ? canonical(match[1]) : ""
  }

  function commandAppIdSignature(execString) {
    var match = String(execString || "").match("--(?:app-id|class|name)=[\\\"']?([^\\s\\\"']+)")
    return match && match.length > 1 ? canonical(match[1]) : ""
  }

  function entryAliasSignatures(entry) {
    if (!entry) return []
    var values = [
      canonical(entry.name || ""),
      canonical(entry.icon || "")
    ]
    var exec = String(entry.execString || "").trim()
    var first = exec.match(/^[\\\"']?([^\\s\\\"']+)/)
    if (first && first.length > 1) {
      var command = String(first[1] || "")
      var slash = command.lastIndexOf("/")
      if (slash >= 0) command = command.slice(slash + 1)
      values.push(canonical(command))
    }
    return values
  }

  function hasStrongAlias(rawKey, aliases) {
    for (var i = 0; i < aliases.length; i++) {
      var alias = String(aliases[i] || "")
      if (alias.length >= 4 && rawKey.indexOf(alias) !== -1) return true
    }
    return false
  }

  function entryForRawAppId(rawId) {
    var rawKey = canonical(rawId)
    if (!rawKey) return null

    var rows = allEntries()
    var webMatches = []
    var aliasMatches = []
    for (var i = 0; i < rows.length; i++) {
      var entry = rows[i].entry
      if (!entry) continue
      var id = canonical(entry.id)
      var startup = canonical(entry.startupClass || "")
      var commandAppId = commandAppIdSignature(entry.execString || "")
      if (id === rawKey || (startup && startup === rawKey) || (commandAppId && commandAppId === rawKey))
        return entry

      // Omarchy web apps are launched with Chromium-family --app= URLs.
      // Their Wayland app id becomes e.g. chrome-youtube.com__-Default,
      // which must be associated with YouTube.desktop rather than shown as       // a second generic "gear" application.
      var host = webAppHostSignature(entry.execString || "")
      if (host && rawKey.indexOf(host) !== -1) webMatches.push(entry)

      // Some native apps use a reverse-DNS Wayland id that differs from the
      // desktop id and omit StartupWMClass. Example:
      //   localsend.desktop -> org.localsend.localsend_app
      // Match only strong (>=4 chars) name/icon/executable aliases and only
      // accept a unique result so we never attach a preview to the wrong app.
      if (hasStrongAlias(rawKey, entryAliasSignatures(entry))) aliasMatches.push(entry)
    }
   if (webMatches.length === 1) return webMatches[0]
    return aliasMatches.length === 1 ? aliasMatches[0] : null
  }

  function pinnedKeyForEntry(entry) {
    if (!entry) return ""
    var id = canonical(entry.id)
    for (var i = 0; i < root.pinnedApps.length; i++) {
      var pin = root.pinnedApps[i] || ({})
      if (String(pin.key || "") === id || canonical(pin.desktop || "") === id)
        return String(pin.key || id)
    }
    return id
  }

  function browserWebAppIdentity(rawId) {
    var raw = String(rawId || "").toLowerCase()
    var match = raw.match(/^(?:chrome|chromium|brave|microsoft-edge|opera|vivaldi|helium)-(.+)$/)
    if (!match || match.length < 2) return ({ web: false, key: "", hostLabel: "" })
    var tail = String(match[1] || "")
    var host = tail.split("__")[0]
    var label = host.split(".")[0]
    return ({ web: true, key: canonical(tail), hostLabel: canonical(label) })
  }

  function pinnedKeyForRawApp(rawId, title) {
    var rawKey = canonical(rawId)
    var titleKey = canonical(title)
    var web = browserWebAppIdentity(rawId)
    var matches = []
    for (var i = 0; i < root.pinnedApps.length; i++) {
      var pin = root.pinnedApps[i] || ({})
      var key = String(pin.key || canonical(pin.desktop || ""))
      if (!key) continue
      var aliases = [pin.key, pin.desktop, pin.name, pin.icon]
      var hit = false
      for (var j = 0; j < aliases.length; j++) {
        var alias = canonical(aliases[j])
        if (!alias) continue
        if (rawKey === alias) return key
        var target = web.web ? web.key : rawKey
        if (alias.length >= 4 && target.indexOf(alias) !== -1) hit = true
        if (web.web && web.hostLabel && alias === web.hostLabel) hit = true
      }
      var entry = findEntry(key, pin.desktop)
      if (entry) {
        var startup = canonical(entry.startupClass || "")
        var commandId = commandAppIdSignature(entry.execString || "")
        var host = webAppHostSignature(entry.execString || "")
        if ((startup && startup === rawKey) || (commandId && commandId === rawKey)) return key
        if (web.web && host && web.key.indexOf(host) !== -1) hit = true
      }
      if (!hit && web.web) {
        var pinName = canonical(pin.name || "")
        if (pinName.length >= 4 && titleKey.indexOf(pinName) !== -1) hit = true
      }
      if (hit && matches.indexOf(key) === -1) matches.push(key)
    }
    return matches.length === 1 ? String(matches[0]) : ""
  }

  function resolvedKeyForAppId(rawId, title) {
    var rawKey = canonical(rawId)
    if (!rawKey) return ""
    var pinned = pinnedKeyForRawApp(rawId, title)
    if (pinned) return pinned
    var entry = entryForRawAppId(rawId)
    return entry ? pinnedKeyForEntry(entry) : rawKey
  }

  function findEntry(key, desktopHint) {
    var rows = allEntries()
    var hint = canonical(desktopHint)
    for (var i = 0; i < rows.length; i++) {
      var entry = rows[i].entry
      if (!entry) continue
      var id = canonical(entry.id)
      if ((hint && id === hint) || id === key) return entry
    }
    return null
  }

  function iconFor(entry, fallback) {
    if (entry && root.appLibrary) {
      var source = root.appLibrary.iconSource(String(entry.icon || ""))
      if (source) return source
    }
    var themed = Quickshell.iconPath(String(fallback || ""), true)
    if (themed) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  function minimizedCount(key) {
    return Number(root.minimizedCounts[key] || 0)
  }

  function loadMinimizedState(raw) {
    var counts = ({})
    var windows = ({})
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      windows = parsed.windows || ({})
      for (var address in windows) {
        var rawKey = String(windows[address].appKey || "")
        var key = resolvedKeyForAppId(rawKey, windows[address].title || "")
        if (key) counts[key] = Number(counts[key] || 0) + 1
      }
    } catch (e) { }
    root.minimizedCounts = counts
    root.minimizedWindows = windows
    refreshTimer.restart()
  }

  function rawIdForHyprToplevel(top) {
    if (!top) return ""
    try {
      var ipc = top.lastIpcObject || ({})
      var cls = String(ipc["class"] || ipc.initialClass || "")
      if (cls) return cls
    } catch (e) { }
    try { return top.wayland ? String(top.wayland.appId || "") : "" }
    catch (e2) { return "" }
  }

  function titleForHyprToplevel(top) {
    if (!top) return ""
    try { if (top.title) return String(top.title) } catch (e) { }
    try { return top.wayland ? String(top.wayland.title || "") : "" }
    catch (e2) { return "" }
  }

  function waylandForHyprToplevel(top) {
    if (!top) return null
    try { if (top.wayland) return top.wayland } catch (e) { }
    var address = ""
    try { address = String(top.address || "") } catch (e2) { }
    if (!address) return null
    var values = ToplevelManager.toplevels.values || []
    for (var i = 0; i < values.length; i++) {
      var candidate = values[i]
      if (!candidate) continue
      var hypr = hyprToplevelFor(candidate)
      if (!hypr) continue
      try { if (String(hypr.address || "") === address) return candidate } catch (e3) { }
    }
    return null
  }

  function runningGroups() {
    var groups = ({})
    var values = Hyprland.toplevels.values || []
    var active = Hyprland.activeToplevel
    for (var i = 0; i < values.length; i++) {
      var top = values[i]
      if (!top) continue
      var rawId = rawIdForHyprToplevel(top)
      var title = titleForHyprToplevel(top)
      var key = resolvedKeyForAppId(rawId, title)
      if (!key) continue
      if (!groups[key]) groups[key] = { key: key, rawId: rawId, count: 0, active: false }
      groups[key].count++
      if (top === active || top.activated === true) groups[key].active = true
    }
    return groups
  }

  function windowsForKey(key) {
    var wanted = String(key || "")
    var result = []
    if (!wanted) return result
    var values = Hyprland.toplevels.values || []
    for (var i = 0; i < values.length; i++) {
      var top = values[i]
      if (!top) continue
      var rawId = rawIdForHyprToplevel(top)
      var title = titleForHyprToplevel(top)
      if (resolvedKeyForAppId(rawId, title) !== wanted) continue
      var wayland = waylandForHyprToplevel(top)
      if (wayland) result.push(wayland)
    }
    return result
  }

  function hyprToplevelFor(top) {
    if (!top) return null
    try { return top.HyprlandToplevel || null }
    catch (e) { return null }
  }

  function addressForToplevel(top) {
    var hypr = hyprToplevelFor(top)
    if (!hypr) return ""
    try {
      var direct = String(hypr.address || "")
      if (direct) return direct
    } catch (e) { }
    try {
      var ipc = hypr.lastIpcObject || null
      var ipcAddress = ipc ? String(ipc.address || "") : ""
      if (ipcAddress) return ipcAddress
    } catch (e) { }
    try {
      var handle = hypr.handle || null
      return handle ? String(handle.address || "") : ""
    } catch (e) { return "" }
  }

  function savedAddressForToplevel(top) {
    if (!top) return ""
    var wantedKey = canonical(top.appId)
    var wantedTitle = String(top.title || "")
    var exact = []
    var sameApp = []
    for (var address in root.minimizedWindows) {
      var saved = root.minimizedWindows[address] || ({})
      if (String(saved.appKey || "") !== wantedKey) continue
      sameApp.push(address)
      if (String(saved.title || "") === wantedTitle) exact.push(address)
    }
    if (exact.length === 1) return String(exact[0])
    if (sameApp.length === 1) return String(sameApp[0])
    return ""
  }

  function activatePreviewWindow(top) {
    if (!top) return
    var address = addressForToplevel(top)
    var key = canonical(top.appId)
    var title = String(top.title || "")
    if (!address) address = savedAddressForToplevel(top)
    Quickshell.execDetached([
      "bash", root.helperPath("omaux-dock-window"),
      "activate-match", String(address || ""), key, title
    ])
  }

  function appendRow(spec, group, pinned) {
    var key = spec.key
    var entry = findEntry(key, spec.desktop)
    var desktop = spec.desktop || (entry ? String(entry.id || "") : "")
    var name = spec.name || (entry && root.appLibrary ? root.appLibrary.entryName(entry) : (group ? group.rawId : key))
    var iconName = spec.icon || (entry ? String(entry.icon || "") : (group ? group.rawId : key))
    var running = group ? Number(group.count || 0) : 0
    var minimized = minimizedCount(key)
    dockModel.append({
      appKey: key,
      desktopId: desktop,
      label: name,
      iconSource: iconFor(entry, iconName),
      runningCount: running,
      minimizedCount: minimized,
      active: group ? group.active === true : false,
      pinned: pinned === true
    })
  }

  function refreshDock() {
    var groups = runningGroups()
    var pinnedKeys = ({})
    dockModel.clear()

    for (var i = 0; i < pinnedApps.length; i++) {
      var pin = pinnedApps[i]
      pinnedKeys[pin.key] = true
      appendRow(pin, groups[pin.key] || null, true)
    }

    var extras = []
    for (var key in groups) if (!pinnedKeys[key]) extras.push(groups[key])
    extras.sort(function(a, b) { return String(a.rawId).localeCompare(String(b.rawId)) })
    for (var j = 0; j < extras.length; j++) {
      var g = extras[j]
      var entry = findEntry(g.key, "")
      appendRow({
        key: g.key,
        desktop: entry ? String(entry.id || "") : "",
        name: entry && root.appLibrary ? root.appLibrary.entryName(entry) : g.rawId,
        icon: entry ? String(entry.icon || "") : g.rawId
      }, g, false)
    }
  }

  function clickApp(key, desktopId) {
    Quickshell.execDetached(["bash", root.helperPath("omaux-dock-window"), "click", String(key), String(desktopId || "")])
  }

  function open() { root.opened = true }
  function close() { root.opened = false }

  Timer {
    id: refreshTimer
    interval: 80
    repeat: false
    onTriggered: root.refreshDock()
  }

  Timer {
    id: hyprRefreshDelay
    interval: 120
    repeat: false
    onTriggered: refreshTimer.restart()
  }

  function requestHyprlandRefresh() {
    Hyprland.refreshToplevels()
    hyprRefreshDelay.restart()
  }

  Timer {
    // Safety reconciliation is intentionally slow; normal updates are event-driven.
    interval: 15000
    running: true
    repeat: true
    onTriggered: Quickshell.execDetached(["bash", root.helperPath("omaux-dock-window"), "prune"])
  }

  FileView {
    id: pinStateFile
    path: root.pinStatePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadPins(text())
    onFileChanged: reload()
    onLoadFailed: root.loadPins("{}")
  }

  FileView {
    id: minimizedFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadMinimizedState(text())
    onFileChanged: reload()
    onLoadFailed: root.loadMinimizedState("{}")
  }

  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() {
      Quickshell.execDetached(["bash", root.helperPath("omaux-dock-window"), "prune"])
      refreshTimer.restart()
    }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() {
      Quickshell.execDetached(["bash", root.helperPath("omaux-dock-window"), "prune"])
      root.requestHyprlandRefresh()
    }
  }

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { refreshTimer.restart() }
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() { refreshTimer.restart() }
  }

  Component.onCompleted: {
    if (root.appLibrary) root.appLibrary.refreshIcons()
    root.requestHyprlandRefresh()
  }

  component DockButton: Item {
    id: buttonRoot
    property string labelText: ""
    property url imageSource: ""
    property string glyph: ""
    property bool runningApp: false
    property bool activeApp: false
    property bool minimizedApp: false
    property int windowCount: 0
    signal activated()
    signal hoverEntered()
    signal hoverExited()

    width: 36
    height: 43

    Rectangle {
      id: hoverPlate
      width: 34
      height: 34
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      radius: 9
      color: mouse.containsMouse ? Util.alpha(Color.foreground, 0.09)
                                : (buttonRoot.activeApp ? Util.alpha(Color.accent, 0.10) : "transparent")
      scale: mouse.containsMouse ? 1.10 : 1.0
      transformOrigin: Item.Center

      Behavior on scale { NumberAnimation { duration: 135; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 120 } }

      Image {
        visible: buttonRoot.glyph === ""
        anchors.centerIn: parent
        width: 24
        height: 24
        source: buttonRoot.imageSource
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
        smooth: true
        mipmap: true
        opacity: buttonRoot.minimizedApp ? 0.64 : 1.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
      }

      Text {
        visible: buttonRoot.glyph !== ""
        anchors.centerIn: parent
        text: buttonRoot.glyph
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 24
      }

      Rectangle {
        visible: buttonRoot.windowCount > 1
        width: 13
        height: 13
        radius: 7
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -2
        anchors.topMargin: -2
        color: Color.accent
        border.width: 1
        border.color: Color.background

        Text {
          anchors.centerIn: parent
          text: String(buttonRoot.windowCount)
          color: Color.background
          font.family: Style.font.family
          font.bold: true
          font.pixelSize: 8
        }
      }
    }

    Rectangle {
      visible: buttonRoot.runningApp
      width: buttonRoot.activeApp ? 12 : 4
      height: 3
      radius: 1.5
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 2
      color: buttonRoot.activeApp ? Color.accent : Color.foreground
      opacity: buttonRoot.minimizedApp ? 0.42 : 0.92
      Behavior on width { NumberAnimation { duration: 145; easing.type: Easing.OutCubic } }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: buttonRoot.hoverEntered()
      onExited: buttonRoot.hoverExited()
      onClicked: buttonRoot.activated()
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: dockWindow
      required property var modelData
      screen: modelData
      visible: root.opened
      color: "transparent"
      implicitHeight: 58
      exclusionMode: ExclusionMode.Auto
      surfaceFormat.opaque: false
      WlrLayershell.namespace: "omaux-dock"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        bottom: true
        left: true
        right: true
      }

      mask: Region { item: dockCard }

      WindowPreviewPopup {
        id: windowPreview
        dockRoot: root
        hostWindow: dockWindow
        dockCardItem: dockCard
      }

      Rectangle {
        id: dockShadow
        width: dockCard.width + 6
        height: dockCard.height + 6
        radius: dockCard.radius + 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        color: Util.alpha(Color.background, 0.28)
      }

      Rectangle {
        id: dockCard
        width: dockRow.implicitWidth + 17
        height: 46
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        radius: 14
        color: Util.alpha(Color.background, 0.91)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.16)

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
          id: dockRow
          anchors.centerIn: parent
          spacing: 5

          DockButton {
            labelText: "Apps"
            glyph: "󰀻"
            onActivated: {
              windowPreview.dismiss()
              Quickshell.execDetached(["omarchy-menu", "toggle", "apps"])
            }
          }

          Rectangle {
            width: 1
            height: 27
            anchors.verticalCenter: parent.verticalCenter
            color: Util.alpha(Color.foreground, 0.16)
          }

          Repeater {
            model: dockModel

            DockButton {
              id: appButton
              required property string appKey
              required property string desktopId
              required property string label
              required property string iconSource
              required property int runningCount
              required property int minimizedCount
              required property bool active

              labelText: label
              imageSource: iconSource
              runningApp: runningCount > 0
              activeApp: active
              minimizedApp: runningCount > 0 && minimizedCount >= runningCount
              windowCount: runningCount

              onHoverEntered: {
                if (runningCount > 0) windowPreview.enterApp(appButton, appKey, label, iconSource)
              }
              onHoverExited: windowPreview.leaveApp(appKey)
              onActivated: {
                if (runningCount > 0) {
                  // Running apps are window groups. Never choose a window from
                  // the app icon itself; window selection belongs to previews.
                  windowPreview.enterApp(appButton, appKey, label, iconSource)
                  return
                }
                windowPreview.dismiss()
                root.clickApp(appKey, desktopId)
              }
              Component.onDestruction: windowPreview.leaveApp(appKey)
            }
          }
        }
      }
    }
  }
}
