extends GutTest
## The demo scene loads, builds its layers and lets the camera drive them.


func test_demo_builds_and_crossfades() -> void:
	var demo: Node2D = load("res://addons/zoom_bands/demo/demo.tscn").instantiate()
	add_child_autofree(demo)
	for n in ["Far", "Mid", "Near", "Camera", "Bands"]:
		assert_not_null(demo.get_node_or_null(n), n)
	demo._set_zoom(-2.0)
	demo.controller._process(0.0)
	assert_eq(demo.get_node("Mid").modulate.a, 1.0, "the start zoom is Mid's centre")
	assert_false(demo.get_node("Near").visible, "Near is past its reach")
	demo._set_zoom(9.0)
	demo.controller._process(0.0)
	assert_almost_eq(demo.controller.last_zoom(), demo.ZOOM_MAX, 1e-6, "zoom clamps at ZOOM_MAX")
	assert_eq(demo.get_node("Near").modulate.a, 1.0)


func test_demo_switches_the_falloff() -> void:
	var demo: Node2D = load("res://addons/zoom_bands/demo/demo.tscn").instantiate()
	add_child_autofree(demo)
	demo._set_zoom(-1.525)
	demo.controller._process(0.0)
	var linear: float = demo.get_node("Mid").modulate.a
	demo.toggle_falloff()
	assert_eq(demo.controller.falloff, ZoomBands.Falloff.SMOOTH)
	demo.controller._process(0.0)
	assert_gt(demo.get_node("Mid").modulate.a, linear, "the same zoom eases brighter near the centre")
	demo._process(0.0)
	assert_string_contains(demo.label.text, "(smooth)")
	demo.toggle_falloff()
	assert_eq(demo.controller.falloff, ZoomBands.Falloff.LINEAR, "and back")
