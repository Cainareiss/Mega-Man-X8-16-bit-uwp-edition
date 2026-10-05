# Save persistence (UWP 1.0.0.16)

The port keeps the original `user://savegame.save` filename and binary Variant
format (save schema 0.4). Package identity and publisher are unchanged.

## Changes

- Save changes to global progress, collectibles and settings automatically,
  coalesced at the end of the frame. Also flush on quit, focus loss and suspend.
- Do not save from the keybinding loader while restoring game state.
- Write and validate a temporary file before replacing the primary. Preserve a
  validated previous primary as `savegame.save.bak`.
- Load the primary, backup or completed temporary record. Do not replace an
  unreadable or unsupported existing save with defaults. Report failures in the
  Godot log instead of emitting a successful save notification.
- Install updates with `Add-AppxPackage`, without uninstalling the existing
  package. Uninstalling may delete UWP LocalState, including the save.

## Validation

`tools/save_tests` is an isolated Godot 3.5.3 test project. It stages the actual
Savefile, SaveStorage and GlobalVariables scripts, with unrelated game services
stubbed. Its user-data folder is separate from the player's game.

The `write` process changes boss progress, collects an item and changes an option.
The separate `read` process checks persistence, backup recovery after truncation,
write-open failure, preservation of an unreadable existing file and acceptance
of legacy 0.4 floating-point versions. CI runs both processes before publishing
the export artifact.

These checks do not simulate Xbox suspend at the operating-system level. Verify
on-device by finishing a boss or collecting an upgrade, closing the application,
and reopening it, without uninstalling or clearing saved data.

If an older build already erased all valid copies, this patch cannot reconstruct
the lost progress. Keep any existing `.bak` or `.tmp` file next to the primary.
