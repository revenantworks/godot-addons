extends SceneTree
## Takes the store screenshots from the real demo scene (no mock-ups, PLAN rule 5).
## Needs a real renderer, so do not pass --headless.
##
## Run from the project folder:
##   godot --path . -s res://tools/capture_screenshots.gd
## Output: tools/out/*.png. Each shot renders in its own SubViewport at a fixed size (the
## demo laid out at 1280 x 720 and drawn at the shot's size), so the result does not depend on
## the window or the screen. release.ps1 -Screenshots copies them into media/.
##
## The shots start from the default bindings and never write the demo's bindings file, so a
## player's saved demo bindings are neither shown nor changed.

const OUT_DIR := "res://tools/out"
const DEMO := "res://addons/safe_keybinds/demo/demo.tscn"
const LAYOUT := Vector2i(1280, 720)
const PANEL_SIZE := Vector2(720, 620)
const SHOTS := [
	{"name": "01-controls", "step": "open", "size": Vector2i(2560, 1440)},
	{"name": "02-moved", "step": "moved", "size": Vector2i(2560, 1440)},
	{"name": "03-capturing", "step": "capturing", "size": Vector2i(2560, 1440)},
	{"name": "04-play", "step": "play", "size": Vector2i(2560, 1440)},
	{"name": "thumbnail", "step": "moved", "size": Vector2i(1280, 720)},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for shot: Dictionary in SHOTS:
		var vp := SubViewport.new()
		vp.size = shot.size
		vp.size_2d_override = LAYOUT
		vp.size_2d_override_stretch = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var demo: Node2D = load(DEMO).instantiate()
		vp.add_child(demo)
		await process_frame
		_stage(demo, shot.step)
		await process_frame
		# The rows grow the panel while they fill; fix its size once they are in.
		demo.controls.size = PANEL_SIZE
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := "%s/%s.png" % [OUT_DIR, shot.name]
		var err := img.save_png(ProjectSettings.globalize_path(path))
		print("shot %s %s err=%d" % [path, img.get_size(), err])
		if err != OK:
			failed += 1
		vp.queue_free()
		await process_frame
	quit(1 if failed else 0)


## Sets the demo up for one shot, through the same calls a click or key press makes.
func _stage(demo: Node2D, step: String) -> void:
	var c: KeybindControls = demo.controls
	c.save_path = ""  # never write the demo's bindings file
	c.reset_all()
	c.status_text = ""
	c.position = Vector2(40, 52)
	if step == "play":
		demo.player.position = Vector2(140, -60)
		demo.player.color = Color(0.95, 0.6, 0.35)
		demo._update_hint()
		return
	c.refresh()
	c.visible = true
	c._set_status("")
	if step == "open":
		return
	# Bind E (Interact's key) to Jump: E moves from Interact to Jump.
	c.begin_capture("jump", 0)
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.physical_keycode = KEY_E
	e.pressed = true
	c.capture_event(e)
	if step == "capturing":
		c.begin_capture("interact", 0)
