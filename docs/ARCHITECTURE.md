# Architecture

OmaUX has two layers:

1. **Marketplace core** — QML plus user-space helpers. No sudo and no silent system mutation.
2. **Opt-in integrations** — explicit user-owned Hyprland/Chrome/localization/power changes with backups and rollback.

Modules should remain independently enableable. New features must never require editing packaged Omarchy files under `/usr/share/omarchy`.
