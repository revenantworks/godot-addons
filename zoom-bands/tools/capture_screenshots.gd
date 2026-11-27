extends SceneTree
## Takes the store screenshots from the real demo scene (no mock-ups, PLAN rule 5).
## Needs a real renderer, so do not pass --headless.
##
## Run from the project folder:
##   godot --path . -s res://tools/capture_screenshots.gd
## Output: tools/out/*.png. Each shot renders in its own SubViewport at a fixed size, so the
## result does not depend on the window or the screen. release.ps1 -Screenshots copies them
## into media/. 04-inspector keeps its old file name from an earlier plan for an inspector
## shot; it is the running demo with Mid fading into Near (zoom exponent -1).

const OUT_DIR := "res://tools/out"
const DEMO := "res://addons/zoom_bands/demo/demo.tscn"
const SHOTS := [
	{"name": "01-far", "z": -4.5, "size": Vector2i(2560, 1440)},
	{"name": "02-crossfade", "z": -3.0, "size": Vector2i(2560, 1440)},
	{"name": "03-near", "z": 2.0, "size": Vector2i(2560, 1440)},
	{"name": "04-inspector", "z": -1.0, "size": Vector2i(2560, 1440)},
	{"name": "thumbnail", "z": -3.0, "size": Vector2i(1280, 720)},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for shot: Dictionary in SHOTS:
		var vp := SubViewport.new()
		vp.size = shot.size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var demo: Node2D = load(DEMO).instantiate()
		vp.add_child(demo)
		await process_frame
		demo._set_zoom(shot.z)
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
