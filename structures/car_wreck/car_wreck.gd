@tool
@icon("res://structures/car_wreck/car_wreck_icon.svg")
class_name CarWreck
extends StaticBody2D
## An old rounded car left to rot: one tire flat, glass gone so the sky shows through the
## windows, a bent antenna and weeds growing through. You can climb on its hood and roof.
## The node's position is the middle between its wheels, on the ground.

@export_range(0.6, 1.6) var size := 1.0:
	set(v):
		size = v
		_rebuild()
@export var facing_right := true:
	set(v):
		facing_right = v
		_rebuild()
@export var surface := "metal"


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for ch in get_children():
		if ch is CollisionShape2D:
			ch.queue_free()
	for r: Rect2 in [Rect2(-58, -27, 116, 23), Rect2(-25, -47, 44, 20)]:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var rr := _flip_rect(r)
		rect.size = rr.size * size
		cs.shape = rect
		cs.position = rr.get_center() * size
		add_child(cs)
	queue_redraw()


func _flip_rect(r: Rect2) -> Rect2:
	if facing_right:
		return r
	return Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)


func get_rain_edges() -> Array:
	var s := 1.0 if facing_right else -1.0
	return [[global_transform * (Vector2(-24 * s, -47) * size), global_transform * (Vector2(18 * s, -47) * size)],
		[global_transform * (Vector2(26 * s, -28) * size), global_transform * (Vector2(56 * s, -24) * size)]]


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size * (1.0 if facing_right else -1.0), size))
	draw_colored_polygon(PackedVector2Array([Vector2(-58, -7), Vector2(-61, -14), Vector2(-59, -23), Vector2(-50, -27.5),
		Vector2(-27, -29), Vector2(30, -29), Vector2(49, -26.5), Vector2(58, -21), Vector2(61, -13), Vector2(58, -7)]), c)
	# cabin as pillars and roof, so the windows stay open
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -45), Vector2(16, -45), Vector2(13, -49), Vector2(-19, -49.5)]), c)
	DrawKit.limb(self, Vector2(-28, -29), Vector2(-21, -46), 4.0, 3.0)
	DrawKit.limb(self, Vector2(24, -29), Vector2(15, -46), 3.0, 2.5)
	draw_rect(Rect2(-4, -45, 3, 16), c)
	draw_rect(Rect2(-28, -32, 52, 4), c)
	# broken glass left in the corners
	draw_colored_polygon(PackedVector2Array([Vector2(-1, -44), Vector2(6, -44), Vector2(0, -38)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(-21, -31), Vector2(-12, -31), Vector2(-19, -36)]), c)
	# wheels: the rear tire is flat
	draw_circle(Vector2(37, -9), 10.0, c)
	DrawKit.ellipse(self, Vector2(-37, -6), Vector2(12, 6.5), 0.0, c)
	# bumpers, headlight, mirror, antenna
	draw_rect(Rect2(56, -12, 7, 4), c)
	draw_rect(Rect2(-64, -12, 7, 4), c)
	draw_circle(Vector2(56, -20), 3.5, c)
	draw_rect(Rect2(19, -33, 5, 3), c)
	var bend := -Weather.wind * 6.0 * Weather.gust_at(global_position.x) + sin(Weather.time * 3.0) * 1.5 * Weather.wind
	draw_polyline(PackedVector2Array([Vector2(-50, -27), Vector2(-52, -45), Vector2(-56 + bend * 0.5, -58), Vector2(-62 + bend, -64)]), c, 1.0)
	# weeds growing under and through it
	for k in 9:
		var x := -48.0 + k * 11.0
		var b := -Weather.wind * 3.0 * Weather.gust_at(global_position.x + x) + sin(Weather.time * 4.0 + k) * Weather.wind
		draw_line(Vector2(x, 0), Vector2(x + b, -6.0 - (k * 7) % 10), c, 1.2)
	draw_set_transform(Vector2.ZERO)
