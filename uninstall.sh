#!/usr/bin/env bash
set -euo pipefail
python - "$HOME/.config/hypr/looknfeel.lua" "$HOME/.config/hypr/autostart.lua" <<'PY'
from pathlib import Path
import re,sys
for name,tag in [(sys.argv[1],'hyprbars'),(sys.argv[2],'window-controls')]:
 p=Path(name)
 if not p.exists(): continue
 s=p.read_text()
 s=re.sub(r'\n?-- OmaUX:'+re.escape(tag)+r' begin.*?-- OmaUX:'+re.escape(tag)+r' end\n?', '\n', s, flags=re.S)
 p.write_text(s)
PY
omarchy-plugin-disable io.github.engine9r.omaux-menu >/dev/null 2>&1 || true
rm -rf "$HOME/.config/omarchy/plugins/io.github.engine9r.omaux-menu"
rm -f "$HOME/.local/bin/omaux-dock-window" "$HOME/.local/bin/omaux-dock-pin" "$HOME/.local/bin/omaux-window-layout" "$HOME/.local/bin/omaux-window-controls"
hyprctl reload >/dev/null 2>&1 || true
echo 'OmaUX integrations removed. User state and backups were preserved.'
