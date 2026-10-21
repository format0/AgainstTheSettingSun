@tool
@icon("res://structures/terrain/terrain_icon.svg")
class_name Terrain
extends StaticBody2D
## Natural ground: hills, banks, ravines and cliffs, drawn as one black shape along a line
## of points. Grows grass where it is not too steep, and stones and roots along the edge.
## `points` is the top surface from left to right (relative to the node); the shape is
## closed downwards to `bottom`. Edit the points in the Inspector or with the handles.

@export var points := PackedVector2Array([Vector2(0, 0), Vector2(300, 0)]):
	set(v):
		points = v
		_rebuild()
## How far below the node the shape reaches.
@export var bottom := 400.0:
	set(v):
		bottom = v
		_rebuild()
@export var grass := true:
	set(v):
		grass = v
		_rebuild()
@export_range(0.0, 1.0) var grass_height := 0.7:
	set(v):
		grass_height = v
		_rebuild()
## Stones, roots and clumps along the edge.
@export var edge_detail := true:
	set(v):
		edge_detail = v
		_rebuild()
@export var detail_seed := 1:
	set(v):
		detail_seed = v
		_rebuild()
## Footstep sound: grass, dirt, stone, wood, metal. Empty = the level's ground surface.
@export var surface := ""

var _poly := PackedVector2Array()
var _details: Array[PackedVector2Array] = []
var _roots: Array[PackedVector2Array] = []
var _collision: CollisionPolygon2D
var _grass: GrassField


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	if points.size() < 2:
		return
	_poly = PackedVector2Array()
	if not is_equal_approx(points[0].y, bottom):
		_poly.append(Vector2(points[0].x, bottom))
	_poly.append_array(points)
	if not is_equal_approx(points[points.size() - 1].y, bottom):
		_poly.append(Vector2(points[points.size() - 1].x, bottom))
	var rng := RandomNumberGenerator.new()
	rng.seed = detail_seed
	_details.clear()
	_roots.clear()
	if edge_detail:
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var length := a.distance_to(b)
			var dir := (b - a) / maxf(length, 0.001)
			var steep := absf(dir.y) > 0.6
			var d := rng.randf_range(4, 20)
			while d < length - 4.0:
				var p := a + dir * d
				if steep:
					# roots and stones poking out of a bank
					if rng.randf() < 0.5:
						var out := Vector2(-dir.y, dir.x) * signf(dir.y) * -1.0
						var tip := p + (out * rng.randf_range(6, 14) + Vector2(0, rng.randf_range(2, 10)))
						_roots.append(PackedVector2Array([p, p.lerp(tip, 0.5) + Vector2(0, 2), tip]))
					else:
						_details.append(DrawKit.blob(p, Vector2(rng.randf_range(3, 7), rng.randf_range(3, 5)), rng.randi(), 0.3, 9, false))
					d += rng.randf_range(10, 24)
				else:
					# pebbles and clods sitting on the surface
					var r := Vector2(rng.randf_range(2.5, 6.0), rng.randf_range(1.6, 3.5))
					_details.append(DrawKit.blob(p - Vector2(0, r.y * 0.5), r, rng.randi(), 0.3, 9, true))
					d += rng.randf_range(18, 60)
	if not is_inside_tree():
		return
	if _collision == null:
		_collision = CollisionPolygon2D.new()
		add_child(_collision)
	_collision.polygon = _poly
	if grass and _grass == null:
		_grass = GrassField.new()
		_grass.z_as_relative = false
		_grass.z_index = Layers.GRASS
		add_child(_grass)
	elif not grass and _grass:
		_grass.queue_free()
		_grass = null
	if _grass:
		_grass.position = Vector2(points[0].x, 0)
		_grass.height_max = 26.0 * grass_height
		_grass.height_min = 3.0 * grass_height
		_grass.tall_height = Vector2(26, 58) * grass_height
		var prof := PackedVector2Array()
		for p in points:
			prof.append(p - Vector2(points[0].x, 0))
		_grass.width = points[points.size() - 1].x - points[0].x
		_grass.grass_seed = detail_seed
		_grass.profile = prof
	queue_redraw()


## World y of the surface at a world x (the highest edge there), or NAN outside.
func surface_y(world_x: float) -> float:
	var x := world_x - global_position.x
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if x >= minf(a.x, b.x) and x <= maxf(a.x, b.x) and a.x != b.x:
			return global_position.y + lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return NAN


func get_rain_edges() -> Array:
	var out := []
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if absf(b.y - a.y) < absf(b.x - a.x):
			out.append([global_transform * a, global_transform * b])
	return out


func _draw() -> void:
	if _poly.size() < 3:
		return
	var c := Color.BLACK
	draw_colored_polygon(_poly, c)
	for d in _details:
		draw_colored_polygon(d, c)
	for r in _roots:
		draw_polyline(r, c, 2.0)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	if _poly.size() > 2:
		return _editor_bbox(_poly)
	return _editor_bbox(points).grow_side(SIDE_BOTTOM, bottom)


func _editor_hit(p: Vector2) -> DrawKit.EditorHit:
	return DrawKit.EditorHit.SHAPE if _poly.size() > 2 and Geometry2D.is_point_in_polygon(p, _poly) else DrawKit.EditorHit.MISS


static func _editor_bbox(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO) if pts.size() > 0 else Rect2()
	for q in pts:
		r = r.expand(q)
	return r
