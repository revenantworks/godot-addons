extends GutTest
## ZoomBandController: writes band alphas to its targets and hides the faint.

var _root: Node2D
var _ctl: ZoomBandController
var _near: Node2D
var _mid: Node2D
var _far: Node2D


func before_each() -> void:
	_root = autofree(Node2D.new())
	_near = Node2D.new()
	_near.name = "Near"
	_mid = Node2D.new()
	_mid.name = "Mid"
	_far = Node2D.new()
	_far.name = "Far"
	_ctl = ZoomBandController.new()
	_ctl.name = "Bands"
	for n in [_near, _mid, _far, _ctl]:
		_root.add_child(n)
	_ctl.bands = [
		ZoomBand.make(^"../Near", 0.0, ZoomBands.Hold.ABOVE),
		ZoomBand.make(^"../Mid", -2.0),
		ZoomBand.make(^"../Far", -4.0, ZoomBands.Hold.BELOW),
	]


func test_apply_zoom_writes_modulate_alpha_and_visibility() -> void:
	_ctl.apply_zoom(-0.95)
	assert_almost_eq(_near.modulate.a, 0.5, 1e-6, "near half out below its centre")
	assert_almost_eq(_mid.modulate.a, 1.0 - 1.05 / 1.9, 1e-6)
	assert_eq(_far.modulate.a, 0.0)
	assert_true(_near.visible)
	assert_false(_far.visible, "at the floor the layer is hidden")
	assert_eq(_ctl.last_zoom(), -0.95)


func test_hold_bands_cover_both_ends_of_the_axis() -> void:
	_ctl.apply_zoom(10.0)
	assert_eq(_near.modulate.a, 1.0, "closest band holds above")
	_ctl.apply_zoom(-10.0)
	assert_eq(_far.modulate.a, 1.0, "farthest band holds below")
	assert_false(_near.visible)


func test_custom_alpha_property_and_no_hiding() -> void:
	_ctl.alpha_property = &"position:x"
	_ctl.hide_below_floor = false
	_ctl.apply_zoom(-4.0)
	assert_eq(_far.position.x, 1.0, "any property path takes the alpha")
	assert_eq(_near.position.x, 0.0)
	assert_true(_near.visible, "hiding is off")
	assert_eq(_near.modulate.a, 1.0, "modulate untouched")


func test_camera_drives_the_bands() -> void:
	var cam := Camera2D.new()
	_root.add_child(cam)
	_ctl.camera = cam
	cam.zoom = Vector2(0.25, 0.25)
	_ctl._process(0.0)
	assert_almost_eq(_ctl.last_zoom(), -2.0, 1e-9, "zoom 0.25 is z -2")
	assert_eq(_mid.modulate.a, 1.0)


func test_missing_targets_are_skipped() -> void:
	_ctl.bands.append(ZoomBand.make(^"../Nowhere", 1.0))
	_ctl.bands.append(null)
	_ctl.apply_zoom(0.0)
	assert_eq(_near.modulate.a, 1.0, "the rest still apply")


func test_width_floor_follows_the_closest_centres() -> void:
	assert_almost_eq(_ctl.width_floor(), 1.0 / 0.99, 1e-9, "centres 2.0 apart")
	_ctl.bands[1].center = -0.5
	assert_almost_eq(_ctl.width_floor(), 0.25 / 0.99, 1e-9, "the 0.5 gap now decides it")
	_ctl.bands = [_ctl.bands[0]]
	assert_eq(_ctl.width_floor(), 0.0, "one band has no gap")


func test_max_alpha_reports_a_dark_zoom_at_a_narrow_width() -> void:
	_ctl.band_width = 1.1
	assert_gt(_ctl.max_alpha(-1.0), _ctl.visible_floor)
	_ctl.band_width = 0.9
	assert_lt(_ctl.max_alpha(-1.0), _ctl.visible_floor, "control: too narrow goes dark")


func test_bands_applied_signal() -> void:
	watch_signals(_ctl)
	_ctl.apply_zoom(-1.5)
	assert_signal_emitted_with_parameters(_ctl, "bands_applied", [-1.5])


