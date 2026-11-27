extends GutTest
## KeybindActions: the table, configure(), the installer and the token codec.

var _dev_was: bool


func before_each() -> void:
	_dev_was = KeybindActions.dev_keys
	KeybindActions.reserved = []
	KeybindActions.keep_space_out_of_accept = false
	KeybindActions.dev_keys = true
	assert_eq(KeybindActions.configure(KeybindActions.DEFAULT_ACTIONS), OK, "control: the default table")
	KeybindActions.install()


func after_each() -> void:
	KeybindActions.reserved = []
	KeybindActions.keep_space_out_of_accept = false
	KeybindActions.dev_keys = _dev_was
	KeybindActions.configure(KeybindActions.DEFAULT_ACTIONS)
	KeybindActions.install()


# --- the default table -------------------------------------------------------

func test_every_action_name_exists_after_install() -> void:
	for name in KeybindActions.names():
		assert_true(InputMap.has_action(name), "missing action %s" % name)
	assert_eq(KeybindActions.names().size(), 15, "the default table has fifteen actions")


## The default tokens are written as ints; they must be the keys they claim.
func test_the_default_ints_are_the_keys_they_name() -> void:
	var want := {
		"move_up": ["key:-:%d" % KEY_W, "key:-:%d" % KEY_UP, "axis-:-:%d" % JOY_AXIS_LEFT_Y],
		"move_down": ["key:-:%d" % KEY_S, "key:-:%d" % KEY_DOWN, "axis+:-:%d" % JOY_AXIS_LEFT_Y],
		"move_left": ["key:-:%d" % KEY_A, "key:-:%d" % KEY_LEFT, "axis-:-:%d" % JOY_AXIS_LEFT_X],
		"move_right": ["key:-:%d" % KEY_D, "key:-:%d" % KEY_RIGHT, "axis+:-:%d" % JOY_AXIS_LEFT_X],
		"jump": ["key:-:%d" % KEY_SPACE, "joy:-:%d" % JOY_BUTTON_A],
		"interact": ["key:-:%d" % KEY_E, "joy:-:%d" % JOY_BUTTON_X],
		"attack": ["mouse:-:%d" % MOUSE_BUTTON_LEFT, "axis+:-:%d" % JOY_AXIS_TRIGGER_RIGHT],
		"crouch": ["key:-:%d" % KEY_C, "joy:-:%d" % JOY_BUTTON_B],
		"zoom_in": ["mouse:-:%d" % MOUSE_BUTTON_WHEEL_UP, "key:-:%d" % KEY_EQUAL, "key:S:%d" % KEY_EQUAL, "key:-:%d" % KEY_KP_ADD],
		"zoom_out": ["mouse:-:%d" % MOUSE_BUTTON_WHEEL_DOWN, "key:-:%d" % KEY_MINUS, "key:-:%d" % KEY_KP_SUBTRACT],
		"quick_save": ["key:-:%d" % KEY_F5],
		"quick_load": ["key:-:%d" % KEY_F9],
		"pause": ["key:-:%d" % KEY_ESCAPE, "joy:-:%d" % JOY_BUTTON_START],
		"fullscreen_toggle": ["key:-:%d" % KEY_F11, "key:A:%d" % KEY_ENTER, "key:A:%d" % KEY_KP_ENTER],
		"debug_overlay": ["key:-:%d" % KEY_F3],
	}
	assert_eq(want.size(), KeybindActions.names().size(), "every row is checked")
	for name in want:
		assert_eq(KeybindActions.defaults_for(name), want[name], "%s's defaults" % name)


func test_every_default_event_count_matches() -> void:
	for row in KeybindActions.actions:
		var name: String = row["name"]
		var events := InputMap.action_get_events(name)
		assert_eq(events.size(), row["defaults"].size(),
				"%s should have %d default event(s)" % [name, row["defaults"].size()])


func test_move_up_has_w_up_and_the_stick() -> void:
	var events := InputMap.action_get_events("move_up")
	assert_eq(events.size(), 3)
	var codes := []
	var stick_up := false
	for e in events:
		if e is InputEventKey:
			codes.append((e as InputEventKey).physical_keycode)
		elif e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			stick_up = m.axis == JOY_AXIS_LEFT_Y and m.axis_value < 0.0 and m.device == -1
	assert_true(codes.has(KEY_W), "W is bound")
	assert_true(codes.has(KEY_UP), "Up is bound")
	assert_true(stick_up, "the left stick pushed up, on every pad")


