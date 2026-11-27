class_name KeybindActions
extends RefCounted
## The table of rebindable actions, the installer that puts it in the live
## InputMap, and the token codec that the table and the bindings file share.
##
## A binding is stored as a token string, "<kind>:<mods>:<code>":
##   kind  "key" (a physical key, the same place on every layout),
##         "keycode" (a layout key), "mouse" (a mouse button or wheel),
##         "joy" (a gamepad button), or "axis+" / "axis-" (a gamepad stick
##         or trigger pushed toward its positive or negative end).
##   mods  "-" for none, else the letters C (Ctrl), S (Shift), A (Alt),
##         M (Meta), in that order. "SC" is not a token: one chord, one
##         spelling. Gamepad tokens always have "-".
##   code  Godot's Key, MouseButton, JoyButton or JoyAxis enum value.
## So "key:-:87" is W, "key:CS:83" is Ctrl+Shift+S, "mouse:-:4" is the
## wheel going up, "joy:-:0" is the bottom face button (A, Cross) and
## "axis-:-:1" is the left stick pushed up. A lone modifier (Ctrl, Shift,
## Alt, Meta) is never a binding, and neither is a trigger's negative end
## (a trigger rests at 0 and only goes up). Gamepad tokens match every
## connected pad.
##
## The table is `actions`: one Dictionary per action, with
##   "name"      the InputMap action name (required, unique),
##   "defaults"  its default tokens (required, at most MAX_BINDINGS),
##   "label"     the text the Controls screen shows (default: from the name),
##   "group"     a heading for the Controls screen (default: ""),
##   "kind"      HELD or PRESSED, a hint for your own code (default: PRESSED),
##   "dev_only"  true to bind its keys only while `dev_keys` is on.
## It starts as DEFAULT_ACTIONS. Replace it with configure(), or build rows
## from the actions already in your project's Input Map with from_input_map().

const HELD := "held"
const PRESSED := "pressed"

## The most tokens one action may hold. KeybindStore refuses a new slot past
## it and drops extra tokens from a hand-edited file.
const MAX_BINDINGS := 4

## How far a stick or trigger must move (0 to 1) before a capture reads it
## as a binding.
const AXIS_THRESHOLD := 0.5

## The button names label() uses for gamepad tokens. Godot numbers pad
## buttons by position (JOY_BUTTON_A is the bottom face button on every pad),
## so only the names change. Pads that are neither read as XBOX.
enum PadStyle { XBOX, PLAYSTATION }

const _KINDS: Array[String] = ["key", "keycode", "mouse", "joy", "axis+", "axis-"]

## The sixteen canonical modifier strings, in the fixed order C S A M.
const _VALID_MODS: Array[String] = [
	"-", "C", "S", "A", "M", "CS", "CA", "CM", "SA", "SM", "AM",
	"CSA", "CSM", "CAM", "SAM", "CSAM",
]

