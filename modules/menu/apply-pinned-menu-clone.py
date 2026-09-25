#!/usr/bin/env python3
import hashlib
import json
import os
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SOURCE = Path('/usr/share/omarchy/shell/plugins/menu')
PLUGIN_ID = 'io.github.engine9r.omaux-menu'
TARGET = Path.home() / f'.config/omarchy/plugins/{PLUGIN_ID}'
PATCH_VERSION = 'dock-pin-v4'
OWNER_MARKER = '.omaux-managed.json'
BACKUP_ROOT = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'omaux/backups/menu'
APP_SEARCH_SOURCE = Path('/usr/share/omarchy/shell/services/AppSearch.js')
FILES = ('manifest.json', 'Menu.qml', 'MenuModel.js', 'BarWidget.qml')


def source_key():
    h = hashlib.sha256(PATCH_VERSION.encode())
    for name in FILES:
        h.update(name.encode())
        h.update((SOURCE / name).read_bytes())
    h.update(APP_SEARCH_SOURCE.read_bytes())
    return h.hexdigest()


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)


def patch_menu(text):
    text = replace_once(text, 'import \"MenuModel.js\" as MenuModel\n', 'import \"MenuModel.js\" as MenuModel\nimport \"AppSearch.js\" as AppSearch\n', 'AppSearch import')
    props_old = '  property var manifest: null\n'
    props_new = '''  property var manifest: null

  // User dock pins. Kept outside shell.json so pin/unpin is instant and persistent.
  property string dockPinsPath: Quickshell.env("HOME") + "/.config/omaux/pins.json"
  property var dockPinnedKeys: ({})

  function canonicalDockId(value) {
    return String(value || "").toLowerCase().replace(/\\.desktop$/, "").replace(/[^a-z0-9]+/g, "")
  }

  function loadDockPins(raw) {
    var next = ({})
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      var pins = Array.isArray(parsed.pins) ? parsed.pins : []
      for (var i = 0; i < pins.length; i++) {
        var key = String(pins[i].key || root.canonicalDockId(pins[i].desktop || ""))
        if (key) next[key] = true
      }
    } catch (e) { }
    root.dockPinnedKeys = next
  }

  function isDockPinned(desktopId) {
    return root.dockPinnedKeys[root.canonicalDockId(desktopId)] === true
  }

  function toggleDockPin(desktopId, label, icon) {
    if (!desktopId) return
    Quickshell.execDetached(["omaux-dock-pin", "toggle", String(desktopId), String(label || desktopId), String(icon || "")])
  }

  function debugApps(arg) {
    var count = -1
    var error = ""
    try { count = root.appLibrary ? root.appLibrary.sortedEntries("").length : -1 }
    catch (e) { error = String(e) }
    return JSON.stringify({
      appLibrary: root.appLibrary !== null,
      sortedEntries: count,
      displayModel: displayModel.count,
      activeMenu: root.activeMenu,
      appsProviderLoaded: root.providersLoaded["apps"] === true,
      error: error
    })
  }
'''
    text = replace_once(text, props_old, props_new, 'dock pin properties')

    app_lib_old = '''  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
'''
    app_lib_new = '''  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null

  function sortedAppEntries(query) {
    if (root.appLibrary) return root.appLibrary.sortedEntries(query)
    return AppSearch.sortedEntries(DesktopEntries.applications.values || [], query, null)
  }

  function appEntryName(entry) {
    return root.appLibrary ? root.appLibrary.entryName(entry) : AppSearch.entryName(entry)
  }

  function appEntrySubtext(entry) {
    return root.appLibrary ? root.appLibrary.entrySubtext(entry) : AppSearch.entrySubtext(entry)
  }

  function appIconSource(icon) {
    if (root.appLibrary) return root.appLibrary.iconSource(icon)
    var value = String(icon || "")
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    var themed = Quickshell.iconPath(value || "application-x-executable", true)
    return themed && themed.length > 0 ? themed : Quickshell.iconPath("application-x-executable", true)
  }

  function launchDesktopApp(desktopId, label) {
    var id = String(desktopId || "")
    if (!id) return
    if (root.appLibrary) { root.appLibrary.launch(id, label); return }
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", id + ".desktop"])
  }
'''
    text = replace_once(text, app_lib_old, app_lib_new, 'direct DesktopEntries fallback')

    merge_old = '''  function mergeAppRows() {
    if (!root.appLibrary) return

    var rows = root.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appLibrary.entrySubtext(entry)
'''
    merge_new = '''  function mergeAppRows() {
    var rows = root.sortedAppEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appEntrySubtext(entry)
'''
    text = replace_once(text, merge_old, merge_new, 'apps direct merge')
    text = replace_once(text, '        label: root.appLibrary.entryName(entry),\n', '        label: root.appEntryName(entry),\n', 'apps direct name')
    text = replace_once(text, '      if (root.appLibrary) root.appLibrary.launch(appId, label)\n', '      root.launchDesktopApp(appId, label)\n', 'apps direct launch')
    text = replace_once(text, '                source: row.isApp && root.appLibrary ? root.appLibrary.iconSource(row.appIcon) : ""\n', '                source: row.isApp ? root.appIconSource(row.appIcon) : ""\n', 'apps direct icon')

    desktop_conn_old = '''  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }
'''
    desktop_conn_new = '''  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }
'''
    text = replace_once(text, desktop_conn_old, desktop_conn_new, 'DesktopEntries watcher')

    watchers_old = '''  // The JSONC sources are watched so live edits to the default file (or the
  // user extension at ~/.config/omarchy/extensions/omarchy-menu.jsonc) take
  // effect without restarting the shell.
  FileView {
    id: defaultMenuFile
'''
    watchers_new = '''  FileView {
    id: dockPinsFile
    path: root.dockPinsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadDockPins(text())
    onFileChanged: reload()
    onLoadFailed: root.loadDockPins("{}")
  }

  // The JSONC sources are watched so live edits to the default file (or the
  // user extension at ~/.config/omarchy/extensions/omarchy-menu.jsonc) take
  // effect without restarting the shell.
  FileView {
    id: defaultMenuFile
'''
    text = replace_once(text, watchers_old, watchers_new, 'dock pins watcher')

    trail_old = '''              Row {
                id: trail
                width: Style.space(14)
                anchors.right: parent.right
'''
    trail_new = '''              Row {
                id: trail
                width: row.isApp ? Style.space(34) : Style.space(14)
                z: 4
                anchors.right: parent.right
'''
    text = replace_once(text, trail_old, trail_new, 'app row trail width')

    arrow_old = '''                Text {
                  textFormat: Text.PlainText
                  text: row.kind === "menu" || row.kind === "link" ? "›" : ""
'''
    pin_block = '''                Item {
                  visible: row.isApp
                  width: visible ? Style.space(30) : 0
                  height: Style.space(30)

                  Rectangle {
                    anchors.fill: parent
                    radius: Math.min(root.cornerRadius, width / 2)
                    color: pinMouse.containsMouse ? Util.alpha(root.foreground, 0.10) : "transparent"

                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: ""
                      color: root.isDockPinned(row.appId) ? Color.accent : (row.hasCursor ? root.selectedText : root.foreground)
                      opacity: root.isDockPinned(row.appId) ? 1.0 : 0.48
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }

                    MouseArea {
                      id: pinMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: function(mouse) {
                        root.toggleDockPin(row.appId, row.label, row.appIcon)
                        mouse.accepted = true
                      }
                    }
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  text: row.kind === "menu" || row.kind === "link" ? "›" : ""
'''
    text = replace_once(text, arrow_old, pin_block, 'app pin button')
    return text


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return None


