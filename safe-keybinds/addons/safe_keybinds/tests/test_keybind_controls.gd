extends GutTest
## KeybindControls: the ready-made screen, driven by synthetic events.

const PATH := "user://test_keybind_controls.cfg"

var _screen: KeybindControls


func before_each() -> void:
	KeybindActions.reserved = []
	KeybindActions.dev_keys = true
	KeybindActions.configure(KeybindActions.DEFAULT_ACTIONS)
	KeybindActions.install()
	_clear()
	_screen = KeybindControls.new()
	_screen.save_path = PATH
	add_child_autofree(_screen)


func after_each() -> void:
	# The screen rebuilds its rows with queue_free; let those frees land so
	# they are not counted as orphans.
	await wait_process_frames(1)
	_clear()
	KeybindActions.reserved = []
	KeybindActions.configure(KeybindActions.DEFAULT_ACTIONS)
	KeybindActions.install()


func _clear() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _key(code: Key, ctrl := false, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.ctrl_pressed = ctrl
	ev.pressed = pressed
	return ev


func _row(action: String) -> HBoxContainer:
	return _screen.find_child(action, true, false) as HBoxContainer


func _row_label(action: String) -> String:
	return (_row(action).get_child(0) as Label).text


func test_one_row_per_action_and_dev_rows_hidden() -> void:
	var shown := _screen.visible_actions()
	assert_eq(shown.size(), KeybindActions.names().size() - 1, "every row but the dev_only one")
	assert_false(shown.has("debug_overlay"))
	for action in shown:
		assert_not_null(_row(action), "a row for %s" % action)
	assert_eq(_screen.binding_buttons("move_up").size(), 3, "W, Up and the stick")
	assert_eq((_screen.binding_buttons("move_up")[0] as Button).text, "W")
	assert_eq((_screen.binding_buttons("move_up")[2] as Button).text, "Left Stick Up")


func test_show_dev_rows_lists_them() -> void:
	var s := KeybindControls.new()
	s.show_dev_rows = true
	s.save_path = ""
	add_child_autofree(s)
	assert_true(s.visible_actions().has("debug_overlay"))


func test_capture_rebinds_saves_and_updates_the_inputmap() -> void:
	watch_signals(_screen)
	_screen.begin_capture("jump", 0)
	assert_true(_screen.is_capturing())
	assert_eq((_screen.binding_buttons("jump")[0] as Button).text, KeybindControls.CAPTURE_TEXT)
	assert_true(_screen.capture_event(_key(KEY_J)))
	assert_false(_screen.is_capturing())
	assert_eq(_screen.bindings["jump"], ["key:-:%d" % KEY_J, "joy:-:%d" % JOY_BUTTON_A])
	assert_true(InputMap.action_has_event("jump", KeybindActions.decode("key:-:%d" % KEY_J)), "live at once")
	assert_eq(KeybindStore.load(PATH, false)["bindings"]["jump"], ["key:-:%d" % KEY_J, "joy:-:%d" % JOY_BUTTON_A],
			"and saved")
	assert_signal_emitted(_screen, "bindings_changed")
	assert_eq(_row_label("jump"), "Jump *", "a changed row is marked")


func test_capture_ignores_releases_and_lone_modifiers_then_takes_the_chord() -> void:
	_screen.begin_capture("quick_save", 0)
	assert_false(_screen.capture_event(_key(KEY_CTRL, true)), "Ctrl alone waits")
	assert_false(_screen.capture_event(_key(KEY_S, true, false)), "a release waits")
	assert_true(_screen.is_capturing())
	assert_true(_screen.capture_event(_key(KEY_S, true)))
	assert_eq(_screen.bindings["quick_save"], ["key:C:%d" % KEY_S])


func test_capture_of_a_taken_key_moves_it_and_says_so() -> void:
	_screen.begin_capture("jump", 0)
	_screen.capture_event(_key(KEY_E))
	assert_eq(_screen.bindings["jump"], ["key:-:%d" % KEY_E, "joy:-:%d" % JOY_BUTTON_A])
	assert_eq(_screen.bindings["interact"], ["joy:-:%d" % JOY_BUTTON_X], "interact lost E")
	assert_eq(_screen.status_text, "E moved from Interact to Jump.")
	assert_eq(_row_label("interact"), "Interact *")
	_screen.remove_binding("interact", 0)
	assert_eq(_row_label("interact"), "Interact (unbound)")


func test_esc_cancels_and_changes_nothing() -> void:
	var before: Dictionary = _screen.bindings.duplicate(true)
	_screen.begin_capture("jump", 0)
	assert_true(_screen.capture_event(_key(KEY_ESCAPE)))
	assert_false(_screen.is_capturing())
	assert_eq(_screen.bindings, before)
	assert_false(FileAccess.file_exists(PATH), "nothing saved")
	assert_eq((_screen.binding_buttons("jump")[0] as Button).text, "Space", "the button reads its key again")


func test_capture_through_input_marks_the_event_handled() -> void:
	_screen.begin_capture("crouch", 0)
	Input.parse_input_event(_key(KEY_X))
	Input.flush_buffered_events()
	assert_eq(_screen.bindings["crouch"], ["key:-:%d" % KEY_X, "joy:-:%d" % JOY_BUTTON_B], "the screen's _input took it")


func test_a_reserved_key_is_refused_with_a_notice() -> void:
	KeybindActions.reserved = ["key:-:%d" % KEY_F12]
	_screen.begin_capture("jump", 0)
	assert_true(_screen.capture_event(_key(KEY_F12)))
	assert_eq(_screen.bindings["jump"], KeybindActions.defaults_for("jump"), "unchanged")
	assert_eq(_screen.status_text, "F12 cannot be bound here.")


func test_add_button_appends_and_disappears_at_the_cap() -> void:
	assert_true(_screen.has_add_button("jump"))
	assert_false(_screen.has_add_button("zoom_in"), "zoom_in ships at the cap")
	_screen.begin_capture("jump", 2)
	_screen.capture_event(_key(KEY_J))
	assert_eq(_screen.bindings["jump"], ["key:-:%d" % KEY_SPACE, "joy:-:%d" % JOY_BUTTON_A, "key:-:%d" % KEY_J],
			"a third binding")
	assert_eq(_screen.binding_buttons("jump").size(), 3)


func test_remove_reset_and_reset_all() -> void:
	_screen.remove_binding("move_up", 0)
	assert_eq(_screen.bindings["move_up"], ["key:-:%d" % KEY_UP, "axis-:-:%d" % JOY_AXIS_LEFT_Y])
	assert_false((_row("move_up").get_child(_row("move_up").get_child_count() - 1) as Button).disabled,
			"Reset is live on a changed row")
	_screen.reset_action("move_up")
	assert_eq(_screen.bindings["move_up"], KeybindActions.defaults_for("move_up"))
	assert_true((_row("move_up").get_child(_row("move_up").get_child_count() - 1) as Button).disabled,
			"and off at the default")
	_screen.remove_binding("jump", 0)
	_screen.remove_binding("pause", 0)
	_screen.reset_all()
	assert_eq(_screen.bindings, KeybindStore.reset_all())
	assert_eq(_screen.status_text, "Every control is back to its default.")


func test_right_click_removes_a_binding() -> void:
	var button := _screen.binding_buttons("attack")[0] as Button
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	button.gui_input.emit(click)
	assert_eq(_screen.bindings["attack"], ["axis+:-:%d" % JOY_AXIS_TRIGGER_RIGHT])


func test_delete_or_the_pads_top_button_removes_a_binding() -> void:
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	(_screen.binding_buttons("crouch")[1] as Button).gui_input.emit(y)
	assert_eq(_screen.bindings["crouch"], ["key:-:%d" % KEY_C], "Y removed B")
	(_screen.binding_buttons("crouch")[0] as Button).gui_input.emit(_key(KEY_DELETE))
	assert_eq(_screen.bindings["crouch"], [], "Delete removed C")
	assert_false(KeybindControls.is_remove_event(_key(KEY_DELETE, false, false)), "control: a release is not")
	assert_false(KeybindControls.is_remove_event(_key(KEY_X)), "control: X is not")


func test_capture_takes_a_pad_button_or_a_pushed_stick() -> void:
	_screen.begin_capture("interact", 1)
	var b := InputEventJoypadButton.new()
	b.device = 3
	b.button_index = JOY_BUTTON_RIGHT_SHOULDER
	b.pressed = true
	assert_true(_screen.capture_event(b))
	assert_eq(_screen.bindings["interact"], ["key:-:%d" % KEY_E, "joy:-:%d" % JOY_BUTTON_RIGHT_SHOULDER])
	assert_eq((_screen.binding_buttons("interact")[1] as Button).text, "RB")
	_screen.begin_capture("crouch", 0)
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_RIGHT_Y
	m.axis_value = 0.2
	assert_false(_screen.capture_event(m), "a stick near rest waits")
	m.axis_value = 0.9
	assert_true(_screen.capture_event(m))
	assert_eq(_screen.bindings["crouch"], ["axis+:-:%d" % JOY_AXIS_RIGHT_Y, "joy:-:%d" % JOY_BUTTON_B])


func test_a_pad_button_moves_like_a_key() -> void:
	_screen.begin_capture("crouch", 1)
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	_screen.capture_event(a)
	assert_eq(_screen.bindings["crouch"], ["key:-:%d" % KEY_C, "joy:-:%d" % JOY_BUTTON_A])
	assert_eq(_screen.bindings["jump"], ["key:-:%d" % KEY_SPACE], "jump lost A")
	assert_eq(_screen.status_text, "A moved from Jump to Crouch.")


func test_focus_stays_on_the_binding_you_changed() -> void:
	assert_true(_screen.focus_first(), "a pad can start on the first binding")
	assert_eq(get_viewport().gui_get_focus_owner(), _screen.binding_buttons("move_up")[0])
	var jump_pad := _screen.binding_buttons("jump")[1] as Button
	jump_pad.grab_focus()
	_screen.begin_capture("jump", 1)
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	_screen.capture_event(rb)
	var focused := get_viewport().gui_get_focus_owner()
	assert_eq(focused, _screen.binding_buttons("jump")[1], "the rebuilt button has the focus")
	assert_eq((focused as Button).text, "RB")
	_screen.remove_binding("jump", 1)
	assert_true(_row("jump").is_ancestor_of(get_viewport().gui_get_focus_owner()),
			"after a remove the focus stays in the row")


func test_an_empty_save_path_writes_nothing() -> void:
	_screen.save_path = ""
	_screen.begin_capture("jump", 0)
	_screen.capture_event(_key(KEY_J))
	assert_true(InputMap.action_has_event("jump", KeybindActions.decode("key:-:%d" % KEY_J)), "live still")
	assert_false(FileAccess.file_exists(PATH), "no file")


func test_close_cancels_a_capture_and_emits_closed() -> void:
	watch_signals(_screen)
	_screen.begin_capture("jump", 0)
	(_screen.find_child("Close", true, false) as Button).pressed.emit()
	assert_false(_screen.is_capturing())
	assert_signal_emitted(_screen, "closed")


func test_refresh_reads_the_live_inputmap() -> void:
	var custom := KeybindStore.reset_all()
	custom["interact"] = ["key:-:%d" % KEY_G]
	KeybindStore.apply(custom)
	_screen.refresh()
	assert_eq(_screen.bindings["interact"], ["key:-:%d" % KEY_G])
	assert_eq((_screen.binding_buttons("interact")[0] as Button).text, "G")


func test_row_state_and_binding_text() -> void:
	var b := KeybindStore.reset_all()
	assert_eq(KeybindControls.row_state(b, "jump"), "")
	b["jump"] = []
	assert_eq(KeybindControls.row_state(b, "jump"), "unbound")
	b["jump"] = ["key:-:%d" % KEY_J]
	assert_eq(KeybindControls.row_state(b, "jump"), "changed")
	assert_eq(KeybindControls.binding_text("mouse:-:1"), "Left Mouse")
	assert_eq(KeybindControls.binding_text("key:C:%d" % KEY_S), "Ctrl+S")
	assert_eq(KeybindControls.binding_text("joy:-:%d" % JOY_BUTTON_START), "Start")
