class_name FarSilhouettes
extends Node2D
## Far layer, drawn half transparent so the sky glows through (haze). What stands on the
## horizon depends on the setting: a village with a church and old windmills in the fields,
## chimneys, a gas holder and cranes at the works, mesas and a bucket ropeway at the quarry.
## Windows light up one by one as night comes. Now and then a flock of geese passes.

@export var scroll_scale := 0.22
@export var haze := 0.52
@export var setting := DistantScenery.Setting.INDUSTRY

var _mill_angle := 0.0
var _smoke: Array[Dictionary] = []
var _puff: Texture2D
var _geese_x := -1.0
var _geese_y := 200.0
var _geese_wait := 8.0
var _windows: Array[Vector3] = []


func _ready() -> void:
	_puff = _make_puff()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 40:
		_windows.append(Vector3(rng.randf_range(0, 2600), rng.randf_range(0, 1), rng.randf_range(0.25, 0.95)))


func _stacks() -> Array[Vector2]:
	match setting:
		DistantScenery.Setting.INDUSTRY:
			return [Vector2(960, 430), Vector2(995, 446), Vector2(1052, 418), Vector2(1700, 452), Vector2(2210, 440)]
		DistantScenery.Setting.FIELDS:
			return [Vector2(386, 568)]
		DistantScenery.Setting.QUARRY:
			return [Vector2(1320, 500)]
	return []


func _process(delta: float) -> void:
	_mill_angle += (0.25 + Weather.wind * 0.9) * delta
	for s in _stacks():
		var industry := setting == DistantScenery.Setting.INDUSTRY
		if randf() < delta * (7.0 if industry else 2.0):
			_smoke.append({"p": s, "r": randf_range(5, 9) if industry else randf_range(2, 4), "a": randf_range(0.25, 0.4) if industry else 0.12, "age": 0.0})
	for p in _smoke:
		p.age += delta
		p.r += (5.0 + p.age * 1.5) * delta
		p.p += Vector2((-Weather.wind * 26.0 * (0.6 + 0.6 * Weather.gust) - 5.0) * delta, -maxf(2.0, 16.0 - p.age * 2.4) * delta)
	_smoke = _smoke.filter(func(p): return p.age < 9.0)
	_geese_wait -= delta
	if _geese_x > -300.0:
		_geese_x -= (60.0 + Weather.wind * 40.0) * delta
	elif _geese_wait < 0.0 and Daylight.progress < 0.7:
		_geese_x = GameCamera.view_rect.size.x + 100.0
		_geese_y = randf_range(140, 300)
		_geese_wait = randf_range(25, 50)
	queue_redraw()


func _hill_y(x: float) -> float:
	match setting:
		DistantScenery.Setting.QUARRY:
			# flat-topped mesas with steep sides
			var m := sin(x * 0.004) * 0.5 + sin(x * 0.0093 + 2.0) * 0.5
			return 600.0 - clampf(m * 3.0, -0.2, 1.0) * 70.0 + sin(x * 0.05) * 2.0
		DistantScenery.Setting.FIELDS:
			return 600.0 + sin(x * 0.005) * 18.0 + sin(x * 0.013 + 1.0) * 8.0
	return 606.0 + sin(x * 0.006) * 14.0 + sin(x * 0.017 + 1.0) * 6.0


func _draw() -> void:
	var cam := GameCamera.view_rect.position.x * scroll_scale
	var w := GameCamera.view_rect.size.x
	var col := Color(0, 0, 0, haze)
	var hill := PackedVector2Array([Vector2(cam - 10, 680)])
	var x := cam - 10.0
	while x <= cam + w + 20.0:
		hill.append(Vector2(x, _hill_y(x)))
		x += 12.0
	hill.append(Vector2(cam + w + 20.0, 680))
	draw_colored_polygon(hill, col)
	match setting:
		DistantScenery.Setting.FIELDS:
			_draw_fields(cam, w, col)
		DistantScenery.Setting.INDUSTRY:
			_draw_industry(cam, w, col)
		DistantScenery.Setting.QUARRY:
			_draw_quarry(cam, w, col)
	for p in _smoke:
		var pr: float = p.r
		draw_texture_rect(_puff, Rect2(p.p - Vector2(pr, pr), Vector2(pr, pr) * 2.0), false, Color(1, 1, 1, p.a * (1.0 - p.age / 9.0) * 0.9))
	_draw_windows(cam, w)
	if _geese_x > -300.0:
		for i in 9:
			var row := ceili(i / 2.0)
			var side := 1.0 if i % 2 == 1 else -1.0
			var gp := Vector2(cam + _geese_x + row * 13.0, _geese_y + side * row * 9.0)
			var flap := sin(Weather.time * 9.0 + i) * 3.0
			draw_polyline(PackedVector2Array([gp + Vector2(-4, -flap), gp, gp + Vector2(4, -flap)]), Color(0, 0, 0, 0.7), 1.3)


