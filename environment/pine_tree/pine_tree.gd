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

## Boughs: {u, side, poly (in the bough's own frame, pointing right), phase}.
var _boughs: Array[Dictionary] = []
## Dead twigs low on the trunk: [u, side, length].
var _twigs: Array[Vector3] = []

# The shapes never change, only where they are: each piece is recorded once into a canvas
# item and every frame only its transform is set (see _pose).
var _parts: CanvasParts
var _trunk_segs: Array[RID] = []
var _trunk_caps: Array[RID] = []
var _bough_items: Array[RID] = []
var _twig_items: Array[RID] = []
var _leader: RID
var _bounds := Rect2()


func _ready() -> void:
	_grow()


func _grow() -> void:
	_boughs.clear()
	_twigs.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	# whorls of boughs all the way up, overlapping into a ragged cone with gaps where storms
	# took them; each bough droops, then turns up at the tip, and hangs a fringe of needles
	var n := int(height / 13.0)
	for i in n:
		var u := 0.2 + 0.8 * float(i) / n + rng.randf_range(-0.01, 0.01)
		for side: float in [-1.0, 1.0]:
			if rng.randf() < ragged * 0.45 and u < 0.85:
				continue
			var reach := height * 0.3 * pow(1.0 - u, 0.9) * rng.randf_range(0.6, 1.15) + 7.0
			_boughs.append({"u": u, "side": side, "poly": _bough(rng, reach, rng.randf_range(6.0, 10.0) * (1.0 - u * 0.55)),
				"phase": rng.randf() * TAU})
	for i in rng.randi_range(2, 4):
		_twigs.append(Vector3(rng.randf_range(0.06, 0.22), -1.0 if rng.randf() < 0.5 else 1.0, rng.randf_range(10, 24)))
	_build_parts()


func _bough(rng: RandomNumberGenerator, length: float, thick: float) -> PackedVector2Array:
	var droop := length * rng.randf_range(0.28, 0.45)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var steps := maxi(6, int(length / 2.6))
	for k in steps + 1:
		var u := float(k) / steps
		var x := length * u
		# down along the bough, then a little up again at the tip
		var y := droop * (u * u * 1.4 - u * u * u * 0.8) - (u * 7.0 * u * u if u > 0.7 else 0.0) * thick * 0.2
		var w := thick * (1.0 - u * 0.6)
		top.append(Vector2(x, y - w * 0.5 - (rng.randf_range(0.5, 2.0) if k % 3 == 0 else 0.0)))
		# needle tufts: deep points and shallow notches, now and then a hanging side spray
		var hang := w * (rng.randf_range(1.0, 1.9) if k % 2 == 0 else rng.randf_range(0.35, 0.7))
		if rng.randf() < 0.18 and u > 0.2 and u < 0.85:
			hang *= 1.9
		bottom.append(Vector2(x + rng.randf_range(-0.8, 0.8), y + hang))
	top.append(Vector2(length + thick * 0.6, top[top.size() - 1].y - thick * 0.3))
	bottom.reverse()
	return top + bottom


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _parts:
		_parts.clear()


## Record the trunk segments, joints, boughs, twigs and the leader once; only their
## transforms change as the tree sways.
func _build_parts() -> void:
	if not is_inside_tree():
		return
	if _parts == null:
		_parts = CanvasParts.new(self)
	_parts.clear()
	_trunk_segs.clear()
	_trunk_caps.clear()
	_bough_items.clear()
	_twig_items.clear()
	for i in 8:
		var w0 := lerpf(7.0, 1.5, i / 8.0)
		var w1 := lerpf(7.0, 1.5, (i + 1) / 8.0)
		var rid := _parts.add()
		RenderingServer.canvas_item_add_polygon(rid, PackedVector2Array([Vector2(0, w0 * 0.5), Vector2(1, w1 * 0.5), Vector2(1, -w1 * 0.5), Vector2(0, -w0 * 0.5)]), PackedColorArray([Color.BLACK]))
		_trunk_segs.append(rid)
	for i in 9:
		var rid := _parts.add()
		RenderingServer.canvas_item_add_circle(rid, Vector2.ZERO, lerpf(7.0, 1.5, i / 8.0) * 0.5, Color.BLACK)
		_trunk_caps.append(rid)
	for tw in _twigs:
		var rid := _parts.add()
		var tip := Vector2(tw.y * tw.z, tw.z * 0.35)
		RenderingServer.canvas_item_add_line(rid, Vector2.ZERO, tip, Color.BLACK, 1.4)
		RenderingServer.canvas_item_add_line(rid, tip * 0.55, tip * 0.55 + Vector2(tw.y * 5.0, 4.0), Color.BLACK, 1.0)
		_twig_items.append(rid)
	for b in _boughs:
		var rid := _parts.add()
		CanvasParts.add_polygon(rid, b.poly)
		_bough_items.append(rid)
	_leader = _parts.add()
	CanvasParts.add_polygon(_leader, PackedVector2Array([Vector2(0, -10), Vector2(4, 4), Vector2(6, 12), Vector2(-6, 12), Vector2(-4, 4)]))
	_bounds = Rect2(-height * 0.4, -height - 20.0, height * 0.8, height + 30.0)
	_pose()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _parts == null:
		return
	_parts.sync_layers()
	if CanvasParts.on_screen(self, _bounds):
		_pose()


func _bend(u: float) -> Vector2:
	var gust := Weather.gust_at(global_position.x)
	var sway := -Weather.wind * (0.4 + 0.9 * gust) * 18.0 + sin(Weather.time * 1.3 + tree_seed) * 4.0 * Weather.wind
	return Vector2(sway * u * u, 0)


## The trunk bends (more towards the top), the boughs ride on it, lift on the windward side,
## droop on the leeward side and flutter at the tips.
func _pose() -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		pts.append(Vector2(0, -height * u) + _bend(u))
	for i in 8:
		var d := pts[i + 1] - pts[i]
		RenderingServer.canvas_item_set_transform(_trunk_segs[i], Transform2D(d, d.normalized().orthogonal(), pts[i]))
	for i in 9:
		RenderingServer.canvas_item_set_transform(_trunk_caps[i], Transform2D(0.0, pts[i]))
	for i in _twigs.size():
		RenderingServer.canvas_item_set_transform(_twig_items[i], Transform2D(0.0, Vector2(0, -height * _twigs[i].x) + _bend(_twigs[i].x)))
	var wind := Weather.wind
	var gust := Weather.gust_at(global_position.x)
	for i in _boughs.size():
		var b := _boughs[i]
		var u: float = b.u
		var side: float = b.side
		var lift := -wind * 0.12 * side * (0.5 + gust)
		var flutter := sin(Weather.time * 4.0 + b.phase) * wind * 0.05
		RenderingServer.canvas_item_set_transform(_bough_items[i], Transform2D((lift + flutter) * side, Vector2(side, 1.0), 0.0, Vector2(0, -height * u) + _bend(u)))
	RenderingServer.canvas_item_set_transform(_leader, Transform2D(0.0, pts[8]))
