# Switch Magic 0.5.3 — Picker identity hardening

This patch release addresses the layer-namespace finding from the
[marketplace review](https://github.com/omacom/omarchy-plugin-marketplace/issues/15240#issuecomment-7053890340).

Switch Magic now checks that picker layers belong to its hosting Quickshell
process. Another layer-shell process using the same namespace is ignored when
changing keyboard submaps, waiting for the picker to unmap, or cancelling pending
focus. Invalid process IDs are rejected, and shortcut renewal cannot reuse a
lease belonging to a different shell process.

The release also strengthens expired-keybind regression coverage for foreign
unbinds, reattachment, watchdog expiry, detach and picker-only handle expiry.
The runtime crash guard itself already shipped in 0.5.2.

Existing preferences, views and shortcuts are preserved. There are no new runtime
dependencies or manual configuration migrations. All 0.5.2 settings, focus and
scratchpad fixes are included. Settings retain their keyboard-only clipboard
protection; paste and input-method composition remain unavailable.

Install:

```sh
omarchy plugin add https://github.com/renanmt/switch-magic --enable
```

Update:

```sh
omarchy plugin update renanmt.switch-magic
```

The full `python scripts/check.py` suite passes, including 22 model tests, Lua
shortcut/focus regressions, offscreen QML and Qt 6.12.0 clipboard checks, installer
and migration tests, manifest validation, JSON checks and QML parsing. An isolated
probe also verified that the actual QML command construction supplies the PID to
both Lua programs. Compositor events and credentials were mocked; hostile-client
testing was not performed on the live desktop.

The PID comes from Wayland client credentials reported by Hyprland. This
distinguishes separate client processes; it does not isolate plugins hosted in
the same Quickshell process or restrict arbitrary compositor IPC. See the
[validation notes](https://github.com/renanmt/switch-magic/blob/v0.5.3/docs/VALIDATION.md).

Thanks to [@arthurpolice](https://github.com/arthurpolice) for
[PR #4](https://github.com/renanmt/switch-magic/pull/4) and
[@HANCORE-linux](https://github.com/HANCORE-linux) for the marketplace review.
The picker identity fix is in [PR #5](https://github.com/renanmt/switch-magic/pull/5).

[Full changelog](https://github.com/renanmt/switch-magic/compare/v0.5.2...v0.5.3)
