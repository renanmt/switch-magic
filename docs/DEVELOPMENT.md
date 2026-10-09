# Development

```sh
python scripts/check.py
# or behavior tests only (Node + Lua, no npm dependencies):
npm test
```

The project separates pure selection/layout logic (`lib/Model.js`), capture
cards (`components/WindowCard.qml`), preferences UI, the Omarchy service
(`SwitchMagic.qml`), and a small compositor key-release bridge (`runtime/bindings.lua`).
The four geometry algorithms are implemented in JS; their properties are
JSON-defined. Adding a fundamentally new layout requires a geometry algorithm
and a corresponding editor field entry. JSON specifies properties; it does
not execute code. Regenerate the schema with `node scripts/schema.cjs` after
changing the shared field catalogue.

After editing QML in a symlinked development checkout, run `omarchy restart shell`
if the host retains cached components. Settings edits reload without a restart.

For isolated development, run `python scripts/preview.py`. It loads Omarchy's
theme in a temporary harness without registering global shortcuts, so the
installed plugin can remain active. Use the printed IPC commands to open a
preview or preferences. The preview harness cannot save settings.

```sh
# Show a layout using real windows without switching focus; Esc closes it.
omarchy-shell switch-magic preview fan
omarchy-shell switch-magic cancel

# Inspect runtime state / configuration errors:
omarchy-shell switch-magic state
hyprctl configerrors
```

Developer previews can show private window content. Keep captures of personal desktop content out of commits. The README
screenshots use fictional windows in an isolated rendering session. Regenerate them with
`python scripts/screenshots.py` in a Wayland session; a temporary overlay renders
fictional fixtures without registering shortcuts or capturing desktop content. [VALIDATION.md](VALIDATION.md) records the checks performed for this build.


[← Back to Switch Magic](../README.md)

## Automatic shortcut lifecycle

`components/AutomaticBindings.qml` attaches runtime Lua bindings and renews an
8-second lease every 2 seconds. Ownership tokens prevent an old component from
removing a replacement instance's shortcuts. A config reload triggers reattachment. Changing shortcut assignments reloads the
saved configuration before installing the new bindings so removed chords regain
their original actions. Offscreen QML checks exercise the settings controls with
synthetic data, including conflict and reset confirmations.
Disable/unload or lease expiry reloads the saved Hyprland configuration, preserving
saved Lua callbacks without reconstructing them from `hyprctl binds` output.
Other temporary runtime-only Hyprland changes are also reset by that reload.

`scripts/migrate-bindings.py` removes only the exact legacy include, with a backup.
The top-level `bindings.lua` remains a harmless compatibility stub during upgrades.
For a development symlink, `python scripts/install.py` enables the service; it does
not install keyboard configuration. Normal users use `omarchy plugin add`.
