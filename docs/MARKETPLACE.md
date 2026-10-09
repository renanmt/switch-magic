### Repository URL

https://github.com/renanmt/switch-magic

### Category

Productivity

### Tags

hyprland, quickshell, workspaces

### Suggest a missing tag

_No response_

### Maintainer notes

Switch Magic is a visual workspace and window switcher with four built-in layouts,
live or snapshot previews, configurable shortcuts, and a custom view editor. Permanent plugin ID:
`renanmt.switch-magic`. Version: `0.4.0`.

No manual setup is needed in 0.4.0. Standard plugin enable attaches runtime
shortcuts; disable/removal restores saved bindings by reloading Hyprland's
configuration. A heartbeat lease restores bindings after an unexpected shell exit.
The migration helper removes only the exact legacy marked include with a backup.
See `runtime/bindings.lua` and `components/AutomaticBindings.qml` for the lifecycle.

Requires Omarchy 4 with Quickshell and Hyprland 0.56+ Lua configuration, plus
Python 3 for legacy configuration migration. The plugin captures Wayland toplevels and an in-memory desktop snapshot for background blur,
activates selected windows/workspaces through Hyprland, and saves only its inline shell settings.
It does not write window captures to disk or request elevated privileges.

The root preview and README screenshots use fictional content rendered by the
actual UI in an isolated session. Fresh installations include only four default
views. License: MIT.

### Submission checklist

- [ ] The repository is public and contains installation and removal instructions.
- [ ] I have documented the plugin license and any external dependencies.
- [ ] I confirm that I own or have permission to submit this plugin and its preview assets.
- [ ] The plugin does not overwrite user configuration without explicit consent.
- [ ] I understand that approval is for listing and is not a security review.
