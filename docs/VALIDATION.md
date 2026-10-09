# Validation

## Version 0.4.0

- Full `python scripts/check.py`: 19 model tests, Lua lifecycle tests, offscreen
  workspace-card and settings tests, 6 installer tests, 6 migration tests,
  manifest validation, JSON checks, and QML parsing.
- Live checks: all default shortcuts; custom Ctrl+Super+K and Ctrl+Super+Tab;
  single-step cycling, modifier release, reassignment, and saved-binding restoration.
- Configuration reload, plugin disable/enable, and lease expiry restore and
  reattach bindings correctly, with no Hyprland configuration errors.
- All four scopes open on the focused output across three monitors.
- Seven README screenshots regenerated from fictional fixtures and inspected.

## Configurable shortcuts and settings

- Live Alt+Super+Tab input verifies all four arrows, WASD and repeated Tab,
  with one selection step per press in List view. Escape restores the desktop
  keyboard mode. Lua tests cover layer filtering, previous-mode restoration
  and cleanup when the shortcut lease expires.

- 19 model tests cover default migration, custom chord validation, conflicts,
  confirmed reassignment, disabled assignments, persistence and reset while
  preserving custom views.
- Offscreen settings interactions verify conflict cancellation/acceptance,
  dropdown rollback, autosave, background blur, Display logo, reset confirmation and preservation
  of custom views, plus scrolling/clipping with the duplicate form open.
- Live physical input verifies all four default scopes, repeated-key cycling,
  custom Ctrl+Super+K and Ctrl+Super+Tab, modifier release, and restoration of
  saved desktop actions when a shortcut is removed.


## Workspace overview review fixes

- Offscreen QML checks use synthetic desktop entries to verify app icons,
  fallback initials, positive preview sizes in all four built-in layouts, and
  hover selection only when enabled. They run in `python scripts/check.py`.
- Lua lifecycle tests cover removing Omarchy's `SUPER + CTRL + TAB` binding
  alongside the plugin's `CTRL + SUPER + TAB` spelling. Before the fix both
  actions fired, changing workspace/monitor before the picker opened.
- Physical Ctrl+Super+Tab input was checked on three monitors: the picker
  opens on the focused output, closes on modifier release, and only one action
  owns that key chord.

## Version 0.3.2

All checks pass, including 6 installer and 6 migration tests. New regression
cases create legacy 0755 directories and 0644 full-configuration backups, then
verify automatic tightening even with clean/missing bindings or a failed
installer preflight. Backup contents and external symlink targets remain unchanged.


## Version 0.3.1

Regression tests reproduce the reviewer's umask 022 case: migration backups
remain 0600 inside a 0700 directory and the original remains 0600. Migration
also passes under umask 000. Simulated installer failure restores both file
contents and the original 0600/0640 modes even after intermediate mode changes.
Atomic rollback is separately checked under umask 000. All 15 model tests, Lua
lifecycle tests, 5 installer tests, 5 migration tests, manifest validation, and
QML parsing pass.


## Version 0.3.0

Checked on Omarchy 4.0.4, Hyprland 0.56.2 and Quickshell 0.3.1:

- All three physical modifier chords, hold visibility, single-step cycling,
  release activation and restoring the previously focused window after tests.
- Automatic reattachment after a Hyprland configuration reload.
- Standard plugin disable and remove commands restore all five original actions
  across Alt+Tab, Shift+Alt+Tab and Ctrl+Alt+Tab, with no configuration errors.
- Attaching without a heartbeat expires the lease and restores saved bindings.
- The existing marked include migrated automatically and was backed up.
- 15 model tests, Lua lifecycle tests, 4 installer tests, 4 migration tests,
  manifest validation, and QML parsing pass.


## Version 0.2.2

Fresh-install regression coverage asserts exactly four built-in views and an
empty custom library. Isolated runtime checks confirmed automatic persistence
of creation, styling, names, assignments and confirmed deletion; immediate
close flushes pending changes, invalid values are rejected, and simulated write
failure keeps preferences open until the automatic retry succeeds.

