# Switch Magic 0.4.0 — Spaces and shortcuts

Browse workspaces on your current monitor with **Alt+Super+Tab**, alongside the familiar **Alt+Tab** window picker. Spaces show each workspace’s windows, support all four layouts, and open on the focused display.

- Choose preset or custom shortcuts beside each scope in Views. Conflicts ask before moving a shortcut; unassigned scopes leave their previous desktop bindings available.
- Navigate with arrows or **WASD**, even while holding shortcut modifiers. Desktop bindings no longer intercept picker navigation.
- Adjust background blur from 0–100%, with **20%** as the default, and use a single **Display logo** toggle.
- Reset shipped settings while keeping custom views and their styling.
- Use the reorganized View studio: fixed library and duplication controls on the left, independently scrolling controls and preview, and clipped content above the footer.
- Updated instructions and seven screenshots rendered with fictional data.

Install:

```sh
omarchy plugin add https://github.com/renanmt/switch-magic --enable
```

Update:

```sh
omarchy plugin update renanmt.switch-magic
```

Open preferences with **F2** in the picker or `omarchy-shell switch-magic settings`.
Existing saved preferences and custom views are retained. Reset to defaults to adopt the shipped settings. Disable or uninstall restores saved desktop shortcuts.

Validation includes model, Lua lifecycle, offscreen settings and workspace rendering tests, installer and migration tests, manifest validation, QML parsing, and live keyboard checks. Marketplace verification is requested separately for the exact release commit.

Thanks to @mrvigneshvt for the workspace overview contribution in #1.
