@tool
@icon("res://cover/rock_face/rock_face_icon.svg")
class_name RockFace
extends Cover
## A big weathered rock standing behind the path: hard facets, overhanging strata, cracks,
## scree at its foot, tufts of grass and a crooked shrub on top. The node's position is the middle of its foot.

@export var size := Vector2(170, 120):
	set(v):
		size = v
		_rebuild()
@export var rock_seed := 5:
	set(v):
		rock_seed = v
		_rebuild()
@export var shrub := true:
	set(v):
		shrub = v
		queue_redraw()

var _rock := PackedVector2Array()
var _tufts := PackedVector2Array()
var _scree: Array[PackedVector2Array] = []
var _crown: Array[PackedVector2Array] = []


func _ready() -> void:
	z_index = Layers.COVER
	_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	_rock = DrawKit.rock_outline(size, rock_seed, 2, 2)
	_tufts.clear()
	for i in range(4, _rock.size() - 4, 3):
		if rng.randf() < 0.45 and _rock[i].y < -size.y * 0.5:
			_tufts.append(_rock[i])
	# scree at the foot
	_scree.clear()
	for i in 6:
		var x := rng.randf_range(-size.x * 0.65, size.x * 0.65)
		if absf(x) < size.x * 0.42:
			continue
		var r := Vector2(rng.randf_range(3, 7), rng.randf_range(2, 4))
		_scree.append(DrawKit.blob(Vector2(x, -r.y * 0.5), r, rng.randi(), 0.3, 8, true))
	_crown.clear()
	_crown.append(DrawKit.foliage(Vector2(15, 6.5), rock_seed * 3 + 1, 2.2))
	_crown.append(DrawKit.foliage(Vector2(11, 5), rock_seed * 3 + 2, 2.0))
	queue_redraw()


func _cover_shapes() -> Array[PackedVector2Array]:
	return [_rock]


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_rock, Color.BLACK)
	var gx := global_position.x
	for i in _tufts.size():
		var p := _tufts[i]
		for k in 6:
			var bend := -Weather.wind * (3.0 + k) * (0.4 + Weather.gust_at(gx + p.x)) + sin(Weather.time * 5.0 + k + i) * Weather.wind
			draw_line(p + Vector2(k * 2.0 - 5.0, 2.0), p + Vector2(k * 2.0 - 5.0 + bend, -5.0 - (k * 7 + i * 3) % 9), Color.BLACK, 1.1)
	for sc in _scree:
		draw_colored_polygon(sc, Color.BLACK)
	if shrub and _rock.size() > 8:
		# a crooked little tree clinging to the top of the rock
		var base := _rock[0]
		for p in _rock:
			if p.y < base.y:
				base = p
		base += Vector2(4, 2)
		var sway := -Weather.wind * 4.0 * (0.5 + Weather.gust_at(gx + base.x)) + sin(Weather.time * 1.9) * 1.5 * Weather.wind
		var fork := base + Vector2(2, -11)
		var top := base + Vector2(9 + sway * 0.5, -25)
		var side := base + Vector2(-13 + sway, -20)
		DrawKit.limb(self, base, fork, 4.0, 3.0)
		DrawKit.limb(self, fork, top, 3.0, 1.4)
		DrawKit.limb(self, fork, side, 2.0, 0.8)
		var flick := sin(Weather.time * 6.0) * 0.6 * Weather.wind
		draw_set_transform(top + Vector2(sway * 0.3, -3 + flick))
		draw_colored_polygon(_crown[0], Color.BLACK)
		draw_set_transform(side + Vector2(sway * 0.3, -2 - flick))
		draw_colored_polygon(_crown[1], Color.BLACK)
		draw_set_transform(Vector2.ZERO)
	_draw_cover_outline()

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(size.x * 0.5, -size.y)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = Vector2(maxf(30.0, absf(p.x) * 2.0), maxf(20.0, -p.y))
