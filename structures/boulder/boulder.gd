@tool
@icon("res://structures/boulder/boulder_icon.svg")
class_name Boulder
extends StaticBody2D
## A rock to stand on or jump over, with moss tufts on top. Change `rock_seed` for another
## shape. The node's position is the middle of its foot.

@export var size := Vector2(70, 40):
	set(v):
		size = v
		_rebuild()
@export var rock_seed := 1:
	set(v):
		rock_seed = v
		_rebuild()
@export var surface := "stone"

var _poly := PackedVector2Array()
var _collision: CollisionPolygon2D


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	_poly = PackedVector2Array()
	var n := 12
	for i in n + 1:
		var u := float(i) / n
		var a := PI + u * PI
		var r := 1.0 + rng.randf_range(-0.1, 0.08)
		_poly.append(Vector2(cos(a) * size.x * 0.5 * r, sin(a) * size.y * r if i > 0 and i < n else 0.0))
	if not is_inside_tree():
		return
	if _collision == null:
		_collision = CollisionPolygon2D.new()
		add_child(_collision)
	_collision.polygon = _poly
	queue_redraw()


func get_rain_edges() -> Array:
	return [[global_transform * Vector2(-size.x * 0.3, -size.y * 0.9), global_transform * Vector2(size.x * 0.3, -size.y * 0.9)]]


func _draw() -> void:
	draw_colored_polygon(_poly, Color.BLACK)
	for k in 7:
		var p := _poly[3 + k % 6]
		draw_line(p, p + Vector2(-1.0 - Weather.wind * 2.0, -4.0 - k % 3 * 2.0), Color.BLACK, 1.0)
