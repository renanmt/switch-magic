# Switch Magic 0.5.0 — Switch within an app

Browse only the focused app's windows across workspaces and monitors with the new
**App** scope. Its shortcut starts **Unassigned** so it does not take over an
existing desktop binding. Choose a chord under **Views → App** to enable it.

- New **App** scope alongside Workspace, Monitor, Everywhere and Spaces.
- Independent layout, preview mode and shortcut under **Views → App**, defaulting
  to Carousel with live previews.
- The originating app stays fixed while the picker is open. Windows match its
  app ID/window class and use the existing recent-window ordering and visibility filters.
- Custom shortcuts accept a literal backtick as well as the `GRAVE` key name.
- Alt+backtick is an opt-in preset: hold Alt and press backtick to cycle, then
  release Alt to switch.
- New installations, upgrades and reset leave App unassigned. Existing settings
  gain the new profile automatically, and user-saved App shortcuts are preserved.

Install:

```sh
omarchy plugin add https://github.com/renanmt/switch-magic --enable
```

Update:

```sh
omarchy plugin update renanmt.switch-magic
```

Open preferences with **F2** in the picker or `omarchy-shell switch-magic settings`.
Saved preferences and custom views are retained. No manual setup is required.
Disable or uninstall restores saved desktop shortcuts.

Validation: 21 model tests, Lua shortcut lifecycle tests, offscreen settings and
workspace-card tests, 6 installer tests, 6 migration tests, manifest validation,
JSON checks and QML parsing. Live activation confirmed the new profile and
Alt+grave bindings with no plugin or Hyprland configuration errors. Physical
input and end-to-end focus switching remain a manual check.

Marketplace verification is requested separately for the exact release commit.
