#!/usr/bin/env python3
import importlib.util
import os
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'modules/install/manage-binaries.py'
spec = importlib.util.spec_from_file_location('managed_binaries', MODULE)
managed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(managed)

root = Path(tempfile.mkdtemp(prefix='omaux-bin-safety-'))
old_state_home = os.environ.get('XDG_STATE_HOME')
try:
    os.environ['XDG_STATE_HOME'] = str(root / 'state')
    source = root / 'source'
    target = root / 'bin'
    backup = root / 'backup'
    source.mkdir()
    target.mkdir()
    name = 'omaux-dock-window'
    src = source / name
    dst = target / name
    src.write_text('OMAUX-V1\n')
    src.chmod(0o755)

    # Unknown pre-existing file is backed up and restored on uninstall.
    dst.write_text('USER-FILE\n')
    managed.install_files(source, target, backup, [name])
    assert dst.read_text() == 'OMAUX-V1\n'
    assert any(backup.iterdir())
    managed.uninstall_files(source, target, [name])
    assert dst.read_text() == 'USER-FILE\n'

    # A user-modified target after installation is never deleted by uninstall.
    shutil.rmtree(backup)
    backup.mkdir()
    managed.install_files(source, target, backup, [name])
    dst.write_text('USER-MODIFIED-AFTER-INSTALL\n')
    managed.uninstall_files(source, target, [name])
    assert dst.read_text() == 'USER-MODIFIED-AFTER-INSTALL\n'

    # A legacy exact OmaUX payload can be removed even without state metadata.
    dst.write_text(src.read_text())
    state = managed.state_path()
    if state.exists():
        state.unlink()
    managed.uninstall_files(source, target, [name])
    assert not dst.exists()

    # Symlink conflicts are backed up as links and restored, never followed.
    external = root / 'external'
    external.write_text('EXTERNAL\n')
    dst.symlink_to(external)
    backup2 = root / 'backup2'
    managed.install_files(source, target, backup2, [name])
    assert dst.is_file() and not dst.is_symlink()
    managed.uninstall_files(source, target, [name])
    assert dst.is_symlink()
    assert dst.resolve() == external.resolve()
    assert external.read_text() == 'EXTERNAL\n'
finally:
    if old_state_home is None:
        os.environ.pop('XDG_STATE_HOME', None)
    else:
        os.environ['XDG_STATE_HOME'] = old_state_home
    shutil.rmtree(root)

print('binary install safety tests: PASS')