The rendered settings panel was inspected with the recreated theme-colored
vector icon and live wordmark text. The settings header has no byline or save
button, and the four-view library has no unnecessary carousel arrows.
Personal settings and source reference images are not bundled into defaults.

## Version 0.2.1

Regression checks cover switching copied list/fan/carousel views into a true
3-column grid, explicit maximum rows and columns, exact tile-and-gap screen
fitting, pagination, oversized single tiles, and migration of older custom views
without row limits. All 14 model tests, Lua tests, installer tests and parsing
checks pass.

An isolated Quickshell editor confirmed row/column edits and both preview sizes
use the same screen-fit limits. A hidden instance of the actual plugin confirmed
name edits persist automatically while unrelated styling stays in the draft;
duplicate names are rejected. Requesting or cancelling deletion preserves the
view; accepting removes it and restores the base template selection. These tests
used temporary configuration files and produced no plugin QML errors.

## Version 0.2.0

Automated checks cover immutable templates, independent duplication, stable IDs,
unique names, rename/delete and profile reassignment, every editable field's
validation, v1 migration, and persisted configuration round trips. The existing
window-selection, geometry, Lua binding, and installer tests also pass.

Desktop inspection rendered all four views, the studio controls and interactive
preview, the shortcut carousel with migrated custom views, and About using the
real Omarchy theme. The logo credit is right-aligned below the wordmark.
The isolated Quickshell runtime produced no Switch Magic QML warnings.
An isolated settings writer confirmed custom styling and shortcut assignments
survive a fresh process. Built-in overrides and invalid values were rejected
without changing the settings file. The installed v0.2 service loaded without
Switch Magic QML errors and preserved the existing per-scope preferences;
Hyprland configuration validation remained clean.

## Original integration checks (0.1.0)

Target environment: Omarchy 4.0.4, Hyprland 0.56.2, Quickshell 0.3.1.

Automated checks cover workspace/monitor/all filtering, MRU order, pinned and
special workspaces, initial selection, wrapping, window removal, malformed
configuration, non-mutating merges, all four layouts over window counts 1–31
and landscape/portrait/small viewports, and Alt-release routing with both Alt
keys. JSON, QML and Lua parsing and the official Omarchy manifest validator
are also run by `python scripts/check.py`.

Desktop validation: all four layouts and the preferences panel were rendered
in an isolated Quickshell host with Omarchy's real theme. Individual window
captures were observed, including windows on other monitors. Screenshots used
for inspection are intentionally not included: they contain user window data.

Installed desktop integration checks passed:

- Physical key events for Alt+Tab, Shift+Alt+Tab and Ctrl+Alt+Tab selected the
  workspace (2 windows), monitor (4), and all-workspaces (6) scopes respectively.
- The overlay stayed open while Alt was held; focus stayed on the original
  window until acceptance. A repeated Tab advanced exactly one position.
- Alt release hid the overlay and focused the selected window, including
  cross-monitor targets. The original focus was restored after testing.
- The switcher rendered on layer-shell's overlay layer above a fullscreen
  window. Escape cancelled without changing focus or fullscreen state.
- F2 opened preferences; releasing Alt kept preferences open; Escape closed it.
- A partial JSON update persisted and reloaded; invalid geometry was rejected
  without mutating shell.json. The default profile was restored afterward.
- Hyprland configuration validation returned no errors.

Activation is deliberately scheduled after the overlay unmaps; this prevents
Hyprland's layer-focus restoration from undoing the chosen window focus.
QML changes in this development symlink required a shell restart to flush the
host's component cache. The standalone wtype modifier path did not trigger
compositor shortcuts in this setup; integration tests used ydotool physical
key events instead.

Not exhaustively tested: protected content, GPU/driver combinations other than
this machine, and sustained capture performance with dozens of large windows.
