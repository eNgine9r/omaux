#!/usr/bin/env python3
from pathlib import Path

dock = Path("Dock.qml").read_text()

assert "function webAppHostSignature(execString)" in dock
assert "function commandAppIdSignature(execString)" in dock
assert "function entryAliasSignatures(entry)" in dock
assert "function hasStrongAlias(rawKey, aliases)" in dock
assert "function browserWebAppIdentity(rawId)" in dock
assert "function pinnedKeyForRawApp(rawId, title)" in dock
assert "var target = web.web ? web.key : rawKey" in dock
assert "web.hostLabel && alias === web.hostLabel" in dock
assert "titleKey.indexOf(pinName) !== -1" in dock
assert "function resolvedKeyForAppId(rawId, title)" in dock
assert "var pinned = pinnedKeyForRawApp(rawId, title)" in dock
assert "var key = resolvedKeyForAppId(rawId, top.title)" in dock
assert "resolvedKeyForAppId(top.appId, top.title) === wanted" in dock
assert "resolvedKeyForAppId(rawKey, windows[address].title || \"\")" in dock

activate = dock.split("function activatePreviewWindow(top)", 1)[1].split("function appendRow", 1)[0]
assert "var key = canonical(top.appId)" in activate

print("app identity mapping tests: PASS")
