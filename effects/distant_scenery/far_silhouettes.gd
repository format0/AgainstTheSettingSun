class_name FarSilhouettes
extends Node2D
## Far layer: rolling hills, wind turbines with blinking lights, a factory with smoking chimneys,
## and now and then a flock of geese. Drawn half transparent so the sky glows through (haze).

@export var scroll_scale := 0.22
@export var haze := 0.52
@export var turbine_x := PackedFloat32Array([140, 400, 690, 1180, 1500, 1720])
@export var factory_x := 900.0

var _turbine_angle := PackedFloat32Array()
var _smoke: Array[Dictionary] = []
var _puff: Texture2D
var _geese_x := -1.0
var _geese_y := 200.0
var _geese_wait := 8.0


func _ready() -> void:
	_turbine_angle.resize(turbine_x.size())
	for i in turbine_x.size():
		_turbine_angle[i] = randf() * TAU
	_puff = _make_puff()


func _stacks() -> Array[Vector2]:
	return [Vector2(factory_x + 60, 438), Vector2(factory_x + 95, 452), Vector2(factory_x + 152, 425)]


func _process(delta: float) -> void:
	for i in turbine_x.size():
		_turbine_angle[i] += (0.8 + 0.4 * sin(i * 3.1)) * (0.5 + Weather.wind) * delta
	for s in _stacks():
		if randf() < delta * 7.0:
			_smoke.append({"p": s, "r": randf_range(5, 9), "a": randf_range(0.25, 0.4), "age": 0.0})
	for p in _smoke:
		p.age += delta
		p.r += (5.0 + p.age * 1.5) * delta
		p.p += Vector2((-Weather.wind * 26.0 * (0.6 + 0.6 * Weather.gust) - 5.0) * delta, -maxf(2.0, 16.0 - p.age * 2.4) * delta)
	_smoke.assign(_smoke.filter(func(p): return p.age < 9.0))
	_geese_wait -= delta
	if _geese_x > -300.0:
		_geese_x -= (60.0 + Weather.wind * 40.0) * delta
	elif _geese_wait < 0.0:
		_geese_x = GameCamera.view_rect.size.x + 100.0
		_geese_y = randf_range(140, 300)
		_geese_wait = randf_range(20, 40)
	queue_redraw()


func _hill_y(x: float) -> float:
	return 606.0 + sin(x * 0.006) * 14.0 + sin(x * 0.017 + 1.0) * 6.0


func _draw() -> void:
	var cam := GameCamera.view_rect.position.x * scroll_scale
	var w := GameCamera.view_rect.size.x
	var col := Color(0, 0, 0, haze)
	var hill := PackedVector2Array([Vector2(cam - 10, 660)])
	var x := cam - 10.0
	while x <= cam + w + 20.0:
		hill.append(Vector2(x, _hill_y(x)))
		x += 16.0
	hill.append(Vector2(cam + w + 20.0, 660))
	draw_colored_polygon(hill, col)
	var f := factory_x
	for r in [Rect2(f, 520, 190, 100), Rect2(f + 40, 488, 60, 40), Rect2(f + 140, 500, 70, 30)]:
		draw_rect(r, col)
	for s in _stacks():
		draw_rect(Rect2(s.x - 5, s.y, 10, 600 - s.y), col)
	for p in _smoke:
		var pr: float = p.r
		draw_texture_rect(_puff, Rect2(p.p - Vector2(pr, pr), Vector2(pr, pr) * 2.0), false, Color(1, 1, 1, p.a * (1.0 - p.age / 9.0) * 0.9))
	var blink := sin(Weather.time * 3.4) > 0.55
	for i in turbine_x.size():
		var tx := turbine_x[i]
		if tx < cam - 100.0 or tx > cam + w + 100.0:
			continue
		var ty := _hill_y(tx) - 6.0
		var th := 110.0 + 20.0 * sin(i * 2.7)
		var hub := Vector2(tx, ty - th)
		draw_rect(Rect2(tx - 1.6, ty - th, 3.2, th), col)
		for k in 3:
			var a := _turbine_angle[i] + k * TAU / 3.0
			var tip := hub + Vector2.from_angle(a) * th * 0.42
			draw_colored_polygon(PackedVector2Array([hub, tip + Vector2.from_angle(a + PI / 2.0) * 2.0, tip]), col)
		if blink:
			draw_circle(hub - Vector2(0, 1), 2.0, Color(1.0, 0.2, 0.15, 0.95))
	for i in 14:
		if (i * 7 + int(Weather.time * 0.4 + i)) % 5 != 0:
			draw_rect(Rect2(f + 12 + (i % 7) * 25, 535 + (i / 7) * 22, 5, 4), Color(1.0, 0.67, 0.35, 0.55))
	if _geese_x > -300.0:
		for i in 9:
			var row := ceili(i / 2.0)
			var side := 1.0 if i % 2 == 1 else -1.0
			var gp := Vector2(cam + _geese_x + row * 13.0, _geese_y + side * row * 9.0)
			var flap := sin(Weather.time * 9.0 + i) * 3.0
			draw_polyline(PackedVector2Array([gp + Vector2(-4, -flap), gp, gp + Vector2(4, -flap)]), Color(0, 0, 0, 0.7), 1.3)


func _make_puff() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.55, Color(0, 0, 0, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
