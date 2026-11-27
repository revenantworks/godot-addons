class_name KeybindControls
extends PanelContainer
## A small, ready-made Controls screen: one row per action, a button per
## binding, a "+" to add one, and Reset buttons. It builds itself in code, so
## add it like any Control:
##
##     var controls := KeybindControls.new()
##     add_child(controls)
##
## Click a binding, then press the new key, mouse button, gamepad button,
## stick or trigger (Esc cancels). Right-click a binding, or focus it and
## press Delete or the pad's top face button (Y, Triangle), to remove it.
## Every change goes into the live InputMap at once and, unless save_path is
## "", into the bindings file.
##
## A gamepad alone can drive it: when the screen is shown and a pad is
## connected, the first binding takes the focus, and focus stays on the
## binding you changed.
##
## The pure helpers (row_state, binding_text) are static, so a screen of your
## own can reuse them.

signal bindings_changed(bindings: Dictionary)
signal closed

## Where changes are saved. "" saves nothing (the InputMap still changes).
@export var save_path: String = KeybindStore.DEFAULT_PATH
## Show the rows marked dev_only.
@export var show_dev_rows: bool = false
## The heading at the top of the screen.
@export var title: String = "Controls"

const CAPTURE_TEXT := "Press a key or button..."
const ADD_TEXT := "+"

## The bindings the screen shows and edits.
var bindings: Dictionary = {}
## The last notice shown to the player ("" for none).
var status_text: String = ""

var _capture_action := ""
var _capture_slot := -1
var _rows: VBoxContainer
var _status: Label
var _buttons := {}  # action -> Array of its binding Buttons (the "+" last, if shown)


func _ready() -> void:
	if bindings.is_empty():
		bindings = KeybindStore.from_input_map()
	_build()
	if is_visible_in_tree() and not Input.get_connected_joypads().is_empty():
		focus_first.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _rows != null and is_visible_in_tree() \
			and not Input.get_connected_joypads().is_empty():
		focus_first.call_deferred()


## Gives the focus to the first binding button, so a gamepad or the keyboard
## can move through the screen. Shown with a pad connected, the screen does
## this by itself. Returns false when there is no button to focus.
func focus_first() -> bool:
	if not is_inside_tree():
		return false
	for action in visible_actions():
		var buttons: Array = _buttons.get(action, [])
		if not buttons.is_empty():
			(buttons[0] as Button).grab_focus()
			return true
	return false


## Re-reads the live InputMap and redraws every row.
func refresh() -> void:
	bindings = KeybindStore.from_input_map()
	cancel_capture()
	_fill_rows()


## The actions this screen lists, in table order.
func visible_actions() -> Array[String]:
	var out: Array[String] = []
	for row in KeybindActions.actions:
		if bool(row.get("dev_only", false)) and not show_dev_rows:
			continue
		out.append(row["name"])
	return out


## Whether the screen is waiting for a key or button.
func is_capturing() -> bool:
	return _capture_action != ""


## Starts waiting for the key or button that goes into `action`'s `slot`. A
## slot at the end of the action's list adds a binding.
func begin_capture(action: String, slot: int) -> void:
	cancel_capture()
	_capture_action = action
	_capture_slot = slot
	var buttons: Array = _buttons.get(action, [])
	if slot < buttons.size():
		(buttons[slot] as Button).text = CAPTURE_TEXT
	_set_status("Press the new key or button for %s, or Esc to cancel." % _label_of(action))


## Stops waiting, changing nothing.
func cancel_capture() -> void:
	if _capture_action == "":
		return
	_capture_action = ""
	_capture_slot = -1
	_fill_rows()


## Feeds one event to a running capture. Returns true when the event was
## used (bound, or Esc to cancel). Lone modifiers and releases are ignored, so
## a chord like Ctrl+S is captured when the S goes down; a stick or trigger
## is captured once it is past KeybindActions.AXIS_THRESHOLD.
func capture_event(event: InputEvent) -> bool:
	if _capture_action == "":
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if KeybindActions.is_cancel_key(event):
		cancel_capture()
		_set_status("")
		return true
	if KeybindActions.is_modifier_key(event):
		return false
	var token := KeybindActions.encode(event)
	if token == "":
		return false
	var action := _capture_action
	var result := KeybindStore.rebind(bindings, action, _capture_slot, token)
	_capture_action = ""
	_capture_slot = -1
	if not bool(result["ok"]):
		_fill_rows()
		_set_status("%s cannot be bound here." % KeybindActions.label(token))
		return true
	var displaced: String = result["displaced"]
	_commit(result["bindings"])
	if displaced != "":
		_set_status("%s moved from %s to %s." % [KeybindActions.label(token), _label_of(displaced), _label_of(action)])
	else:
		_set_status("")
	return true


## Removes the binding in `action`'s `slot`.
func remove_binding(action: String, slot: int) -> void:
	cancel_capture()
	_commit(KeybindStore.remove_slot(bindings, action, slot))
	_set_status("")


## Puts one action back to its defaults.
func reset_action(action: String) -> void:
	cancel_capture()
	_commit(KeybindStore.reset_action(bindings, action))
	_set_status("%s is back to its default." % _label_of(action))


## Puts every action back to its defaults.
func reset_all() -> void:
	cancel_capture()
	_commit(KeybindStore.reset_all())
	_set_status("Every control is back to its default.")


## The binding Buttons of one row (not the "+"), for tests and custom styling.
func binding_buttons(action: String) -> Array:
	var out: Array = []
	for b in _buttons.get(action, []):
		if (b as Button).get_meta("slot", -1) < (bindings.get(action, []) as Array).size():
			out.append(b)
	return out


