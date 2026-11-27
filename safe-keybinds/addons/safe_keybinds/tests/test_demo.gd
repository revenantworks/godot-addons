extends GutTest
## The demo scene loads, installs the actions and opens its Controls screen.

const DEMO := "res://addons/safe_keybinds/demo/demo.tscn"


func after_each() -> void:
	await wait_process_frames(1)
	KeybindActions.keep_space_out_of_accept = false
	KeybindActions.configure(KeybindActions.DEFAULT_ACTIONS)
	InputMap.load_from_project_settings()
	KeybindActions.install()
	var p := "user://safe_keybinds_demo.cfg"
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


func test_the_demo_runs_and_pause_opens_the_controls() -> void:
	var demo: Node = (load(DEMO) as PackedScene).instantiate()
	add_child_autofree(demo)
	await wait_process_frames(2)
	assert_true(InputMap.has_action("move_up"), "the demo installs the actions")
	var controls := demo.find_child("Controls", true, false) as KeybindControls
	assert_not_null(controls)
	assert_false(controls.visible, "closed at start")
	var hint := demo.find_child("Hint", true, false) as Label
	assert_string_contains(hint.text, "W")
	assert_string_contains(demo.hint_text(1), "Move up: Left Stick Up")
	assert_string_contains(demo.hint_text(1), "Jump: A")
	assert_string_contains(demo.hint_text(0), "Jump: Space")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	demo._unhandled_input(esc)
	assert_true(controls.visible, "pause opens the Controls screen")
	controls.closed.emit()
	assert_false(controls.visible, "and Close shuts it")
