class_name FarSilhouettes
extends Node2D
## Far layer. Everything is drawn in one opaque haze colour and the DistantScenery fades the
## whole layer at once (a CanvasGroup), so overlapping shapes never darken each other and the
## sky glows through evenly. What stands on the horizon depends on the setting: a village with a church and old windmills in the fields,
## chimneys, a gas holder and cranes at the works, mesas and a bucket ropeway at the quarry.
## Wind turbines blink red on the ridges. Windows light up one by one as night comes. Now and
## then a flock of geese passes.

@export var scroll_scale := 0.22
## The colour of the far haze (multiplied by the remaining daylight).
@export var tint := Color(0.17, 0.068, 0.052)
@export var setting := DistantScenery.Setting.INDUSTRY

var _mill_angle := 0.0
var _turbine_angle := 0.0
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
			return [Vector2(950, 430), Vector2(985, 446), Vector2(1062, 418), Vector2(1440, 452), Vector2(2150, 440)]
		DistantScenery.Setting.FIELDS:
			return [Vector2(386, 568)]
		DistantScenery.Setting.QUARRY:
			return [Vector2(1320, 500)]
	return []


func _process(delta: float) -> void:
	_mill_angle += (0.25 + Weather.wind * 0.9) * delta
	_turbine_angle += (0.5 + Weather.wind) * 0.9 * delta
	var industry := setting == DistantScenery.Setting.INDUSTRY
	var amount := VFX.v("smoke")
	for s in _stacks():
		if randf() < delta * (10.0 if industry else 3.0) * amount:
			_smoke.append({"p": s + Vector2(randf_range(-2, 2), 0), "r": randf_range(4, 6) if industry else 2.5, "a": randf_range(0.3, 0.45) if industry else 0.16,
				"age": 0.0, "life": randf_range(7.0, 11.0), "rise": randf_range(14, 22)})
	for p in _smoke:
		p.age += delta
		var k: float = p.age / p.life
		p.r += (3.0 + p.age * 1.6) * delta
		# warm smoke rises fast, then the wind takes it and it drifts nearly level
		var rise: float = p.rise * exp(-p.age * 0.35)
		var drift := -Weather.wind * 30.0 * (0.4 + 0.8 * Weather.gust_at(float(p.p.x) * 3.0)) * minf(1.0, p.age * 0.5)
		p.p += Vector2(drift + sin(Weather.time * 0.7 + float(p.r)) * 2.0 * k, -rise) * delta
	_smoke = _smoke.filter(func(p): return p.age < p.life)
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
	var col := Color(tint * (0.3 + 0.7 * Daylight.light()) * VFX.v("haze"), 1.0)
	var hill := PackedVector2Array([Vector2(cam - 10, 680)])
	var x := cam - 10.0
	while x <= cam + w + 20.0:
		hill.append(Vector2(x, _hill_y(x)))
		x += 12.0
	hill.append(Vector2(cam + w + 20.0, 680))
	draw_colored_polygon(hill, col)
	match setting:
		DistantScenery.Setting.FIELDS:
			_draw_turbines(cam, w, col, [140.0, 520.0, 700.0, 1420.0, 1640.0, 2120.0, 2480.0])
			_draw_fields(cam, w, col)
		DistantScenery.Setting.INDUSTRY:
			_draw_industry(cam, w, col)
		DistantScenery.Setting.QUARRY:
			_draw_turbines(cam, w, col, [460.0, 1900.0, 2260.0])
			_draw_quarry(cam, w, col)
	for p in _smoke:
		var pr: float = p.r
		var k: float = p.age / p.life
		var fade := smoothstep(0.0, 0.08, k) * (1.0 - k)
		draw_texture_rect(_puff, Rect2(p.p - Vector2(pr, pr), Vector2(pr, pr) * 2.0), false, Color(col, p.a * fade * 1.4))
	_draw_windows(cam, w)
	if _geese_x > -300.0:
		for i in 9:
			var row := ceili(i / 2.0)
			var side := 1.0 if i % 2 == 1 else -1.0
			var gp := Vector2(cam + _geese_x + row * 13.0, _geese_y + side * row * 9.0)
			var flap := sin(Weather.time * 9.0 + i) * 3.0
			draw_polyline(PackedVector2Array([gp + Vector2(-4, -flap), gp, gp + Vector2(4, -flap)]), col, 1.3)


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


