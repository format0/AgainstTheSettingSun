@tool
@icon("res://cover/ruined_wall/ruined_wall_icon.svg")
class_name RuinedWall
extends Cover
## What is left of an old brick wall or a house's end wall: a broken top that falls away brick
## by brick, toothed edges, arched windows with what is left of their frames, missing bricks,
## charred beams, ivy and hanging weeds. With `gable` it rises to a peak like the end of a
## house. The node's position is the bottom-left corner.
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
## A gable end: the wall rises to a peak this high above `size.y` in the middle (0 = none).
@export var gable := 0.0:
	set(v):
		gable = v
		_rebuild()
## Ivy growing over the wall (0..1).
@export_range(0.0, 1.0) var ivy := 0.3:
	set(v):
		ivy = v
		_rebuild()

var _polys: Array[PackedVector2Array] = []
var _rubble: Array[PackedVector2Array] = []
var _weed_points := PackedVector2Array()
var _bars: Array[PackedVector2Array] = []
var _beams: Array[PackedVector2Array] = []
var _ivy: Array[PackedVector2Array] = []


func _ready() -> void:
	z_index = Layers.COVER
	_rebuild()


## The height of the intact wall at x (with the gable).
func _full_height(x: float) -> float:
	return size.y + gable * (1.0 - absf(2.0 * x / size.x - 1.0))


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wall_seed
	var brick := 7.0
	# a few heights along the wall (as a share of the full height); between them the
	# masonry has fallen away in brick steps, with single bricks sticking out of the edge
	var keys: Array[Vector2] = []
	var kx := 0.0
	while kx < size.x:
		var full := rng.randf() > crumble * 0.85
		var f := rng.randf_range(0.97, 1.0) if full else rng.randf_range(maxf(0.25, 1.0 - crumble * 1.3), 0.8)
		if crumble <= 0.0:
			f = 1.0
		keys.append(Vector2(kx, f))
		kx += rng.randf_range(35, 90)
	keys.append(Vector2(size.x, 1.0 if crumble <= 0.0 else rng.randf_range(0.5, 1.0)))
	var top := PackedVector2Array()
	_weed_points.clear()
	_beams.clear()
	var x := 0.0
	var ki := 0
	while x < size.x - 0.01:
		var x1 := minf(x + rng.randf_range(6.0, 11.0), size.x)
		while ki < keys.size() - 2 and keys[ki + 1].x <= x:
			ki += 1
		var a := keys[ki]
		var b := keys[ki + 1]
		var f := lerpf(a.y, b.y, clampf(((x + x1) * 0.5 - a.x) / maxf(b.x - a.x, 1.0), 0.0, 1.0))
		if f >= 0.96:
			# intact: the true line of the wall or the gable, with the odd chipped brick
			var chip := brick * 0.6 if rng.randf() < crumble * 0.3 else 0.0
			top.append(Vector2(x, -_full_height(x) + chip))
			top.append(Vector2(x1, -_full_height(x1) + chip))
		else:
			var h := roundf(f * _full_height((x + x1) * 0.5) / brick) * brick
			if rng.randf() < 0.2:
				h += brick
			# a brick sticking out sideways at the corner of a step
			var jut := rng.randf_range(-1.5, 2.5)
			top.append(Vector2(x + jut, -h))
			top.append(Vector2(x1, -h))
			if rng.randf() < 0.2:
				_weed_points.append(Vector2((x + x1) * 0.5, -h))
			if rng.randf() < 0.035 and h > 40.0:
				# a charred beam end sticking out of the break
				var ang := rng.randf_range(-2.4, -0.7)
				var l := rng.randf_range(16, 32)
				var bp := Vector2((x + x1) * 0.5, -h + 6.0)
				var d := Vector2.from_angle(ang)
				var nn := d.orthogonal() * 2.2
				_beams.append(PackedVector2Array([bp - nn, bp + d * l - nn * 0.6, bp + d * (l + 3.0), bp + d * l + nn * 0.6, bp + nn]))
		x = x1
	# the sides: straight and plinthed where the wall stands, toothed brick by brick where it broke
	var left_h := -top[0].y
	var right_h := -top[top.size() - 1].y
	var wall := PackedVector2Array([Vector2(-3, 0), Vector2(-3, -10), Vector2(0, -11)])
	if crumble > 0.25:
		var y := 14.0
		var k := 0
		while y < left_h - brick:
			if y > left_h * 0.45:
				wall.append(Vector2(0.0 if k % 2 == 0 else 3.0, -y))
				wall.append(Vector2(0.0 if k % 2 == 0 else 3.0, -y - brick))
			y += brick
			k += 1
	wall.append_array(top)
	var right := PackedVector2Array()
	if crumble > 0.25:
		var y := 14.0
		var k := 0
		while y < right_h - brick:
			if y > right_h * 0.45:
				right.append(Vector2(size.x - (0.0 if k % 2 == 0 else 3.0), -y))
				right.append(Vector2(size.x - (0.0 if k % 2 == 0 else 3.0), -y - brick))
			y += brick
			k += 1
		right.reverse()
	wall.append_array(right)
	wall.append_array(PackedVector2Array([Vector2(size.x, -11), Vector2(size.x + 3, -10), Vector2(size.x + 3, 0)]))
	var holes: Array[PackedVector2Array] = []
	_bars.clear()
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
		# the old window frame: a cross of glazing bars, broken in a ruin
		var arch_top := bottom - wh - ww * 0.5
		if rng.randf() > crumble * 0.7:
			_bars.append(PackedVector2Array([Vector2(cx, bottom), Vector2(cx, arch_top)]))
		else:
			_bars.append(PackedVector2Array([Vector2(cx, bottom), Vector2(cx + rng.randf_range(-3, 3), bottom - wh * rng.randf_range(0.3, 0.6))]))
		var hy := bottom - wh * 0.55
		if rng.randf() > crumble * 0.5:
			_bars.append(PackedVector2Array([Vector2(cx - ww * 0.5, hy), Vector2(cx + ww * 0.5, hy)]))
		else:
			_bars.append(PackedVector2Array([Vector2(cx - ww * 0.5, hy), Vector2(cx - ww * 0.1, hy + 4.0)]))
		_bars.append(PackedVector2Array([Vector2(cx - ww * 0.5, bottom - 2.0), Vector2(cx + ww * 0.5, bottom - 2.0)]))
		if crumble < 0.3:
			holes.append(hole)
			continue
		# a crack from the arch up through the top, so the window is a notch, not a hole
		var crack := PackedVector2Array()
		var cy := bottom - wh - ww * 0.45
		var zig := 0.0
		var left := PackedVector2Array()
		var rgt := PackedVector2Array()
		while cy > -size.y - gable - 20.0:
			left.append(Vector2(cx + zig - 0.8, cy))
			rgt.append(Vector2(cx + zig + 0.8, cy))
			cy -= 6.0
			zig += rng.randf_range(-2.5, 2.5)
		crack.append_array(left)
		rgt.reverse()
		crack.append_array(rgt)
		var merged := Geometry2D.merge_polygons(hole, crack)
		holes.append(merged[0] if merged.size() > 0 else hole)
	if gable > 30.0:
		# a round window high in the gable
		holes.append(DrawKit.ellipse_points(Vector2(size.x * 0.5, -size.y - gable * 0.35), Vector2(7, 7), 0.0, 14))
		_bars.append(PackedVector2Array([Vector2(size.x * 0.5 - 7, -size.y - gable * 0.35), Vector2(size.x * 0.5 + 7, -size.y - gable * 0.35)]))
	# missing bricks near the top, letting the sky through
	for i in int(size.x / 30.0 * (0.3 + crumble)):
		var bx := rng.randf_range(8, size.x - 16)
		var by := -_full_height(bx) * rng.randf_range(0.62, 0.9)
		var r := Rect2(bx, by, 6.0 if rng.randf() < 0.6 else 10.0, 3.5)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var inside := true
		for cp in corners:
			if not Geometry2D.is_point_in_polygon(cp + Vector2(0, -3), wall) or not Geometry2D.is_point_in_polygon(cp + Vector2(0, 3), wall):
				inside = false
		if inside:
			holes.append(PackedVector2Array(corners))
	_rubble.clear()
	for i in int(crumble * 10.0):
		var rx := rng.randf_range(-20, size.x + 20) if rng.randf() < 0.5 else (rng.randf_range(-24, 6) if rng.randf() < 0.5 else rng.randf_range(size.x - 6, size.x + 24))
		_rubble.append(DrawKit.blob(Vector2(rx, -2), Vector2(rng.randf_range(4, 9), rng.randf_range(3, 6)), rng.randi(), 0.4, 7, true))
	_polys = [wall]
	# a polygon can't have holes, so cut the wall into strips through the middle of each one
	for h in holes:
		var cx := 0.0
		for q in h:
			cx += q.x
		cx /= h.size()
		var next: Array[PackedVector2Array] = []
		for p in _polys:
			for half in [Rect2(-100, -2000, cx + 100, 3000), Rect2(cx, -2000, size.x + 200 - cx, 3000)]:
				var r: Rect2 = half
				next.append_array(Geometry2D.intersect_polygons(p, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])))
		_polys = next
	for h in holes:
		var next: Array[PackedVector2Array] = []
		for p in _polys:
			next.append_array(Geometry2D.clip_polygons(p, h))
		_polys = next
	# ivy climbing one corner and spilling over the top
	_ivy.clear()
	var ivy_side := 0.0 if rng.randf() < 0.5 else size.x
	for i in int(ivy * 14.0):
		var u := rng.randf()
		var p: Vector2
		if rng.randf() < 0.6:
			p = Vector2(ivy_side + rng.randf_range(-3, 3), -left_h * u * 0.9 if ivy_side == 0.0 else -right_h * u * 0.9)
		else:
			var tx := clampf(ivy_side + (rng.randf_range(0, 60) if ivy_side == 0.0 else -rng.randf_range(0, 60)), 0.0, size.x)
			p = Vector2(tx, _top_at(top, tx) + rng.randf_range(-2, 4))
		var poly := DrawKit.foliage(Vector2(rng.randf_range(4, 8), rng.randf_range(3.5, 6.5)), rng.randi(), 2.4)
		for k in poly.size():
			poly[k] += p
		_ivy.append(poly)
	queue_redraw()


