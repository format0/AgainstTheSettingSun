@tool
@icon("res://structures/catwalk/catwalk_icon.svg")
class_name Catwalk
extends StaticBody2D
## A steel grating walkway with a railing, some posts bent or missing. With `one_way` the
## player can jump up through it from below. Hangers or posts hold it up.
## The node's position is the left end of the deck.

enum Support { NONE, POSTS, HANGERS }

@export var length := 220.0:
	set(v):
		length = v
		_rebuild()
@export var one_way := true:
	set(v):
		one_way = v
		_rebuild()
@export var railing := true:
	set(v):
		railing = v
		queue_redraw()
@export var support := Support.HANGERS:
	set(v):
		support = v
		queue_redraw()
## Length of posts (down) or hangers (up).
@export var support_length := 160.0:
	set(v):
		support_length = v
		queue_redraw()
@export var rust_seed := 1:
	set(v):
		rust_seed = v
		queue_redraw()
@export var surface := "metal"

var _shape: CollisionShape2D


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, 6)
	_shape.shape = rect
	_shape.position = Vector2(length * 0.5, 3)
	_shape.one_way_collision = one_way
	queue_redraw()


func get_rain_edges() -> Array:
	return [[global_transform * Vector2.ZERO, global_transform * Vector2(length, 0)]]


func _draw() -> void:
	var c := Color.BLACK
	var rng := RandomNumberGenerator.new()
	rng.seed = rust_seed
	draw_rect(Rect2(0, 0, length, 4), c)
	# grating teeth underneath
	var x := 1.0
	while x < length:
		draw_line(Vector2(x, 4), Vector2(x, 6.5), c, 1.0)
		x += 3.0
	draw_rect(Rect2(0, 6, length, 1.5), c)
	if railing:
		var posts := maxi(2, int(length / 44.0) + 1)
		var prev_top := Vector2.ZERO
		for i in posts:
			var px := length * i / (posts - 1)
			var lean := rng.randf_range(-0.12, 0.12) if rng.randf() < 0.3 else 0.0
			var top := Vector2(px, 0) + Vector2.from_angle(-PI * 0.5 + lean) * 28.0
			if rng.randf() < 0.12 and i > 0 and i < posts - 1:
				# a missing post: only a stub
				draw_line(Vector2(px, 0), Vector2(px, -7), c, 2.0)
				prev_top = Vector2.ZERO
				continue
			draw_line(Vector2(px, 0), top, c, 2.0)
			if prev_top != Vector2.ZERO:
				draw_line(prev_top, top, c, 1.8)
				draw_line(prev_top.lerp(Vector2(prev_top.x, 0), 0.5), top.lerp(Vector2(top.x, 0), 0.5), c, 1.2)
			prev_top = top
	match support:
		Support.POSTS:
			for px: float in [12.0, length - 12.0]:
				draw_rect(Rect2(px - 3, 6, 6, support_length), c)
				draw_line(Vector2(px, 30), Vector2(px + (20 if px < length * 0.5 else -20), 6), c, 2.0)
		Support.HANGERS:
			for px: float in [10.0, length - 10.0]:
				draw_line(Vector2(px, 2), Vector2(px, -support_length), c, 2.0)
