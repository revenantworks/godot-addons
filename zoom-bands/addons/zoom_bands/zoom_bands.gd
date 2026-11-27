@tool
class_name ZoomBands
extends RefCounted
## Zoom-band maths: which detail layer shows, and how strongly, at a zoom.
##
## A zoom band is a layer of detail that belongs to one stretch of the zoom
## axis. Each band has a centre on that axis; it is fully opaque there and
## fades out, reaching zero at band_width away from it. Neighbouring bands
## overlap, so zooming crossfades from one layer of detail into the next
## instead of popping.
##
## The zoom axis is the zoom exponent, z = log2(zoom): one step of z doubles
## the scale on screen. Working in z makes the bands evenly spaced to the eye.
##
## Everything here is static and pure (no nodes, no state), so it can be used
## on its own, from a shader-side script, or through ZoomBandController.

## How a band behaves beyond its centre.
## NONE fades out on both sides. ABOVE holds full alpha at every zoom above its
## centre (the closest band, so close-ups never go blank). BELOW holds full
## alpha at every zoom below its centre (the farthest band, so the widest view
## never goes blank).
enum Hold { NONE, ABOVE, BELOW }

## How alpha falls from a band's centre to its edge.
## LINEAR is a straight ramp. SMOOTH is smoothstep of that ramp: the same
## alpha at the centre, the edge and the half-way point, but a layer eases in
## and out instead of starting and stopping at a corner.
enum Falloff { LINEAR, SMOOTH }


## The zoom exponent of a linear zoom factor: log2(zoom). A Camera2D at
## zoom (4, 4) reads 2.0; at (0.5, 0.5) it reads -1.0.
static func zoom_exp(zoom: float) -> float:
	return log(zoom) / log(2.0)


## The band's alpha at zoom z: 1.0 at its centre, falling linearly to 0.0 at
## band_width either side, and 0.0 beyond.
static func alpha(z: float, center: float, band_width: float) -> float:
	return clampf(1.0 - absf(z - center) / band_width, 0.0, 1.0)


## alpha(), held at 1.0 for every zoom above the centre.
static func alpha_hold_above(z: float, center: float, band_width: float) -> float:
	return alpha(minf(z, center), center, band_width)


## alpha(), held at 1.0 for every zoom below the centre.
static func alpha_hold_below(z: float, center: float, band_width: float) -> float:
	return alpha(maxf(z, center), center, band_width)


## A linear alpha reshaped by `falloff`. LINEAR returns it unchanged.
static func shape(a: float, falloff: Falloff = Falloff.LINEAR) -> float:
	if falloff == Falloff.SMOOTH:
		return smoothstep(0.0, 1.0, a)
	return a


## The inverse of shape(): the linear alpha that `falloff` turns into `a`.
static func unshape(a: float, falloff: Falloff = Falloff.LINEAR) -> float:
	if falloff == Falloff.SMOOTH:
		# smoothstep on [0, 1] is 3a^2 - 2a^3; this is its closed-form inverse.
		return 0.5 - sin(asin(1.0 - 2.0 * clampf(a, 0.0, 1.0)) / 3.0)
	return a


## The alpha for a band with the given Hold mode and Falloff.
static func band_alpha(z: float, center: float, band_width: float, hold: Hold = Hold.NONE,
		falloff: Falloff = Falloff.LINEAR) -> float:
	var a: float
	match hold:
		Hold.ABOVE:
			a = alpha_hold_above(z, center, band_width)
		Hold.BELOW:
			a = alpha_hold_below(z, center, band_width)
		_:
			a = alpha(z, center, band_width)
	return shape(a, falloff)


## The band_width at which the dimmest zoom between two centres `spacing` apart
## sits exactly on `visible_floor`. Any band_width at or below this leaves a
## zoom where both neighbours are at or under the floor, so if layers hide at
## the floor nothing draws there. Use a width strictly above it.
##
## At the midpoint each neighbour is spacing / 2 away, so its linear alpha is
## 1 - (spacing / 2) / w. Keeping that above the floor gives
## w > (spacing / 2) / (1 - visible_floor). With SMOOTH, the floor is first
## turned back into the linear alpha that eases to it.
static func min_width(spacing: float, visible_floor: float, falloff: Falloff = Falloff.LINEAR) -> float:
	return (spacing / 2.0) / (1.0 - unshape(visible_floor, falloff))


## One step of a band_width adjustment. A negative step stops at min_w, a
## positive one at max_w; the other bound is left alone, so a width that
## starts outside the range walks back in one step at a time.
static func step_width(band_width: float, step: float, min_w: float, max_w: float) -> float:
	if step < 0.0:
		return maxf(min_w, band_width + step)
	return minf(max_w, band_width + step)


## The strongest alpha any band has at z. bands is an Array of
## [center: float, hold: Hold] pairs. "Is anything drawn at this zoom" is
## whether this stays above your visible floor.
static func max_alpha(z: float, bands: Array, band_width: float, falloff: Falloff = Falloff.LINEAR) -> float:
	var best := 0.0
	for b in bands:
		best = maxf(best, band_alpha(z, float(b[0]), band_width, b[1], falloff))
	return best


## Sweeps z from z_min to z_max in `step` and returns the dimmest point as
## Vector2(alpha, z). Use it in a test to prove a configuration never leaves a
## zoom with nothing drawn: assert the x stays above your visible floor.
static func dimmest(bands: Array, band_width: float, z_min: float, z_max: float, step: float = 0.01,
		falloff: Falloff = Falloff.LINEAR) -> Vector2:
	var worst := Vector2(INF, z_min)
	var z := z_min
	while z <= z_max + 1e-9:
		var a := max_alpha(z, bands, band_width, falloff)
		if a < worst.x:
			worst = Vector2(a, z)
		z += step
	return worst
