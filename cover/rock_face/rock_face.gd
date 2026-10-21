@tool
@icon("res://cover/rock_face/rock_face_icon.svg")
class_name RockFace
extends Cover
## A big boulder or a jut of rock standing behind the path, with tufts of grass and a
## crooked shrub on top. The node's position is the middle of its foot.

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


func _ready() -> void:
	z_index = Layers.COVER
	_rebuild()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	_rock = PackedVector2Array([Vector2(-size.x * 0.5, 0)])
	var n := 14
	for i in n + 1:
		var u := float(i) / n
		var a := PI - u * PI
		var r := 1.0 + rng.randf_range(-0.12, 0.1) + 0.08 * sin(u * 11.0 + rock_seed)
		var p := Vector2(cos(a) * size.x * 0.5, -sin(a) * size.y) * r
		# a few hard, angular breaks so it reads as stone, not as a bush
		if i % 3 == 1:
			p += Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 6))
		_rock.append(p)
	_rock.append(Vector2(size.x * 0.5, 0))
	_tufts.clear()
	for i in range(3, n - 2, 2):
		if rng.randf() < 0.6:
			_tufts.append(_rock[i])
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
	if shrub and _rock.size() > 8:
		var base := _rock[_rock.size() / 2 + 1]
		var sway := -Weather.wind * 4.0 * (0.5 + Weather.gust_at(gx + base.x)) + sin(Weather.time * 1.9) * 1.5 * Weather.wind
		# a crooked little tree clinging to the rock
		var top := base + Vector2(6 + sway * 0.5, -24)
		DrawKit.limb(self, base, base + Vector2(2, -12), 4.0, 3.0)
		DrawKit.limb(self, base + Vector2(2, -12), top, 3.0, 1.6)
		DrawKit.limb(self, base + Vector2(2, -12), base + Vector2(-14 + sway, -22), 2.0, 0.8)
		for k in 14:
			var a := k * 0.9
			var p := (top if k % 2 == 0 else base + Vector2(-14 + sway, -22)) + Vector2(cos(a) * (4.0 + k % 4 * 2.5), sin(a) * 3.0 - 2.0)
			var flick := sin(Weather.time * 7.0 + k) * 0.5 * Weather.wind
			DrawKit.ellipse(self, p + Vector2(sway * 0.3, flick), Vector2(4.0, 1.8), a + flick, Color.BLACK, 7)
	_draw_cover_outline()
