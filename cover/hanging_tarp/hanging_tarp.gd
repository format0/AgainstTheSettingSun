@tool
@icon("res://cover/hanging_tarp/hanging_tarp_icon.svg")
class_name HangingTarp
extends Cover
## A torn tarpaulin hanging from a rusty rail. It hides the player only where it hangs,
## and strong gusts lift it aside: wait for a lull before you rely on it.
## The node's position is the left end of the rail.

@export var width := 120.0:
	set(v):
		width = v
		_reset_cloth()
@export var drop := 130.0:
	set(v):
		drop = v
		_reset_cloth()
@export var columns := 9
@export var rows := 9
## How strongly the wind lifts it.
@export var wind_catch := 1.0
@export var tear_seed := 3

var _pts: Array[Vector2] = []
var _old: Array[Vector2] = []
var _rest_y: Array[float] = []


func _ready() -> void:
	z_index = Layers.COVER
	_reset_cloth()


func _reset_cloth() -> void:
	_pts.clear()
	_old.clear()
	_rest_y.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tear_seed
	for j in rows:
		for i in columns:
			var p := Vector2(i * width / (columns - 1), j * drop / (rows - 1))
			_pts.append(p)
			_old.append(p)
	# ragged hem: the last row hangs at uneven lengths
	for i in columns:
		_rest_y.append(rng.randf_range(0.15, 1.0))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _pts.size() != columns * rows:
		return
	var sub := 3
	var h := minf(delta, 1.0 / 30.0) / sub
	var sx := width / (columns - 1)
	var sy := drop / (rows - 1)
	for s in sub:
		for k in range(columns, _pts.size()):
			var i := k % columns
			var j := k / columns
			var gust := Weather.gust_at(global_position.x + _pts[k].x)
			var flutter := sin(Weather.time * 5.3 + i * 0.7 + j * 0.4) * sin(Weather.time * 2.1 + j)
			var ripple := sin(Weather.time * 7.1 - j * 0.9 + i * 0.5) * sin(Weather.time * 3.3 + i)
			var force := Vector2(-Weather.wind * wind_catch * (90.0 + 170.0 * gust * Weather.gust) * (0.3 + 0.7 * j / (rows - 1.0)) + (flutter * 90.0 + ripple * 120.0) * Weather.wind, 420.0 + ripple * 80.0 * Weather.wind)
			var v := (_pts[k] - _old[k]) * 0.97
			_old[k] = _pts[k]
			_pts[k] += v + force * h * h
		for it in 4:
			for k in _pts.size():
				var i := k % columns
				var j := k / columns
				if i < columns - 1:
					_link(k, k + 1, sx)
				if j < rows - 1:
					_link(k, k + columns, sy)
	queue_redraw()


func _link(a: int, b: int, length: float) -> void:
	var d := _pts[b] - _pts[a]
	var dist := maxf(d.length(), 0.001)
	var corr := d * ((dist - length) / dist * 0.5)
	var a_pinned := a < columns
	var b_pinned := b < columns
	if not a_pinned:
		_pts[a] += corr * (1.0 if not b_pinned else 2.0)
	if not b_pinned:
		_pts[b] -= corr * (1.0 if not a_pinned else 2.0)


func _outline() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _pts.size() != columns * rows:
		return out
	for i in columns:
		out.append(_pts[i])
	for j in range(1, rows):
		out.append(_pts[j * columns + columns - 1])
	var last := (rows - 1) * columns
	for i in range(columns - 2, 0, -1):
		var p := _pts[last + i]
		var up := _pts[last - columns + i]
		out.append(up.lerp(p, _rest_y[i]))
	for j in range(rows - 1, 0, -1):
		out.append(_pts[j * columns])
	return out


func _cover_shapes() -> Array[PackedVector2Array]:
	var o := _outline()
	if o.size() < 3:
		return []
	return [o]


func _draw() -> void:
	var c := Color.BLACK
	draw_rect(Rect2(-14.0, -5.0, width + 28.0, 4.0), c)
	DrawKit.chain(self, Vector2(-8, -5), Vector2(-8, -60), 7.0, 1.8)
	DrawKit.chain(self, Vector2(width + 8, -5), Vector2(width + 8, -60), 7.0, 1.8)
	if _pts.size() == columns * rows:
		# cell by cell as triangles, so a cloth folding over itself still draws
		var cols := PackedColorArray([c, c, c])
		for j in rows - 1:
			for i in columns - 1:
				var a := _pts[j * columns + i]
				var b := _pts[j * columns + i + 1]
				var d := _pts[(j + 1) * columns + i]
				var e := _pts[(j + 1) * columns + i + 1]
				if j == rows - 2:
					d = a.lerp(d, _rest_y[i]) if i > 0 else d
					e = b.lerp(e, _rest_y[i + 1]) if i + 1 < columns - 1 else e
				draw_primitive(PackedVector2Array([a, b, e]), cols, PackedVector2Array())
				draw_primitive(PackedVector2Array([a, e, d]), cols, PackedVector2Array())
	for i in columns:
		draw_circle(Vector2(i * width / (columns - 1), -2.0), 2.0, c)
	_draw_cover_outline()

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(0, 0, width, drop)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(width, drop), "props": ["width", "drop"]}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	width = maxf(20.0, p.x)
	drop = maxf(20.0, p.y)
