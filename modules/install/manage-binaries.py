#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path

SCHEMA_VERSION = 1
STATE_NAME = 'managed-binaries.json'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def state_path():
    root = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'omaux'
    root.mkdir(parents=True, exist_ok=True)
    return root / STATE_NAME


def load_state():
    path = state_path()
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        data = {}
    if not isinstance(data, dict) or data.get('schemaVersion') != SCHEMA_VERSION:
        data = {'schemaVersion': SCHEMA_VERSION, 'files': {}}
    if not isinstance(data.get('files'), dict):
        data['files'] = {}
    return data


def save_state(state):
    path = state_path()
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True) + '\n')
    tmp.replace(path)


def regular_file(path):
    return path.exists() and path.is_file() and not path.is_symlink()


def unique_backup(backup_dir, name):
    candidate = backup_dir / name
    suffix = 1
    while candidate.exists() or candidate.is_symlink():
        candidate = backup_dir / f'{name}.{suffix}'
        suffix += 1
    return candidate


def install_files(source_root, target_root, backup_dir, names):
    state = load_state()
    prior_state = json.loads(json.dumps(state))
    rollback = []
    try:
        backup_dir.mkdir(parents=True, exist_ok=True)
        target_root.mkdir(parents=True, exist_ok=True)
        for name in names:
            src = source_root / name
            dst = target_root / name
            if not src.is_file():
                raise RuntimeError(f'missing OmaUX binary source: {src}')

            old = state['files'].get(name) if isinstance(state['files'].get(name), dict) else {}
            old_hash = old.get('sha256')
            restore = old.get('restore') if isinstance(old.get('restore'), str) else None
            current_owned = regular_file(dst) and isinstance(old_hash, str) and digest(dst) == old_hash
            identical = regular_file(dst) and digest(dst) == digest(src)

            moved = None
            if (dst.exists() or dst.is_symlink()) and not current_owned and not identical:
                moved = unique_backup(backup_dir, name)
                shutil.move(str(dst), str(moved))
                restore = str(moved)
                print(f'backed up pre-existing binary: {dst} -> {moved}')

            rollback.append((dst, moved))
            shutil.copy2(src, dst)
            dst.chmod(0o755)
            entry = {'sha256': digest(dst)}
            if restore:
                entry['restore'] = restore
            state['files'][name] = entry

        save_state(state)
    except Exception:
        for dst, moved in reversed(rollback):
            try:
                if dst.exists() or dst.is_symlink():
                    if dst.is_dir() and not dst.is_symlink():
                        shutil.rmtree(dst)
                    else:
                        dst.unlink()
                if moved and (moved.exists() or moved.is_symlink()):
                    shutil.move(str(moved), str(dst))
            except OSError:
                pass
        save_state(prior_state)
        raise


def uninstall_files(source_root, target_root, names):
    state = load_state()
    for name in names:
        dst = target_root / name
        entry = state['files'].get(name) if isinstance(state['files'].get(name), dict) else {}
        expected = entry.get('sha256')
        restore = entry.get('restore') if isinstance(entry.get('restore'), str) else None
        source = source_root / name

        if not (dst.exists() or dst.is_symlink()):
            state['files'].pop(name, None)
            continue

        owned = regular_file(dst) and isinstance(expected, str) and digest(dst) == expected
        legacy_owned = regular_file(dst) and source.is_file() and digest(dst) == digest(source)
        if not (owned or legacy_owned):
            print(f'preserving unmanaged or modified binary: {dst}')
            state['files'].pop(name, None)
            continue

        dst.unlink()
        print(f'removed OmaUX-managed binary: {dst}')
        if restore:
            backup = Path(restore)
            if backup.exists() or backup.is_symlink():
                shutil.move(str(backup), str(dst))
                print(f'restored pre-existing binary: {dst}')
        state['files'].pop(name, None)

    save_state(state)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('install', 'uninstall'))
    parser.add_argument('--source-root', required=True, type=Path)
    parser.add_argument('--target-root', required=True, type=Path)
    parser.add_argument('--backup-dir', type=Path)
    parser.add_argument('names', nargs='+')
    args = parser.parse_args()

    if args.action == 'install':
        if args.backup_dir is None:
            parser.error('--backup-dir is required for install')
        install_files(args.source_root, args.target_root, args.backup_dir, args.names)
    else:
        uninstall_files(args.source_root, args.target_root, args.names)


if __name__ == '__main__':
    main()
