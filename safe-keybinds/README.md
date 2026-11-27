# Safe Keybinds for Godot 4

Let players rebind keyboard, mouse and gamepad controls. A table of actions, a save file that
survives crashes, the conflict rules players expect, and a small ready-made Controls screen that
a gamepad alone can drive.

The plugin itself, with its full guide and API, is in
[`addons/safe_keybinds/README.md`](addons/safe_keybinds/README.md).

## Install

- From the Godot Asset Library or Asset Store: search for Safe Keybinds and install. The download
  holds only `addons/safe_keybinds/`.
- By hand: copy `addons/safe_keybinds/` into your project's `addons/` folder. The classes register
  through `class_name`, so enabling the plugin in Project Settings is optional.

## Use

```gdscript
func _ready() -> void:
	KeybindActions.configure(KeybindActions.from_input_map(["move_left", "move_right", "jump"]))
	KeybindActions.install()
	KeybindStore.apply(KeybindStore.load()["bindings"])

func open_controls() -> void:
	var controls := KeybindControls.new()
	controls.closed.connect(controls.queue_free)
	$UI.add_child(controls)
```

Open this folder as a Godot project to run the demo (`addons/safe_keybinds/demo/demo.tscn` is the
main scene). WASD, the arrows or the left stick move, Space or A jumps, E or X recolours, the
wheel zooms, Esc or Start opens the Controls screen.

## Limits

- One player: a gamepad binding answers every pad (no per-pad bindings for local multiplayer).
- One bindings file at a time.
- The Controls screen uses plain Godot controls; style it with your project's Theme.
- Godot 4.3 or later, GDScript only. Tested on 4.3, 4.4, 4.5, 4.6 and 4.7.
- The tests in `addons/safe_keybinds/tests/` need GUT 9.x. Delete that folder if you do not use GUT.

## Licence

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). Free for any game, commercial
included. Keep the NOTICE file (or its text) when you redistribute the plugin.

## Support

Bugs: open an issue on this repository with a minimal project that shows it. Issues are read
when time allows; no reply time is promised and no custom work is offered.

## AI disclosure

The code, demo scene, tests and documentation were written with Claude, Anthropic's AI model,
and checked by Revenantworks with the plugin's own test suite on Godot 4.3 to 4.7. No AI-generated
images, sound or fonts in the plugin: the demo draws plain shapes in code. The store icon in
`media/` is a placeholder of plain shapes, drawn by a script written with Claude.

Made by Revenantworks.
