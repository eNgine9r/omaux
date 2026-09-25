#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

MARKER = "OmaUX PET_SURFACE_V2"
PLUGIN_ID = 'moduleName: "raiden-meixelysia.omarchy-pets"'


def candidates() -> list[Path]:
    root = Path.home() / ".config" / "omarchy" / "plugins"
    if not root.is_dir():
        return []
    return [p for p in root.rglob("Panel.qml") if p.is_file()]


def find_panel() -> Path:
    for path in candidates():
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if PLUGIN_ID in text:
            return path
    raise SystemExit("omarchy-pets Panel.qml was not found under ~/.config/omarchy/plugins")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


def patch(text: str) -> str:
    if MARKER in text:
        return text

    text = replace_once(
        text,
        '  readonly property int stageScreenY: Math.round(panel.cardOrigin.y + Border.top(panel.borderSpec) + panel.padding)\n',
        '  readonly property int stageScreenY: Math.round(panel.cardOrigin.y + Border.top(panel.borderSpec) + panel.padding)\n'
        f'  // {MARKER}: clamp against the screen, not a fullscreen layer surface.\n'
        '  readonly property int desktopWidth: panel.screen ? panel.screen.width : stage.width\n'
        '  readonly property int desktopHeight: panel.screen ? panel.screen.height : stage.height\n',
        "screen geometry hook",
    )

    text = replace_once(
        text,
        '  readonly property int petX: Math.max(0, Math.min(restX + dragDx, pinnedWindow.width - stage.width))\n'
        '  readonly property int petY: Math.max(0, Math.min(restY + dragDy, pinnedWindow.height - stage.height))\n',
        '  readonly property int petX: Math.max(0, Math.min(restX + dragDx, desktopWidth - stage.width))\n'
        '  readonly property int petY: Math.max(0, Math.min(restY + dragDy, desktopHeight - stage.height))\n',
        "pet clamping",
    )

    text = replace_once(
        text,
        '    x: root.onDesktop ? root.petX : 0\n'
        '    y: root.onDesktop ? root.petY : 0\n',
        '    // Desktop position is handled by the layer-surface margins.\n'
        '    x: 0\n'
        '    y: 0\n',
        "stage position",
    )

    old_window = '''    anchors {
      left: true
      top: true
      right: true
      bottom: true
    }
    // Whole window while engaged, so a fast drag cannot escape.
    mask: Region {
      x: sprite.engaged ? 0 : stage.x
      y: sprite.engaged ? 0 : stage.y
      width: sprite.engaged ? pinnedWindow.width : stage.width
      height: sprite.engaged ? pinnedWindow.height : stage.height
    }
'''
    new_window = f'''    // {MARKER}: one tiny layer surface instead of a transparent fullscreen surface.
    implicitWidth: stage.width
    implicitHeight: stage.height
    focusable: false
    anchors {{
      left: true
      top: true
    }}
    margins {{
      left: root.petX
      top: root.petY
    }}
    mask: Region {{
      x: 0
      y: 0
      width: pinnedWindow.width
      height: pinnedWindow.height
    }}
'''
    return replace_once(text, old_window, new_window, "pinned layer surface")


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def validate(plugin_dir: Path) -> tuple[bool, str]:
    if shutil.which("omarchy"):
        result = run(["omarchy", "plugin", "validate", str(plugin_dir)])
        if result.returncode != 0:
            return False, result.stdout
    qmllint = Path("/usr/lib/qt6/bin/qmllint")
    shell_dir = Path.home() / ".local" / "share" / "omarchy" / "shell"
    if qmllint.exists() and shell_dir.exists():
        result = run([str(qmllint), "-I", str(shell_dir), "Panel.qml"], cwd=plugin_dir)
        if result.returncode != 0:
            return False, result.stdout
    return True, "validation passed"


def main() -> int:
    parser = argparse.ArgumentParser(description="Fix Omarchy Pets fullscreen layer-surface bug")
    parser.add_argument("--no-restart", action="store_true", help="patch and validate without restarting omarchy-shell")
    parser.add_argument("--check", action="store_true", help="report state without changing files")
    args = parser.parse_args()

    panel = find_panel()
    original = panel.read_text(encoding="utf-8")
    print(f"panel={panel}")
    if MARKER in original:
        print("state=already_patched")
        return 0
    if args.check:
        print("state=needs_patch")
        return 2

    try:
        updated = patch(original)
    except RuntimeError as exc:
        print(f"patch_error={exc}", file=sys.stderr)
        return 3

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = panel.with_name(f"Panel.qml.omaux-backup-{stamp}")
    shutil.copy2(panel, backup)
    panel.write_text(updated, encoding="utf-8")
    print(f"backup={backup}")

    ok, output = validate(panel.parent)
    print(output.strip())
    if not ok:
        shutil.copy2(backup, panel)
        print("validation_failed=restored_backup", file=sys.stderr)
        return 4

    if not args.no_restart:
        if shutil.which("omarchy"):
            result = run(["omarchy", "restart", "shell"])
            print(result.stdout.strip())
            if result.returncode != 0:
                print("warning=shell_restart_failed", file=sys.stderr)
                return 5
    print("state=patched")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
