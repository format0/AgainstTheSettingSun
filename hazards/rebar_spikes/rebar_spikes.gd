@tool
@icon("res://hazards/rebar_spikes/rebar_spikes_icon.svg")
class_name RebarSpikes
extends KillZone
## Broken concrete with rusted reinforcing bars sticking up, at the bottom of a pit.
## Falling onto it is death. The node's position is the top-left of the deadly strip;
## the spikes stand on its bottom edge.

@export var spike_seed := 1:
	set(v):
		spike_seed = v
		queue_redraw()


func _ready() -> void:
	cause = "crushed"
	z_index = Layers.ELEMENTS
	super()


func _draw() -> void:
	var c := Color.BLACK
	var rng := RandomNumberGenerator.new()
	rng.seed = spike_seed
	var base := size.y
	var x := 0.0
	while x < size.x:
		var w := rng.randf_range(16, 34)
		var h := rng.randf_range(6, 14)
		draw_colored_polygon(DrawKit.rough_rect(Rect2(x, base - h, w, h + 6), rng.randi(), 2.0, 5.0), c)
		x += w - 2.0
	x = 4.0
	while x < size.x - 4.0:
		var tip := Vector2(x + rng.randf_range(-6, 6), base - size.y * rng.randf_range(0.6, 1.0))
		var mid := Vector2(x, base).lerp(tip, 0.6) + Vector2(rng.randf_range(-3, 3), 0)
		draw_polyline(PackedVector2Array([Vector2(x, base), mid, tip]), c, 2.0)
		x += rng.randf_range(5, 12)
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), DrawKit.EDITOR_HAZARD, "spikes")