func _top_at(top: PackedVector2Array, x: float) -> float:
	for i in top.size() - 1:
		if x >= top[i].x and x <= top[i + 1].x:
			return top[i].y
	return top[top.size() - 1].y


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
	for b in _bars:
		draw_polyline(b, Color.BLACK, 1.6)
	for b in _beams:
		draw_colored_polygon(b, Color.BLACK)
	for v in _ivy:
		draw_colored_polygon(v, Color.BLACK)
	if weeds:
		for i in _weed_points.size():
			var w := _weed_points[i]
			DrawKit.vine(self, w, 10.0 + (i * 7) % 18, i * 1.7)
			for k in 4:
				var bend := -Weather.wind * 4.0 * (0.5 + Weather.gust_at(global_position.x + w.x))
				draw_line(w + Vector2(k * 2 - 3, 0), w + Vector2(k * 2 - 3 + bend, -6.0 - (k * 5) % 7), Color.BLACK, 1.0)
	_draw_cover_outline()

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(0, -size.y - gable, size.x, size.y + gable)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(size.x, -size.y)}, {"id": "gable", "pos": Vector2(size.x * 0.5, -size.y - gable)}]


func _editor_drag(id: Variant, p: Vector2) -> void:
	if id == "size":
		size = Vector2(maxf(40.0, p.x), maxf(30.0, -p.y))
	else:
		gable = maxf(0.0, -p.y - size.y)
