# Safe Keybinds

Keyboard, mouse and gamepad rebinding for Godot 4: a table of actions, a save
file that survives crashes, the conflict rules players expect, and a small
ready-made Controls screen that a gamepad alone can drive.

- Godot 4.3 or later, GDScript only. Tested on 4.3, 4.4, 4.5, 4.6 and 4.7.
- Keys, mouse buttons, gamepad buttons, sticks and triggers.
- Apache License 2.0. See `LICENSE` and `NOTICE`.

## Install

Copy `addons/safe_keybinds/` into your project's `addons/` folder. The classes
register through `class_name`, so enabling the plugin in Project Settings is
optional.

## Use

At startup, describe your actions, install them, then load and apply the
player's saved bindings:

```gdscript
func _ready() -> void:
	KeybindActions.configure([
		{"name": "move_left", "defaults": ["key:-:%d" % KEY_A, "key:-:%d" % KEY_LEFT], "group": "Movement"},
		{"name": "move_right", "defaults": ["key:-:%d" % KEY_D, "key:-:%d" % KEY_RIGHT], "group": "Movement"},
		{"name": "jump", "defaults": ["key:-:%d" % KEY_SPACE, "joy:-:%d" % JOY_BUTTON_A], "group": "Actions"},
		{"name": "fire", "defaults": ["mouse:-:%d" % MOUSE_BUTTON_LEFT], "group": "Actions"},
	])
	KeybindActions.install()
	KeybindStore.apply(KeybindStore.load()["bindings"])
```

Already set your actions up in Project Settings > Input Map? Read them in
instead of writing the table by hand:

```gdscript
	KeybindActions.configure(KeybindActions.from_input_map(["move_left", "move_right", "jump", "fire"]))
```

Then show the Controls screen wherever your menu needs it:

```gdscript
var controls := KeybindControls.new()
controls.closed.connect(controls.queue_free)
$UI.add_child(controls)
```

Click a binding, then press the new key, mouse button, gamepad button, stick
or trigger. Esc cancels. Right-click a binding, or focus it and press Delete or
the pad's top face button (Y, Triangle), to remove it. "+" adds one. Every
change is live at once and saved to `user://keybinds.cfg`.

With a gamepad connected, the screen focuses its first binding when it is
shown, and the focus stays on the binding you change, so a player can do all
of it from the pad. Pad buttons are named for an Xbox pad by default; set
`KeybindActions.pad_style` (or use `guess_pad_style(device)`) for PlayStation
names such as Cross and R2.

Without `configure()`, the kit uses a generic table of fifteen actions (move,
jump, interact, attack, crouch, zoom, quick save and load, pause, full screen,
and a developer-only debug overlay). The demo uses it.

## The demo

`demo/demo.tscn`: move the square with WASD, the arrows or the left stick,
Space or A to jump, E or X to recolour it, the wheel or +/- to zoom. Esc or
Start opens the Controls screen. The hint line shows the pad's controls while a
pad is connected.

## Rules

- **One key, one action.** Binding a key or button that another action holds
  moves it, and the screen says so ("E moved from Interact to Jump.").
- **At most four bindings per action** (`KeybindActions.MAX_BINDINGS`).
- **Reset takes its defaults back** from any action that has since claimed one.
- **Chords count as different keys.** S, Ctrl+S and Ctrl+Shift+S can belong to
  three actions. A lone modifier (Ctrl, Shift, Alt, Meta) is never a binding.
- **Reserved keys** (`KeybindActions.reserved`) can never be bound, for keys
  your game handles itself.
- **Developer rows** (`"dev_only": true`) bind only while
  `KeybindActions.dev_keys` is on (by default, in the editor).

## The save file

A `ConfigFile` with three sections: `[meta] version`, `[bindings]` with only
the actions that differ from their defaults, and `[settings]` for any other
values your game wants to keep beside them (`KeybindStore.get_setting`,
`set_setting`, `write_settings`).

Every write goes to a `.tmp` file first and is then renamed over the real one,
so a crash mid-write never leaves a short file. A file that cannot be read is
renamed to `.bad`, the defaults load, and `load()` returns one warning for the
player. A hand-edited file is read as far as it makes sense: bad tokens are
skipped, and a key listed under two actions goes to the earlier one.

## Tokens

A binding is a string `"<kind>:<mods>:<code>"`:

- `kind`: `key` (a physical key, layout-independent), `keycode` (a layout key),
  `mouse` (a mouse button or wheel), `joy` (a gamepad button), or `axis+` /
  `axis-` (a stick or trigger pushed toward that end).
- `mods`: `-` for none, or any of `C` `S` `A` `M` (Ctrl, Shift, Alt, Meta) in
  that order. Gamepad tokens always use `-`.
- `code`: Godot's own `Key`, `MouseButton`, `JoyButton` or `JoyAxis` number.

So `joy:-:0` is the bottom face button (A, Cross) and `axis-:-:1` is the left
stick pushed up. A gamepad binding works on every connected pad. A stick or
trigger counts once it is pushed past `KeybindActions.AXIS_THRESHOLD` (0.5),
and a trigger has no `axis-` end.

`KeybindActions.encode(event)` and `decode(token)` convert, and `label(token)`
gives the text a player reads ("Ctrl+S", "Wheel Up", "Numpad +", "A",
"Left Stick Up", "RT").

## API

`KeybindActions` (static):

- `configure(rows) -> Error`, `validate(rows) -> Array[String]`: set the action
  table; a bad table is refused whole, with one error per problem.
- `from_input_map(names, group = "")`: rows from the project's Input Map.
- `install()`: create the actions in the InputMap with their defaults.
- `names()`, `row_of(name)`, `defaults_for(name)`.
- `encode(event)`, `decode(token)`, `label(token)`, `matches_token(event, token)`,
  `is_pad_token(token)`.
- `pad_style` (`PadStyle.XBOX` or `PLAYSTATION`) and `guess_pad_style(device)`.
- `reserved`, `dev_keys` / `set_dev_keys(on)`, `keep_space_out_of_accept`.

`KeybindStore` (static):

- `load(path, quarantine = true)`, `save(bindings, settings = {}, path)`.
- `apply(bindings)`, `from_input_map()`.
- `rebind(bindings, action, slot, token)`, `remove_slot`, `reset_action`,
  `reset_all`, `owner_of`.
- `get_setting(key, fallback, path)`, `set_setting`, `write_settings`.

`KeybindControls` (a `PanelContainer`):

- `save_path` ("" saves nothing), `show_dev_rows`, `title`.
- Signals `bindings_changed(bindings)` and `closed`.
- `refresh()`, `begin_capture(action, slot)`, `cancel_capture()`,
  `capture_event(event)`, `remove_binding`, `reset_action`, `reset_all`,
  `focus_first()`.
- Static `row_state(bindings, action)`, `binding_text(token)` and
  `is_remove_event(event)` for a screen of your own.

`KeybindAtomicFile` (static): the crash-safe writer the store uses.

## Limits

- One player: a gamepad binding answers every pad. Per-pad bindings for local
  multiplayer are not covered.
- Pad buttons are named for Xbox or PlayStation pads; a Nintendo pad shows the
  Xbox names for the same positions.
- One bindings file at a time per call.
- The Controls screen is plain Godot controls with no theme of its own; style
  it with your project's Theme.
- `keycode` labels follow the player's keyboard layout; `key` labels use it too
  when a display server is running, and US names in headless runs.
- The tests in `tests/` need GUT 9.x. Delete that folder if you do not use GUT.

## Licence

Apache License 2.0. See `LICENSE` and `NOTICE`.
