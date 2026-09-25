#!/usr/bin/env python3
from pathlib import Path

s = Path("Dock.qml").read_text()
assert "function rawIdForHyprToplevel(top)" in s
assert 'ipc["class"] || ipc.initialClass' in s
assert "var values = Hyprland.toplevels.values || []" in s
assert "var active = Hyprland.activeToplevel" in s
assert "function waylandForHyprToplevel(top)" in s
assert "resolvedKeyForAppId(rawId, title)" in s
assert "target: Hyprland.toplevels" in s
assert "target: Hyprland" in s
print("Hyprland app identity source tests: PASS")
