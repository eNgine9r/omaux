from pathlib import Path

root = Path(__file__).resolve().parents[1]
bridge = (root / "modules/media/omaux-spotify-mpris").read_text()
qml = (root / "modules/media/SpotifyMiniPlayer.qml").read_text()
install = (root / "install.sh").read_text()

assert "playerctl -l" in bridge
assert "spotify_inactive" in bridge
assert '[[ "$ARG" =~' in bridge, "seek/volume inputs must be validated"
assert "--follow" in bridge, "metadata should be event-driven"
assert "visible: available" in qml, "widget must disappear without Spotify"
assert "asynchronous: true" in qml, "artwork must not block the UI"
assert "restartTimer" in qml, "Spotify restarts must recover"
assert "durationSeconds > 0" in qml, "seek must guard unknown-duration media"
assert "/usr/share/omarchy" not in install, "core install must not overwrite packaged Omarchy files"
print("spotify media safety: ok")
