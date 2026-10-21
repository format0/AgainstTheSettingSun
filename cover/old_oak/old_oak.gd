@tool
@icon("res://cover/old_oak/old_oak_icon.svg")
class_name OldOak
extends Cover
## A huge old oak with a trunk wide enough to hide behind: gnarled limbs spreading wide, a
## crown of leaf clumps with the sky showing through, swaying and rustling in the wind and
## shedding leaves. The node's position is the foot of the trunk.

@export_range(0.5, 2.0) var size := 1.0:
	set(v):
		size = v
		_grow()
@export var tree_seed := 4:
	set(v):
		tree_seed = v
		_grow()
## A dead tree keeps only its bare limbs.
@export var leafless := false:
	set(v):
		leafless = v
		_build_parts()
@export var sheds_leaves := true

var _branches: Array[Dictionary] = []
var _trunk := PackedVector2Array()
var _roots: Array[PackedVector2Array] = []
## Broken-off stubs and burls on the trunk: [from, to, thickness].
var _stubs: Array[Vector3] = []
var _leaves_fx: GPUParticles2D

# The trunk, roots and stubs never move: they are drawn once by this node. The limbs and the
# leaf clumps keep their shapes and only move, so each is recorded once into a canvas item
# and every frame only the transforms are set (see _process).
var _parts: CanvasParts
## Per branch: the two limb segments, the three round joints, the clumps (or an invalid RID).
var _seg_a: Array[RID] = []
var _seg_b: Array[RID] = []
var _cap_start: Array[RID] = []
var _cap_mid: Array[RID] = []
var _cap_end: Array[RID] = []
var _crown: Array[RID] = []
var _clump_mat: ShaderMaterial
var _bounds := Rect2()


func _ready() -> void:
	z_index = Layers.COVER
	_grow()
	if not Engine.is_editor_hint() and sheds_leaves and not leafless:
		_leaves_fx = LeafParticles.make(Vector2(120, 60) * size, 22)
		_leaves_fx.position = Vector2(0, -190 * size)
		add_child(_leaves_fx)


func _grow() -> void:
	_branches.clear()
	_roots.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var s := size
	var trunk_h := 92.0 * s
	var w := 23.0 * s
	# the trunk: wide, ridged, flaring into roots
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		var flare := pow(1.0 - u, 3.0) * 20.0 * s
		var ridge := sin(u * 11.0 + tree_seed) * 2.0 * s
		var lean := sin(u * 2.0 + tree_seed) * 5.0 * s * u
		var taper := lerpf(1.0, 0.62, u * u)
		left.append(Vector2(-w * taper - flare + ridge + lean, -trunk_h * u))
		right.append(Vector2(w * 0.92 * taper + flare + ridge * 0.6 + lean, -trunk_h * u))
	right.reverse()
	_trunk = left + right
	for k in 4:
		var side := -1.0 if k < 2 else 1.0
		var a := Vector2(side * (w + 4.0 * s), -6.0 * s)
		var tip := Vector2(side * (w + rng.randf_range(18, 36) * s), rng.randf_range(-1, 2))
		_roots.append(PackedVector2Array([a + Vector2(0, -8 * s), tip, a + Vector2(0, 2)]))
	_stubs.clear()
	for k in rng.randi_range(1, 3):
		var u := rng.randf_range(0.3, 0.8)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var at := Vector2(side * w * lerpf(1.0, 0.62, u * u) * 0.9, -trunk_h * u)
		var reach := rng.randf_range(6, 15) * s
		var a := -PI * 0.5 + side * rng.randf_range(0.7, 1.3)
		_stubs.append(Vector3(at.x, at.y, 0.0))
		_stubs.append(Vector3(at.x + cos(a) * reach, at.y + sin(a) * reach, rng.randf_range(3.5, 6.0) * s))
	var top := Vector2(sin(2.0 + tree_seed) * 5.0 * s, -trunk_h + 6.0 * s)
	var limbs := rng.randi_range(3, 4)
	for i in limbs:
		var a := lerpf(-PI * 0.95, -PI * 0.05, (i + rng.randf_range(0.25, 0.75)) / limbs)
		_grow_branch(rng, top, a, rng.randf_range(62, 84) * s, rng.randf_range(17, 22) * s, 1)
	_build_parts()
	queue_redraw()


