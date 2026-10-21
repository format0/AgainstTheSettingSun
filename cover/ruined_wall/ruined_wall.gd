@tool
@icon("res://cover/ruined_wall/ruined_wall_icon.svg")
class_name RuinedWall
extends Cover
## What is left of an old brick wall: a broken, stepped top, arched windows that let the
## sky through, cracks and hanging weeds. The node's position is the bottom-left corner.
## The player hides in front of the wall but not in front of a window.

@export var size := Vector2(220, 150):
	set(v):
		size = v
		_rebuild()
## 0 = an intact wall with a straight top (inside a building), 1 = mostly fallen down.
@export_range(0.0, 1.0) var crumble := 0.5:
	set(v):
		crumble = v
		_rebuild()
@export_range(0, 4) var windows := 1:
	set(v):
		windows = v
		_rebuild()
@export var wall_seed := 3:
	set(v):
		wall_seed = v
		_rebuild()
@export var weeds := true

var _polys: Array[PackedVector2Array] = []
var _rubble: Array[PackedVector2Array] = []
var _weed_points := PackedVector2Array()


func _ready() -> void:
	z_index = Layers.COVER
	_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wall_seed
	var brick := 7.0
	# a few heights along the wall; between them the masonry has fallen away in
	# brick steps, with single bricks sticking out of the broken edge
	var keys: Array[Vector2] = []
	var kx := 0.0
	while kx < size.x:
		var full := rng.randf() > crumble * 0.85
		var h := size.y * (rng.randf_range(0.9, 1.0) if full else rng.randf_range(maxf(0.25, 1.0 - crumble * 1.3), 0.8))
		if crumble <= 0.0:
			h = size.y
		keys.append(Vector2(kx, h))
		kx += rng.randf_range(35, 90)
	keys.append(Vector2(size.x, size.y * rng.randf_range(0.5, 1.0)))
	var top := PackedVector2Array()
	_weed_points.clear()
	for i in keys.size() - 1:
		var a := keys[i]
		var b := keys[i + 1]
		var steps := maxi(1, int(absf(b.y - a.y) / brick))
		var step_w := (b.x - a.x) / steps
		for k in steps:
			var x0 := a.x + k * step_w
			var x1 := minf(a.x + (k + 1) * step_w, size.x)
			var h := roundf(lerpf(a.y, b.y, (k + 0.5) / steps) / brick) * brick
			if rng.randf() < 0.18:
				h += brick
			top.append(Vector2(x0, -h))
			top.append(Vector2(x1, -h))
			if rng.randf() < 0.2:
				_weed_points.append(Vector2((x0 + x1) * 0.5, -h))
	var wall := PackedVector2Array([Vector2(0, 0)])
	wall.append_array(top)
	wall.append(Vector2(size.x, 0))
	var holes: Array[PackedVector2Array] = []
	for i in windows:
		var cx := size.x * (i + 1.0) / (windows + 1.0) + rng.randf_range(-10, 10)
		var bottom := -maxf(62.0, size.y * 0.42)
		var ww := rng.randf_range(20, 28)
		var wh := minf(46.0, size.y * 0.35)
		var hole := PackedVector2Array([Vector2(cx - ww * 0.5, bottom), Vector2(cx + ww * 0.5, bottom), Vector2(cx + ww * 0.5, bottom - wh)])
		for k in range(1, 8):
			var a := k * PI / 8.0
			hole.append(Vector2(cx + cos(a) * ww * 0.5, bottom - wh - sin(a) * ww * 0.5))
		hole.append(Vector2(cx - ww * 0.5, bottom - wh))
		# a crack from the arch up through the top, so the window is a notch, not a hole
		var crack := PackedVector2Array()
		var cy := bottom - wh - ww * 0.45
		var zig := 0.0
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		while cy > -size.y - 20.0:
			left.append(Vector2(cx + zig - 0.8, cy))
			right.append(Vector2(cx + zig + 0.8, cy))
			cy -= 6.0
			zig += rng.randf_range(-2.5, 2.5)
		crack.append_array(left)
		right.reverse()
		crack.append_array(right)
		var merged := Geometry2D.merge_polygons(hole, crack)
		holes.append(merged[0] if merged.size() > 0 else hole)
	_rubble.clear()
	for i in int(crumble * 10.0):
		var rx := rng.randf_range(-20, size.x + 20) if rng.randf() < 0.5 else (rng.randf_range(-24, 6) if rng.randf() < 0.5 else rng.randf_range(size.x - 6, size.x + 24))
		_rubble.append(DrawKit.blob(Vector2(rx, -2), Vector2(rng.randf_range(4, 9), rng.randf_range(3, 6)), rng.randi(), 0.4, 7, true))
	_polys = [wall]
	for h in holes:
		var next: Array[PackedVector2Array] = []
		for p in _polys:
			next.append_array(Geometry2D.clip_polygons(p, h))
		_polys = next
	queue_redraw()


func _cover_shapes() -> Array[PackedVector2Array]:
	return _polys


func _process(_delta: float) -> void:
	if weeds and not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	for p in _polys:
		if p.size() >= 3:
			draw_colored_polygon(p, Color.BLACK)
	for r in _rubble:
		draw_colored_polygon(r, Color.BLACK)
	if weeds:
		for i in _weed_points.size():
			var w := _weed_points[i]
			DrawKit.vine(self, w, 10.0 + (i * 7) % 18, i * 1.7)
			for k in 4:
				var bend := -Weather.wind * 4.0 * (0.5 + Weather.gust_at(global_position.x + w.x))
				draw_line(w + Vector2(k * 2 - 3, 0), w + Vector2(k * 2 - 3 + bend, -6.0 - (k * 5) % 7), Color.BLACK, 1.0)
	_draw_cover_outline()
