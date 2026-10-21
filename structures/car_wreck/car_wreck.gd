@tool
@icon("res://structures/car_wreck/car_wreck_icon.svg")
class_name CarWreck
extends StaticBody2D
## An old rounded car from the fifties left to rot: soft fastback roof, fat fenders over the
## wheels, one tire flat, glass gone so the sky shows through the windows, a bent antenna and
## weeds growing through. You can climb on its hood and roof.
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

var _body := PackedVector2Array()
var _roof := PackedVector2Array()


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	_shape_car()
	if not is_inside_tree():
		return
	for ch in get_children():
		if ch is CollisionShape2D:
			ch.queue_free()
	for r: Rect2 in [Rect2(-60, -27, 120, 21), Rect2(-30, -48, 50, 21)]:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var rr := r if facing_right else Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)
		rect.size = rr.size * size
		cs.shape = rect
		cs.position = rr.get_center() * size
		add_child(cs)
	queue_redraw()


func _curve(points: Array, tangents: Array) -> PackedVector2Array:
	var c := Curve2D.new()
	for i in points.size():
		var t: Vector2 = tangents[i]
		c.add_point(points[i], -t, t)
	return c.tessellate(4, 3.0)


func _arch(center: Vector2, r: float) -> PackedVector2Array:
	# the wheel arch, cut up into the bottom edge from left to right
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + i * PI / 8.0
		pts.append(center + Vector2(cos(a), sin(a) * 1.05) * r)
	return pts


func _shape_car() -> void:
	# body: a smooth top line from the rear bumper over the boot and bonnet to the front
	var top := _curve([Vector2(-63, -12), Vector2(-56, -25), Vector2(-30, -30), Vector2(26, -30), Vector2(52, -26), Vector2(63, -14)],
		[Vector2(0, -4), Vector2(-6, -2), Vector2(-10, 0), Vector2(10, 0), Vector2(6, 1), Vector2(1, 4)])
	_body = PackedVector2Array()
	_body.append_array(top)
	_body.append(Vector2(62, -7))
	_body.append(Vector2(50, -7))
	var front := _arch(Vector2(37, -7), 13.0)
	front.reverse()
	_body.append_array(front)
	_body.append(Vector2(24, -7))
	_body.append(Vector2(-24, -7))
	var rear := _arch(Vector2(-37, -7), 13.0)
	rear.reverse()
	_body.append_array(rear)
	_body.append(Vector2(-50, -7))
	_body.append(Vector2(-62, -7))
	# roof: a rounded fastback shell
	_roof = _curve([Vector2(-40, -29), Vector2(-20, -47), Vector2(6, -49), Vector2(22, -30)],
		[Vector2(2, -4), Vector2(7, -2), Vector2(7, 2), Vector2(2, 4)])


func get_rain_edges() -> Array:
	var s := 1.0 if facing_right else -1.0
	return [[global_transform * (Vector2(-18 * s, -48) * size), global_transform * (Vector2(8 * s, -49) * size)],
		[global_transform * (Vector2(26 * s, -30) * size), global_transform * (Vector2(52 * s, -26) * size)]]


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size * (1.0 if facing_right else -1.0), size))
	draw_colored_polygon(_body, c)
	# the roof as a shell 4 px thick, with pillars, so the windows stay open
	draw_polyline(_roof, c, 5.0, true)
	var roof_in := PackedVector2Array()
	for p in _roof:
		roof_in.append(p + Vector2(0, 2))
	draw_polyline(roof_in, c, 3.0, true)
	DrawKit.limb(self, Vector2(-38, -29), Vector2(-24, -44), 4.0, 3.5)
	DrawKit.limb(self, Vector2(-6, -29), Vector2(-5, -47), 3.0, 3.0)
	DrawKit.limb(self, Vector2(21, -30), Vector2(14, -43), 3.0, 2.5)
	draw_line(Vector2(-40, -30), Vector2(23, -30), c, 3.0)
	# broken glass left in the corners
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -45), Vector2(5, -45), Vector2(-2, -38)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -31), Vector2(-24, -31), Vector2(-31, -37)]), c)
	# fat fenders over the wheels
	DrawKit.ellipse(self, Vector2(37, -16), Vector2(15, 7), 0.0, c, 14)
	DrawKit.ellipse(self, Vector2(-37, -16), Vector2(15, 7), 0.0, c, 14)
	# wheels: the rear tire is flat
	draw_circle(Vector2(37, -8), 9.5, c)
	DrawKit.ellipse(self, Vector2(-37, -5), Vector2(11, 5.5), 0.0, c, 16)
	# bumpers, headlamp, door handle, mirror
	draw_rect(Rect2(57, -12, 8, 3.5), c)
	draw_rect(Rect2(-66, -12, 8, 3.5), c)
	DrawKit.ellipse(self, Vector2(58, -20), Vector2(3.5, 4.0), 0.0, c, 10)
	draw_rect(Rect2(19, -34, 5, 3), c)
	# a bent antenna
	var bend := -Weather.wind * 6.0 * Weather.gust_at(global_position.x) + sin(Weather.time * 3.0) * 1.5 * Weather.wind
	draw_polyline(PackedVector2Array([Vector2(-52, -26), Vector2(-54, -42), Vector2(-57 + bend * 0.5, -55), Vector2(-63 + bend, -62)]), c, 1.0)
	# weeds growing under and through it
	for k in 9:
		var x := -48.0 + k * 11.0
		var b := -Weather.wind * 3.0 * Weather.gust_at(global_position.x + x) + sin(Weather.time * 4.0 + k) * Weather.wind
		draw_line(Vector2(x, 0), Vector2(x + b, -6.0 - (k * 7) % 10), c, 1.2)
	draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-70 * size, -52 * size, 140 * size, 54 * size)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(70.0 * size, -52.0 * size)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = clampf(absf(p.x) / 70.0, 0.6, 1.6)