func test_an_unmoved_camera_does_no_work() -> void:
	var cam := Camera2D.new()
	_root.add_child(cam)
	_ctl.camera = cam
	cam.zoom = Vector2(0.25, 0.25)
	watch_signals(_ctl)
	_ctl._process(0.0)
	_ctl._process(0.0)
	_ctl._process(0.0)
	assert_signal_emit_count(_ctl, "bands_applied", 1, "two still frames skip")
	cam.zoom = Vector2(0.5, 0.5)
	_ctl._process(0.0)
	assert_signal_emit_count(_ctl, "bands_applied", 2, "a moved zoom applies")


func test_changes_re_apply_at_the_same_zoom() -> void:
	var cam := Camera2D.new()
	_root.add_child(cam)
	_ctl.camera = cam
	cam.zoom = Vector2(0.5, 0.5)
	_ctl._process(0.0)
	assert_almost_eq(_mid.modulate.a, 1.0 - 1.0 / 1.9, 1e-6)
	_ctl.band_width = 4.0
	_ctl._process(0.0)
	assert_almost_eq(_mid.modulate.a, 0.75, 1e-6, "a property change re-applies")
	_ctl.bands[1].center = -1.0
	_ctl._process(0.0)
	assert_eq(_mid.modulate.a, 1.0, "a band edited in place re-applies")
	_mid.modulate.a = 0.2
	_ctl._process(0.0)
	assert_almost_eq(_mid.modulate.a, 0.2, 1e-6, "control: an outside write is not undone on a still frame")
	_ctl.refresh()
	_ctl._process(0.0)
	assert_eq(_mid.modulate.a, 1.0, "refresh() forces the next frame")
	_ctl.bands.append(ZoomBand.make(^"../Far", -1.0))
	_ctl._process(0.0)
	assert_eq(_far.modulate.a, 1.0, "a band appended in place is picked up")


func test_smooth_falloff_reaches_the_targets() -> void:
	_ctl.falloff = ZoomBands.Falloff.SMOOTH
	_ctl.apply_zoom(-0.475)
	assert_almost_eq(_near.modulate.a, 0.84375, 1e-6, "smoothstep of the linear 0.75")
	assert_gt(_ctl.width_floor(), 1.0 / 0.99, "the floor follows the falloff")


func test_configuration_warnings_name_each_problem() -> void:
	add_child(_root)
	assert_eq(_ctl._get_configuration_warnings().size(), 0, "the default setup is sound")
	_ctl.band_width = 0.4
	_ctl.bands.append(null)
	_ctl.bands.append(ZoomBand.make(^"", 1.0))
	_ctl.bands.append(ZoomBand.make(^"../Nowhere", 2.0))
	var text := "\n".join(_ctl._get_configuration_warnings())
	assert_string_contains(text, "band_width 0.40 is too narrow")
	assert_string_contains(text, "bands[3] is empty")
	assert_string_contains(text, "bands[4] has no target")
	assert_string_contains(text, "bands[5] target \"../Nowhere\" is not in the scene")
	_ctl.bands = []
	assert_string_contains("\n".join(_ctl._get_configuration_warnings()), "Add at least one ZoomBand")


func test_editor_preview_never_reaches_the_saved_scene() -> void:
	add_child(_root)
	_ctl._in_editor = true
	_far.modulate.a = 0.7
	_ctl.preview_zoom = 0.0
	_ctl.editor_preview = true
	assert_eq(_near.modulate.a, 1.0, "the preview shows zoom 0")
	assert_false(_far.visible, "and hides what is faded out")
	_ctl.preview_zoom = -4.0
	assert_eq(_far.modulate.a, 1.0, "moving the preview zoom follows")
	_ctl.notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
	assert_almost_eq(_far.modulate.a, 0.7, 1e-6, "saved with its own alpha")
	assert_true(_far.visible, "and its own visibility")
	assert_eq(_near.modulate.a, 1.0)
	_ctl.notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
	assert_eq(_far.modulate.a, 1.0, "the preview comes back after the save")
	_ctl.editor_preview = false
	assert_almost_eq(_far.modulate.a, 0.7, 1e-6, "turning it off puts the targets back")
	assert_true(_near.visible)


func test_editor_preview_does_nothing_in_a_game() -> void:
	_ctl.editor_preview = true
	_ctl.preview_zoom = -4.0
	assert_eq(_far.modulate.a, 1.0, "untouched")
	assert_true(_near.visible, "untouched")
	assert_true(is_nan(_ctl.last_zoom()), "nothing applied")
