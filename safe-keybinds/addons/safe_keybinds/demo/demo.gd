extends Node2D
## Safe Keybinds demo. Move the square with the move keys or the left stick,
## jump, interact, zoom, and press the pause key (Esc or Start by default) to
## open the Controls screen and rebind any of them, from the keyboard, the
## mouse or a gamepad. The bindings are saved to SAVE_PATH, so they come back
## the next time the demo runs.

const SAVE_PATH := "user://safe_keybinds_demo.cfg"
const SPEED := 260.0
const ZOOM_STEP := 1.1

var player: ColorRect
var camera: Camera2D
var hint: Label
var controls: KeybindControls
var _hop := 0.0


func _ready() -> void:
	# Space is the jump key here, so a focused button must not take it as a press.
	KeybindActions.keep_space_out_of_accept = true
	KeybindActions.install()
	var loaded := KeybindStore.load(SAVE_PATH)
	KeybindStore.apply(loaded["bindings"])

	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)

	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.color = Color(0.16, 0.18, 0.22)
	floor_rect.position = Vector2(-600, -400)
	floor_rect.size = Vector2(1200, 800)
	add_child(floor_rect)

	player = ColorRect.new()
	player.name = "Player"
	player.color = Color(0.35, 0.65, 0.95)
	player.size = Vector2(40, 40)
	player.position = Vector2(-20, -20)
	add_child(player)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	hint = Label.new()
	hint.name = "Hint"
	hint.position = Vector2(16, 12)
	ui.add_child(hint)

	controls = KeybindControls.new()
	controls.name = "Controls"
	controls.save_path = SAVE_PATH
	controls.visible = false
	controls.position = Vector2(40, 60)
	controls.closed.connect(_close_controls)
	controls.bindings_changed.connect(func(_b: Dictionary) -> void: _update_hint())
	ui.add_child(controls)
	if not loaded["warnings"].is_empty():
		controls.status_text = loaded["warnings"][0]
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_use_pad_names()
	_update_hint()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_use_pad_names()
	controls.refresh()
	_update_hint()


## Names pad buttons after the first connected pad (Cross on a PlayStation pad).
func _use_pad_names() -> void:
	var pads := Input.get_connected_joypads()
	KeybindActions.pad_style = KeybindActions.guess_pad_style(pads[0]) if not pads.is_empty() \
			else KeybindActions.PadStyle.XBOX


func _process(delta: float) -> void:
	if controls.visible:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.position += dir * SPEED * delta
	if _hop > 0.0:
		_hop = maxf(0.0, _hop - delta)
	player.scale = Vector2.ONE * (1.0 + 0.4 * sin(_hop / 0.3 * PI))
	if Input.is_action_pressed("zoom_in"):
		_zoom_by(1.0 + delta)
	if Input.is_action_pressed("zoom_out"):
		_zoom_by(1.0 / (1.0 + delta))


func _unhandled_input(event: InputEvent) -> void:
	if controls.is_capturing():
		return
	if event.is_action_pressed("pause", false, true):
		if controls.visible:
			_close_controls()
		else:
			controls.refresh()
			controls.visible = true
		get_viewport().set_input_as_handled()
		return
	if controls.visible:
		return
	if event.is_action_pressed("jump"):
		_hop = 0.3
	elif event.is_action_pressed("interact"):
		player.color = Color.from_hsv(randf(), 0.55, 0.95)
	elif event.is_action_pressed("zoom_in") and _is_wheel(event):
		_zoom_by(ZOOM_STEP)
	elif event.is_action_pressed("zoom_out") and _is_wheel(event):
		_zoom_by(1.0 / ZOOM_STEP)


func _close_controls() -> void:
	controls.cancel_capture()
	controls.visible = false
	_update_hint()


func _zoom_by(f: float) -> void:
	var z := clampf(camera.zoom.x * f, 0.25, 4.0)
	camera.zoom = Vector2(z, z)


func _is_wheel(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).button_index in [
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]


## The controls the player has now, read from the live InputMap: the first
## gamepad binding of each action when `pad` is 1, the first key or mouse
## binding when it is 0, and when it is -1 (the default) the pad's when a pad
## is connected.
func hint_text(pad_mode: int = -1) -> String:
	var pad := pad_mode == 1 or (pad_mode == -1 and not Input.get_connected_joypads().is_empty())
	var b := KeybindStore.from_input_map()
	var parts: Array[String] = []
	for action in ["move_up", "move_left", "move_down", "move_right", "jump", "interact", "pause"]:
		var first := "unbound"
		for token in b.get(action, []):
			if KeybindActions.is_pad_token(token) == pad:
				first = KeybindActions.label(token)
				break
		parts.append("%s: %s" % [KeybindActions.row_of(action).get("label", action), first])
	return "  ".join(parts)


func _update_hint() -> void:
	hint.text = hint_text()
