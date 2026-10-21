@tool
@icon("res://structures/roof/roof_icon.svg")
class_name Roof
extends StaticBody2D
## A roof to stand on: tiles, wooden shingles or corrugated iron along a line of points (a
## gable, a lean-to, a hipped roof...). The edge shows the courses of tiles, there are gaps
## where tiles are missing and holes with the rafters showing, gutters at the eaves (one
## hanging loose), and optionally a chimney and a weathervane that turns in the wind.
## `profile` is the top surface from left to right, relative to the node.

enum Cladding { TILES, SHINGLES, CORRUGATED }

@export var profile := PackedVector2Array([Vector2(0, 0), Vector2(150, -70), Vector2(300, 0)]):
	set(v):
		profile = v
		_rebuild()
@export var thickness := 14.0:
	set(v):
		thickness = v
		_rebuild()
@export var cladding := Cladding.TILES:
	set(v):
		cladding = v
		_rebuild()
## 0 = sound, 1 = falling in.
@export_range(0.0, 1.0) var damage := 0.3:
	set(v):
		damage = v
		_rebuild()
## Where along the roof the chimney stands (0..1); below 0 for none.
@export_range(-0.05, 1.0) var chimney_at := -0.05:
	set(v):
		chimney_at = v
		_rebuild()
@export var weathervane := false:
	set(v):
		weathervane = v
		queue_redraw()
## Seen from the side a roof is a solid shape down to its eaves; turn off for a thin roof
## (a canopy, a lean-to you can stand under).
@export var solid := true:
	set(v):
		solid = v
		_rebuild()
@export var gutters := true:
	set(v):
		gutters = v
		queue_redraw()
@export var roof_seed := 1:
	set(v):
		roof_seed = v
		_rebuild()
@export var surface := "wood"

var _slab: Array[PackedVector2Array] = []
var _outer := PackedVector2Array()
var _rafters: Array[PackedVector2Array] = []
var _tufts := PackedVector2Array()
var _chimney := PackedVector2Array()
var _ridge := Vector2.ZERO
var _collision: CollisionPolygon2D
var _vane_angle := 0.0
var _flap := 0.0


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	if profile.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = roof_seed
	var course := 7.0 if cladding == Cladding.TILES else (6.0 if cladding == Cladding.SHINGLES else 5.0)
	# the top edge, course by course
	var top := PackedVector2Array()
	var dips: Array[Vector2] = []   # stretches of missing tiles, as [from, to] distances
	var total := 0.0
	for i in profile.size() - 1:
		total += profile[i].distance_to(profile[i + 1])
	var d := rng.randf_range(20, 60)
	while d < total - 20.0:
		if rng.randf() < damage * 0.7:
			dips.append(Vector2(d, d + rng.randf_range(10, 26)))
		d += rng.randf_range(40, 110)
	var run := 0.0
	_tufts.clear()
	_ridge = profile[0]
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if a.y < _ridge.y:
			_ridge = a
		if b.y < _ridge.y:
			_ridge = b
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 0.001)
		var n := Vector2(dir.y, -dir.x)   # outward (up)
		var downhill := 1.0 if dir.y > 0.0 else -1.0
		var steps := maxi(1, int(length / course))
		for k in steps:
			var u0 := float(k) / steps
			var p := a.lerp(b, u0)
			var at := run + length * u0
			var sink := 0.0
			for dp in dips:
				if at > dp.x and at < dp.y:
					sink = thickness * 0.55
			match cladding:
				Cladding.TILES:
					# each course overlaps the next: a small step facing downhill
					top.append(p - n * sink)
					top.append(p + dir * course * (0.8 if downhill > 0.0 else 0.2) + n * (1.8 - sink))
				Cladding.SHINGLES:
					top.append(p - n * sink + n * rng.randf_range(0.0, 0.8))
					top.append(p + dir * course * 0.75 + n * (rng.randf_range(1.0, 2.4) - sink))
				Cladding.CORRUGATED:
					top.append(p + n * (1.3 * sin(at * 1.2) - sink * 0.5))
			if sink == 0.0 and rng.randf() < 0.05 + damage * 0.08 and absf(dir.y) < 0.9:
				_tufts.append(p + n)
		run += length
	top.append(profile[profile.size() - 1])
	# the underside, `thickness` below
	var under := PackedVector2Array()
	if solid:
		under.append(profile[profile.size() - 1] + Vector2(0, thickness))
		under.append(profile[0] + Vector2(0, thickness))
	else:
		for i in range(profile.size() - 1, -1, -1):
			under.append(profile[i] + Vector2(0, thickness))
	_outer = top + under
	# holes through the roof with the rafters showing
	_slab = [_outer]
	_rafters.clear()
	var holes := int(damage * 4.0 + rng.randf() * damage * 2.0)
	for h in holes:
		var i := rng.randi_range(0, profile.size() - 2)
		var a := profile[i]
		var b := profile[i + 1]
		if a.distance_to(b) < 60.0:
			continue
		var c := a.lerp(b, rng.randf_range(0.25, 0.75)) + Vector2(0, thickness * (0.5 if not solid else rng.randf_range(0.8, 2.2)))
		var hole := DrawKit.blob(c, Vector2(rng.randf_range(9, 18), thickness * 0.38), rng.randi(), 0.35, 10, false)
		var next: Array[PackedVector2Array] = []
		for s in _slab:
			next.append_array(Geometry2D.clip_polygons(s, hole))
		_slab = next
		# rafters and battens crossing the hole
		var dir := (b - a).normalized()
		for k in range(-2, 3):
			var rc := c + dir * k * 7.0
			_rafters.append(PackedVector2Array([rc + Vector2(0, -thickness * 0.6), rc + Vector2(0, thickness * 0.6)]))
		_rafters.append(PackedVector2Array([c - dir * 20.0, c + dir * 20.0]))
	# a chimney stack standing on the slope
	_chimney = PackedVector2Array()
	if chimney_at >= 0.0:
		var x := lerpf(profile[0].x, profile[profile.size() - 1].x, chimney_at)
		var y := _surface_at(x)
		var h := 30.0 + rng.randf_range(0, 14)
		_chimney = PackedVector2Array([Vector2(x - 8, y + 4), Vector2(x - 8, y - h), Vector2(x - 10, y - h), Vector2(x - 10, y - h - 4),
			Vector2(x - 3, y - h - 4), Vector2(x - 3, y - h - 10), Vector2(x + 1, y - h - 10), Vector2(x + 1, y - h - 4),
			Vector2(x + 10, y - h - 4), Vector2(x + 10, y - h), Vector2(x + 8, y - h), Vector2(x + 8, y + 4)])
		if damage > 0.5:
			# the top courses of bricks have fallen
			_chimney[3] = Vector2(x - 10, y - h - 1)
			_chimney[8] = Vector2(x + 10, y - h + 3)
	if is_inside_tree():
		if _collision == null:
			_collision = CollisionPolygon2D.new()
			add_child(_collision)
		var shape := PackedVector2Array(profile)
		shape.append_array(under)
		_collision.polygon = shape
	queue_redraw()