## A small generic table, so the addon works out of the box and the demo has
## something to show. The ints are Godot's Key, MouseButton, JoyButton and
## JoyAxis enum values (the tests check them against the KEY_*,
## MOUSE_BUTTON_*, JOY_BUTTON_* and JOY_AXIS_* constants). The pad defaults
## are the left stick to move, A to jump, X to interact, the right trigger to
## attack, B to crouch and Start to pause. zoom_in sits at the MAX_BINDINGS
## cap on purpose.
const DEFAULT_ACTIONS: Array[Dictionary] = [
	{"name": "move_up", "group": "Movement", "label": "Move up", "kind": HELD,
		"defaults": ["key:-:87", "key:-:4194320", "axis-:-:1"]},
	{"name": "move_down", "group": "Movement", "label": "Move down", "kind": HELD,
		"defaults": ["key:-:83", "key:-:4194322", "axis+:-:1"]},
	{"name": "move_left", "group": "Movement", "label": "Move left", "kind": HELD,
		"defaults": ["key:-:65", "key:-:4194319", "axis-:-:0"]},
	{"name": "move_right", "group": "Movement", "label": "Move right", "kind": HELD,
		"defaults": ["key:-:68", "key:-:4194321", "axis+:-:0"]},
	{"name": "jump", "group": "Actions", "label": "Jump", "kind": PRESSED,
		"defaults": ["key:-:32", "joy:-:0"]},
	{"name": "interact", "group": "Actions", "label": "Interact", "kind": PRESSED,
		"defaults": ["key:-:69", "joy:-:2"]},
	{"name": "attack", "group": "Actions", "label": "Attack", "kind": PRESSED,
		"defaults": ["mouse:-:1", "axis+:-:5"]},
	{"name": "crouch", "group": "Actions", "label": "Crouch", "kind": HELD,
		"defaults": ["key:-:67", "joy:-:1"]},
	{"name": "zoom_in", "group": "Camera", "label": "Zoom in", "kind": HELD,
		"defaults": ["mouse:-:4", "key:-:61", "key:S:61", "key:-:4194437"]},
	{"name": "zoom_out", "group": "Camera", "label": "Zoom out", "kind": HELD,
		"defaults": ["mouse:-:5", "key:-:45", "key:-:4194435"]},
	{"name": "quick_save", "group": "Game", "label": "Quick save", "kind": PRESSED,
		"defaults": ["key:-:4194336"]},
	{"name": "quick_load", "group": "Game", "label": "Quick load", "kind": PRESSED,
		"defaults": ["key:-:4194340"]},
	{"name": "pause", "group": "Game", "label": "Pause menu", "kind": PRESSED,
		"defaults": ["key:-:4194305", "joy:-:6"]},
	{"name": "fullscreen_toggle", "group": "Game", "label": "Fullscreen", "kind": PRESSED,
		"defaults": ["key:-:4194342", "key:A:4194309", "key:A:4194310"]},
	{"name": "debug_overlay", "group": "Developer", "label": "Debug overlay", "kind": PRESSED,
		"defaults": ["key:-:4194334"], "dev_only": true},
]

## The live table. Change it with configure(), never by hand.
static var actions: Array[Dictionary] = _normalised(DEFAULT_ACTIONS)

## Whether rows marked "dev_only" bind their keys. Starts on in the editor and
## off in an exported game. The actions exist either way, so code that asks
## Input about them never asks for an action the map lacks.
static var dev_keys: bool = OS.has_feature("editor")

## Tokens no action may ever hold: chords your game reads straight off the
## event (a screenshot key, a console key). configure() refuses a default that
## is reserved, and KeybindStore.rebind() refuses to bind one.
static var reserved: Array[String] = []

## When true, install() removes Space from Godot's built-in ui_accept action.
## Turn it on when Space is one of your actions: otherwise a focused button or
## list row takes Space as its own press. Enter stays ui_accept.
static var keep_space_out_of_accept: bool = false

## The names label() gives gamepad tokens. Set it from the player's pad with
## guess_pad_style(), or from a setting of your own.
static var pad_style: PadStyle = PadStyle.XBOX


## Replaces the table with `rows`, after checking them: every row needs a
## unique, non-empty "name" and an Array of "defaults" that all decode, at
## most MAX_BINDINGS of them, none reserved and none shared with another row.
## Missing "label", "group", "kind" and "dev_only" are filled in. On any
## problem it prints one error per problem, leaves the table unchanged and
## returns ERR_INVALID_DATA. It does not touch the InputMap: call install().
static func configure(rows: Array) -> Error:
	var problems := validate(rows)
	for p in problems:
		push_error("KeybindActions: " + p)
	if not problems.is_empty():
		return ERR_INVALID_DATA
	actions = _normalised(rows)
	return OK


