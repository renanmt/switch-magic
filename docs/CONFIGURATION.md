# Configuration

[`defaults.json`](../defaults.json) defines the four immutable built-in views and
default shortcut profiles. User settings are version 2 and live **inline in the
plugin entry** in `~/.config/omarchy/shell.json`:

```json
{
  "id": "renanmt.switch-magic",
  "version": 2,
  "profiles": {
    "workspace": { "view": "fan", "preview": "view" },
    "monitor": { "view": "list", "preview": "snapshot" },
    "all": { "view": "grid", "preview": "icon" },
    "spaces": { "view": "grid", "preview": "hybrid" }
  },
  "customViews": [],
  "behavior": { "hoverSelect": false, "includeSpecial": false, "showLogo": true }
}
```

Do **not** replace your entire shell.json with this object. Update the existing
`renanmt.switch-magic` entry in its `plugins` array. A custom view is a complete
copy of a view from `defaults.json` with a unique `id` and `name`, stored in
`customViews`. Profiles reference that stable ID. The View studio creates these
objects for you; renaming a view keeps its assignments intact.

| View section | Properties |
| --- | --- |
| `engine` | `list`, `grid`, `carousel`, or `fan` |
| `geometry` | Tile width/height, stage width, gap, visible count, maximum columns/rows, spread, angle, depth, inactive scale/opacity |
| `card` | Corner radius, borders, surfaces, tint, padding, shadows, fonts, text sizes/weight/spacing, footer, label and icon visibility/sizing |
| `preview` | `live`, `snapshot`, `hybrid`, or `icon` |
| `animation` | Duration, easing, position/scale/rotation/opacity transitions, entrance duration/scale, master toggle |
| `scene` | Theme/custom accent, backdrop dimming, heading size/tracking, logo size, hints |

[`settings.schema.json`](../settings.schema.json) lists every property and range.
The same field catalogue drives the editor, validation, and schema generation.
Geometry controls relevant to the selected engine appear in the studio.
Grid views have **Maximum columns** and **Maximum rows** (1–8 each).
The grid fits full-size tiles and gaps into the current monitor, automatically
reduces either limit when necessary, and pages through remaining windows.
The studio displays the effective limits and highlights when your settings
exceed the screen. Its preview uses the same screen dimensions as the switcher.
Switching a custom view's engine to Grid starts with 3 columns and 2 rows,
retaining its tile sizes and styling. Grid capacity comes from rows × columns;
`maxVisible` applies only to List, Carousel, and Hand of cards.
Existing custom grids without `geometry.rows` derive it from their old
`maxVisible` and column count on load.
Set `animation.enabled` to `false` for reduced motion. Fonts and accents set to
`theme` follow Omarchy automatically. `behavior.showLogo` controls the picker
wordmark and logo; it does not affect the preferences window.

Settings reload live. Invalid values or attempts to change the built-in views
retain the last valid configuration and expose a diagnostic in `state` and
preferences. Version 1 settings migrate automatically; customized geometry,
appearance, or motion become named copies so existing choices are preserved.
The next automatic save writes version 2. Legacy `layouts`, `appearance`, and the bundled
`views` field are persisted as `null` because the shell merges inline updates.

Apply a validated partial update or inspect saved configuration through IPC:

```sh
omarchy-shell switch-magic configure '{"profiles":{"workspace":{"view":"fan"}}}'
omarchy-shell switch-magic configuration
```

The active special workspace remains reachable in workspace scope, and pinned
windows are included on their monitor. The `spaces` profile opens the workspace
overview on the focused monitor; selecting a card activates that workspace.
Previews preserve aspect ratio.
List/grid paginate to keep the window list manageable.


[← Back to Switch Magic](../README.md)
