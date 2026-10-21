class_name MidSilhouettes
extends Node2D
## Middle layer: closer and darker than the far one. Rows of poplars and a barn in the
## fields; pylons, a rail bridge and silos at the works; dark firs and rock needles at the
## quarry. Trees sway in the wind.

@export var scroll_scale := 0.5
## The colour of the nearer haze (multiplied by the remaining daylight).
@export var tint := Color(0.09, 0.036, 0.03)
@export var setting := DistantScenery.Setting.INDUSTRY
@export var pylon_x := PackedFloat32Array([260, 820, 1380, 1940])
@export var mast_x := 1180.0

var _trees: Array[Vector4] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var x := 40.0
	while x < 2600.0:
		x += rng.randf_range(14, 60) if setting != DistantScenery.Setting.QUARRY else rng.randf_range(8, 30)
		if rng.randf() < 0.55:
			_trees.append(Vector4(x, rng.randf_range(50, 110), rng.randf_range(9, 16), rng.randf() * TAU))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := GameCamera.view_rect.position.x * scroll_scale
	var w := GameCamera.view_rect.size.x
	var col := Color(tint * (0.3 + 0.7 * Daylight.light()) * VFX.v("haze"), 1.0)
	match setting:
		DistantScenery.Setting.FIELDS:
			_poplars(cam, w, col, 1.0)
			_barn(1500.0, cam, w, col)
			_wooden_poles(cam, w, col)
		DistantScenery.Setting.INDUSTRY:
			_poplars(cam, w, col, 0.5)
			_pylons(cam, w, col)
			_silos(cam, w, col)
		DistantScenery.Setting.QUARRY:
			_firs(cam, w, col)
			_needles(cam, w, col)
	# the land runs on below the horizon, so gaps in the near ground (a creek, a pit) show it, not sky
	draw_rect(Rect2(cam - 20, 624, w + 60, 260), col)


func _poplars(cam: float, w: float, col: Color, share: float) -> void:
	for i in _trees.size():
		var p := _trees[i]
		if p.x < cam - 40.0 or p.x > cam + w + 40.0 or fmod(i * 0.618, 1.0) > share:
			continue
		var sway := -Weather.wind * 7.0 * (0.5 + Weather.gust_at(p.x * 2.0)) + sin(Weather.time * 1.8 + p.w) * 2.0
		var c := Curve2D.new()
		c.add_point(Vector2(p.x - p.z * 0.5, 626), Vector2.ZERO, Vector2(-p.z * 0.4, -p.y * 0.5))
		c.add_point(Vector2(p.x + sway, 626 - p.y), Vector2(-p.z * 0.5, p.y * 0.3), Vector2(p.z * 0.5, p.y * 0.3))
		c.add_point(Vector2(p.x + p.z * 0.5, 626), Vector2(p.z * 0.4, -p.y * 0.5))
		draw_colored_polygon(c.tessellate(3), col)


func _firs(cam: float, w: float, col: Color) -> void:
	for p in _trees:
		if p.x < cam - 40.0 or p.x > cam + w + 40.0:
			continue
		var h := p.y * 0.9
		var sway := -Weather.wind * 4.0 * (0.5 + Weather.gust_at(p.x * 2.0)) + sin(Weather.time * 1.5 + p.w) * 1.5
		var pts := PackedVector2Array([Vector2(p.x - 2, 628)])
		var tiers := 5
		for k in tiers:
			var u0 := float(k) / tiers
			var y := 628.0 - h * (0.15 + u0 * 0.8)
			var half := p.z * (1.0 - u0 * 0.8)
			pts.append(Vector2(p.x - half + sway * u0, y + 4))
			pts.append(Vector2(p.x - half * 0.4 + sway * u0, y - 4))
		pts.append(Vector2(p.x + sway, 628.0 - h))
		for k in range(tiers - 1, -1, -1):
			var u0 := float(k) / tiers
			var y := 628.0 - h * (0.15 + u0 * 0.8)
			var half := p.z * (1.0 - u0 * 0.8)
			pts.append(Vector2(p.x + half * 0.4 + sway * u0, y - 4))
			pts.append(Vector2(p.x + half + sway * u0, y + 4))
		pts.append(Vector2(p.x + 2, 628))
		draw_colored_polygon(pts, col)


func _needles(cam: float, w: float, col: Color) -> void:
	# weathered crags standing out of the forest: broad at the foot, broken along the top
	for nx: float in [300.0, 760.0, 1250.0, 1900.0, 2400.0]:
		if nx < cam - 160.0 or nx > cam + w + 160.0:
			continue
		var h := 70.0 + fmod(nx * 0.37, 60.0)
		var half := 70.0 + fmod(nx * 0.53, 50.0)
		var pts := PackedVector2Array([Vector2(nx - half, 630)])
		var n := 14
		for i in range(1, n):
			var u := float(i) / n
			var x := lerpf(-half, half, u)
			var body := pow(sin(u * PI), 0.7) * h
			var crag := (sin(u * 23.0 + nx) * 0.5 + sin(u * 51.0 + nx * 0.3) * 0.3) * 9.0 * sin(u * PI)
			pts.append(Vector2(nx + x, 630.0 - body - crag))
		pts.append(Vector2(nx + half, 630))
		draw_colored_polygon(pts, col)
		# a few firs clinging to the top
		for k in 3:
			var fx := nx + (fmod(nx * (k + 1) * 0.31, 1.0) - 0.5) * half
			var fu := (fx - nx + half) / (2.0 * half)
			var fy := 630.0 - pow(sin(fu * PI), 0.7) * h + 3.0
			var fh := 16.0 + k * 5.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx - fh * 0.28, fy), Vector2(fx, fy - fh), Vector2(fx + fh * 0.28, fy)]), col)


