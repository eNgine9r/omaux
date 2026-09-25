#!/usr/bin/env python3
import importlib.machinery
import importlib.util
from pathlib import Path

path = Path('bin/omaux-window-layout')
loader = importlib.machinery.SourceFileLoader('omaux_window_layout', str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)

assert mod.state_key({'address': '0xabc', 'stableId': 'stable-7'}) == 'stable-7'
assert mod.state_key({'address': '0xabc'}) == '0xabc'

old = {
    '0xabc': {'preMax': {'x': 1}},
    'stable-keep': {'preMax': {'x': 2}},
    'stale-stable': {'preMax': {'x': 3}},
}
clients = [
    {'address': '0xabc', 'stableId': 'stable-new'},
    {'address': '0xdef', 'stableId': 'stable-keep'},
]
reconciled = mod.reconcile_state(old, clients)
assert reconciled == {'stable-keep': {'preMax': {'x': 2}}}

legacy = {'0xbeef': {'original': {'x': 9}}}
assert mod.reconcile_state(legacy, [{'address': '0xbeef'}]) == legacy
print('window layout stable-state tests: PASS')