func _grow_branch(rng: RandomNumberGenerator, start: Vector2, angle: float, length: float, thick: float, level: int) -> void:
	var bend := rng.randf_range(-0.35, 0.35)
	var mid := start + Vector2.from_angle(angle + bend) * length * 0.5
	var end := mid + Vector2.from_angle(angle - bend * 0.6) * length * 0.5
	# clumps of leaves on the outer twigs: lumpy masses with a rim of single leaves, thin
	# twigs reaching into them, and a few loose sprigs around, so the sky shows through
	var clumps: Array[Dictionary] = []
	if level >= 3:
		for k in (5 if level >= 4 else 2):
			var off := Vector2(rng.randf_range(-20, 20), rng.randf_range(-17, 7)) * size
			var r := rng.randf_range(7.0, 13.0) * size
			var sprigs := PackedVector3Array()
			for j in rng.randi_range(2, 4):
				var a := rng.randf_range(-PI, 0.2) if rng.randf() < 0.8 else rng.randf_range(0.2, PI)
				sprigs.append(Vector3(cos(a) * r * rng.randf_range(1.05, 1.5), sin(a) * r * rng.randf_range(0.95, 1.35), a + rng.randf_range(-0.6, 0.6)))
			clumps.append({"off": off, "poly": DrawKit.foliage(Vector2(r * 1.25, r * 0.92), rng.randi(), 3.4 * size),
				"phase": rng.randf() * TAU, "sprigs": sprigs})
	_branches.append({"start": start, "mid": mid, "end": end, "thick": thick, "level": level, "phase": rng.randf() * TAU, "clumps": clumps})
	if level < 4 and length > 14.0:
		var n := 2 if rng.randf() < 0.6 else 3
		for i in n:
			var spread := (i - (n - 1) * 0.5) * rng.randf_range(0.45, 0.8)
			var a := angle + spread + rng.randf_range(-0.2, 0.2)
			# oaks spread sideways more than they climb
			a = lerpf(a, -PI * 0.5 + signf(a + PI * 0.5) * 1.2, 0.15)
			_grow_branch(rng, end, a, length * rng.randf_range(0.62, 0.8), thick * 0.6, level + 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _parts:
		_parts.clear()


## Record each limb segment, joint and crown of clumps once.
func _build_parts() -> void:
	if not is_inside_tree():
		return
	if _parts == null:
		_parts = CanvasParts.new(self)
		_clump_mat = ShaderMaterial.new()
		_clump_mat.shader = preload("res://cover/old_oak/clump_flutter.gdshader")
	_parts.clear()
	for list in [_seg_a, _seg_b, _cap_start, _cap_mid, _cap_end, _crown]:
		list.clear()
	var leaf_shape := DrawKit.leaf_points(4.2 * size, 2.0 * size)
	_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
	for b in _branches:
		var th: float = b.thick
		# a limb segment is a unit-long taper along +x; its transform stretches it from one
		# joint to the next, so it stays exact while the joints sway by different amounts
		_seg_a.append(_segment(th, th * 0.8))
		_seg_b.append(_segment(th * 0.8, th * 0.6))
		_cap_start.append(_cap(th * 0.5))
		_cap_mid.append(_cap(th * 0.4))
		_cap_end.append(_cap(th * 0.3))
		_bounds = _bounds.expand(b.start).expand(b.end)
		if leafless or (b.clumps as Array).is_empty():
			_crown.append(RID())
			continue
		_crown.append(_build_crown(b, leaf_shape))
		for cl in b.clumps:
			_bounds = _bounds.expand((b.end as Vector2) + (cl.off as Vector2))
	_bounds = _bounds.grow(40.0 * size)
	_pose(0.0, 0.0, 0.0)


func _segment(w0: float, w1: float) -> RID:
	var rid := _parts.add()
	RenderingServer.canvas_item_add_polygon(rid, PackedVector2Array([Vector2(0, w0 * 0.5), Vector2(1, w1 * 0.5), Vector2(1, -w1 * 0.5), Vector2(0, -w0 * 0.5)]), PackedColorArray([Color.BLACK]))
	return rid


func _cap(r: float) -> RID:
	var rid := _parts.add()
	RenderingServer.canvas_item_add_circle(rid, Vector2.ZERO, r, Color.BLACK)
	return rid


## All the clumps on one branch tip, in the tip's frame: each clump, its twig, its sprigs and
## their leaves, tagged per vertex so the shader can make them flutter.
func _build_crown(b: Dictionary, leaf_shape: PackedVector2Array) -> RID:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var th: float = b.thick
	for cl in b.clumps:
		var off: Vector2 = cl.off
		var ph: float = cl.phase / TAU
		# the twig from the branch tip (fixed) to the clump (moving with it)
		_add_line(pts, cols, uvs, idx, Vector2.ZERO, off + Vector2(0, 2), maxf(1.0, th * 0.35), Color(ph, 0, 0, 1), Color(ph, 0, 1, 1), off)
		# the clump, turning a little about its centre
		var poly: PackedVector2Array = cl.poly
		var tri := Geometry2D.triangulate_polygon(poly)
		var base := pts.size()
		for q in poly:
			pts.append(off + q)
			cols.append(Color(ph, 0.03, 1, 1))
			uvs.append(off)
		for i in tri:
			idx.append(base + i)
		for sp: Vector3 in cl.sprigs:
			var tip := Vector2(sp.x, sp.y)
			# the sprig turns with the clump; its leaf turns more, about its own stalk
			_add_line(pts, cols, uvs, idx, off + tip * 0.7, off + tip, 0.9, Color(ph, 0.03, 1, 1), Color(ph, 0.03, 1, 1), off)
			base = pts.size()
			for q in leaf_shape:
				pts.append(off + tip + q.rotated(sp.z))
				cols.append(Color(ph, 0.25, 1, 1))
				uvs.append(off + tip)
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var rid := _parts.add(_clump_mat)
	RenderingServer.canvas_item_add_triangle_array(rid, idx, pts, cols, uvs)
	return rid


func _add_line(pts: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array, idx: PackedInt32Array,
		a: Vector2, b: Vector2, width: float, col_a: Color, col_b: Color, pivot: Vector2) -> void:
	var n := (b - a).normalized().orthogonal() * width * 0.5
	var base := pts.size()
	pts.append_array(PackedVector2Array([a + n, b + n, b - n, a - n]))
	cols.append_array(PackedColorArray([col_a, col_b, col_b, col_a]))
	uvs.append_array(PackedVector2Array([pivot, pivot, pivot, pivot]))
	idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _cover_shapes() -> Array[PackedVector2Array]:
	return [_trunk]


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _parts == null:
		return
	if _leaves_fx:
		LeafParticles.blow(_leaves_fx, global_position.x)
	_parts.sync_layers()
	# off screen there is nothing to move; it catches up when it comes back into view
	if not CanvasParts.on_screen(self, _bounds):
		return
	var gust := Weather.gust_at(global_position.x)
	var wind := Weather.wind
	_clump_mat.set_shader_parameter("weather_time", Weather.time)
	_clump_mat.set_shader_parameter("wind", wind)
	_clump_mat.set_shader_parameter("gust_shift", Vector2(-wind * 2.5 * gust, 0.0))
	_pose(Weather.time, gust, wind)


## Sway the limbs for this moment (the further out, the more they move) by moving their parts.
func _pose(t: float, gust: float, wind: float) -> void:
	for i in _branches.size():
		var b := _branches[i]
		var lvl: int = b.level
		var k := (lvl - 1) / 3.0
		var sway := Vector2(-wind * (2.0 + 9.0 * k * k) * (0.5 + 0.8 * gust) + sin(t * (1.1 + lvl * 0.4) + b.phase) * k * 2.2 * wind, 0)
		var s0: Vector2 = b.start + sway * (k - 0.33 if lvl > 1 else 0.0)
		var m: Vector2 = b.mid + sway * (k - 0.15)
		var e: Vector2 = b.end + sway * k
		RenderingServer.canvas_item_set_transform(_seg_a[i], _stretch(s0, m))
		RenderingServer.canvas_item_set_transform(_seg_b[i], _stretch(m, e))
		RenderingServer.canvas_item_set_transform(_cap_start[i], Transform2D(0.0, s0))
		RenderingServer.canvas_item_set_transform(_cap_mid[i], Transform2D(0.0, m))
		RenderingServer.canvas_item_set_transform(_cap_end[i], Transform2D(0.0, e))
		if _crown[i].is_valid():
			RenderingServer.canvas_item_set_transform(_crown[i], Transform2D(0.0, e))


## Maps the unit segment onto a→b: x runs along it, y across it at true width.
static func _stretch(a: Vector2, b: Vector2) -> Transform2D:
	var d := b - a
	return Transform2D(d, d.normalized().orthogonal(), a)


func _draw() -> void:
	var c := Color.BLACK
	draw_colored_polygon(_trunk, c)
	for r in _roots:
		draw_colored_polygon(r, c)
	for i in range(0, _stubs.size(), 2):
		var th := _stubs[i + 1].z
		DrawKit.limb(self, Vector2(_stubs[i].x, _stubs[i].y), Vector2(_stubs[i + 1].x, _stubs[i + 1].y), th * 1.4, th * 0.7)
	_draw_cover_outline()
