#!/usr/bin/env python3
from pathlib import Path

qml = Path("WindowPreviewPopup.qml").read_text()

assert "function activateSelectedWindow(top)" in qml
assert "id: headerActivateMouse" in qml
assert "id: previewActivateMouse" in qml
assert "preventStealing: true" in qml
assert qml.count("root.activateSelectedWindow(previewCard.modelData)") >= 3
assert qml.index("id: screencopy") < qml.index("id: previewActivateMouse")
assert qml.index("id: closeButton") < qml.index("id: headerActivateMouse")
print("preview click hit-target tests: PASS")
