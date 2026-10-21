@tool
@icon("res://cover/boiler/boiler_icon.svg")
class_name Boiler
extends Cover
## An old riveted boiler lying on its saddles, with a crooked smoke stack, pipes and valve
## wheels you can see the sky through. Steam still leaks from a cracked pipe now and then.
## The node's position is the middle of its foot.

@export var length := 220.0:
	set(v):
		length = v
		queue_redraw()
@export var diameter := 92.0:
	set(v):
		diameter = v
		queue_redraw()
@export var stack_height := 110.0:
	set(v):
		stack_height = v
		queue_redraw()
@export var leaks_steam := true

var _steam: Array[Dictionary] = []
var _puff_wait := 1.0


func _ready() -> void:
	z_index = Layers.COVER


func _body() -> PackedVector2Array:
	var r := diameter * 0.5
	var cy := -18.0 - r
	var pts := PackedVector2Array()
	for i in 9:
		var a := -PI * 0.5 + i * PI / 8.0
		pts.append(Vector2(length * 0.5 - r * 0.35 + cos(a) * r * 0.35, cy + sin(a) * r))
	for i in 9:
		var a := PI * 0.5 + i * PI / 8.0
		pts.append(Vector2(-length * 0.5 + r * 0.35 + cos(a) * r * 0.35, cy + sin(a) * r))
	return pts


func _cover_shapes() -> Array[PackedVector2Array]:
	var r := diameter * 0.5
	var saddle := PackedVector2Array([Vector2(-length * 0.32, 0), Vector2(length * 0.32, 0), Vector2(length * 0.32, -20 - r), Vector2(-length * 0.32, -20 - r)])
	return [_body(), saddle]


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if leaks_steam:
		_puff_wait -= delta
		if _puff_wait < 0.0:
			_puff_wait = randf_range(0.05, 0.12) if randf() < 0.9 else randf_range(2.0, 5.0)
			_steam.append({"p": Vector2(length * 0.38, -18.0 - diameter - 6.0), "v": Vector2(randf_range(-10, 10), -randf_range(25, 45)), "age": 0.0, "r": randf_range(3, 6)})
	for s in _steam:
		s.age += delta
		s.v += Vector2(-Weather.wind * 60.0, -6.0) * delta
		s.p += s.v * delta
		s.r += 8.0 * delta
	_steam = _steam.filter(func(s): return s.age < 2.5)
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var r := diameter * 0.5
	var cy := -18.0 - r
	draw_colored_polygon(_body(), c)
	# riveted bands around the shell
	for i in 5:
		var bx := lerpf(-length * 0.4, length * 0.4, i / 4.0)
		draw_rect(Rect2(bx - 2.0, cy - r - 2.0, 4.0, diameter + 4.0), c)
	# saddles
	for sx in [-length * 0.28, length * 0.28]:
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 22, 0), Vector2(sx + 22, 0), Vector2(sx + 14, -24), Vector2(sx - 14, -24)]), c)
	# smoke stack, slightly crooked, with a cap
	var sb := Vector2(-length * 0.25, cy - r + 4.0)
	var st := sb + Vector2(6.0, -stack_height)
	DrawKit.limb(self, sb, st, 18.0, 15.0)
	draw_rect(Rect2(st.x - 13.0, st.y - 4.0, 26.0, 5.0), c)
	draw_colored_polygon(PackedVector2Array([st + Vector2(-15, -10), st + Vector2(15, -10), st + Vector2(0, -19)]), c)
	draw_line(st + Vector2(-10, -4), st + Vector2(-10, -10), c, 1.5)
	draw_line(st + Vector2(10, -4), st + Vector2(10, -10), c, 1.5)
	# a pipe with a valve wheel
	var p0 := Vector2(length * 0.38, cy - r + 6.0)
	draw_line(p0, p0 + Vector2(0, -24), c, 6.0)
	draw_line(p0 + Vector2(0, -24), p0 + Vector2(40, -24), c, 6.0)
	draw_line(p0 + Vector2(40, -24), p0 + Vector2(40, 30 + r), c, 6.0)
	_wheel(p0 + Vector2(20, -38), 11.0)
	_wheel(Vector2(-length * 0.05, cy - r - 14.0), 8.0)
	draw_line(Vector2(-length * 0.05, cy - r), Vector2(-length * 0.05, cy - r - 14.0), c, 3.0)
	# pressure gauge on a stalk
	var g := Vector2(length * 0.1, cy - r - 20.0)
	draw_line(g + Vector2(0, 20), g, c, 2.0)
	draw_arc(g, 7.0, 0.0, TAU, 20, c, 2.0)
	draw_line(g, g + Vector2.from_angle(-2.4 + sin(Weather.time * 0.7) * 0.05) * 5.0, c, 1.4)
	for s in _steam:
		var a: float = 0.25 * (1.0 - s.age / 2.5)
		DrawKit.draw_puff(self, s.p, s.r * 1.6, Color(0.8, 0.72, 0.66, a * Daylight.light()))
	_draw_cover_outline()


func _wheel(at: Vector2, radius: float) -> void:
	var c := Color.BLACK
	draw_arc(at, radius, 0.0, TAU, 24, c, 2.2)
	for k in 4:
		var a := k * PI / 4.0
		draw_line(at - Vector2.from_angle(a) * radius, at + Vector2.from_angle(a) * radius, c, 1.4)
	draw_circle(at, 2.5, c)
