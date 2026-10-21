@tool
@icon("res://environment/wind_tree/wind_tree_icon.svg")
class_name WindTree
extends Node2D
## A procedurally grown tree that bends with the gusts, flutters its leaves and sheds them into the wind.
## Change `tree_seed` until you like the shape. The node's position is the foot of the trunk.

@export var tree_seed := 7:
	set(v):
		tree_seed = v
		_grow()
@export_range(0.4, 2.5) var size := 1.0:
	set(v):
		size = v
		_grow()
@export_range(3, 7) var depth := 6:
	set(v):
		depth = v
		_grow()
## How much it bends in the wind.
@export var flexibility := 1.0
@export var sheds_leaves := true
## A dead tree: no leaves at all.
@export var bare := false:
	set(v):
		bare = v
		queue_redraw()

var _branches: Array[Dictionary] = []
var _leaves_fx: GPUParticles2D


func _ready() -> void:
	_grow()
	if not Engine.is_editor_hint() and sheds_leaves and not bare:
		_leaves_fx = LeafParticles.make(Vector2(70, 50) * size, 28)
		_leaves_fx.position = Vector2(0, -150.0 * size)
		add_child(_leaves_fx)


func _grow() -> void:
	_branches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	_grow_branch(rng, -1, -PI / 2.0 + rng.randf_range(-0.05, 0.08), 62.0 * size, 13.0 * size, 0)
	queue_redraw()


func _grow_branch(rng: RandomNumberGenerator, parent: int, angle: float, length: float, thick: float, level: int) -> void:
	var leaves: Array[Vector4] = []
	if level >= depth - 2:
		for i in (9 if level == depth else 4):
			leaves.append(Vector4(rng.randf_range(-11, 11), rng.randf_range(-9, 6), rng.randf_range(2.2, 4.2), rng.randf() * TAU))
	var index := _branches.size()
	_branches.append({"parent": parent, "angle": angle, "length": length, "thick": thick, "level": level,
		"phase": rng.randf() * TAU, "leaves": leaves, "end": Vector2.ZERO, "world_angle": angle})
	if level < depth and length > 6.0:
		var n := 2 if level < 1 else (2 if rng.randf() < 0.6 else 3)
		for i in n:
			var spread := (i - (n - 1) / 2.0) * 0.35
			_grow_branch(rng, index, angle + rng.randf_range(-0.65, 0.65) + spread, length * rng.randf_range(0.62, 0.8), thick * 0.62, level + 1)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	queue_redraw()
	if _leaves_fx:
		LeafParticles.blow(_leaves_fx, global_position.x)


func _draw() -> void:
	var t := Weather.time
	var gust := Weather.gust_at(global_position.x)
	var wind := Weather.wind * flexibility
	for b in _branches:
		var lvl: int = b.level
		var sway := -wind * (0.015 + lvl * 0.035) * (0.5 + 0.9 * gust) + sin(t * (1.3 + lvl * 0.5) + b.phase) * 0.025 * lvl * (0.3 + wind)
		var start := Vector2.ZERO
		var wa: float = b.angle + sway
		if b.parent >= 0:
			var p: Dictionary = _branches[b.parent]
			start = p.end
			wa = p.world_angle + (b.angle - p.angle) + sway
		b.world_angle = wa
		var end: Vector2 = start + Vector2.from_angle(wa) * b.length
		b.end = end
		var n := Vector2.from_angle(wa).orthogonal()
		var w0: float = b.thick * 0.5
		var w1: float = b.thick * 0.31
		draw_colored_polygon(PackedVector2Array([start + n * w0, end + n * w1, end - n * w1, start - n * w0]), Color.BLACK)
		# round joints, so bends between branches don't show notches
		draw_circle(start, w0, Color.BLACK)
		draw_circle(end, w1, Color.BLACK)
		if bare:
			continue
		for l in b.leaves:
			var leaf: Vector4 = l
			var c := end + Vector2(leaf.x - wind * 2.0 * gust, leaf.y + sin(t * 11.0 + leaf.w) * 0.8)
			draw_set_transform(c, leaf.w + sin(t * 9.0 + leaf.w) * 0.5 * wind, Vector2(leaf.z, leaf.z * 0.55))
			draw_circle(Vector2.ZERO, 1.0, Color.BLACK)
		draw_set_transform(Vector2.ZERO)

