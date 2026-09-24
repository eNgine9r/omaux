#!/usr/bin/env python3
import hashlib
import json
import os
import shutil
from pathlib import Path

SOURCE = Path('/usr/share/omarchy/shell/plugins/menu')
TARGET = Path.home() / '.config/omarchy/plugins/io.github.engine9r.omaux-menu'
PATCH_VERSION = 'dock-pin-v3'
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
    text = replace_once(text, 'import "MenuModel.js" as MenuModel\n', 'import "MenuModel.js" as MenuModel\nimport "AppSearch.js" as AppSearch\n', 'AppSearch import')
    props_old = '  property var manifest: null\n'
    props_new = '''  property var manifest: null

  property string dockPinsPath: Quickshell.env("HOME") + "/.config/omaux/pins.json"
  property var dockPinnedKeys: ({})

  function canonicalDockId(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]+/g, "")
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
'''
    text = replace_once(text, props_old, props_new, 'dock pin properties')
    return text


def main():
    if not SOURCE.is_dir():
        raise SystemExit('Omarchy menu source not found')
    key = source_key()
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    stage = TARGET.parent / f'.omaux-menu-stage-{os.getpid()}'
    if stage.exists():
        shutil.rmtree(stage)
    shutil.copytree(SOURCE, stage, symlinks=False)
    shutil.copy2(APP_SEARCH_SOURCE, stage / 'AppSearch.js')

    manifest_path = stage / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['id'] = 'io.github.engine9r.omaux-menu'
    manifest['name'] = 'OmaUX Menu'
    manifest['description'] = 'Omarchy menu clone with OmaUX app pin actions'
    manifest.setdefault('omarchy', {})['clonedFrom'] = 'omarchy.menu'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')

    menu_path = stage / 'Menu.qml'
    menu_path.write_text(patch_menu(menu_path.read_text()))
    (stage / '.dock-pin-source').write_text(key + '\n')

    if TARGET.exists():
        shutil.rmtree(TARGET)
    stage.rename(TARGET)
    print(f'pinned menu clone rebuilt: {key[:12]}')


if __name__ == '__main__':
    main()
