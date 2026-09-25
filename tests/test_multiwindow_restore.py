#!/usr/bin/env python3
from pathlib import Path

helper = Path('bin/omaux-dock-window').read_text()
dock = Path('Dock.qml').read_text()

assert 'stableId:(.stableId // "")' in helper
assert '$now.workspace == "special:minimized"' in helper
assert '$saved.stableId == $now.stableId' in helper
assert 'if [[ "$current" != "special:minimized" ]]' in helper
assert 'follow = true' not in helper
assert 'activate_address() {' in helper
assert 'restore_address "$addr"' in helper
assert 'focus_window "$addr"' in helper
assert '"activate", address' in dock
assert 'root.minimizedWindows[address] !== undefined' not in dock
print('multi-window dock restore tests: PASS')
