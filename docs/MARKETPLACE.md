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
`renanmt.switch-magic`. Version: `0.5.3`.

Version 0.5.3 addresses the namespace-spoofing finding in marketplace #15240.
Both Lua runtimes require the hosting Quickshell PID and match it against the
layer PID obtained by Hyprland from Wayland client credentials, as well as the
namespace. The check covers submap entry/exit, startup discovery, focus
cancellation and unmap waiting. Missing or invalid identities are rejected.
The change adds no runtime dependency or configuration migration. Regression
tests cover foreign/missing identities and expired keybind lifecycle paths.

The release retains 0.5.2's settings-save and window-switching fixes, including
Discard/Cancel when unsaved changes prevent closing preferences.
Selected windows are raised after focus; the compositor waits for the picker to
unmap and cancels a pending selection if the picker reopens. Expired shortcut
handles are guarded. Workspace scope now includes the focused scratchpad or
other special workspace; empty special workspaces fall back to the workspace
behind them. Existing shortcut assignments and custom views are preserved.

The release retains 0.5.1's fix for the settings clipboard finding from marketplace #11243.
All settings fields keep their native Qt input read-only and process bounded
keyboard edits separately, preventing automatic clipboard text reads. Paste
and input-method composition are unavailable; typing, selection, copy/cut,
undo/redo, validation and saving remain supported. The offscreen clipboard
probe on Qt 6.12.0 and the full test suite pass. See docs/VALIDATION.md for evidence and limits.

The release also includes the 0.5.0 App scope for windows matching the focused app across
workspaces and monitors, with its own view and shortcut settings. It starts
unassigned; users can choose Alt+backtick or another chord in Views → App.
Existing shortcut assignments and custom views are preserved on upgrade.

No manual setup is needed. Standard plugin enable attaches runtime
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
