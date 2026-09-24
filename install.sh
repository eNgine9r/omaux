#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:---core}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omaux"
BACKUP="$STATE/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$STATE" "$BACKUP" "${XDG_CONFIG_HOME:-$HOME/.config}/omaux" "$HOME/.local/bin"
for n in omaux-dock-window omaux-dock-pin omaux-window-layout; do install -Dm755 "$ROOT/bin/$n" "$HOME/.local/bin/$n"; done
[[ -s "$HOME/.config/omaux/pins.json" ]] || printf '%s\n' '{"version":1,"pins":[]}' > "$HOME/.config/omaux/pins.json"
if [[ "$MODE" == "--full" ]]; then
  install -Dm755 "$ROOT/bin/omaux-window-controls" "$HOME/.local/bin/omaux-window-controls"
  for f in "$HOME/.config/hypr/looknfeel.lua" "$HOME/.config/hypr/autostart.lua"; do [[ -f "$f" ]] && cp -a "$f" "$BACKUP/$(basename "$f")"; done
  grep -q 'OmaUX:hyprbars' "$HOME/.config/hypr/looknfeel.lua" || cat >> "$HOME/.config/hypr/looknfeel.lua" <<EOT

-- OmaUX:hyprbars begin
dofile("$ROOT/integrations/hyprbars.lua")
-- OmaUX:hyprbars end
EOT
  grep -q 'OmaUX:window-controls' "$HOME/.config/hypr/autostart.lua" || cat >> "$HOME/.config/hypr/autostart.lua" <<'EOT'

-- OmaUX:window-controls begin
o.launch_on_start("omaux-window-controls")
-- OmaUX:window-controls end
EOT
  omaux-window-controls || true
  python "$ROOT/modules/menu/apply-pinned-menu-clone.py"
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy-plugin-enable io.github.engine9r.omaux-menu >/dev/null 2>&1 || true
  hyprctl reload >/dev/null 2>&1 || true
fi
printf 'OmaUX installed (%s). Backup: %s\n' "$MODE" "$BACKUP"
