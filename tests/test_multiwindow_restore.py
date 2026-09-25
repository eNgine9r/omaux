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

assert 'follow = false, window =' in helper
assert 'address:$addr' in helper
assert 'address = [[$addr]]' not in helper
assert 'window = [[address:$addr]]' not in helper
assert '"activate", address' in dock
assert 'root.minimizedWindows[address] !== undefined' not in dock

click_block = helper.split('click_app() {', 1)[1].split('\n}\n\ncase ', 1)[0]
assert 'minimize_address' not in click_block
assert 'visible=$(find_visible_for_key "$wanted" || true)' in click_block
assert 'focus_window "$visible"' in click_block
assert 'restore_address "$minimized"' in click_block
assert 'focusHistoryID // 999999' in helper
assert '[[ "$key" == "$wanted" && "$ws" == "special:minimized" ]]' in helper

print('multi-window dock restore tests: PASS')
