import QtQuick

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: true

  function open() { root.opened = true }
  function close() { root.opened = false }

  Dock {
    shell: root.shell
    manifest: root.manifest
    opened: root.opened
  }

  SpotifyMiniWidget {
    enabled: root.opened
  }
}
