@tool
@icon("res://addons/zoom_bands/icons/zoom_band.svg")
class_name ZoomBand
extends Resource
## One band for ZoomBandController: the node it fades and where on the zoom
## axis (log2 of the camera zoom) it is fully shown. Every change emits
## `changed`, so a controller re-applies and its editor preview follows.

## The node whose alpha this band drives, relative to the controller.
@export var target: NodePath:
	set(value):
		target = value
		emit_changed()
## The zoom exponent at which this band is fully opaque.
@export var center := 0.0:
	set(value):
		center = value
		emit_changed()
## Whether the band holds full alpha past its centre (see ZoomBands.Hold).
@export var hold: ZoomBands.Hold = ZoomBands.Hold.NONE:
	set(value):
		hold = value
		emit_changed()


static func make(p_target: NodePath, p_center: float, p_hold: ZoomBands.Hold = ZoomBands.Hold.NONE) -> ZoomBand:
	var b := ZoomBand.new()
	b.target = p_target
	b.center = p_center
	b.hold = p_hold
	return b