## The problems configure() would refuse `rows` for; [] when they are fine.
static func validate(rows: Array) -> Array[String]:
	var out: Array[String] = []
	var names := {}
	var owners := {}
	for i in rows.size():
		var row = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			out.append("row %d is not a Dictionary" % i)
			continue
		var name = row.get("name", "")
		if typeof(name) != TYPE_STRING and typeof(name) != TYPE_STRING_NAME:
			out.append("row %d: name is not a String" % i)
			continue
		name = String(name)
		if name == "":
			out.append("row %d has no name" % i)
			continue
		if names.has(name):
			out.append("'%s' appears twice" % name)
		names[name] = true
		var defaults = row.get("defaults", null)
		if typeof(defaults) != TYPE_ARRAY:
			out.append("'%s': defaults is not an Array" % name)
			continue
		if (defaults as Array).size() > MAX_BINDINGS:
			out.append("'%s' has %d defaults, more than MAX_BINDINGS (%d)" % [name, defaults.size(), MAX_BINDINGS])
		for tok in defaults:
			if typeof(tok) != TYPE_STRING or decode(tok) == null:
				out.append("'%s': %s is not a valid token" % [name, str(tok)])
				continue
			if reserved.has(tok):
				out.append("'%s': %s is reserved" % [name, tok])
			if owners.has(tok):
				out.append("%s is a default of both '%s' and '%s'" % [tok, owners[tok], name])
			else:
				owners[tok] = name
	return out