## Wind turbines along the far ridges: thin towers, three slow blades, and a red light on
## each nacelle blinking in step with the others (it shines through the haze).
func _draw_turbines(cam: float, w: float, col: Color, xs: Array) -> void:
	var blink := sin(Weather.time * 3.4) > 0.55
	for tx: float in xs:
		if tx < cam - 80.0 or tx > cam + w + 80.0:
			continue
		var gy := _hill_y(tx) + 2.0
		var h := 95.0 + fmod(tx * 0.37, 35.0)
		var hub := Vector2(tx, gy - h)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 2.2, gy), Vector2(tx + 2.2, gy), Vector2(tx + 1.2, gy - h), Vector2(tx - 1.2, gy - h)]), col)
		draw_rect(Rect2(hub + Vector2(-2.5, -2.5), Vector2(8, 4.5)), col)
		var a0 := _turbine_angle * (0.8 + fmod(tx, 7.0) * 0.06) + tx
		for k in 3:
			var a := a0 + k * TAU / 3.0
			var d := Vector2.from_angle(a)
			var L := h * 0.42
			draw_colored_polygon(PackedVector2Array([hub + d.orthogonal() * 1.6, hub + d * L * 0.25 + d.orthogonal() * 2.2, hub + d * L, hub - d.orthogonal() * 0.8]), col)
		if blink and Daylight.progress > 0.15:
			draw_circle(hub + Vector2(1.5, -3.5), 1.8, Color(1.0, 0.2, 0.15, 0.95))


func _draw_industry(cam: float, w: float, col: Color) -> void:
	# every building stands on the hill line and reaches below it, so nothing floats
	var f := 900.0
	var blocks := [Vector3(f - 10, 200, 92), Vector3(f + 40, 60, 132), Vector3(f + 140, 70, 112), Vector3(f + 520, 260, 84),
		Vector3(f + 1180, 160, 104), Vector3(f + 1360, 90, 70)]
	for b: Vector3 in blocks:
		if b.x + b.y < cam - 50.0 or b.x > cam + w + 50.0:
			continue
		var base := maxf(_hill_y(b.x), _hill_y(b.x + b.y)) + 30.0
		var top := minf(_hill_y(b.x), _hill_y(b.x + b.y)) - b.z
		draw_rect(Rect2(b.x, top, b.y, base - top), col)
		# saw-tooth roof on the long halls
		if b.y > 150.0:
			var x := b.x
			while x < b.x + b.y - 10.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x, top + 0.5), Vector2(x + 16, top - 9), Vector2(x + 16, top + 0.5)]), col)
				x += 18.0
	for s in _stacks():
		var base := _hill_y(s.x) + 20.0
		draw_rect(Rect2(s.x - 5, s.y, 10, base - s.y), col)
		draw_rect(Rect2(s.x - 6.5, s.y, 13, 3), col)
	# a gas holder: a drum inside a lattice frame
	var gx := 1600.0
	if gx > cam - 150.0 and gx < cam + w + 150.0:
		var gb := _hill_y(gx) + 20.0
		draw_rect(Rect2(gx - 56, gb - 104, 112, 104), col)
		for k in 7:
			var px := gx - 60.0 + k * 20.0
			draw_line(Vector2(px, gb), Vector2(px, gb - 150), col, 1.4)
		for k in 4:
			var y := gb - 150.0 + k * 15.0
			draw_line(Vector2(gx - 60, y), Vector2(gx + 60, y), col, 1.0)
	# tower cranes
	for cx: float in [560.0, 2050.0]:
		if cx < cam - 200.0 or cx > cam + w + 200.0:
			continue
		var gb := _hill_y(cx) + 10.0
		draw_line(Vector2(cx, gb), Vector2(cx, 400), col, 3.0)
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
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
