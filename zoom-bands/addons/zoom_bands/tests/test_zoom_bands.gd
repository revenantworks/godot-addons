extends GutTest
## ZoomBands: the pure maths. Values here are the shipped 1.0.0 curve, so a
## change to them is a change of behaviour, not a refactor.


func test_alpha_is_full_at_the_centre_and_zero_at_band_width() -> void:
	assert_eq(ZoomBands.alpha(1.0, 1.0, 1.9), 1.0)
	assert_almost_eq(ZoomBands.alpha(0.95, 0.0, 1.9), 0.5, 1e-6, "half way out is half alpha")
	assert_almost_eq(ZoomBands.alpha(-0.95, 0.0, 1.9), 0.5, 1e-6, "symmetric below")
	assert_eq(ZoomBands.alpha(1.9, 0.0, 1.9), 0.0, "zero at band_width")
	assert_eq(ZoomBands.alpha(-9.0, 0.0, 1.9), 0.0, "clamped beyond")
	# Positive control: a near-miss value must not pass as today's.
	assert_true(absf(ZoomBands.alpha(0.95, 0.0, 1.9) - 0.4) > 1e-6, "control")


func test_hold_above_keeps_full_alpha_over_the_centre_only() -> void:
	assert_eq(ZoomBands.alpha_hold_above(4.0, 0.0, 1.9), 1.0, "held above")
	assert_almost_eq(ZoomBands.alpha_hold_above(-0.95, 0.0, 1.9), 0.5, 1e-6, "fades below")
	assert_eq(ZoomBands.alpha_hold_above(-5.0, 0.0, 1.9), 0.0)


func test_hold_below_keeps_full_alpha_under_the_centre_only() -> void:
	assert_eq(ZoomBands.alpha_hold_below(-4.0, 0.0, 1.9), 1.0, "held below")
	assert_almost_eq(ZoomBands.alpha_hold_below(0.95, 0.0, 1.9), 0.5, 1e-6, "fades above")
	assert_eq(ZoomBands.alpha_hold_below(5.0, 0.0, 1.9), 0.0)


func test_band_alpha_dispatches_on_hold() -> void:
	assert_eq(ZoomBands.band_alpha(3.0, 0.0, 1.9), 0.0, "NONE fades")
	assert_eq(ZoomBands.band_alpha(3.0, 0.0, 1.9, ZoomBands.Hold.ABOVE), 1.0)
	assert_eq(ZoomBands.band_alpha(-3.0, 0.0, 1.9, ZoomBands.Hold.BELOW), 1.0)
	assert_eq(ZoomBands.band_alpha(-3.0, 0.0, 1.9, ZoomBands.Hold.ABOVE), 0.0)


func test_zoom_exp_is_log2_of_the_zoom() -> void:
	assert_almost_eq(ZoomBands.zoom_exp(1.0), 0.0, 1e-9)
	assert_almost_eq(ZoomBands.zoom_exp(4.0), 2.0, 1e-9)
	assert_almost_eq(ZoomBands.zoom_exp(0.5), -1.0, 1e-9)


func test_min_width_matches_the_midpoint_arithmetic() -> void:
	# Centres 2.0 apart, floor 0.01: w > 1.0 / 0.99 = 1.0101...
	var w := ZoomBands.min_width(2.0, 0.01)
	assert_almost_eq(w, 1.0 / 0.99, 1e-9)
	# At exactly that width the midpoint sits on the floor.
	assert_almost_eq(ZoomBands.alpha(-1.0, 0.0, w), 0.01, 1e-9)


func test_step_width_clamps_only_in_the_direction_of_travel() -> void:
	assert_almost_eq(ZoomBands.step_width(1.9, -0.1, 1.1, 3.0), 1.8, 1e-9)
	assert_almost_eq(ZoomBands.step_width(1.15, -0.1, 1.1, 3.0), 1.1, 1e-9, "narrow stops at min")
	assert_almost_eq(ZoomBands.step_width(2.95, 0.1, 1.1, 3.0), 3.0, 1e-9, "widen stops at max")
	assert_almost_eq(ZoomBands.step_width(3.5, -0.1, 1.1, 3.0), 3.4, 1e-9, "outside the range walks back in")


func test_dimmest_finds_no_dark_zoom_at_a_safe_width() -> void:
	var bands := [[0.0, ZoomBands.Hold.ABOVE], [-2.0, ZoomBands.Hold.NONE], [-4.0, ZoomBands.Hold.BELOW]]
	var worst := ZoomBands.dimmest(bands, 1.1, -6.0, 3.0)
	assert_gt(worst.x, 0.01, "dimmest %s" % worst)


