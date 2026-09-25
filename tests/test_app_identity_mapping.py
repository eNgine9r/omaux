#!/usr/bin/env python3
from pathlib import Path

dock = Path("Dock.qml").read_text()

assert "function webAppHostSignature(execString)" in dock
assert "entry.startupClass" in dock
assert "entry.execString" in dock
assert "function commandAppIdSignature(execString)" in dock
assert "commandAppId === rawKey" in dock
assert "rawKey.indexOf(host) !== -1" in dock
assert "function entryAliasSignatures(entry)" in dock
assert "function hasStrongAlias(rawKey, aliases)" in dock
assert "alias.length >= 4 && rawKey.indexOf(alias) !== -1" in dock
assert "aliasMatches.length === 1 ? aliasMatches[0] : null" in dock
assert "if (webMatches.length === 1) return webMatches[0]" in dock
assert "function resolvedKeyForAppId(rawId)" in dock
assert "var key = resolvedKeyForAppId(rawId)" in dock
assert "resolvedKeyForAppId(top.appId) === wanted" in dock
assert "var key = resolvedKeyForAppId(rawKey)" in dock

activate = dock.split("function activatePreviewWindow(top)", 1)[1].split("function appendRow", 1)[0]
assert "var key = canonical(top.appId)" in activate

print("app identity mapping tests: PASS")
