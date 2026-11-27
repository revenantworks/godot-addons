# Zoom Bands

Crossfade detail layers by camera zoom in Godot 4. One continuous zoom axis,
evenly spaced bands, no popping between levels of detail.

- Godot 4.3 or later, GDScript only. Tested on 4.3, 4.4, 4.5, 4.6 and 4.7.
- Works with any renderer, including GL Compatibility.
- Apache License 2.0. See `LICENSE` and `NOTICE`.

## How it works

The zoom axis is the zoom exponent, `z = log2(camera.zoom.x)`. One step of `z`
doubles the scale on screen, so bands spaced evenly in `z` feel evenly spaced
to the eye.

Each band has a centre on that axis. Its alpha is 1.0 at the centre and falls
to 0.0 at `band_width` either side. Neighbouring bands overlap, so a zoom
crossfades one layer into the next. The nearest band can hold full alpha
above its centre (`Hold.ABOVE`) and the farthest below its centre
(`Hold.BELOW`), so neither end of the zoom range goes blank.

The fall is linear by default. Set `falloff` to `SMOOTH` and it eases in and
out (smoothstep): the same alpha at the centre, the edge and half way, with no
corner where a fade starts or stops.

A layer at or under `visible_floor` (default 0.01) is hidden, so faded-out
layers cost nothing to draw. A frame where the camera's zoom has not moved
does no work at all.

## Install

Copy `addons/zoom_bands/` into your project's `addons/` folder, or install it
from the Godot Asset Store. The classes register through `class_name`;
enabling the plugin in Project Settings is optional.

## Minimal use

```gdscript
extends Node2D

func _ready() -> void:
	var bands := ZoomBandController.new()
	bands.camera = $Camera2D
	bands.bands = [
		ZoomBand.make(^"../Near", 0.0, ZoomBands.Hold.ABOVE),  # zoom 1x and closer
		ZoomBand.make(^"../Mid", -2.0),                         # around 0.25x
		ZoomBand.make(^"../Far", -4.0, ZoomBands.Hold.BELOW),  # 0.0625x and wider
	]
	add_child(bands)
```

`Near`, `Mid` and `Far` are any `CanvasItem` nodes (a TileMapLayer, a
Node2D that draws, a Sprite2D). The controller writes each one's
`modulate.a` whenever the zoom moves. Set `alpha_property` to a property path
such as `"band_alpha"` if your layer script wants to fade itself.

No camera? Call `apply_zoom(z)` yourself. It always applies, even at the zoom
it applied last.

Changed something the controller cannot see, such as a target node you
swapped out from under a band? Call `refresh()` and the next frame re-applies.
Changes to the controller's own properties, or to any `ZoomBand` in `bands`,
do this for you.

## Set it up in the editor

Add a `ZoomBandController` node, assign the camera, and add `ZoomBand`
resources to `bands`.

- **Preview:** under Editor preview, turn on `editor_preview` and drag
  `preview_zoom` to see the crossfade at any zoom without running the game.
  The preview puts every target back as it was before the scene is saved and
  when you turn it off, so it never changes your saved scene.
- **Warnings:** the node shows a warning when `bands` is empty, a band has no
  target or a target that is not in the scene, or `band_width` is too narrow
  for the band centres (some zoom would show nothing).

## Pick a safe band width

If the bands are too narrow, the zoom halfway between two centres shows
nothing. With the linear falloff the narrowest safe width is

    band_width > (spacing / 2) / (1 - visible_floor)

which `controller.width_floor()` and `ZoomBands.min_width(spacing, floor)`
compute for you, for either falloff. With centres 2.0 apart and the default
floor that is 1.0101, so the defaults use 1.9. To prove a setup never goes
dark, sweep it in a test:

```gdscript
var worst := ZoomBands.dimmest([[0.0, ZoomBands.Hold.ABOVE], [-2.0, ZoomBands.Hold.NONE]], 1.9, -6.0, 3.0)
assert(worst.x > 0.01)  # worst.y is the zoom where it is dimmest
```

## API

`ZoomBands` (static, pure):

- `zoom_exp(zoom)`: `log2(zoom)`.
- `alpha(z, center, width)`, `alpha_hold_above(...)`, `alpha_hold_below(...)`,
  `band_alpha(z, center, width, hold, falloff)`.
- `Falloff`: `LINEAR` or `SMOOTH`; `shape(a, falloff)` and its inverse `unshape(a, falloff)`.
- `min_width(spacing, visible_floor, falloff)`: the width floor above.
- `step_width(width, step, min_w, max_w)`: one clamped step, for dev keys or a slider.
- `max_alpha(z, bands, width, falloff)` and `dimmest(bands, width, z_min, z_max, step, falloff)`.

Every `falloff` argument is optional and defaults to `LINEAR`.

`ZoomBandController` (Node): `camera`, `bands`, `band_width`, `falloff`,
`alpha_property`, `visible_floor`, `hide_below_floor`, `editor_preview`,
`preview_zoom`; `apply_zoom(z)`, `refresh()`, `alpha_for(band, z)`,
`max_alpha(z)`, `width_floor()`, `last_zoom()`; signal `bands_applied(z)`.

`ZoomBand` (Resource): `target`, `center`, `hold`; `ZoomBand.make(target, center, hold)`.
It emits `changed` when any of them changes.

## Demo

Open `addons/zoom_bands/demo/demo.tscn` and run it. Mouse wheel or +/-
zooms, arrow keys pan, S switches between the linear and smooth falloff, and
the label shows each layer's alpha.

## Tests

The addon ships its own GUT tests (GUT 9.x is needed to run them):

    godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://addons/zoom_bands/tests/gutconfig.json -gexit

You can delete `addons/zoom_bands/tests/` if you do not use GUT.