def managed_target_kind(target):
    if target.is_symlink() or not target.is_dir():
        return None

    marker = read_json(target / OWNER_MARKER)
    if (
        isinstance(marker, dict)
        and marker.get('manager') == 'OmaUX'
        and marker.get('pluginId') == PLUGIN_ID
    ):
        return 'managed'

    # Backward-compatible ownership proof for alpha.1 clones created by OmaUX.
    manifest = read_json(target / 'manifest.json')
    if (
        (target / '.dock-pin-source').is_file()
        and isinstance(manifest, dict)
        and manifest.get('id') == PLUGIN_ID
        and isinstance(manifest.get('omarchy'), dict)
        and manifest['omarchy'].get('clonedFrom') == 'omarchy.menu'
    ):
        return 'legacy-managed'
    return None


def write_owner_marker(stage, key):
    marker = {
        'schemaVersion': 1,
        'manager': 'OmaUX',
        'pluginId': PLUGIN_ID,
        'sourceKey': key,
    }
    (stage / OWNER_MARKER).write_text(json.dumps(marker, indent=2) + '\n')


def install_stage(stage):
    if TARGET.is_symlink():
        raise RuntimeError(f'refusing to replace symlink target: {TARGET}')
    if TARGET.exists() and not TARGET.is_dir():
        raise RuntimeError(f'refusing to replace non-directory target: {TARGET}')

    backup = None
    if TARGET.exists():
        ownership = managed_target_kind(TARGET)
        if ownership is None:
            raise RuntimeError(
                f'refusing to replace unmanaged plugin directory: {TARGET}; '
                'move it aside manually if you want OmaUX to manage this plugin ID'
            )
        BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        backup = BACKUP_ROOT / f'{PLUGIN_ID}-{stamp}'
        shutil.move(str(TARGET), str(backup))

    try:
        stage.rename(TARGET)
    except Exception:
        if backup and backup.exists() and not TARGET.exists():
            shutil.move(str(backup), str(TARGET))
        raise
    return backup


def main():
    if not SOURCE.is_dir():
        raise SystemExit('Omarchy menu source not found')
    key = source_key()
    stamp = TARGET / '.dock-pin-source'
    if stamp.exists() and stamp.read_text().strip() == key:
        print(f'pinned menu clone current: {key[:12]}')
        return

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.omaux-menu-stage-', dir=TARGET.parent))
    shutil.copytree(SOURCE, stage, dirs_exist_ok=True, symlinks=False)
    shutil.copy2(APP_SEARCH_SOURCE, stage / 'AppSearch.js')

    manifest_path = stage / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['id'] = PLUGIN_ID
    manifest['name'] = 'OmaUX Menu'
    manifest['description'] = 'Omarchy menu clone with OmaUX app pin actions'
    manifest.setdefault('omarchy', {})['clonedFrom'] = 'omarchy.menu'
    if isinstance(manifest.get('barWidget'), dict):
        manifest['barWidget']['displayName'] = 'OmaUX Menu'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')

    menu_path = stage / 'Menu.qml'
    menu_path.write_text(patch_menu(menu_path.read_text()))
    (stage / '.dock-pin-source').write_text(key + '\n')
    write_owner_marker(stage, key)

    try:
        backup = install_stage(stage)
    except Exception:
        if stage.exists():
            shutil.rmtree(stage)
        raise
    if backup:
        print(f'previous managed menu backed up: {backup}')
    print(f'pinned menu clone rebuilt: {key[:12]}')


if __name__ == '__main__':
    main()
