# Changelog

All notable changes to Zoom Bands. Versions follow semantic versioning.

## [1.0.0]

First public release, under Apache-2.0.

- `ZoomBands`: static, pure band maths (`zoom_exp`, `alpha`, `band_alpha` with `Hold` modes,
  `min_width`, `step_width`, `max_alpha`, `dimmest`).
- `ZoomBand`: a resource for one layer (target, centre, hold).
- `ZoomBandController`: a node that crossfades any `CanvasItem` layers by a `Camera2D`'s zoom,
  hides layers at or under `visible_floor`, and emits `bands_applied(z)`. A frame where the zoom
  has not moved does no work; `refresh()` forces the next one.
- `Falloff`: `LINEAR` (the default) or `SMOOTH` (smoothstep), on the controller and every
  maths function; `min_width` and `width_floor()` follow the falloff.
- Editor: a preview of the crossfade at any zoom (`editor_preview`, `preview_zoom`) that never
  reaches the saved scene, configuration warnings for an empty band list, a missing target and a
  band width too narrow for the centres, and node and resource icons.
- Demo scene with three layers on one zoom axis; each layer is one repeated texture that fills
  the view at every zoom the demo allows. S switches the falloff.
- `tools/capture_screenshots.gd` takes the store screenshots and `tools/capture_gif.gd` with
  `tools/make_gif.py` the store GIF, all from the demo scene (not in the download).
- 31 GUT tests (GUT 9.x). Godot 4.3 or later.
