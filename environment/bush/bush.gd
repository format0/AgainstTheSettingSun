@tool
@icon("res://environment/bush/bush_icon.svg")
class_name Bush
extends Node2D
## A shrub of clumped leaves and twigs that bends and flutters in the wind. Scenery only;
## put it in the foreground (z) to frame the view. The node's position is its foot.

@export var size := Vector2(60, 40):
	set(v):
		size = v
		_grow()
@export var bush_seed := 1:
	set(v):
		bush_seed = v
		_grow()
## Bare twigs only.
@export var thorny := false:
	set(v):
		thorny = v
		queue_redraw()

var _clumps: Array[Vector4] = []
var _twigs: Array[Vector4] = []
var _leafy: Array[PackedVector2Array] = []


func _ready() -> void:
	_grow()


func _grow() -> void:
	_clumps.clear()
	_twigs.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = bush_seed
	for i in 7:
		var u := rng.randf_range(-0.5, 0.5)
		_clumps.append(Vector4(u * size.x, -size.y * (0.35 + rng.randf() * 0.5) * (1.0 - absf(u) * 0.8), size.y * rng.randf_range(0.25, 0.42), rng.randf() * TAU))
	_leafy.clear()
	for k in _clumps:
		_leafy.append(DrawKit.foliage(Vector2(k.z * 1.15, k.z * 0.85), rng.randi(), clampf(size.y * 0.08, 2.2, 4.0)))
	for i in 9:
		_twigs.append(Vector4(rng.randf_range(-0.4, 0.4) * size.x, rng.randf_range(-1.6, -1.0) + rng.randf_range(-0.5, 0.5), size.y * rng.randf_range(0.6, 1.25), rng.randf() * TAU))
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var t := Weather.time
	var gust := Weather.gust_at(global_position.x)
	var bend := -Weather.wind * (0.4 + gust) * 0.18
	for tw in _twigs:
		var a := tw.y + bend + sin(t * 2.0 + tw.w) * 0.05 * Weather.wind
		var base := Vector2(tw.x * 0.3, 0)
		var tip := base + Vector2.from_angle(a) * tw.z
		DrawKit.limb(self, base, tip, 2.4, 0.6)
		if thorny:
			for k in 3:
				var p := base.lerp(tip, 0.3 + k * 0.22)
				draw_line(p, p + Vector2.from_angle(a + (0.9 if k % 2 == 0 else -0.9)) * 5.0, c, 0.8)
	if thorny:
		return
	for i in _clumps.size():
		var k := _clumps[i]
		var sway := Vector2(bend * -k.y * 0.9 + sin(t * 1.9 + k.w) * Weather.wind * 1.2, 0)
		draw_set_transform(Vector2(k.x, k.y) + sway, sin(t * (3.0 + Weather.wind * 5.0) + k.w) * 0.03 * Weather.wind)
		draw_colored_polygon(_leafy[i], c)
	draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(size.x * 0.5, -size.y)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = Vector2(maxf(16.0, absf(p.x) * 2.0), maxf(10.0, -p.y))