func test_zoom_in_has_four_events() -> void:
	var events := InputMap.action_get_events("zoom_in")
	assert_eq(events.size(), 4, "wheel, bare =, Shift+=, numpad +")
	var wheel_found := false
	var bare_equal_found := false
	var shift_equal_found := false
	var kp_add_found := false
	for e in events:
		if e is InputEventMouseButton:
			if (e as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
				wheel_found = true
		elif e is InputEventKey:
			var k := e as InputEventKey
			if k.physical_keycode == KEY_EQUAL and not k.shift_pressed:
				bare_equal_found = true
			elif k.physical_keycode == KEY_EQUAL and k.shift_pressed:
				shift_equal_found = true
			elif k.physical_keycode == KEY_KP_ADD:
				kp_add_found = true
	assert_true(wheel_found, "mouse:-:4")
	assert_true(bare_equal_found, "key:-:61 without shift")
	assert_true(shift_equal_found, "key:S:61 with shift")
	assert_true(kp_add_found, "key:-:4194437 numpad +")


func test_zoom_out_has_three_events() -> void:
	assert_eq(InputMap.action_get_events("zoom_out").size(), 3, "wheel down, -, numpad -")


func test_install_twice_is_idempotent() -> void:
	KeybindActions.install()
	KeybindActions.install()
	for row in KeybindActions.actions:
		var name: String = row["name"]
		assert_eq(InputMap.action_get_events(name).size(), row["defaults"].size(),
				"%s unchanged after a second install" % name)


func test_defaults_are_conflict_free() -> void:
	var seen := {}
	for row in KeybindActions.actions:
		for token in row["defaults"]:
			assert_false(seen.has(token), "token %s appears in two rows" % token)
			seen[token] = row["name"]


func test_every_row_declares_kind_group_label() -> void:
	for row in KeybindActions.actions:
		assert_true(row.has("kind"), "%s missing kind" % row.get("name", "?"))
		assert_true(row.has("group"), "%s missing group" % row.get("name", "?"))
		assert_true(row.has("label"), "%s missing label" % row.get("name", "?"))
		assert_true(row["kind"] == KeybindActions.HELD or row["kind"] == KeybindActions.PRESSED)


func test_every_default_token_decodes() -> void:
	for row in KeybindActions.actions:
		for token in row["defaults"]:
			assert_not_null(KeybindActions.decode(token), "%s should decode" % token)


func test_encode_decode_roundtrip_for_every_default() -> void:
	for row in KeybindActions.actions:
		for token in row["defaults"]:
			var ev := KeybindActions.decode(token)
			assert_eq(KeybindActions.encode(ev), token, "round trip for %s" % token)


func test_fullscreen_has_f11_and_alt_enter_and_is_rebindable() -> void:
	assert_eq(InputMap.action_get_events("fullscreen_toggle").size(), 3, "F11, Alt+Enter and Alt+numpad Enter")
	var out := KeybindStore.rebind(KeybindStore.reset_all(), "fullscreen_toggle", 0, "key:-:%d" % KEY_F10)
	assert_eq(out["bindings"]["fullscreen_toggle"][0], "key:-:%d" % KEY_F10, "rebinding takes")


# --- the codec ---------------------------------------------------------------

func test_encode_synthetic_ctrl_shift_s() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_S
	ev.pressed = true
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	assert_eq(KeybindActions.encode(ev), "key:CS:83")


func test_encode_a_layout_key_as_keycode() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.pressed = true
	assert_eq(KeybindActions.encode(ev), "keycode:-:%d" % KEY_Q, "no physical code: the layout key")
	assert_eq((KeybindActions.decode("keycode:-:%d" % KEY_Q) as InputEventKey).keycode, KEY_Q)


func test_decode_rejects_bad_tokens() -> void:
	assert_null(KeybindActions.decode("key:87"), "one-colon shape is unparseable")
	assert_null(KeybindActions.decode("key:SC:83"), "non-canonical mod order")
	assert_null(KeybindActions.decode("key:-:%d" % KEY_CTRL), "a bare modifier can never be a binding")
	assert_null(KeybindActions.decode("pad:-:7"), "unknown kind")
	assert_null(KeybindActions.decode("key:-:-3"), "a negative code")
	assert_null(KeybindActions.decode("key:-:x"), "a code that is not an int")


func test_encode_lone_ctrl_is_empty_string() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_CTRL
	ev.pressed = true
	ev.ctrl_pressed = true
	assert_eq(KeybindActions.encode(ev), "")
	assert_true(KeybindActions.is_modifier_key(ev), "and it reads as a lone modifier")


func test_encode_a_joypad_button_from_any_pad() -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 2
	ev.button_index = JOY_BUTTON_RIGHT_SHOULDER
	ev.pressed = true
	assert_eq(KeybindActions.encode(ev), "joy:-:%d" % JOY_BUTTON_RIGHT_SHOULDER, "the device is not kept")
	var back := KeybindActions.decode("joy:-:%d" % JOY_BUTTON_RIGHT_SHOULDER) as InputEventJoypadButton
	assert_eq(back.button_index, JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(back.device, -1, "a decoded binding is for every pad")
	assert_true(back.pressed)


func test_encode_a_stick_or_trigger_only_past_the_threshold() -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_RIGHT_X
	m.axis_value = 0.3
	assert_eq(KeybindActions.encode(m), "", "a nudge is not a binding")
	m.axis_value = 0.8
	assert_eq(KeybindActions.encode(m), "axis+:-:%d" % JOY_AXIS_RIGHT_X)
	m.axis_value = -0.8
	assert_eq(KeybindActions.encode(m), "axis-:-:%d" % JOY_AXIS_RIGHT_X)
	m.axis = JOY_AXIS_TRIGGER_LEFT
	m.axis_value = -0.8
	assert_eq(KeybindActions.encode(m), "", "a trigger has no negative end")
	m.axis_value = 1.0
	assert_eq(KeybindActions.encode(m), "axis+:-:%d" % JOY_AXIS_TRIGGER_LEFT)
	var back := KeybindActions.decode("axis-:-:%d" % JOY_AXIS_RIGHT_X) as InputEventJoypadMotion
	assert_eq(back.axis, JOY_AXIS_RIGHT_X)
	assert_eq(back.axis_value, -1.0)
	assert_eq(back.device, -1)


func test_decode_rejects_bad_gamepad_tokens() -> void:
	assert_null(KeybindActions.decode("joy:C:0"), "a gamepad token takes no modifiers")
	assert_null(KeybindActions.decode("axis+:S:0"), "nor does a stick")
	assert_null(KeybindActions.decode("joy:-:%d" % JOY_BUTTON_MAX), "past the last button")
	assert_null(KeybindActions.decode("axis+:-:%d" % JOY_AXIS_MAX), "past the last axis")
	assert_null(KeybindActions.decode("axis-:-:%d" % JOY_AXIS_TRIGGER_RIGHT), "a trigger's negative end")
	assert_null(KeybindActions.decode("axis:-:0"), "an axis needs its direction")
	assert_not_null(KeybindActions.decode("joy:-:%d" % JOY_BUTTON_PADDLE1), "control: a paddle is a button")


func test_a_bound_stick_drives_the_action() -> void:
	var m := InputEventJoypadMotion.new()
	m.device = 0
	m.axis = JOY_AXIS_LEFT_Y
	m.axis_value = -0.9
	assert_true(m.is_action_pressed("move_up"), "the left stick up is move_up")
	assert_false(m.is_action_pressed("move_down"), "and not move_down")
	var b := InputEventJoypadButton.new()
	b.device = 1
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	assert_true(b.is_action_pressed("jump"), "A on the second pad jumps too")


func test_label_for_gamepad_tokens() -> void:
	var was := KeybindActions.pad_style
	KeybindActions.pad_style = KeybindActions.PadStyle.XBOX
	assert_eq(KeybindActions.label("joy:-:%d" % JOY_BUTTON_A), "A")
	assert_eq(KeybindActions.label("joy:-:%d" % JOY_BUTTON_LEFT_SHOULDER), "LB")
	assert_eq(KeybindActions.label("joy:-:%d" % JOY_BUTTON_DPAD_LEFT), "D-pad Left")
	assert_eq(KeybindActions.label("joy:-:%d" % 40), "Button 40")
	assert_eq(KeybindActions.label("axis-:-:%d" % JOY_AXIS_LEFT_Y), "Left Stick Up")
	assert_eq(KeybindActions.label("axis+:-:%d" % JOY_AXIS_RIGHT_X), "Right Stick Right")
	assert_eq(KeybindActions.label("axis+:-:%d" % JOY_AXIS_TRIGGER_RIGHT), "RT")
	assert_eq(KeybindActions.label("axis-:-:%d" % 7), "Axis 7 -")
	KeybindActions.pad_style = KeybindActions.PadStyle.PLAYSTATION
	assert_eq(KeybindActions.label("joy:-:%d" % JOY_BUTTON_A), "Cross")
	assert_eq(KeybindActions.label("joy:-:%d" % JOY_BUTTON_Y), "Triangle")
	assert_eq(KeybindActions.label("joy:-:%d" % JOY_BUTTON_START), "Options")
	assert_eq(KeybindActions.label("axis+:-:%d" % JOY_AXIS_TRIGGER_LEFT), "L2")
	assert_eq(KeybindActions.label("joy:-:%d" % JOY_BUTTON_DPAD_UP), "D-pad Up", "the d-pad has one name")
	KeybindActions.pad_style = was


func test_is_pad_token_and_guess_pad_style() -> void:
	assert_true(KeybindActions.is_pad_token("joy:-:0"))
	assert_true(KeybindActions.is_pad_token("axis-:-:1"))
	assert_false(KeybindActions.is_pad_token("key:-:%d" % KEY_J))
	assert_false(KeybindActions.is_pad_token("mouse:-:1"))
	assert_eq(KeybindActions.guess_pad_style(99), KeybindActions.PadStyle.XBOX, "no pad: Xbox names")


func test_label_for_mouse_tokens() -> void:
	assert_eq(KeybindActions.label("mouse:-:3"), "Middle Mouse")
	assert_eq(KeybindActions.label("mouse:-:4"), "Wheel Up")
	assert_eq(KeybindActions.label("mouse:S:1"), "Shift+Left Mouse")


func test_label_for_modifier_keycode_token() -> void:
	assert_eq(KeybindActions.label("keycode:C:65"), "Ctrl+A")


func test_label_for_numpad_add_keycode_token() -> void:
	assert_eq(KeybindActions.label("keycode:-:4194437"), "Numpad +")


func test_is_cancel_key_is_esc_with_any_modifiers() -> void:
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	assert_true(KeybindActions.is_cancel_key(esc))
	esc.shift_pressed = true
	assert_true(KeybindActions.is_cancel_key(esc), "Shift+Esc too")
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	assert_false(KeybindActions.is_cancel_key(q), "control: Q is not")


func test_matches_token_reads_a_reserved_chord() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_P
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	ev.pressed = true
	assert_true(KeybindActions.matches_token(ev, "key:CS:%d" % KEY_P))
	ev.echo = true
	assert_false(KeybindActions.matches_token(ev, "key:CS:%d" % KEY_P), "an echo is not a press")
	ev.echo = false
	ev.shift_pressed = false
	assert_false(KeybindActions.matches_token(ev, "key:CS:%d" % KEY_P), "Ctrl+P alone is another chord")


# --- options -----------------------------------------------------------------

## With keep_space_out_of_accept, Godot's ui_accept keeps Enter but loses
## Space, so a focused button never takes Space as its press.
func test_space_leaves_ui_accept_only_when_asked() -> void:
	KeybindActions.keep_space_out_of_accept = true
	KeybindActions.install()
	var space := 0
	var enter := 0
	for ev in InputMap.action_get_events("ui_accept"):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			if k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE:
				space += 1
			if k.keycode == KEY_ENTER or k.physical_keycode == KEY_ENTER:
				enter += 1
	assert_eq(space, 0, "ui_accept has no Space after install")
	assert_gt(enter, 0, "control: Enter is still ui_accept")
	assert_eq(InputMap.action_get_events("jump").size(), 2, "Space and A still jump")
	InputMap.load_from_project_settings()


func test_dev_rows_are_unbound_without_dev_keys() -> void:
	KeybindActions.set_dev_keys(false)
	KeybindActions.install()
	assert_true(InputMap.has_action("debug_overlay"), "the action still exists")
	assert_eq(InputMap.action_get_events("debug_overlay").size(), 0, "no key without dev keys")
	KeybindStore.apply(KeybindStore.reset_all())
	assert_eq(InputMap.action_get_events("debug_overlay").size(), 0, "an apply keeps it unbound")
	assert_eq(KeybindStore.from_input_map()["debug_overlay"], KeybindActions.defaults_for("debug_overlay"),
			"a save would keep the default, never 'unbound'")
	KeybindActions.set_dev_keys(true)
	assert_eq(InputMap.action_get_events("debug_overlay").size(), 1, "control: dev keys bind F3")


# --- configure() and from_input_map() ----------------------------------------

func test_configure_replaces_the_table_and_fills_missing_fields() -> void:
	var rows := [
		{"name": "fire", "defaults": ["key:-:%d" % KEY_F]},
		{"name": "reload_weapon", "defaults": ["key:-:%d" % KEY_R, "mouse:-:%d" % MOUSE_BUTTON_RIGHT], "group": "Combat"},
	]
	assert_eq(KeybindActions.configure(rows), OK)
	assert_eq(KeybindActions.names(), ["fire", "reload_weapon"] as Array[String])
	var row := KeybindActions.row_of("reload_weapon")
	assert_eq(row["label"], "Reload weapon", "the label comes from the name")
	assert_eq(row["group"], "Combat")
	assert_eq(row["kind"], KeybindActions.PRESSED, "kind defaults to pressed")
	assert_false(row["dev_only"])
	KeybindActions.install()
	assert_eq(InputMap.action_get_events("reload_weapon").size(), 2, "installed")


func test_validate_names_every_problem() -> void:
	var rows := [
		{"name": "a", "defaults": ["key:-:65"]},
		{"name": "a", "defaults": []},
		{"name": "", "defaults": []},
		{"name": "b", "defaults": ["key:-:65"]},
		{"name": "c", "defaults": ["nope"]},
		{"name": "d", "defaults": ["key:-:1", "key:-:2", "key:-:3", "key:-:4", "key:-:5"]},
		{"name": "e", "defaults": "key:-:66"},
		"not a row",
	]
	var problems := KeybindActions.validate(rows)
	assert_eq(problems.size(), 7, "duplicate name, no name, shared default, bad token, over the cap, non-array, non-row: %s" % [problems])
	assert_eq(KeybindActions.validate(KeybindActions.DEFAULT_ACTIONS), [] as Array[String], "control: the default table is fine")


func test_configure_refuses_a_bad_table_and_keeps_the_old_one() -> void:
	var before := KeybindActions.names()
	var err := KeybindActions.configure([{"name": "x", "defaults": ["key:-:65"]}, {"name": "y", "defaults": ["key:-:65"]}])
	assert_eq(err, ERR_INVALID_DATA)
	assert_push_error_count(1, "one push_error per problem")
	assert_eq(KeybindActions.names(), before, "the table is unchanged")


func test_a_reserved_token_cannot_be_a_default() -> void:
	KeybindActions.reserved = ["key:CS:%d" % KEY_P]
	assert_eq(KeybindActions.validate([{"name": "x", "defaults": ["key:CS:%d" % KEY_P]}]).size(), 1)
	assert_eq(KeybindActions.validate([{"name": "x", "defaults": ["key:C:%d" % KEY_P]}]).size(), 0, "control: Ctrl+P is free")


func test_from_input_map_reads_the_projects_actions() -> void:
	InputMap.add_action("rk_test_fire")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F
	InputMap.action_add_event("rk_test_fire", k)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.ctrl_pressed = true
	InputMap.action_add_event("rk_test_fire", m)
	var pad := InputEventJoypadButton.new()
	pad.device = -1
	pad.button_index = JOY_BUTTON_X
	InputMap.action_add_event("rk_test_fire", pad)
	var still := InputEventJoypadMotion.new()
	still.axis = JOY_AXIS_RIGHT_Y
	still.axis_value = 0.0
	InputMap.action_add_event("rk_test_fire", still)
	var rows := KeybindActions.from_input_map(["rk_test_fire", "rk_test_missing"], "Combat")
	assert_eq(rows.size(), 1, "a name the map lacks is skipped")
	assert_eq(rows[0]["defaults"], ["key:-:%d" % KEY_F, "mouse:C:%d" % MOUSE_BUTTON_LEFT,
			"joy:-:%d" % JOY_BUTTON_X] as Array[String],
			"keys, mouse buttons and the gamepad button; not the stick with no direction")
	assert_eq(rows[0]["label"], "Rk test fire")
	assert_eq(rows[0]["group"], "Combat")
	assert_eq(KeybindActions.configure(rows), OK, "the rows configure as they are")
	InputMap.erase_action("rk_test_fire")


func test_label_from_name() -> void:
	assert_eq(KeybindActions.label_from_name("move_left"), "Move left")
	assert_eq(KeybindActions.label_from_name("open-map"), "Open map")
	assert_eq(KeybindActions.label_from_name("Jump"), "Jump")