func _surface_at(x: float) -> float:
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if x >= a.x and x <= b.x and b.x > a.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return profile[0].y


func get_rain_edges() -> Array:
	var out := []
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if absf(b.y - a.y) < absf(b.x - a.x) * 1.2:
			out.append([global_transform * a, global_transform * b])
	return out


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# the vane swings round to point into the wind, with a little hunting
	var target := 0.0 if Weather.wind >= 0.0 else PI
	_vane_angle = lerp_angle(_vane_angle, target + sin(Weather.time * 1.7) * 0.25 * (1.0 + Weather.gust_at(global_position.x)), delta * 2.0)
	_flap = sin(Weather.time * (5.0 + Weather.wind * 6.0)) * (0.3 + Weather.gust_at(global_position.x)) * Weather.wind
	queue_redraw()


func _draw() -> void:
	if profile.size() < 2:
		return
	var c := Color.BLACK
	for s in _slab:
		if s.size() >= 3:
			draw_colored_polygon(s, c)
	for r in _rafters:
		draw_polyline(r, c, 1.6)
	if _chimney.size() > 0:
		draw_colored_polygon(_chimney, c)
	for t in _tufts:
		for k in 3:
			draw_line(t + Vector2(k * 1.5 - 1.5, 0), t + Vector2(k * 1.5 - 1.5 - Weather.wind * 2.0, -3.0 - (k * 3) % 4), c, 0.9)
	# ridge cap
	if profile.size() >= 3:
		draw_circle(_ridge + Vector2(0, 1), 3.2, c)
	var first := profile[0]
	var last := profile[profile.size() - 1]
	if gutters:
		# a gutter at each eave, the right one broken and hanging
		draw_circle(first + Vector2(-2, thickness - 2), 3.0, c)
		draw_line(first + Vector2(-2, thickness), first + Vector2(-2, thickness + 26), c, 2.0)
		if damage > 0.25:
			var hang := last + Vector2(3, thickness - 2)
			var end := hang + Vector2(14, 30).rotated(_flap * 0.15)
			draw_line(hang, end, c, 3.0)
		else:
			draw_circle(last + Vector2(2, thickness - 2), 3.0, c)
	if cladding == Cladding.CORRUGATED and damage > 0.2:
		# a loose sheet at the low end lifting in the gusts
		var e := last
		var dir := (profile[profile.size() - 2] - last).normalized()
		var lift := Vector2(0, -1).rotated(_flap * 0.6)
		var hinge := e + dir * 22.0
		var tip := e + dir * 2.0 + lift * (3.0 + 9.0 * absf(_flap))
		draw_polyline(PackedVector2Array([hinge, hinge.lerp(tip, 0.5) + lift * 1.5, tip]), c, 2.6)
	if weathervane:
		var base := _ridge + Vector2(0, -2)
		var top := base + Vector2(0, -34)
		draw_line(base, top, c, 1.6)
		draw_line(top + Vector2(-6, 8), top + Vector2(6, 8), c, 1.0)
		draw_line(top + Vector2(0, 2), top + Vector2(0, 14), c, 1.0)
		# the cockerel, turning
		var face := cos(_vane_angle)
		var ck := PackedVector2Array([Vector2(-9, 0), Vector2(-4, -3), Vector2(1, -2), Vector2(4, -8), Vector2(7, -7), Vector2(6, -3), Vector2(9, -1),
			Vector2(4, 1), Vector2(-2, 2), Vector2(-8, 6), Vector2(-7, 1)])
		for i in ck.size():
			ck[i] = top + Vector2(ck[i].x * face, ck[i].y - 2.0)
		if absf(face) > 0.15:
			draw_colored_polygon(ck, c)
		else:
			draw_line(top + Vector2(0, -10), top + Vector2(0, 6), c, 2.0)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	if _outer.size() > 2:
		return _editor_bbox(_outer)
	return _editor_bbox(profile).grow_side(SIDE_BOTTOM, thickness)


func _editor_hit(p: Vector2) -> DrawKit.EditorHit:
	return DrawKit.EditorHit.SHAPE if _outer.size() > 2 and Geometry2D.is_point_in_polygon(p, _outer) else DrawKit.EditorHit.MISS


static func _editor_bbox(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO) if pts.size() > 0 else Rect2()
	for q in pts:
		r = r.expand(q)
	return r