## Whether the row shows a "+" (it is under MAX_BINDINGS).
func has_add_button(action: String) -> bool:
	for b in _buttons.get(action, []):
		if (b as Button).text == ADD_TEXT:
			return true
	return false


## "" when `action` holds exactly its defaults, "unbound" when it holds
## nothing, "changed" otherwise.
static func row_state(current: Dictionary, action: String) -> String:
	var tokens: Array = current.get(action, [])
	if tokens.is_empty():
		return "unbound"
	if tokens == KeybindActions.defaults_for(action):
		return ""
	return "changed"


## The text of one binding button.
static func binding_text(token: String) -> String:
	var t := KeybindActions.label(token)
	return t if t != "" else token


func _input(event: InputEvent) -> void:
	if _capture_action == "":
		return
	if capture_event(event):
		get_viewport().set_input_as_handled()


func _commit(new_bindings: Dictionary) -> void:
	bindings = new_bindings
	KeybindStore.apply(bindings)
	if save_path != "":
		var err := KeybindStore.save(bindings, {}, save_path)
		if err != OK:
			push_warning("KeybindControls: could not save %s (%s)" % [save_path, error_string(err)])
	_fill_rows()
	bindings_changed.emit(bindings)


func _set_status(text: String) -> void:
	status_text = text
	if _status != null:
		_status.text = text


func _label_of(action: String) -> String:
	var row := KeybindActions.row_of(action)
	return String(row.get("label", action)) if not row.is_empty() else action


func _build() -> void:
	custom_minimum_size = Vector2(560, 360)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 22)
	outer.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = status_text
	outer.add_child(_status)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(bar)
	var reset := Button.new()
	reset.name = "ResetAll"
	reset.text = "Reset all"
	reset.pressed.connect(reset_all)
	bar.add_child(reset)
	var close := Button.new()
	close.name = "Close"
	close.text = "Close"
	close.pressed.connect(func() -> void:
		cancel_capture()
		closed.emit())
	bar.add_child(close)

	_fill_rows()


func _fill_rows() -> void:
	if _rows == null:
		return
	var refocus := _focused_id()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var last_group := ""
	var first := true
	for action in visible_actions():
		var row := KeybindActions.row_of(action)
		var group := String(row.get("group", ""))
		if first or group != last_group:
			first = false
			last_group = group
			if group != "":
				var gl := Label.new()
				gl.text = group
				gl.add_theme_font_size_override("font_size", 17)
				_rows.add_child(gl)
		_rows.add_child(_make_row(action, row))
	if refocus != "":
		_focus_id(refocus)


## The focus id ("<action>/<slot>" or "<action>/reset") of the row button
## that holds the focus, or "".
func _focused_id() -> String:
	if not is_inside_tree():
		return ""
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not _rows.is_ancestor_of(f) or not f.has_meta("focus_id"):
		return ""
	return String(f.get_meta("focus_id"))


## Focuses the rebuilt button with `id`; if that slot is gone, the row's
## first button.
func _focus_id(id: String) -> void:
	var action := id.get_slice("/", 0)
	var row := _row_line(action)
	if row == null:
		return
	var first: Button = null
	for c in row.get_children():
		if c is Button and (c as Button).focus_mode != Control.FOCUS_NONE:
			if first == null:
				first = c
			if String(c.get_meta("focus_id", "")) == id:
				(c as Button).grab_focus()
				return
	if first != null:
		first.grab_focus()


func _row_line(action: String) -> HBoxContainer:
	for c in _rows.get_children():
		if c is HBoxContainer and c.name == action:
			return c
	return null


func _make_row(action: String, row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = action
	var name_label := Label.new()
	name_label.text = String(row.get("label", action))
	match row_state(bindings, action):
		"changed":
			name_label.text += " *"
		"unbound":
			name_label.text += " (unbound)"
	name_label.custom_minimum_size.x = 180
	line.add_child(name_label)

	var tokens: Array = bindings.get(action, [])
	var buttons: Array = []
	for slot in tokens.size():
		var b := Button.new()
		b.text = binding_text(tokens[slot])
		b.tooltip_text = "Click to change, right-click or Delete to remove"
		b.set_meta("slot", slot)
		b.set_meta("focus_id", "%s/%d" % [action, slot])
		b.pressed.connect(begin_capture.bind(action, slot))
		b.gui_input.connect(_on_binding_gui_input.bind(action, slot))
		line.add_child(b)
		buttons.append(b)
	if tokens.size() < KeybindActions.MAX_BINDINGS:
		var add := Button.new()
		add.text = ADD_TEXT
		add.tooltip_text = "Add a binding"
		add.set_meta("slot", tokens.size())
		add.set_meta("focus_id", "%s/%d" % [action, tokens.size()])
		add.pressed.connect(begin_capture.bind(action, tokens.size()))
		line.add_child(add)
		buttons.append(add)
	_buttons[action] = buttons

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	var reset := Button.new()
	reset.text = "Reset"
	reset.disabled = row_state(bindings, action) == ""
	reset.set_meta("focus_id", "%s/reset" % action)
	reset.pressed.connect(reset_action.bind(action))
	line.add_child(reset)
	return line


func _on_binding_gui_input(event: InputEvent, action: String, slot: int) -> void:
	if _capture_action != "":
		return
	if is_remove_event(event):
		remove_binding(action, slot)
		get_viewport().set_input_as_handled()


## Whether `event` asks to remove the binding it lands on: a right-click, a
## Delete or Backspace press, or the pad's top face button (Y, Triangle).
static func is_remove_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	if event is InputEventKey:
		var k := event as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return code == KEY_DELETE or code == KEY_BACKSPACE
	return false

