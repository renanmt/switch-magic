# Changelog

## 0.5.1 — 2026-10-13

- Prevent settings fields from automatically reading foreign clipboard text by keeping native inputs read-only and handling bounded keyboard edits separately.
- Apply the protection to custom shortcuts, view names, numeric values, fonts and colors, including hidden controls.
- Preserve typing, selection, copy/cut, undo/redo, validation and saving. Paste and input-method composition are unavailable in these keyboard-only fields.
- Add an offscreen clipboard retrieval probe with an editable native field as a positive control, plus settings keyboard regression tests.

## 0.5.0 — 2026-10-12

- Add an App scope for windows matching the focused app across workspaces and monitors, with no shortcut assigned by default.
- Keep the originating app fixed while the picker is open, with recent windows first and the usual hidden, unmapped and special-workspace filters.
- Give App its own layout, preview mode and configurable shortcut in Views, defaulting to Carousel with live previews.
- Accept a literal backtick in custom shortcuts and display it instead of the GRAVE key name.
- Leave App unassigned on new installations, upgrades and reset so existing desktop shortcuts stay available; users can opt into Alt+backtick or another chord in Views → App.
- Document the fifth scope and cover filtering, migration, shortcut routing, modifier release and settings persistence with regression tests.

## 0.4.0 — 2026-10-09

- Fix arrow navigation while shortcut modifiers are held by isolating picker input from desktop bindings; add WASD navigation.
- Add a background blur percentage slider beside Display logo, defaulting to 20%.
- Add a workspace overview with per-workspace previews and a dedicated Alt+Super+Tab shortcut; Alt+Tab continues switching current-workspace windows.
- Add shortcut dropdowns, custom chords, and confirmation before moving a shortcut from another scope.
- Restore saved desktop bindings when shortcuts are reassigned or disabled, and handle modifier release for custom chords.
- Add a single Display logo toggle and a reset action that keeps custom views.
- Keep duplication controls fixed in the left studio column, with independently scrolling controls and preview.
- Place each scope’s shortcut selector at the right of the Views selection row.
- Fix workspace icon fallbacks, compact List previews, disabled hover selection and conflicting desktop shortcut spellings.
- Refresh the README instructions and seven screenshots, with a reproducible rendering script.

## 0.3.2

- Automatically restrict existing backup directories to 0700 and files to 0600 before any migration early return or installer preflight.
- Leave symlink targets outside the backup tree untouched.
- Cover upgrades with an already migrated or missing bindings file and failed installer preflight.


## 0.3.1

- Create configuration backup directories with mode 0700 and backup files with mode 0600.
- Preserve original file permissions during installer rollback using exclusive temporary files.
- Add regression coverage for restrictive originals and permissive process umasks.


## 0.3.0

- Attach shortcuts automatically with the standard Omarchy plugin lifecycle.
- Restore saved bindings on disable, removal, or shell heartbeat expiry.
- Reattach after Hyprland configuration reloads.
- Migrate the legacy marked include automatically, preserving a backup.

## 0.2.2 — First public release

- Visual Alt+Tab switching above fullscreen windows, with workspace, monitor,
  and all-workspace scopes.
- List, Grid, Carousel, and Hand of cards layouts with native window captures.
- Live, snapshot, selected-live, and icon preview modes.
- Named custom views with immutable built-in templates, a visual editor, and
  automatic saving.
- Configurable grid row and column limits with automatic screen fitting.
- Omarchy theme colors, typography, and a scalable Switch Magic logo.
- Backed-up keyboard integration with rollback and removal support.
- Public plugin ID: `renanmt.switch-magic`.

Requires Omarchy 4 / Hyprland 0.56+ with Lua configuration. Adding the plugin
through Omarchy requires the documented one-time shortcut setup.