## Little warm windows that come on as it gets dark.
func _draw_windows(cam: float, w: float) -> void:
	if Daylight.progress < 0.25:
		return
	for win in _windows:
		var on := Daylight.progress > 0.25 + win.y * 0.6
		var house := _window_spot(win.x)
		if not on or house == Vector2.ZERO or house.x < cam - 20.0 or house.x > cam + w + 20.0:
			continue
		var flicker := 0.85 + 0.15 * sin(Weather.time * 2.0 + win.x)
		draw_rect(Rect2(house, Vector2(3, 3)), Color(1.0, 0.72, 0.38, 0.75 * win.z * flicker))


func _window_spot(seed_x: float) -> Vector2:
	match setting:
		DistantScenery.Setting.FIELDS:
			for hx: float in [380.0, 640.0, 1080.0, 1530.0, 1990.0]:
				if absf(seed_x * 0.3 - hx) < 260.0:
					return Vector2(hx + fmod(seed_x, 30.0) - 12.0, _hill_y(hx) - 14.0 - fmod(seed_x, 7.0))
		DistantScenery.Setting.INDUSTRY:
			var fx := 900.0 + fmod(seed_x, 200.0)
			return Vector2(fx, 540.0 + fmod(seed_x * 0.37, 50.0))
	return Vector2.ZERO


func _draw_fields(cam: float, w: float, col: Color) -> void:
	# farmhouses and barns
	for hx: float in [380.0, 640.0, 1080.0, 1530.0, 1990.0]:
		if hx < cam - 100.0 or hx > cam + w + 100.0:
			continue
		var gy := _hill_y(hx) + 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 22, gy), Vector2(hx - 22, gy - 16), Vector2(hx - 2, gy - 30), Vector2(hx + 18, gy - 16), Vector2(hx + 18, gy)]), col)
		draw_rect(Rect2(hx + 18, gy - 12, 26, 12), col)
		draw_rect(Rect2(hx + 6, gy - 34, 5, 10), col)
	# a church with a spire
	var cx := 1240.0
	if cx > cam - 100.0 and cx < cam + w + 100.0:
		var gy := _hill_y(cx) + 3.0
		draw_rect(Rect2(cx - 30, gy - 26, 48, 26), col)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 32, gy - 26), Vector2(cx - 6, gy - 40), Vector2(cx + 20, gy - 26)]), col)
		draw_rect(Rect2(cx + 16, gy - 58, 16, 58), col)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 14, gy - 58), Vector2(cx + 34, gy - 58), Vector2(cx + 24, gy - 104)]), col)
		draw_line(Vector2(cx + 24, gy - 104), Vector2(cx + 24, gy - 114), col, 1.2)
		draw_line(Vector2(cx + 20, gy - 110), Vector2(cx + 28, gy - 110), col, 1.2)
	# old windmills turning slowly on the ridges
	for mx: float in [220.0, 860.0, 1760.0, 2300.0]:
		if mx < cam - 80.0 or mx > cam + w + 80.0:
			continue
		var gy := _hill_y(mx) + 2.0
		var hub := Vector2(mx, gy - 46.0)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 10, gy), Vector2(mx + 10, gy), Vector2(mx + 6, gy - 42), Vector2(mx - 6, gy - 42)]), col)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 8, gy - 42), Vector2(mx + 8, gy - 42), Vector2(mx, gy - 52)]), col)
		for k in 4:
			var a := _mill_angle * (0.8 + fmod(mx, 3.0) * 0.1) + k * PI * 0.5
			var tip := hub + Vector2.from_angle(a) * 30.0
			draw_line(hub, tip, col, 1.4)
			draw_colored_polygon(PackedVector2Array([hub.lerp(tip, 0.3), tip, tip + Vector2.from_angle(a + PI * 0.5) * 6.0, hub.lerp(tip, 0.3) + Vector2.from_angle(a + PI * 0.5) * 5.0]), col)


