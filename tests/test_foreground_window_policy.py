#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
helper = (root / "bin/omaux-dock-window").read_text()
windowing = (root / "integrations/windowing.lua").read_text()
install = (root / "install.sh").read_text()
uninstall = (root / "uninstall.sh").read_text()

focus = helper.split("focus_window() {", 1)[1].split("\n}", 1)[0]
assert "floating" in focus and "fullscreen" in focus
assert "hl.dsp.window.float" in focus
assert focus.index("hl.dsp.window.float") < focus.index("hl.dsp.focus")
assert 'o.window(".*", { float = true })' in windowing
assert "OmaUX:windowing" in install
assert "integrations/windowing.lua" in install
assert "'windowing'" in uninstall
print("foreground window policy tests: PASS")
