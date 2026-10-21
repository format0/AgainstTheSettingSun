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
	_poly = DrawKit.rock_outline(size, rock_seed, 1, 1 if size.x > 50.0 else 0)
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
	# moss and grass on the top
	for k in 7:
		var p := _poly[clampi(_poly.size() / 2 - 3 + k, 0, _poly.size() - 1)]
		draw_line(p, p + Vector2(-1.0 - Weather.wind * 2.0, -4.0 - k % 3 * 2.0), Color.BLACK, 1.0)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(size.x * 0.5, -size.y)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = Vector2(maxf(16.0, absf(p.x) * 2.0), maxf(10.0, -p.y))
