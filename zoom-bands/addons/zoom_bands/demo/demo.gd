extends Node2D
## Zoom Bands demo: three detail layers on one zoom axis.
##
## Mouse wheel or +/- zooms, arrow keys pan, S switches between the linear and
## smooth falloff. Far shows big regions, Mid a grid of plots, Near individual
## dots. Watch them crossfade as you zoom; the label shows the zoom exponent and
## each layer's alpha.

const ZOOM_MIN := -5.0
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.25
const PAN_SPEED := 600.0

var camera: Camera2D
var controller: ZoomBandController
var label: Label
var _z := -2.0


class Layer:
	extends Node2D
	## One demo layer: a pattern whose detail suits its band, tiled far past
	## the view at every zoom the demo allows. It draws one texture of a single
	## 4 x 4 cell period, repeated, so the whole layer is one draw call. The
	## half-width is 2048 cells: wide enough to fill the view, small enough to
	## keep the repeated texture coordinates precise.
	const PERIOD := 4
	const TEXELS := 32  # texels per cell in the period texture
	var cell := 64.0
	var color := Color.WHITE
	var dot := false
	var _tex: ImageTexture

	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if dot else CanvasItem.TEXTURE_FILTER_NEAREST
		_tex = ImageTexture.create_from_image(_period_image())

	func _period_image() -> Image:
		var side := PERIOD * TEXELS
		var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for ix in PERIOD:
			for iy in PERIOD:
				var tint := color.darkened(0.15 * float((ix + iy) & 3))
				var o := Vector2(ix, iy) * TEXELS
				for px in TEXELS:
					for py in TEXELS:
						var p := Vector2(px, py) + Vector2(0.5, 0.5)
						if dot:
							if p.distance_to(Vector2.ONE * TEXELS * 0.5) <= TEXELS * 0.2:
								img.set_pixel(int(o.x) + px, int(o.y) + py, tint)
						elif p.x >= TEXELS * 0.04 and p.y >= TEXELS * 0.04 \
								and p.x <= TEXELS * 0.96 and p.y <= TEXELS * 0.96:
							img.set_pixel(int(o.x) + px, int(o.y) + py, tint)
		return img

	func _draw() -> void:
		var s := cell / TEXELS
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		var half := cell * 2048.0 / s
		draw_texture_rect(_tex, Rect2(-half, -half, half * 2.0, half * 2.0), true)


func _ready() -> void:
	var far := _layer("Far", 512.0, Color(0.25, 0.45, 0.3), false)
	var mid := _layer("Mid", 64.0, Color(0.55, 0.5, 0.35), false)
	var near := _layer("Near", 8.0, Color(0.9, 0.85, 0.7), true)
	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	controller = ZoomBandController.new()
	controller.name = "Bands"
	controller.camera = camera
	controller.bands = [
		ZoomBand.make(^"../Near", 0.0, ZoomBands.Hold.ABOVE),
		ZoomBand.make(^"../Mid", -2.0),
		ZoomBand.make(^"../Far", -4.0, ZoomBands.Hold.BELOW),
	]
	add_child(controller)
	var hud := CanvasLayer.new()
	add_child(hud)
	label = Label.new()
	label.position = Vector2(12, 12)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_child(label)
	for l in [far, mid, near]:
		l.queue_redraw()
	_set_zoom(_z)


func _layer(n: String, cell: float, color: Color, dot: bool) -> Layer:
	var l := Layer.new()
	l.name = n
	l.cell = cell
	l.color = color
	l.dot = dot
	add_child(l)
	return l


func _set_zoom(z: float) -> void:
	_z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	var f := pow(2.0, _z)
	camera.zoom = Vector2(f, f)


func _process(delta: float) -> void:
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	camera.position += pan * PAN_SPEED * delta / camera.zoom.x
	var parts := ["z %.2f" % _z]
	for b in controller.bands:
		parts.append("%s %.2f" % [String(b.target).get_file(), controller.alpha_for(b, _z)])
	var curve := "smooth" if controller.falloff == ZoomBands.Falloff.SMOOTH else "linear"
	label.text = "  ".join(parts) + "  (%s)\nwheel or +/- to zoom, arrows to pan, S for the falloff" % curve


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_z + ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_z - ZOOM_STEP)
	elif event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_EQUAL or k.keycode == KEY_KP_ADD:
			_set_zoom(_z + ZOOM_STEP)
		elif k.keycode == KEY_MINUS or k.keycode == KEY_KP_SUBTRACT:
			_set_zoom(_z - ZOOM_STEP)
		elif k.keycode == KEY_S and not k.echo:
			toggle_falloff()


## Switches the controller between the linear and the smooth falloff.
func toggle_falloff() -> void:
	var smooth := controller.falloff == ZoomBands.Falloff.SMOOTH
	controller.falloff = ZoomBands.Falloff.LINEAR if smooth else ZoomBands.Falloff.SMOOTH
