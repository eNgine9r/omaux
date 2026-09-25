#!/usr/bin/env python3
import importlib.util
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'modules/menu/apply-pinned-menu-clone.py'
spec = importlib.util.spec_from_file_location('menuclone', MODULE)
menuclone = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menuclone)

root = Path(tempfile.mkdtemp(prefix='omaux-menu-safety-'))
try:
    menuclone.BACKUP_ROOT = root / 'backups'
    menuclone.TARGET = root / 'plugins' / menuclone.PLUGIN_ID

    menuclone.TARGET.mkdir(parents=True)
    (menuclone.TARGET / 'sentinel.txt').write_text('KEEP')
    stage = root / 'stage-unmanaged'
    stage.mkdir()
    try:
        menuclone.install_stage(stage)
        raise AssertionError('unmanaged target was replaced')
    except RuntimeError as exc:
        assert 'unmanaged plugin directory' in str(exc)
    assert (menuclone.TARGET / 'sentinel.txt').read_text() == 'KEEP'

    shutil.rmtree(stage)
    shutil.rmtree(menuclone.TARGET)
    menuclone.TARGET.mkdir(parents=True)
    (menuclone.TARGET / menuclone.OWNER_MARKER).write_text(json.dumps({
        'manager': 'OmaUX', 'pluginId': menuclone.PLUGIN_ID
    }))
    (menuclone.TARGET / 'old.txt').write_text('OLD')
    stage = root / 'stage-managed'
    stage.mkdir()
    (stage / 'new.txt').write_text('NEW')
    backup = menuclone.install_stage(stage)
    assert (menuclone.TARGET / 'new.txt').read_text() == 'NEW'
    assert backup and (backup / 'old.txt').read_text() == 'OLD'

    shutil.rmtree(menuclone.TARGET)
    menuclone.TARGET.mkdir(parents=True)
    (menuclone.TARGET / '.dock-pin-source').write_text('legacy')
    (menuclone.TARGET / 'manifest.json').write_text(json.dumps({
        'id': menuclone.PLUGIN_ID,
        'omarchy': {'clonedFrom': 'omarchy.menu'}
    }))
    (menuclone.TARGET / 'legacy.txt').write_text('LEGACY')
    stage = root / 'stage-legacy'
    stage.mkdir()
    backup = menuclone.install_stage(stage)
    assert backup and (backup / 'legacy.txt').read_text() == 'LEGACY'

    shutil.rmtree(menuclone.TARGET)
    real = root / 'real'
    real.mkdir()
    (real / 'sentinel').write_text('SAFE')
    menuclone.TARGET.symlink_to(real, target_is_directory=True)
    stage = root / 'stage-symlink'
    stage.mkdir()
    try:
        menuclone.install_stage(stage)
        raise AssertionError('symlink target was replaced')
    except RuntimeError as exc:
        assert 'symlink target' in str(exc)
    assert (real / 'sentinel').read_text() == 'SAFE'
finally:
    shutil.rmtree(root)

print('menu clone safety tests: PASS')
