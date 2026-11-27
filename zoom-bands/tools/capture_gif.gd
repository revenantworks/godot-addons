extends SceneTree
## Renders the frames of the store GIF from the real demo scene (no mock-ups, PLAN rule 5):
## one zoom from the Far band in to the Near band and back out, so every crossfade shows.
## Needs a real renderer, so do not pass --headless.
##
## Run from the project folder:
##   godot --path . -s res://tools/capture_gif.gd
## Output: tools/out/gif/frame_000.png and on. tools/make_gif.py turns them into
## media/crossfade.gif.

const OUT_DIR := "res://tools/out/gif"
const DEMO := "res://addons/zoom_bands/demo/demo.tscn"
const SIZE := Vector2i(960, 540)
const Z_FAR := -4.5
const Z_NEAR := 1.5
const FRAMES_EACH_WAY := 30
const HOLD_FRAMES := 6


func _initialize() -> void:
	_run.call_deferred()


## The zoom exponent of frame i: hold far, ease in to near, hold, ease back out.
static func zoom_at(i: int) -> float:
	var leg := HOLD_FRAMES + FRAMES_EACH_WAY
	var j := i % (leg * 2)
	var going_in := j < leg
	var k := j % leg
	var t := 0.0 if k < HOLD_FRAMES else float(k - HOLD_FRAMES) / float(FRAMES_EACH_WAY - 1)
	t = smoothstep(0.0, 1.0, t)
	return lerpf(Z_FAR, Z_NEAR, t) if going_in else lerpf(Z_NEAR, Z_FAR, t)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var demo: Node2D = load(DEMO).instantiate()
	vp.add_child(demo)
	await process_frame
	var failed := 0
	var total := (HOLD_FRAMES + FRAMES_EACH_WAY) * 2
	for i in total:
		demo._set_zoom(zoom_at(i))
		for f in 2:
			await RenderingServer.frame_post_draw
		var path := "%s/frame_%03d.png" % [OUT_DIR, i]
		if vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) != OK:
			failed += 1
	print("gif frames %d to %s, %d failed" % [total, OUT_DIR, failed])
	quit(1 if failed else 0)
