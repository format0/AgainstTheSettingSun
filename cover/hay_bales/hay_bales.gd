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
			var c := Vector2((i - (n - 1) * 0.5) * d + rng.randf_range(-3, 3), -radius - r * d * 0.86)
			_bales.append(DrawKit.blob(c, Vector2(radius, radius) * rng.randf_range(0.95, 1.05), rng.randi(), 0.06, 24, false))
			for k in 5:
				var a := rng.randf_range(-PI, 0.0)
				_straw.append(Vector4(c.x + cos(a) * radius, c.y + sin(a) * radius, a, rng.randf_range(5, 11)))
	queue_redraw()


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
	_draw_cover_outline()
