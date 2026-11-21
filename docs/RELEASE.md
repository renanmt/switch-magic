# Switch Magic 0.5.2 — Settings and window switching fixes

This patch release fixes settings saves and improves window switching, including
scratchpads and other special workspaces.

- **Settings save correctly:** valid edits no longer fail with “Invalid settings
  structure” when QML converts nested arrays. If changes cannot be saved, closing
  preferences offers Discard or Cancel.
- **Selected windows come forward:** switching focuses and raises the selected
  window, including when floating windows overlap it.
- **Focus waits for the picker:** the compositor waits for the picker to unmap,
  skips closed windows and replaces pending selections. Reopening the picker
  invalidates the old pending selection, including when the new session ends
  with Escape or a workspace selection.
- **Scratchpad switching works:** current-workspace scope uses the focused
  special workspace on the focused monitor, including scratchpad and Quake-console
  windows. An empty special workspace falls back to the underlying workspace.
- **Shortcut recovery is safer:** expired Hyprland keybind handles are checked
  before renewal or cleanup calls.

Existing preferences, custom views and shortcuts are preserved. The App shortcut
remains opt-in. Settings retain 0.5.1's clipboard protection: keyboard editing is
supported, while paste and input-method composition remain unavailable.

Install:

```sh
omarchy plugin add https://github.com/renanmt/switch-magic --enable
```

Update:

```sh
omarchy plugin update renanmt.switch-magic
```

Open preferences with **F2** in the picker or `omarchy-shell switch-magic settings`.
No manual configuration migration is needed.

The full `python scripts/check.py` suite passes: 22 model tests, Lua shortcut and
focus tests, offscreen settings and workspace-card tests, the Qt 6.12.0 clipboard
probe, six installer tests, six migration tests, manifest validation, JSON checks
and QML parsing. Focus invalidation is covered by deterministic compositor mocks;
live desktop checks were reported by the PR authors and were not independently
repeated for this release candidate. See the
[validation notes](https://github.com/renanmt/switch-magic/blob/v0.5.2/docs/VALIDATION.md)
for details.

Thanks to [@devmil](https://github.com/devmil) for
[PR #2](https://github.com/renanmt/switch-magic/pull/2) and
[@arthurpolice](https://github.com/arthurpolice) for
[PR #3](https://github.com/renanmt/switch-magic/pull/3).

[Full changelog](https://github.com/renanmt/switch-magic/compare/v0.5.1...v0.5.2)
