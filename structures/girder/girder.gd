@tool
@icon("res://structures/girder/girder_icon.svg")
class_name Girder
extends StaticBody2D
## A steel beam to walk on: a plain I-beam or a deep lattice truss, riveted, with weeds
## and broken cable ends hanging from it. Optional columns hold it up from the ground.
## The node's position is the left end of its top edge.

@export var length := 200.0:
	set(v):
		length = v
		_rebuild()
## Thickness of the beam. Above 30 it is drawn as a lattice truss.
@export var depth := 16.0:
	set(v):
		depth = v
		_rebuild()
## Columns under the beam, as x positions along it; they reach down `column_height`.
@export var columns := PackedFloat32Array():
	set(v):
		columns = v
		queue_redraw()
@export var column_height := 200.0:
	set(v):
		column_height = v
		queue_redraw()
@export var hanging_weeds := true
@export var surface := "metal"

var _shape: CollisionShape2D
var _weeds: Array[Vector3] = []


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	_weeds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 7.0 + depth)
	for i in int(length / 40.0):
		if rng.randf() < 0.5:
			_weeds.append(Vector3(rng.randf_range(6, length - 6), rng.randf_range(8, 30), rng.randf() * TAU))
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, depth)
	_shape.shape = rect
	_shape.position = Vector2(length * 0.5, depth * 0.5)
	queue_redraw()


func _process(_delta: float) -> void:
	if hanging_weeds and not Engine.is_editor_hint():
		queue_redraw()


func get_rain_edges() -> Array:
	return [[global_transform * Vector2.ZERO, global_transform * Vector2(length, 0)]]


func _draw() -> void:
	var c := Color.BLACK
	if depth > 30.0:
		draw_rect(Rect2(-2, 0, length + 4, 5), c)
		draw_rect(Rect2(-2, depth - 5, length + 4, 5), c)
		DrawKit.truss(self, Vector2(0, depth - 3), Vector2(length, depth - 3), -(depth - 6.0), depth * 0.9, 2.0)
		draw_rect(Rect2(0, 0, 5, depth), c)
		draw_rect(Rect2(length - 5, 0, 5, depth), c)
	else:
		draw_rect(Rect2(-2, 0, length + 4, 4), c)
		draw_rect(Rect2(0, 3, length, depth - 6), c)
		draw_rect(Rect2(-2, depth - 4, length + 4, 4), c)
	DrawKit.bolts(self, Vector2(2, 0), Vector2(length - 2, 0), 14.0, 1.3)
	for x in columns:
		draw_rect(Rect2(x - 6, depth, 12, column_height - depth), c)
		draw_rect(Rect2(x - 9, depth, 18, 4), c)
		draw_rect(Rect2(x - 10, column_height - 6, 20, 6), c)
		DrawKit.limb(self, Vector2(x - 6, depth + 4), Vector2(x - 26, depth + 4), 3.0, 3.0)
		DrawKit.limb(self, Vector2(x - 6, depth + 24), Vector2(x - 26, depth + 4), 2.0, 2.0)
	for w in _weeds:
		DrawKit.vine(self, Vector2(w.x, depth), w.y, w.z)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	var r := Rect2(0, 0, length, depth)
	if not columns.is_empty():
		r = r.expand(Vector2(r.position.x, depth + column_height))
	return r


func _editor_handles() -> Array[Dictionary]:
	var h: Array[Dictionary] = [{"id": "length", "pos": Vector2(length, depth * 0.5)}, {"id": "depth", "pos": Vector2(length * 0.5, depth)}]
	if not columns.is_empty():
		h.append({"id": "column_height", "pos": Vector2(columns[0], depth + column_height)})
	return h


func _editor_drag(id: Variant, p: Vector2) -> void:
	match id:
		"length":
			length = maxf(20.0, p.x)
		"depth":
			depth = maxf(4.0, p.y)
		"column_height":
			column_height = maxf(0.0, p.y - depth)