func test_dimmest_catches_a_width_below_the_floor() -> void:
	# Positive control for the test above: at 0.9 the midpoints go dark.
	var bands := [[0.0, ZoomBands.Hold.ABOVE], [-2.0, ZoomBands.Hold.NONE], [-4.0, ZoomBands.Hold.BELOW]]
	var worst := ZoomBands.dimmest(bands, 0.9, -6.0, 3.0)
	assert_lt(worst.x, 0.01, "dimmest %s" % worst)
	# At 0.9 the dark stretch runs from 0.9 to 1.1 off each centre, so the
	# first dark zoom the sweep meets is within 0.1 of a midpoint.
	assert_almost_eq(absf(fmod(worst.y, 2.0)), 1.0, 0.1 + 0.011, "the dark spot is by a midpoint between centres")
	assert_eq(ZoomBands.max_alpha(-1.0, bands, 0.9), 0.0, "the midpoint itself is dark")


func test_smooth_falloff_keeps_the_centre_edge_and_midpoint() -> void:
	var S := ZoomBands.Falloff.SMOOTH
	assert_eq(ZoomBands.band_alpha(0.0, 0.0, 1.9, ZoomBands.Hold.NONE, S), 1.0, "full at the centre")
	assert_eq(ZoomBands.band_alpha(1.9, 0.0, 1.9, ZoomBands.Hold.NONE, S), 0.0, "zero at band_width")
	assert_almost_eq(ZoomBands.band_alpha(0.95, 0.0, 1.9, ZoomBands.Hold.NONE, S), 0.5, 1e-6, "half at half way")
	# Eases: a quarter of the way out it is brighter than linear, three quarters out dimmer.
	var q := ZoomBands.band_alpha(0.475, 0.0, 1.9, ZoomBands.Hold.NONE, S)
	assert_almost_eq(q, 0.84375, 1e-6, "smoothstep(0.75)")
	assert_gt(q, ZoomBands.alpha(0.475, 0.0, 1.9), "control: not the linear value")
	assert_lt(ZoomBands.band_alpha(1.425, 0.0, 1.9, ZoomBands.Hold.NONE, S), ZoomBands.alpha(1.425, 0.0, 1.9))


func test_smooth_falloff_keeps_the_holds() -> void:
	var S := ZoomBands.Falloff.SMOOTH
	assert_eq(ZoomBands.band_alpha(5.0, 0.0, 1.9, ZoomBands.Hold.ABOVE, S), 1.0)
	assert_eq(ZoomBands.band_alpha(-5.0, 0.0, 1.9, ZoomBands.Hold.BELOW, S), 1.0)


func test_linear_is_the_default_and_unchanged() -> void:
	for z in [-2.0, -0.95, 0.3, 1.0]:
		assert_eq(ZoomBands.band_alpha(z, 0.0, 1.9), ZoomBands.alpha(z, 0.0, 1.9), "z %s" % z)
		assert_eq(ZoomBands.shape(0.3), 0.3)


func test_unshape_inverts_shape() -> void:
	for a in [0.0, 0.01, 0.2, 0.5, 0.8, 0.99, 1.0]:
		var back := ZoomBands.unshape(ZoomBands.shape(a, ZoomBands.Falloff.SMOOTH), ZoomBands.Falloff.SMOOTH)
		assert_almost_eq(back, a, 1e-6, "a %s" % a)
	assert_eq(ZoomBands.unshape(0.4), 0.4, "LINEAR is its own inverse")


func test_smooth_min_width_puts_the_midpoint_on_the_floor() -> void:
	var S := ZoomBands.Falloff.SMOOTH
	var w := ZoomBands.min_width(2.0, 0.01, S)
	assert_gt(w, ZoomBands.min_width(2.0, 0.01), "smooth needs a wider band than linear")
	assert_almost_eq(ZoomBands.band_alpha(-1.0, 0.0, w, ZoomBands.Hold.NONE, S), 0.01, 1e-6)


func test_smooth_dimmest_tracks_the_falloff() -> void:
	var bands := [[0.0, ZoomBands.Hold.ABOVE], [-2.0, ZoomBands.Hold.NONE]]
	var S := ZoomBands.Falloff.SMOOTH
	var w := ZoomBands.min_width(2.0, 0.01, S)
	assert_gt(ZoomBands.dimmest(bands, w + 0.05, -3.0, 1.0, 0.01, S).x, 0.01, "just above the floor stays lit")
	assert_lt(ZoomBands.dimmest(bands, w - 0.05, -3.0, 1.0, 0.01, S).x, 0.01, "control: just below goes dark")