func _draw_industry(cam: float, w: float, col: Color) -> void:
	var f := 900.0
	for r: Rect2 in [Rect2(f, 520, 190, 100), Rect2(f + 40, 488, 60, 40), Rect2(f + 140, 500, 70, 30), Rect2(f + 520, 530, 260, 90), Rect2(f + 1180, 510, 160, 110)]:
		if r.end.x > cam - 50.0 and r.position.x < cam + w + 50.0:
			draw_rect(r, col)
			# saw-tooth roof
			var x := r.position.x
			while x < r.end.x - 10.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + 16, r.position.y - 9), Vector2(x + 16, r.position.y)]), col)
				x += 18.0
	for s in _stacks():
		draw_rect(Rect2(s.x - 5, s.y, 10, 610 - s.y), col)
		draw_rect(Rect2(s.x - 6.5, s.y, 13, 3), col)
	# a gas holder: a lattice drum
	var gx := 1600.0
	if gx > cam - 150.0 and gx < cam + w + 150.0:
		for k in 7:
			var px := gx - 60.0 + k * 20.0
			draw_line(Vector2(px, 610), Vector2(px, 470), col, 1.4)
		for k in 5:
			var y := 610.0 - k * 34.0
			draw_line(Vector2(gx - 60, y), Vector2(gx + 60, y), col, 1.0)
			if k < 4:
				for j in 6:
					draw_line(Vector2(gx - 60 + j * 20, y), Vector2(gx - 40 + j * 20, y - 34), col, 0.7)
		draw_rect(Rect2(gx - 56, 520, 112, 90), col)
	# tower cranes
	for cx: float in [560.0, 2050.0]:
		if cx < cam - 200.0 or cx > cam + w + 200.0:
			continue
		draw_line(Vector2(cx, 610), Vector2(cx, 400), col, 3.0)
		draw_line(Vector2(cx - 50, 404), Vector2(cx + 140, 404), col, 2.4)
		draw_line(Vector2(cx, 384), Vector2(cx - 50, 404), col, 1.2)
		draw_line(Vector2(cx, 384), Vector2(cx + 140, 404), col, 1.2)
		draw_line(Vector2(cx + 100, 404), Vector2(cx + 100, 470 + sin(Weather.time * 0.6) * 4.0), col, 0.8)


func _draw_quarry(cam: float, w: float, col: Color) -> void:
	# a ropeway with buckets crawling along it between two towers
	var a := Vector2(500, 520)
	var b := Vector2(1900, 470)
	for t: Vector2 in [a, b]:
		if t.x > cam - 200.0 and t.x < cam + w + 200.0:
			draw_polyline(PackedVector2Array([Vector2(t.x - 16, _hill_y(t.x) + 4), Vector2(t.x, t.y - 40), Vector2(t.x + 16, _hill_y(t.x) + 4)]), col, 2.0)
			draw_line(Vector2(t.x - 18, t.y - 36), Vector2(t.x + 18, t.y - 36), col, 2.0)
	var pts := DrawKit.rope_points(a - Vector2(0, 36), b - Vector2(0, 36), 60.0, 40)
	draw_polyline(pts, col, 1.0, true)
	for k in 12:
		var u := fmod(k / 12.0 + Weather.time * 0.004, 1.0)
		var p := pts[int(u * 39.0)]
		if p.x > cam - 20.0 and p.x < cam + w + 20.0:
			draw_line(p, p + Vector2(0, 9), col, 0.8)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 9), p + Vector2(5, 9), p + Vector2(4, 16), p + Vector2(-4, 16)]), col)
	# a crusher house on stilts
	var hx := 1320.0
	if hx > cam - 150.0 and hx < cam + w + 150.0:
		var gy := _hill_y(hx)
		draw_rect(Rect2(hx - 40, gy - 90, 80, 50), col)
		for k in 4:
			draw_line(Vector2(hx - 36 + k * 24, gy - 40), Vector2(hx - 36 + k * 24, gy + 4), col, 2.0)
		draw_line(Vector2(hx + 40, gy - 70), Vector2(hx + 160, gy - 10), col, 5.0)


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
