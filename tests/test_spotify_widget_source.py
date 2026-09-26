#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
widget = (root / "SpotifyMiniWidget.qml").read_text()
entry = (root / "Root.qml").read_text()
manifest = (root / "manifest.json").read_text()

# Native MPRIS integration: no polling helper or optional playerctl dependency.
assert "Quickshell.Services.Mpris" in widget
assert "Mpris.players.values" in widget
assert "playerctl" not in widget.lower()
assert 'signature.indexOf("spotify")' in widget

# The overlay must not steal clicks or reserve another strip of desktop space.
assert "exclusionMode: ExclusionMode.Ignore" in widget
assert "mask: Region { item: card }" in widget
assert 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' in widget

# Every transport action is capability-gated and the widget is hidden without Spotify.
assert "root.available && focusedScreen" in widget
assert "panel.player.canGoPrevious" in widget
assert "panel.player.canTogglePlaying" in widget
assert "panel.player.canGoNext" in widget

# Position survives reload/reboot and drag stays horizontally bounded.
assert 'Quickshell.statePath("omaux-spotify-widget.json")' in widget
assert "JsonAdapter" in widget and "xRatio" in widget
assert "xAxis.minimum: 8" in widget and "xAxis.maximum:" in widget
assert "root.savePosition(panel, card)" in widget

# Dynamic transport glyphs must repaint when play/pause state changes.
assert "property string iconKind: button.kind" in widget
assert "onIconKindChanged: requestPaint()" in widget

# Composition is isolated from Dock.qml for easy rollback. Only the panel entrypoint
# owns the Spotify overlay so opening the menu cannot create a duplicate layer.
assert "Dock {" in entry
assert "SpotifyMiniWidget {" in entry
assert '"panel":"Root.qml"' in manifest
assert '"menu":"Dock.qml"' in manifest
print("spotify widget source tests: PASS")
