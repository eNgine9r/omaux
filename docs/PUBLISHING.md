# Publishing OmaUX

## GitHub

Repository: `eNgine9r/omaux`
Visibility: public
Description: `A modular desktop UX suite for Omarchy — Dock, minimize/restore, app pinning, macOS-style traffic lights and optional desktop integrations.`

## Omarchy Plugins Marketplace

- Category: **Desktop**
- Tags: **appearance**, **productivity**, **hyprland**
- Version: `0.1.0-alpha.1`
- Preview: `assets/hero.svg`
- Install: `omarchy plugin add https://github.com/eNgine9r/omaux.git --enable`

Before submission:

```bash
omarchy plugin validate .
bash -n install.sh uninstall.sh bin/omaux-dock-window bin/omaux-dock-pin bin/omaux-window-controls
python -m py_compile bin/omaux-window-layout modules/menu/apply-pinned-menu-clone.py modules/localization/generate-ukrainian-menu.py
```

Submit the public repository through the official plugin submission form after the alpha is tagged.
