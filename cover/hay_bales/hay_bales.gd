@tool
@icon("res://cover/hay_bales/hay_bales_icon.svg")
class_name HayBales
extends Cover
## Round hay bales left in the field, stacked in a little pyramid, with loose straw
## tugged by the wind. The node's position is the middle of the bottom row, on the ground.

@export_range(1, 5) var bottom_row := 3:
	set(v):
		bottom_row = v
		_rebuild()
@export_range(1, 3) var rows := 2:
	set(v):
		rows = v
		_rebuild()
@export var radius := 26.0:
	set(v):
		radius = v
		_rebuild()
@export var bale_seed := 1:
	set(v):
		bale_seed = v
		_rebuild()

var _bales: Array[PackedVector2Array] = []
var _straw: Array[Vector4] = []
var _fork := PackedVector2Array()


func _ready() -> void:
	z_index = Layers.COVER
	_rebuild()


func _rebuild() -> void:
	_bales.clear()
	_straw.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = bale_seed
	var d := radius * 2.0 * 0.96
	for r in rows:
		var n := bottom_row - r
		if n <= 0:
			break
		for i in n:
			var c := Vector2((i - (n - 1) * 0.5) * d + rng.randf_range(-3, 3), -radius * 0.94 - r * d * 0.84)
			_bales.append(_bale(rng, c, radius * rng.randf_range(0.95, 1.05)))
			# loose wisps blowing off the top
			for k in 9:
				var a := rng.randf_range(-PI * 0.95, -PI * 0.05)
				_straw.append(Vector4(c.x + cos(a) * radius * 0.95, c.y + sin(a) * radius * 0.92, a + rng.randf_range(-0.5, 0.5), rng.randf_range(4, 12)))
	# a pitchfork left stuck in the top bale
	_fork = PackedVector2Array()
	if bale_seed % 2 == 1 and not _bales.is_empty():
		var topb := _bales[_bales.size() - 1]
		var tc := Vector2.ZERO
		for q in topb:
			tc += q
		tc /= topb.size()
		var base := tc + Vector2(radius * 0.3, -radius * 0.55)
		_fork = PackedVector2Array([base, base + Vector2(radius * 0.9, -radius * 1.7)])
	queue_redraw()


## A round bale seen end-on: sagging a little under its weight, its edge fuzzy with straw.
func _bale(rng: RandomNumberGenerator, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := int(r * 3.2)
	for k in n:
		var a := k * TAU / n
		var rr := r * (1.0 + rng.randf_range(-0.025, 0.025))
		var p := Vector2(cos(a) * rr * 1.03, sin(a) * rr * (0.94 if sin(a) > 0.0 else 1.0))
		p.y = minf(p.y, r * 0.86)   # flattened where it sits
		if k % 4 == 0 and sin(a) < 0.6:
			# a straw end poking out of the edge
			p += Vector2.from_angle(a + rng.randf_range(-0.3, 0.3)) * rng.randf_range(0.6, 2.2)
		pts.append(c + p)
	return pts


func _cover_shapes() -> Array[PackedVector2Array]:
	return _bales


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	for b in _bales:
		draw_colored_polygon(b, Color.BLACK)
	for s in _straw:
		var bend := -Weather.wind * 0.6 * (0.4 + Weather.gust_at(global_position.x + s.x)) + sin(Weather.time * 6.0 + s.z * 4.0) * 0.15 * Weather.wind
		var dir := Vector2.from_angle(s.z + bend)
		draw_line(Vector2(s.x, s.y), Vector2(s.x, s.y) + dir * s.w, Color.BLACK, 1.0)
	if _fork.size() == 2:
		var a := _fork[0]
		var b := _fork[1]
		draw_line(a, b, Color.BLACK, 2.0)
		var dir := (a - b).normalized()
		var side := dir.orthogonal()
		# the tines go into the hay; only the crossbar and the handle show
		draw_line(a - side * 5.0, a + side * 5.0, Color.BLACK, 2.0)
		for k in 3:
			var t0 := a + side * (k - 1) * 5.0
			draw_line(t0, t0 + dir * 6.0, Color.BLACK, 1.4)
	_draw_cover_outline()

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-bottom_row * radius, -rows * radius * 1.75 - 4, bottom_row * radius * 2.0, rows * radius * 1.75 + 4)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "radius", "pos": Vector2(bottom_row * radius, -rows * radius * 1.75)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	radius = clampf(p.x / bottom_row, 10.0, 60.0)
