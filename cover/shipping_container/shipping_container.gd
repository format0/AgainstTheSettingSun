@tool
@icon("res://cover/shipping_container/shipping_container_icon.svg")
class_name ShippingContainer
extends Cover
## A rusted shipping container standing behind the path, long forgotten: corrugated roof,
## door bars sticking out at one end, the bottom edge eaten through by rust.
## The node's position is the bottom-left corner. Set `solid` to make it a block you can
## stand on instead (then it is in the player's plane and no longer hides him).

enum DoorEnd { NONE, LEFT, RIGHT }

@export var size := Vector2(250, 98):
	set(v):
		size = v
		_rebuild()
@export var door_end := DoorEnd.RIGHT:
	set(v):
		door_end = v
		queue_redraw()
@export var rust_seed := 2:
	set(v):
		rust_seed = v
		_rebuild()
## One door hangs open, swinging a little in the wind.
@export var door_ajar := false
@export var solid := false:
	set(v):
		solid = v
		_rebuild()

var _body: PackedVector2Array
## 0 = a ladder leaning on it, 1 = a torn tarp on the roof, 2 = cables hanging off it.
var _extra := 0
var _weeds := PackedVector2Array()
var _static: StaticBody2D


func _ready() -> void:
	z_index = Layers.ELEMENTS if solid else Layers.COVER
	_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rust_seed
	_body = PackedVector2Array()
	# bottom edge from left to right, with rust holes eaten into it
	var x := 0.0
	_body.append(Vector2(0, 0))
	while x < size.x - 12.0:
		x += rng.randf_range(10, 26)
		if rng.randf() < 0.3 and x < size.x - 30.0:
			var w := rng.randf_range(6, 16)
			var d := rng.randf_range(3, 9)
			_body.append(Vector2(x, 0))
			_body.append(Vector2(x + 2, -d * 0.6))
			_body.append(Vector2(x + w * 0.5, -d))
			_body.append(Vector2(x + w - 2, -d * 0.5))
			_body.append(Vector2(x + w, 0))
			x += w
	_body.append(Vector2(size.x, 0))
	# right end, corner casting, corrugated roof back to the left
	_body.append(Vector2(size.x, -size.y))
	var ribs := int(size.x / 9.0)
	# the roof, sagging where something heavy once landed on it
	var dent := rng.randf_range(0.25, 0.75)
	for i in range(ribs, -1, -1):
		var u := float(i) / ribs
		var rx := size.x * u
		var sag := exp(-pow((u - dent) * 7.0, 2.0)) * 4.0
		_body.append(Vector2(rx, -size.y + sag - (1.6 if i % 2 == 0 else 0.0)))
	_body.append(Vector2(0, -size.y))
	_extra = rust_seed % 3
	_weeds.clear()
	for i in int(size.x / 25.0):
		_weeds.append(Vector2(rng.randf_range(-6, size.x + 6), rng.randf_range(5, 14)))
	if solid and is_inside_tree():
		if _static == null:
			_static = StaticBody2D.new()
			var shape := CollisionShape2D.new()
			_static.add_child(shape)
			add_child(_static)
		var rect := RectangleShape2D.new()
		rect.size = size
		(_static.get_child(0) as CollisionShape2D).shape = rect
		(_static.get_child(0) as CollisionShape2D).position = Vector2(size.x * 0.5, -size.y * 0.5)
		_static.set_meta("surface", "metal")
	elif _static:
		_static.queue_free()
		_static = null
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _cover_shapes() -> Array[PackedVector2Array]:
	if solid:
		return []
	return [_body]


func _draw() -> void:
	var c := Color.BLACK
	draw_colored_polygon(_body, c)
	# corner castings stick out a little
	for cx: float in [-1.5, size.x - 6.5]:
		draw_rect(Rect2(cx, -size.y - 3.0, 8.0, 7.0), c)
		draw_rect(Rect2(cx, -8.0, 8.0, 8.0), c)
	var gust := Weather.gust_at(global_position.x)
	var bend := -Weather.wind * (0.5 + gust)
	for w in _weeds:
		for k in 3:
			draw_line(Vector2(w.x + k * 2.0 - 2.0, 1.0), Vector2(w.x + k * 2.0 - 2.0 + bend * 3.0, -w.y + k * 3.0), c, 1.0)
	match _extra:
		0:
			# a ladder leaning against the end without doors
			var lx := 0.0 if door_end == DoorEnd.RIGHT else size.x
			var s0 := -1.0 if door_end == DoorEnd.RIGHT else 1.0
			var foot := Vector2(lx + s0 * 26.0, 0)
			var head := Vector2(lx + s0 * 2.0, -size.y - 10.0)
			var side := (head - foot).normalized().orthogonal() * 4.0
			draw_line(foot - side, head - side, c, 1.8)
			draw_line(foot + side, head + side, c, 1.8)
			for k in 9:
				var q := foot.lerp(head, (k + 0.6) / 9.6)
				draw_line(q - side, q + side, c, 1.4)
		1:
			# a torn tarp weighed down on the roof, its loose end lifting in the wind
			var a := Vector2(size.x * 0.3, -size.y - 1.0)
			var b := Vector2(size.x * 0.62, -size.y - 1.0)
			var lift := 4.0 + 6.0 * absf(sin(Weather.time * (3.0 + Weather.wind * 5.0))) * Weather.wind * (0.5 + gust)
			draw_colored_polygon(PackedVector2Array([a, a + Vector2(10, -4), b + Vector2(-6, -3), b + Vector2(8, -lift), b + Vector2(14, -lift * 0.6), b + Vector2(4, 0)]), c)
			draw_line(a + Vector2(14, -3), a + Vector2(12, 16), c, 1.0)
		2:
			# cables hanging from the roof edge, swinging
			for k in 3:
				var top := Vector2(size.x * (0.2 + k * 0.27), -size.y)
				var sw := sin(Weather.time * 1.4 + k) * 3.0 * Weather.wind + bend * 4.0
				draw_polyline(PackedVector2Array([top, top + Vector2(-2.0 + sw * 0.4, 0.0) + Vector2(-3, 3), top + Vector2(sw * 0.6 - 4.0, 10.0 + k * 6.0), top + Vector2(sw - 2.0, 18.0 + k * 9.0)]), c, 1.2)
	if door_end != DoorEnd.NONE:
		var ex := size.x if door_end == DoorEnd.RIGHT else 0.0
		var s := 1.0 if door_end == DoorEnd.RIGHT else -1.0
		for k in 4:
			var bx := ex - s * (k * 14.0 + 8.0)
			draw_rect(Rect2(bx - 1.2, -size.y + 6.0, 2.4, size.y - 12.0), c)
			draw_rect(Rect2(bx - 1.2 + s * 2.0, -size.y * 0.5 - 2.0, 7.0 * s, 3.0).abs(), c)
		if door_ajar:
			var swing := 0.25 + 0.12 * sin(Weather.time * 0.9) * Weather.wind - Weather.wind * 0.1 * Weather.gust
			var hinge := Vector2(ex, -size.y + 3.0)
			var w := size.y * 0.55
			var tip := hinge + Vector2(cos(swing) * w * s, 0)
			draw_colored_polygon(PackedVector2Array([hinge, tip + Vector2(0, -sin(swing) * 6.0), tip + Vector2(0, size.y - 6.0 - sin(swing) * 6.0), hinge + Vector2(0, size.y - 6.0)]), c)
	_draw_cover_outline()

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(0, -size.y, size.x, size.y)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(size.x, -size.y)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = Vector2(maxf(60.0, p.x), maxf(40.0, -p.y))
