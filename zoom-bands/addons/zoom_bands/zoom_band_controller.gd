@tool
@icon("res://addons/zoom_bands/icons/zoom_band_controller.svg")
class_name ZoomBandController
extends Node
## Crossfades detail layers by camera zoom.
##
## Give it a Camera2D and a list of ZoomBand entries. Each frame the camera's
## zoom has moved, it reads the zoom exponent, z = log2(camera.zoom.x), works
## out each band's alpha with ZoomBands, writes it to the band's target and,
## by default, hides a target whose alpha is at or under visible_floor so it
## costs nothing to draw. A frame where nothing moved does no work.
##
## Without a camera, call apply_zoom(z) yourself (from your own camera script,
## a tween, or a test).
##
## In the editor, turn on editor_preview to see the crossfade at preview_zoom.
## The preview puts every target back as it was before the scene is saved and
## when it is turned off, so it never changes your saved scene.

## Emitted after each apply_zoom, with the zoom exponent that was applied.
signal bands_applied(z: float)

## The camera whose zoom drives the bands. Leave empty to drive apply_zoom().
@export var camera: Camera2D:
	set(value):
		camera = value
		_changed()
## The bands, nearest or farthest first; order does not matter.
@export var bands: Array[ZoomBand] = []:
	set(value):
		_watch(bands, false)
		bands = value
		_watch(bands, true)
		_changed()
## How far (in zoom exponent) a band reaches either side of its centre.
## Keep it above width_floor() or some zoom will show nothing.
@export_range(0.05, 10.0, 0.05) var band_width := 1.9:
	set(value):
		band_width = value
		_changed()
## How alpha falls from a band's centre to its edge: LINEAR or SMOOTH
## (smoothstep, so layers ease in and out). See ZoomBands.Falloff.
@export var falloff: ZoomBands.Falloff = ZoomBands.Falloff.LINEAR:
	set(value):
		falloff = value
		_changed()
## The property each target's alpha is written to, as a property path.
## "modulate:a" works on any CanvasItem; use a custom property name (for
## example "band_alpha") when your layer script wants to fade itself.
@export var alpha_property: StringName = &"modulate:a":
	set(value):
		_restore_preview()
		alpha_property = value
		_changed()
## A target whose alpha is at or under this is hidden (when hide_below_floor).
@export_range(0.0, 0.5, 0.005) var visible_floor := 0.01:
	set(value):
		visible_floor = value
		_changed()
## Hide CanvasItem targets at or under visible_floor.
@export var hide_below_floor := true:
	set(value):
		hide_below_floor = value
		_changed()

@export_group("Editor preview")
## Show the crossfade in the editor at preview_zoom. Editor only: it does
## nothing in a running game, and your saved scene keeps the targets as they were.
@export var editor_preview := false:
	set(value):
		editor_preview = value
		_refresh_preview()
## The zoom exponent the editor preview shows (log2 of the camera zoom).
@export_range(-10.0, 10.0, 0.05) var preview_zoom := 0.0:
	set(value):
		preview_zoom = value
		_refresh_preview()

var _last_z := NAN
var _dirty := true
var _last_count := -1
# Editor preview only: each touched target's own values, to put back.
# Entries are [node, property path, value, visible or null].
var _saved: Array = []
# True in the editor. A plain field so a test can stand in for the editor.
var _in_editor := Engine.is_editor_hint()


func _ready() -> void:
	if _in_editor:
		_refresh_preview()


func _notification(what: int) -> void:
	if not _in_editor:
		return
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE, NOTIFICATION_EXIT_TREE:
			_restore_preview()
		NOTIFICATION_EDITOR_POST_SAVE:
			_refresh_preview()


func _process(_delta: float) -> void:
	if _in_editor or camera == null:
		return
	var z := ZoomBands.zoom_exp(camera.zoom.x)
	if z == _last_z and not _dirty and bands.size() == _last_count:
		return
	apply_zoom(z)


