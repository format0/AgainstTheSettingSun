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
		_build_parts()

## The branches, in growth order (a parent always comes before its children).
var _parent := PackedInt32Array()
var _angle := PackedFloat32Array()
var _length := PackedFloat32Array()
var _thick := PackedFloat32Array()
var _level := PackedInt32Array()
var _phase := PackedFloat32Array()
## Leaves of each branch: x, y offset from the branch end, size, phase.
var _leaves: Array[PackedVector4Array] = []
var _leaves_fx: GPUParticles2D

# The shapes never change, only where they are: each branch and each branch's leaves are
# recorded once into canvas items, and every frame only their transforms are set.
var _parts: CanvasParts
var _branch_items: Array[RID] = []
var _leaf_items: Array[RID] = []       # invalid RID where a branch has no leaves
var _leaf_mat: ShaderMaterial
var _bounds := Rect2()
# scratch for the pose, reused every frame
var _world_angle := PackedFloat32Array()
var _end := PackedVector2Array()


func _ready() -> void:
	_grow()
	if not Engine.is_editor_hint() and sheds_leaves and not bare:
		_leaves_fx = LeafParticles.make(Vector2(70, 50) * size, 28)
		_leaves_fx.position = Vector2(0, -150.0 * size)
		add_child(_leaves_fx)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _parts:
		_parts.clear()


func _grow() -> void:
	_parent.clear()
	_angle.clear()
	_length.clear()
	_thick.clear()
	_level.clear()
	_phase.clear()
	_leaves.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	_grow_branch(rng, -1, -PI / 2.0 + rng.randf_range(-0.05, 0.08), 62.0 * size, 13.0 * size, 0)
	_build_parts()


func _grow_branch(rng: RandomNumberGenerator, parent: int, angle: float, length: float, thick: float, level: int) -> void:
	var leaves := PackedVector4Array()
	if level >= depth - 2:
		for i in (9 if level == depth else 4):
			leaves.append(Vector4(rng.randf_range(-11, 11), rng.randf_range(-9, 6), rng.randf_range(2.2, 4.2), rng.randf() * TAU))
	var index := _parent.size()
	_parent.append(parent)
	_angle.append(angle)
	_length.append(length)
	_thick.append(thick)
	_level.append(level)
	_phase.append(rng.randf() * TAU)
	_leaves.append(leaves)
	if level < depth and length > 6.0:
		var n := 2 if level < 1 else (2 if rng.randf() < 0.6 else 3)
		for i in n:
			var spread := (i - (n - 1) / 2.0) * 0.35
			_grow_branch(rng, index, angle + rng.randf_range(-0.65, 0.65) + spread, length * rng.randf_range(0.62, 0.8), thick * 0.62, level + 1)


## Record every branch and every cluster of leaves once, in its own frame of reference.
func _build_parts() -> void:
	if not is_inside_tree():
		return
	if _parts == null:
		_parts = CanvasParts.new(self)
		_leaf_mat = ShaderMaterial.new()
		_leaf_mat.shader = preload("res://environment/wind_tree/leaf_flutter.gdshader")
	_parts.clear()
	_branch_items.clear()
	_leaf_items.clear()
	var n := _parent.size()
	_world_angle.resize(n)
	_end.resize(n)
	for i in n:
		# a tapered segment along +x from the joint, with round ends so bends show no notches
		var rid := _parts.add()
		var length := _length[i]
		var w0 := _thick[i] * 0.5
		var w1 := _thick[i] * 0.31
		RenderingServer.canvas_item_add_polygon(rid, PackedVector2Array([Vector2(0, -w0), Vector2(length, -w1), Vector2(length, w1), Vector2(0, w0)]), PackedColorArray([Color.BLACK]))
		RenderingServer.canvas_item_add_circle(rid, Vector2.ZERO, w0, Color.BLACK)
		RenderingServer.canvas_item_add_circle(rid, Vector2(length, 0), w1, Color.BLACK)
		_branch_items.append(rid)
		var leaves := _leaves[i]
		if leaves.is_empty() or bare:
			_leaf_items.append(RID())
			continue
		# the leaves around this branch end, upright (they don't turn with the branch);
		# each one carries its centre and phase so the shader can make it flutter
		var lid := _parts.add(_leaf_mat)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var seg := 16
		for leaf: Vector4 in leaves:
			var c := Vector2(leaf.x, leaf.y)
			var base := pts.size()
			var ph := Color(leaf.w / TAU, 0, 0, 1)
			pts.append(c)
			cols.append(ph)
			uvs.append(c)
			for k in seg:
				var a := k * TAU / seg
				pts.append(c + Vector2(cos(a) * leaf.z, sin(a) * leaf.z * 0.55).rotated(leaf.w))
				cols.append(ph)
				uvs.append(c)
				idx.append_array(PackedInt32Array([base, base + 1 + k, base + 1 + (k + 1) % seg]))
		RenderingServer.canvas_item_add_triangle_array(lid, idx, pts, cols, uvs)
		_leaf_items.append(lid)
	_pose(0.0, 0.0, 0.0, true)
	_bounds = _rest_bounds()


func _rest_bounds() -> Rect2:
	var r := Rect2(Vector2.ZERO, Vector2.ZERO)
	for i in _end.size():
		r = r.expand(_end[i])
	return r.grow(16.0 * size)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _parts == null:
		return
	if _leaves_fx:
		LeafParticles.blow(_leaves_fx, global_position.x)
	_parts.sync_layers()
	# nothing to move while the tree is off screen; it catches up when it comes back
	if not CanvasParts.on_screen(self, _bounds):
		return
	var wind := Weather.wind * flexibility
	_leaf_mat.set_shader_parameter("weather_time", Weather.time)
	_leaf_mat.set_shader_parameter("wind", wind)
	_pose(Weather.time, Weather.gust_at(global_position.x), wind, false)


## Bend the tree for this moment: the same sway as always, each branch carried by its parent.
func _pose(t: float, gust: float, wind: float, rest: bool) -> void:
	for i in _parent.size():
		var lvl := _level[i]
		var sway := 0.0 if rest else -wind * (0.015 + lvl * 0.035) * (0.5 + 0.9 * gust) + sin(t * (1.3 + lvl * 0.5) + _phase[i]) * 0.025 * lvl * (0.3 + wind)
		var start := Vector2.ZERO
		var wa := _angle[i] + sway
		var p := _parent[i]
		if p >= 0:
			start = _end[p]
			wa = _world_angle[p] + (_angle[i] - _angle[p]) + sway
		_world_angle[i] = wa
		var end := start + Vector2.from_angle(wa) * _length[i]
		_end[i] = end
		RenderingServer.canvas_item_set_transform(_branch_items[i], Transform2D(wa, start))
		if _leaf_items[i].is_valid():
			RenderingServer.canvas_item_set_transform(_leaf_items[i], Transform2D(0.0, end + Vector2(-wind * 2.0 * gust, 0.0)))
