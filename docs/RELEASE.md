# Switch Magic 0.5.1 — Settings clipboard hardening

Addresses the settings clipboard finding in marketplace
[issue #11243](https://github.com/omacom/omarchy-plugin-marketplace/issues/11243).
Qt can automatically read foreign clipboard text when an editable field exists,
even without pasting or focusing that field. A streaming offer can block the
shared shell or exhaust its memory.

All settings fields now keep the native Qt input read-only and process bounded
keyboard edits separately. This covers custom shortcuts, view names, numbers,
fonts and colors, including hidden controls.

- Typing, selection, copy/cut, undo/redo, validation and saving remain supported.
- **Paste and input-method composition are unavailable** in settings fields.
- No new runtime dependencies, subprocesses or clipboard tools are introduced.
- Existing shortcuts, preferences and custom views are retained.

Also includes 0.5.0's App scope for switching among the focused app's windows
across workspaces and monitors. Its shortcut starts **Unassigned**; choose
Alt+backtick or another chord under **Views → App** to enable it.

Install:

```sh
omarchy plugin add https://github.com/renanmt/switch-magic --enable
```

Update:

```sh
omarchy plugin update renanmt.switch-magic
```

Open preferences with **F2** in the picker or `omarchy-shell switch-magic settings`.
No manual setup is required. Disable or uninstall restores saved desktop shortcuts.

Validation: the full `python scripts/check.py` suite passes, including 21 model
tests, Lua lifecycle tests, offscreen settings and workspace-card tests, a new
clipboard retrieval probe, six installer tests, six migration tests, manifest
validation, JSON checks and QML parsing. The clipboard probe on installed Qt
6.11.2 observes reads from an editable native positive control and zero reads
from the replacement during creation, clipboard changes and paste attempts.
Qt 6.12.0 was inspected at source level, not executed locally. No live streaming
clipboard denial-of-service test was performed. See
[validation notes](https://github.com/renanmt/switch-magic/blob/v0.5.1/docs/VALIDATION.md)
for scope and limitations.

Marketplace verification is requested separately for the exact release commit.
