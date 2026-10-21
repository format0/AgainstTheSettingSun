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
	for k in _clumps:
		var sway := Vector2(bend * -k.y * 0.9 + sin(t * 1.9 + k.w) * Weather.wind * 1.2, 0)
		var pts := PackedVector2Array()
		for j in 18:
			var a := j * TAU / 18.0
			var r := k.z * (1.0 + 0.12 * sin(a * 5.0 + k.w) + 0.06 * sin(a * 9.0 + t * (4.0 + Weather.wind * 8.0)))
			pts.append(Vector2(k.x, k.y) + sway + Vector2(cos(a), sin(a) * 0.8) * r)
		draw_colored_polygon(pts, c)