## Rows for the actions already in the live InputMap (the ones your project
## defines in Project Settings > Input Map), in the order of `names`. Each
## row's defaults are the action's key, mouse and gamepad events, encoded (at
## most MAX_BINDINGS, in the map's order); events that cannot be a binding
## here (a lone modifier, a stick event with no direction) are left out, and
## a name the map lacks is skipped. Pass the result to configure().
static func from_input_map(action_names: Array, group: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in action_names:
		var name := String(n)
		if not InputMap.has_action(name):
			continue
		var tokens: Array[String] = []
		for ev in InputMap.action_get_events(name):
			var tok := encode(ev)
			if tok != "" and not tokens.has(tok) and tokens.size() < MAX_BINDINGS:
				tokens.append(tok)
		out.append({"name": name, "group": group, "label": label_from_name(name),
				"kind": PRESSED, "defaults": tokens})
	return out


## "move_left" -> "Move left".
static func label_from_name(name: String) -> String:
	var words := name.replace("_", " ").replace("-", " ").strip_edges()
	if words == "":
		return name
	return words.substr(0, 1).to_upper() + words.substr(1)


## Creates every action of the table in the live InputMap with its default
## events. Idempotent: an action that already exists has its events erased
## and re-added, so it is safe to call more than once.
static func install() -> void:
	for row in actions:
		var name: String = row["name"]
		if InputMap.has_action(name):
			InputMap.action_erase_events(name)
		else:
			InputMap.add_action(name)
		if not binds_now(row):
			continue
		for token in row["defaults"]:
			var event := decode(token)
			if event != null:
				InputMap.action_add_event(name, event)
	if keep_space_out_of_accept:
		_drop_space_from_accept()


## Whether `row` binds its keys now: every row, but a dev_only row only while
## dev_keys is on.
static func binds_now(row: Dictionary) -> bool:
	return not bool(row.get("dev_only", false)) or dev_keys


## Turns the dev_only rows' keys on or off, back to their defaults.
static func set_dev_keys(on: bool) -> void:
	dev_keys = on
	for row in actions:
		if not bool(row.get("dev_only", false)):
			continue
		if not InputMap.has_action(row["name"]):
			InputMap.add_action(row["name"])
		InputMap.action_erase_events(row["name"])
		if on:
			for token in row["defaults"]:
				var event := decode(token)
				if event != null:
					InputMap.action_add_event(row["name"], event)


static func _drop_space_from_accept() -> void:
	if not InputMap.has_action("ui_accept"):
		return
	for ev in InputMap.action_get_events("ui_accept"):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			if k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE:
				InputMap.action_erase_event("ui_accept", ev)


## The table row for `name`, or {} when there is none.
static func row_of(name: String) -> Dictionary:
	for row in actions:
		if row["name"] == name:
			return row
	return {}


## A copy of one action's default tokens, or [] if the name is not in the table.
static func defaults_for(name: String) -> Array:
	var row := row_of(name)
	return (row["defaults"] as Array).duplicate() if not row.is_empty() else []


## Every action name, in table order.
static func names() -> Array[String]:
	var out: Array[String] = []
	for row in actions:
		out.append(row["name"])
	return out


## A token decoded into a live event: InputEventKey, InputEventMouseButton,
## InputEventJoypadButton or InputEventJoypadMotion, or null when the token
## is unparseable (wrong shape, unknown kind, non-canonical mods, mods on a
## gamepad token, a negative, non-integer or out-of-range code, a key code
## that is itself a modifier, or a trigger's negative end). Gamepad events
## are for every device (-1), as Project Settings writes them.
static func decode(token: String) -> InputEvent:
	var parts := token.split(":")
	if parts.size() != 3:
		return null
	var kind: String = parts[0]
	var mods: String = parts[1]
	var code_str: String = parts[2]
	if not _KINDS.has(kind):
		return null
	if not _VALID_MODS.has(mods):
		return null
	if not code_str.is_valid_int():
		return null
	var code := code_str.to_int()
	if code < 0:
		return null

	if kind == "joy":
		if mods != "-" or code >= JOY_BUTTON_MAX:
			return null
		var jb := InputEventJoypadButton.new()
		jb.device = -1
		jb.button_index = code
		jb.pressed = true
		return jb
	if kind == "axis+" or kind == "axis-":
		if mods != "-" or code >= JOY_AXIS_MAX:
			return null
		if kind == "axis-" and _is_trigger(code):
			return null
		var jm := InputEventJoypadMotion.new()
		jm.device = -1
		jm.axis = code
		jm.axis_value = 1.0 if kind == "axis+" else -1.0
		return jm

	if kind != "mouse" and _is_modifier_code(code):
		return null

	var ctrl := mods.contains("C")
	var shift := mods.contains("S")
	var alt := mods.contains("A")
	var meta := mods.contains("M")

	if kind == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = code
		mb.pressed = true
		mb.ctrl_pressed = ctrl
		mb.shift_pressed = shift
		mb.alt_pressed = alt
		mb.meta_pressed = meta
		return mb

	var key := InputEventKey.new()
	if kind == "key":
		key.physical_keycode = code
	else:
		key.keycode = code
	key.pressed = true
	key.ctrl_pressed = ctrl
	key.shift_pressed = shift
	key.alt_pressed = alt
	key.meta_pressed = meta
	return key


## The reverse of decode(): "" when the event cannot be a binding (not a key,
## mouse button or gamepad event, no code, a lone modifier, a stick or
## trigger nearer rest than AXIS_THRESHOLD, or a trigger's negative end). A
## key with a physical code encodes as "key", otherwise as "keycode". The
## pad's device number is not kept: a binding works on every pad.
static func encode(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return "mouse:%s:%d" % [_mods_string(mb), mb.button_index]
	if event is InputEventKey:
		var key := event as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == 0:
			return ""
		if _is_modifier_code(code):
			return ""
		var kind := "key" if key.physical_keycode != 0 else "keycode"
		return "%s:%s:%d" % [kind, _mods_string(key), code]
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.button_index < 0 or jb.button_index >= JOY_BUTTON_MAX:
			return ""
		return "joy:-:%d" % jb.button_index
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if jm.axis < 0 or jm.axis >= JOY_AXIS_MAX or absf(jm.axis_value) < AXIS_THRESHOLD:
			return ""
		if jm.axis_value < 0.0 and _is_trigger(jm.axis):
			return ""
		return "%s:-:%d" % ["axis+" if jm.axis_value > 0.0 else "axis-", jm.axis]
	return ""


## Whether `token` is a gamepad token ("joy", "axis+" or "axis-").
static func is_pad_token(token: String) -> bool:
	return token.begins_with("joy:") or token.begins_with("axis+:") or token.begins_with("axis-:")


## A best guess at the button names for the pad `device`, from the name the
## OS gives it: PLAYSTATION for a Sony pad, else XBOX. Assign the result to
## pad_style. A device that is not connected reads as XBOX.
static func guess_pad_style(device: int) -> PadStyle:
	var name := Input.get_joy_name(device).to_lower()
	for word in ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]:
		if name.contains(word):
			return PadStyle.PLAYSTATION
	return PadStyle.XBOX


## The text a player reads for a token: "W", "Ctrl+Shift+S", "Wheel Up",
## "Middle Mouse", "Numpad +", "A", "Left Stick Up", "RT". A physical key is
## shown in the player's own keyboard layout when a display server is
## running; headless it falls back to the US name. Gamepad names follow
## pad_style ("Cross", "R2" for PLAYSTATION).
static func label(token: String) -> String:
	var parts := token.split(":")
	if parts.size() != 3:
		return ""
	var kind: String = parts[0]
	var mods: String = parts[1]
	var code_str: String = parts[2]
	if not code_str.is_valid_int():
		return ""
	var code := code_str.to_int()
	var prefix := _mods_label(mods)
	match kind:
		"mouse":
			return prefix + _mouse_label(code)
		"joy":
			return _pad_button_label(code)
		"axis+":
			return _pad_axis_label(code, true)
		"axis-":
			return _pad_axis_label(code, false)
		"keycode":
			return prefix + _key_label(code)
		"key":
			var kc := code
			if DisplayServer.get_name() != "headless":
				var local := DisplayServer.keyboard_get_keycode_from_physical(code)
				if local != KEY_NONE:
					kc = local
			return prefix + _key_label(kc)
		_:
			return ""


## Ctrl, Shift, Alt or Meta pressed alone. A capture ignores it and waits for
## the key it modifies.
static func is_modifier_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	return _is_modifier_code(code)


## Esc, with or without modifiers. The Controls screen uses it to cancel a
## capture.
static func is_cancel_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	return code == KEY_ESCAPE


## A pressed, non-echo key whose token is exactly `token` (its physical or
## layout spelling). For reading a reserved chord straight off an event.
static func matches_token(event: InputEvent, token: String) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	var got := encode(key)
	return got == token or ("keycode" + token.substr(3)) == got


static func _normalised(rows: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in rows:
		var name := String(row["name"])
		var defaults: Array[String] = []
		for tok in row["defaults"]:
			defaults.append(String(tok))
		out.append({
			"name": name,
			"defaults": defaults,
			"label": String(row.get("label", label_from_name(name))),
			"group": String(row.get("group", "")),
			"kind": String(row.get("kind", PRESSED)),
			"dev_only": bool(row.get("dev_only", false)),
		})
	return out


static func _is_trigger(axis: int) -> bool:
	return axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT


static func _is_modifier_code(code: int) -> bool:
	return code == KEY_CTRL or code == KEY_SHIFT or code == KEY_ALT or code == KEY_META


static func _mods_string(event: InputEventWithModifiers) -> String:
	var out := ""
	if event.ctrl_pressed:
		out += "C"
	if event.shift_pressed:
		out += "S"
	if event.alt_pressed:
		out += "A"
	if event.meta_pressed:
		out += "M"
	return out if out != "" else "-"


static func _mods_label(mods: String) -> String:
	if mods == "-":
		return ""
	var out := ""
	if mods.contains("C"):
		out += "Ctrl+"
	if mods.contains("S"):
		out += "Shift+"
	if mods.contains("A"):
		out += "Alt+"
	if mods.contains("M"):
		out += "Meta+"
	return out


## OS.get_keycode_string spells the numpad "Kp Add", "Kp Subtract" and so on;
## players read "Numpad +", so the numpad range is named here first.
static func _key_label(code: int) -> String:
	match code:
		KEY_KP_0:
			return "Numpad 0"
		KEY_KP_1:
			return "Numpad 1"
		KEY_KP_2:
			return "Numpad 2"
		KEY_KP_3:
			return "Numpad 3"
		KEY_KP_4:
			return "Numpad 4"
		KEY_KP_5:
			return "Numpad 5"
		KEY_KP_6:
			return "Numpad 6"
		KEY_KP_7:
			return "Numpad 7"
		KEY_KP_8:
			return "Numpad 8"
		KEY_KP_9:
			return "Numpad 9"
		KEY_KP_ADD:
			return "Numpad +"
		KEY_KP_SUBTRACT:
			return "Numpad -"
		KEY_KP_MULTIPLY:
			return "Numpad *"
		KEY_KP_DIVIDE:
			return "Numpad /"
		KEY_KP_PERIOD:
			return "Numpad ."
		KEY_KP_ENTER:
			return "Numpad Enter"
		_:
			return OS.get_keycode_string(code)


static func _mouse_label(code: int) -> String:
	match code:
		MOUSE_BUTTON_LEFT:
			return "Left Mouse"
		MOUSE_BUTTON_RIGHT:
			return "Right Mouse"
		MOUSE_BUTTON_MIDDLE:
			return "Middle Mouse"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT:
			return "Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT:
			return "Wheel Right"
		MOUSE_BUTTON_XBUTTON1:
			return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2:
			return "Mouse 5"
		_:
			return "Mouse %d" % code


static func _pad_button_label(code: int) -> String:
	var ps := pad_style == PadStyle.PLAYSTATION
	match code:
		JOY_BUTTON_A:
			return "Cross" if ps else "A"
		JOY_BUTTON_B:
			return "Circle" if ps else "B"
		JOY_BUTTON_X:
			return "Square" if ps else "X"
		JOY_BUTTON_Y:
			return "Triangle" if ps else "Y"
		JOY_BUTTON_BACK:
			return "Share" if ps else "Back"
		JOY_BUTTON_GUIDE:
			return "PS" if ps else "Guide"
		JOY_BUTTON_START:
			return "Options" if ps else "Start"
		JOY_BUTTON_LEFT_STICK:
			return "L3" if ps else "Left Stick Press"
		JOY_BUTTON_RIGHT_STICK:
			return "R3" if ps else "Right Stick Press"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1" if ps else "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1" if ps else "RB"
		JOY_BUTTON_DPAD_UP:
			return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad Right"
		JOY_BUTTON_MISC1:
			return "Mic" if ps else "Share"
		JOY_BUTTON_PADDLE1:
			return "Paddle 1"
		JOY_BUTTON_PADDLE2:
			return "Paddle 2"
		JOY_BUTTON_PADDLE3:
			return "Paddle 3"
		JOY_BUTTON_PADDLE4:
			return "Paddle 4"
		JOY_BUTTON_TOUCHPAD:
			return "Touchpad"
		_:
			return "Button %d" % code


static func _pad_axis_label(code: int, positive: bool) -> String:
	var ps := pad_style == PadStyle.PLAYSTATION
	match code:
		JOY_AXIS_LEFT_X:
			return "Left Stick Right" if positive else "Left Stick Left"
		JOY_AXIS_LEFT_Y:
			return "Left Stick Down" if positive else "Left Stick Up"
		JOY_AXIS_RIGHT_X:
			return "Right Stick Right" if positive else "Right Stick Left"
		JOY_AXIS_RIGHT_Y:
			return "Right Stick Down" if positive else "Right Stick Up"
		JOY_AXIS_TRIGGER_LEFT:
			return "L2" if ps else "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2" if ps else "RT"
		_:
			return "Axis %d %s" % [code, "+" if positive else "-"]
