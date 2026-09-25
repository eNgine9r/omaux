# Changelog

## 0.1.0-alpha.3
- Add macOS-style live window previews for running Dock applications.
- Show up to four live thumbnails with per-window activate and close actions plus overflow count.
- Restore OmaUX-minimized windows directly from preview cards.
- Use a per-screen layer-shell preview surface with edge clamping and smooth fade/scale transitions.
- Keep screencopy capture inactive while previews are hidden.
- Avoid redundant minimized-state rewrites during reconciliation to eliminate unnecessary FileView churn.
- Complete live Omarchy/Hyprland QA for multi-window hover, pointer transfer, dismiss, and shell-restart behavior.

## 0.1.0-alpha.2
- Harden companion menu replacement: refuse unmanaged/symlink destinations.
- Back up existing OmaUX-managed menu clones before staged replacement and restore on failure.
- Add ownership markers plus backward-compatible recognition of alpha.1-generated clones.
- Pin the hyprbars upstream source build to verified commit `7644cecdb947060682891a0db2a0cdc5c0b9e704`.
- Add a supported root `preview.png` for Marketplace listing.

## 0.1.0-alpha.1
- Initial public packaging of the Omarchy workstation UX enhancements.
- Dock, minimize/restore, pinning, traffic lights, layout helpers, optional localization and power modules.
