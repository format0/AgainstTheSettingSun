@tool
@icon("res://structures/tree_stump/tree_stump_icon.svg")
class_name TreeStump
extends StaticBody2D
## The stump of a felled tree with its roots, a jagged broken top, a shoot growing out of
## it and an old axe still stuck in it. The node's position is the middle of its foot.

@export var width := 40.0:
	set(v):
		width = v
		_rebuild()
@export var height := 34.0:
	set(v):
		height = v
		_rebuild()
@export var axe := false:
	set(v):
		axe = v
		queue_redraw()
@export var stump_seed := 1:
	set(v):
		stump_seed = v
		_rebuild()
@export var surface := "wood"

var _poly := PackedVector2Array()
var _shape: CollisionShape2D


func _ready() -> void:
	z_index = Layers.ELEMENTS
	_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = stump_seed
	var w := width * 0.5
	_poly = PackedVector2Array([Vector2(-w - 16, 0), Vector2(-w - 4, -5), Vector2(-w, -height * 0.4), Vector2(-w + 1, -height)])
	var n := 6
	for i in n + 1:
		var u := float(i) / n
		_poly.append(Vector2(lerpf(-w + 1, w - 1, u), -height - (rng.randf_range(0, 7) if i % 2 == 1 else rng.randf_range(0, 2))))
	_poly.append_array(PackedVector2Array([Vector2(w - 1, -height), Vector2(w, -height * 0.4), Vector2(w + 5, -6), Vector2(w + 19, 0)]))
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	_shape.shape = rect
	_shape.position = Vector2(0, -height * 0.5)
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	draw_colored_polygon(_poly, c)
	var sway := -Weather.wind * 3.0 * Weather.gust_at(global_position.x) + sin(Weather.time * 2.3) * Weather.wind
	var shoot := Vector2(-width * 0.3, -height - 2)
	DrawKit.limb(self, shoot, shoot + Vector2(-4 + sway, -18), 2.0, 1.0)
	DrawKit.ellipse(self, shoot + Vector2(-4 + sway, -19), Vector2(4, 2), -0.6 + sway * 0.1)
	DrawKit.ellipse(self, shoot + Vector2(-1 + sway * 0.6, -11), Vector2(3.5, 1.8), 0.6)
	if axe:
		var p := Vector2(width * 0.15, -height - 2)
		DrawKit.limb(self, p, p + Vector2(18, -26), 3.0, 2.6)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 3), p + Vector2(8, -3), p + Vector2(7, 4), p + Vector2(-3, 7)]), c)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-width * 0.5, -height, width, height)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(width * 0.5, -height), "props": ["width", "height"]}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	width = maxf(12.0, absf(p.x) * 2.0)
	height = maxf(8.0, -p.y)