## Writes every band's alpha for zoom exponent z. It always applies, even when
## z is the zoom last applied.
func apply_zoom(z: float) -> void:
	_last_z = z
	_dirty = false
	_last_count = bands.size()
	var path := NodePath(String(alpha_property))
	for band in bands:
		if band == null:
			continue
		var node := get_node_or_null(band.target)
		if node == null:
			continue
		var a := alpha_for(band, z)
		node.set_indexed(path, a)
		if hide_below_floor and node is CanvasItem:
			(node as CanvasItem).visible = a > visible_floor
	bands_applied.emit(z)


## Makes the next frame re-apply even if the zoom has not moved. Changing any
## property here, or any ZoomBand in bands, does this for you; call it after
## changing something the controller cannot see, such as a target node you
## swapped out from under a band.
func refresh() -> void:
	_dirty = true


## The alpha `band` has at zoom exponent z with this controller's band_width
## and falloff.
func alpha_for(band: ZoomBand, z: float) -> float:
	return ZoomBands.band_alpha(z, band.center, band_width, band.hold, falloff)


## The strongest band alpha at z; at or under visible_floor nothing draws.
func max_alpha(z: float) -> float:
	return ZoomBands.max_alpha(z, _band_pairs(), band_width, falloff)


## The narrowest safe band_width for these centres: the closest pair decides
## it. A band_width must be strictly above this. 0.0 with fewer than two bands.
func width_floor() -> float:
	var centres: Array[float] = []
	for band in bands:
		if band != null:
			centres.append(band.center)
	if centres.size() < 2:
		return 0.0
	centres.sort()
	var gap := INF
	for i in range(1, centres.size()):
		gap = minf(gap, centres[i] - centres[i - 1])
	return ZoomBands.min_width(gap, visible_floor, falloff)


## The zoom exponent last applied, or NAN before the first apply.
func last_zoom() -> float:
	return _last_z


## What the editor shows on this node's warning icon. Empty when the setup
## is sound.
func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if bands.is_empty():
		out.append("Add at least one ZoomBand to bands.")
	for i in bands.size():
		var band := bands[i]
		if band == null:
			out.append("bands[%d] is empty: give it a ZoomBand or remove it." % i)
		elif band.target.is_empty():
			out.append("bands[%d] has no target node." % i)
		elif is_inside_tree() and get_node_or_null(band.target) == null:
			out.append("bands[%d] target \"%s\" is not in the scene." % [i, band.target])
	var w_min := width_floor()
	if w_min > 0.0 and band_width <= w_min:
		out.append("band_width %.2f is too narrow: some zoom will show nothing. Use more than %.2f for these centres."
				% [band_width, w_min])
	return out


func _band_pairs() -> Array:
	var out := []
	for band in bands:
		if band != null:
			out.append([band.center, band.hold])
	return out


func _changed() -> void:
	_dirty = true
	if _in_editor and is_inside_tree():
		update_configuration_warnings()
		_refresh_preview()


func _watch(list: Array, on: bool) -> void:
	for band in list:
		if band == null:
			continue
		var linked: bool = band.changed.is_connected(_changed)
		if on and not linked:
			band.changed.connect(_changed)
		elif not on and linked:
			band.changed.disconnect(_changed)


func _refresh_preview() -> void:
	if not _in_editor or not is_inside_tree():
		return
	_restore_preview()
	if not editor_preview:
		return
	var path := NodePath(String(alpha_property))
	for band in bands:
		if band == null:
			continue
		var node := get_node_or_null(band.target)
		if node == null:
			continue
		var vis = (node as CanvasItem).visible if node is CanvasItem else null
		_saved.append([node, path, node.get_indexed(path), vis])
	apply_zoom(preview_zoom)


func _restore_preview() -> void:
	for entry in _saved:
		var node = entry[0]
		if not is_instance_valid(node):
			continue
		node.set_indexed(entry[1], entry[2])
		if entry[3] != null:
			(node as CanvasItem).visible = entry[3]
	_saved.clear()
