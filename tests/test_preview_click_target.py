#!/usr/bin/env python3
from pathlib import Path

qml = Path("WindowPreviewPopup.qml").read_text()
dock = Path("Dock.qml").read_text()

assert "function activateSelectedWindow(top)" in qml
assert "id: headerActivateMouse" in qml
assert "id: previewActivateMouse" in qml
assert "preventStealing: true" in qml
assert qml.count("root.activateSelectedWindow(previewCard.modelData)") >= 3
assert qml.index("id: screencopy") < qml.index("id: previewActivateMouse")
assert qml.index("id: closeButton") < qml.index("id: headerActivateMouse")

# Running-app icons are group affordances only: they expose previews and never
# directly focus/minimize an arbitrary member of the group.
activated = dock.split("onActivated: {", 2)[2].split("Component.onDestruction", 1)[0]
assert "if (runningCount > 0)" in activated
assert "windowPreview.enterApp(appButton, appKey, label, iconSource)" in activated
assert activated.index("if (runningCount > 0)") < activated.index("root.clickApp(appKey, desktopId)")
assert "root.clickApp(appKey, desktopId)" in activated

# Preview text intentionally uses a proportional UI font rather than the shell's
# monospace-oriented default.
assert 'readonly property string uiFontFamily: "Noto Sans"' in qml
assert qml.count("font.family: root.uiFontFamily") >= 5
assert "font.family: Style.font.family" not in qml

print("preview click hit-target tests: PASS")

# Dock and pin helper must share the same persistent pin state path.
dock = Path("Dock.qml").read_text()
pin_helper = Path("bin/omaux-dock-pin").read_text()
assert ".config/omarchy/dock-pins.json" in dock
assert "/omarchy/dock-pins.json" in pin_helper

# Runtime helpers are installed in the user-local bin directory.
assert "/.local/bin/" in dock
assert "Qt.resolvedUrl(\"bin/\" + name)" not in dock
