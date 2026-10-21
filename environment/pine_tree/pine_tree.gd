@tool
@icon("res://environment/pine_tree/pine_tree_icon.svg")
class_name PineTree
extends Node2D
## A tall, ragged pine: a thin trunk and tiers of drooping branches with needle-jagged edges,
## the top whipping in the storm while the base hardly moves. Scenery only.
## The node's position is the foot of the trunk.

@export var height := 260.0:
	set(v):
		height = v
		_grow()
@export var tree_seed := 1:
	set(v):
		tree_seed = v
		_grow()
## Branches lost to storms (0..1): a ragged, half-bare tree.
@export_range(0.0, 1.0) var ragged := 0.3:
	set(v):
		ragged = v
		_grow()

var _tiers: Array[Vector4] = []


func _ready() -> void:
	_grow()


func _grow() -> void:
	_tiers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var n := int(height / 22.0)
	for i in n:
		var u := 0.22 + 0.78 * float(i) / n
		if rng.randf() < ragged * 0.5 and u < 0.85:
			continue
		var reach := height * 0.3 * (1.0 - u) * rng.randf_range(0.7, 1.15) + 8.0
		for side: float in [-1.0, 1.0]:
			if rng.randf() < ragged * 0.35:
				continue
			_tiers.append(Vector4(u, side * reach, rng.randf_range(5, 9), rng.randf() * TAU))
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _bend(u: float) -> Vector2:
	var gust := Weather.gust_at(global_position.x)
	var sway := -Weather.wind * (0.4 + 0.9 * gust) * 18.0 + sin(Weather.time * 1.3 + tree_seed) * 4.0 * Weather.wind
	return Vector2(sway * u * u, 0)


func _draw() -> void:
	var c := Color.BLACK
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		pts.append(Vector2(0, -height * u) + _bend(u))
	for i in 8:
		var u0 := i / 8.0
		DrawKit.limb(self, pts[i], pts[i + 1], lerpf(7.0, 1.5, u0), lerpf(7.0, 1.5, u0 + 0.125))
	for t in _tiers:
		var base := Vector2(0, -height * t.x) + _bend(t.x)
		var flutter := sin(Weather.time * 4.0 + t.w) * Weather.wind * 2.0
		var reach: float = t.y
		var tip := base + Vector2(reach - Weather.wind * 6.0 * t.x * signf(reach + 0.001), absf(reach) * 0.28 + flutter)
		var mid := base.lerp(tip, 0.5) + Vector2(0, -absf(reach) * 0.08)
		var thick: float = t.z
		# a drooping bough: smooth on top, a fringe of hanging needles underneath
		var top_edge := PackedVector2Array()
		var bottom_edge := PackedVector2Array()
		var n := maxi(4, int(absf(reach) / 5.0))
		for k in n + 1:
			var u := float(k) / n
			var q := base.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(tip, u * 2.0 - 1.0)
			var w := thick * (1.0 - u * 0.75)
			top_edge.append(q + Vector2(0, -w * 0.45))
			var hang := w * (0.9 + 0.6 * float(k % 2)) + sin(Weather.time * 6.0 + t.w + k) * 0.6 * Weather.wind
			bottom_edge.append(q + Vector2(0, hang))
		bottom_edge.reverse()
		draw_colored_polygon(top_edge + bottom_edge, c)
	# the crown tip
	draw_colored_polygon(PackedVector2Array([pts[8] + Vector2(0, -8), pts[8] + Vector2(5, 14), pts[8] + Vector2(-5, 14)]), c)
