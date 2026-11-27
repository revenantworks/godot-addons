# Changelog

All notable changes to Safe Keybinds. Versions follow semantic versioning.

## [1.0.0]

First public release, under Apache-2.0.

- `KeybindActions`: a configurable action table (or one read from the Input Map), an installer,
  and the token codec with player-facing labels, for keys, mouse buttons, gamepad buttons,
  sticks and triggers (Xbox or PlayStation button names).
- `KeybindStore`: a versioned ConfigFile of bindings and settings, crash-safe writes, `.bad`
  quarantine, and the rebind, displace, cap and reset rules as pure functions.
- `KeybindControls`: a small ready-made Controls screen, usable from a gamepad alone (focus on
  show and after a change; Delete or the pad's top button removes a binding).
- `KeybindAtomicFile`: tmp-and-rename writes that survive a crash or a failed replace.
- Demo scene with a generic table of fifteen actions, with gamepad defaults.
- `tools/capture_screenshots.gd` takes the store screenshots from the demo scene (not in the
  download).
- 99 GUT tests (GUT 9.x). Godot 4.3 or later.
