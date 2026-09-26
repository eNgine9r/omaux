#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_MANAGER="$ROOT/modules/install/manage-binaries.py"
python - "$HOME/.config/hypr/looknfeel.lua" "$HOME/.config/hypr/autostart.lua" <<'PY'
from pathlib import Path
import re,sys
for name,tag in [(sys.argv[1],'hyprbars'),(sys.argv[1],'windowing'),(sys.argv[2],'window-controls')]:
 p=Path(name)
 if not p.exists(): continue
 s=p.read_text()
 s=re.sub(r'\n?-- OmaUX:'+re.escape(tag)+r' begin.*?-- OmaUX:'+re.escape(tag)+r' end\n?', '\n', s, flags=re.S)
 p.write_text(s)
PY
if python "$ROOT/modules/menu/apply-pinned-menu-clone.py" --remove-managed; then
  omarchy-plugin-disable io.github.engine9r.omaux-menu >/dev/null 2>&1 || true
fi
python "$BIN_MANAGER" uninstall \
  --source-root "$ROOT/bin" \
  --target-root "$HOME/.local/bin" \
  omaux-dock-window omaux-dock-pin omaux-window-layout omaux-window-controls
hyprctl reload >/dev/null 2>&1 || true
echo 'OmaUX integrations removed. User state, unknown targets and backups were preserved.'