func _barn(bx: float, cam: float, w: float, col: Color) -> void:
	if bx < cam - 150.0 or bx > cam + w + 150.0:
		return
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 60, 626), Vector2(bx - 60, 580), Vector2(bx - 40, 556), Vector2(bx, 546), Vector2(bx + 40, 556), Vector2(bx + 60, 580), Vector2(bx + 60, 626)]), col)
	draw_rect(Rect2(bx + 60, 596, 40, 30), col)
	# a silo with a dome
	draw_rect(Rect2(bx - 92, 540, 24, 86), col)
	DrawKit.ellipse(self, Vector2(bx - 80, 540), Vector2(12, 9), 0.0, col, 12)


func _wooden_poles(cam: float, w: float, col: Color) -> void:
	var prev := Vector2.ZERO
	var x := floorf((cam - 200.0) / 180.0) * 180.0
	while x < cam + w + 200.0:
		var top := Vector2(x, 560)
		draw_line(Vector2(x, 626), top, col, 2.0)
		draw_line(top + Vector2(-10, 4), top + Vector2(10, 4), col, 1.6)
		if prev != Vector2.ZERO:
			DrawKit.rope(self, prev + Vector2(-9, 4), top + Vector2(-9, 4), 12.0 + sin(Weather.time * 1.3 + x) * Weather.wind, 0.8, col, 10)
			DrawKit.rope(self, prev + Vector2(9, 4), top + Vector2(9, 4), 12.0 + sin(Weather.time * 1.1 + x) * Weather.wind, 0.8, col, 10)
		prev = top
		x += 180.0


func _pylons(cam: float, w: float, col: Color) -> void:
	for x in pylon_x:
		if x < cam - 320.0 or x > cam + w + 320.0:
			continue
		var top := 470.0
		draw_polyline(PackedVector2Array([Vector2(x - 18, 626), Vector2(x - 3, top), Vector2(x + 3, top), Vector2(x + 18, 626)]), col, 1.4)
		var y := 626.0
		while y > top + 12.0:
			var k0 := (626.0 - y) / (626.0 - top)
			var k1 := minf(1.0, (626.0 - y + 22.0) / (626.0 - top))
			var w0 := 18.0 - 15.0 * k0
			var w1 := 18.0 - 15.0 * k1
			draw_line(Vector2(x - w0, y), Vector2(x + w1, y - 22), col, 1.2)
			draw_line(Vector2(x + w0, y), Vector2(x - w1, y - 22), col, 1.2)
			y -= 22.0
		draw_line(Vector2(x - 26, top + 18), Vector2(x + 26, top + 18), col, 1.4)
		draw_line(Vector2(x - 20, top + 34), Vector2(x + 20, top + 34), col, 1.4)
	for i in pylon_x.size() - 1:
		var a := pylon_x[i]
		var b := pylon_x[i + 1]
		for o: Vector2 in [Vector2(-26, 488), Vector2(26, 488), Vector2(-20, 504), Vector2(20, 504)]:
			var sag := 34.0 + sin(Weather.time * 1.1 + i + o.x) * 2.0 * Weather.wind
			var pts := PackedVector2Array()
			for s in 13:
				var u := s / 12.0
				pts.append(Vector2(lerpf(a, b, u) + o.x, o.y + 4.0 * sag * u * (1.0 - u)))
			draw_polyline(pts, col, 0.9, true)
	draw_polyline(PackedVector2Array([Vector2(mast_x - 7, 626), Vector2(mast_x, 330), Vector2(mast_x + 7, 626)]), col, 1.4)
	if sin(Weather.time * 1.7) > 0.2:
		draw_circle(Vector2(mast_x, 328), 2.4, Color(1.0, 0.18, 0.14))


func _silos(cam: float, w: float, col: Color) -> void:
	for sx: float in [600.0, 1650.0]:
		if sx < cam - 200.0 or sx > cam + w + 200.0:
			continue
		for k in 3:
			var x := sx + k * 30.0
			draw_rect(Rect2(x, 520, 26, 106), col)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 520), Vector2(x + 26, 520), Vector2(x + 13, 508)]), col)
		draw_rect(Rect2(sx - 6, 500, 100, 6), col)
		draw_line(Vector2(sx + 90, 503), Vector2(sx + 170, 600), col, 4.0)
