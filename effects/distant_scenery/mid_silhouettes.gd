class_name MidSilhouettes
extends Node2D
## Middle layer: high-voltage pylons with sagging lines, a row of swaying poplars,
## and a radio mast with a slow red beacon.

@export var scroll_scale := 0.5
@export var haze := 0.26
@export var pylon_x := PackedFloat32Array([260, 820, 1380, 1940])
@export var mast_x := 1180.0

var _poplars: Array[Vector4] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var x := 40.0
	while x < 2400.0:
		x += rng.randf_range(18, 60)
		if rng.randf() < 0.55:
			_poplars.append(Vector4(x, rng.randf_range(50, 110), rng.randf_range(9, 16), rng.randf() * TAU))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := GameCamera.view_rect.position.x * scroll_scale
	var w := GameCamera.view_rect.size.x
	var col := Color(0, 0, 0, 1.0 - haze)
	for p in _poplars:
		if p.x < cam - 40.0 or p.x > cam + w + 40.0:
			continue
		var sway := -Weather.wind * 7.0 * (0.5 + Weather.gust_at(p.x * 2.0)) + sin(Weather.time * 1.8 + p.w) * 2.0
		var c := Curve2D.new()
		c.add_point(Vector2(p.x - p.z * 0.5, 626), Vector2.ZERO, Vector2(-p.z * 0.4, -p.y * 0.5))
		c.add_point(Vector2(p.x + sway, 626 - p.y), Vector2(-p.z * 0.5, p.y * 0.3), Vector2(p.z * 0.5, p.y * 0.3))
		c.add_point(Vector2(p.x + p.z * 0.5, 626), Vector2(p.z * 0.4, -p.y * 0.5))
		draw_colored_polygon(c.tessellate(3), col)
	draw_rect(Rect2(cam - 20, 624, w + 60, 20), col)
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
		for o in [Vector2(-26, 488), Vector2(26, 488), Vector2(-20, 504), Vector2(20, 504)]:
			var sag := 34.0 + sin(Weather.time * 1.1 + i + o.x) * 2.0 * Weather.wind
			var pts := PackedVector2Array()
			for s in 13:
				var u := s / 12.0
				pts.append(Vector2(lerpf(a, b, u) + o.x, o.y + 4.0 * sag * u * (1.0 - u)))
			draw_polyline(pts, col, 0.9, true)
	draw_polyline(PackedVector2Array([Vector2(mast_x - 7, 626), Vector2(mast_x, 330), Vector2(mast_x + 7, 626)]), col, 1.4)
	if sin(Weather.time * 1.7) > 0.2:
		draw_circle(Vector2(mast_x, 328), 2.4, Color(1.0, 0.18, 0.14))
