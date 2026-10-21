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
		queue_redraw()
@export var sheds_leaves := true

var _branches: Array[Dictionary] = []
var _trunk := PackedVector2Array()
var _roots: Array[PackedVector2Array] = []
var _leaves_fx: GPUParticles2D


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
	var top := Vector2(sin(2.0 + tree_seed) * 5.0 * s, -trunk_h + 6.0 * s)
	var limbs := rng.randi_range(3, 4)
	for i in limbs:
		var a := lerpf(-PI * 0.95, -PI * 0.05, (i + rng.randf_range(0.25, 0.75)) / limbs)
		_grow_branch(rng, top, a, rng.randf_range(62, 84) * s, rng.randf_range(17, 22) * s, 1)
	queue_redraw()


func _grow_branch(rng: RandomNumberGenerator, start: Vector2, angle: float, length: float, thick: float, level: int) -> void:
	var bend := rng.randf_range(-0.35, 0.35)
	var mid := start + Vector2.from_angle(angle + bend) * length * 0.5
	var end := mid + Vector2.from_angle(angle - bend * 0.6) * length * 0.5
	var leaves: Array[Vector4] = []
	if level >= 3:
		for k in (7 if level >= 4 else 3):
			leaves.append(Vector4(rng.randf_range(-16, 16) * size, rng.randf_range(-14, 8) * size, rng.randf_range(6, 11) * size, rng.randf() * TAU))
	_branches.append({"start": start, "mid": mid, "end": end, "thick": thick, "level": level, "phase": rng.randf() * TAU, "leaves": leaves})
	if level < 4 and length > 14.0:
		var n := 2 if rng.randf() < 0.6 else 3
		for i in n:
			var spread := (i - (n - 1) * 0.5) * rng.randf_range(0.45, 0.8)
			var a := angle + spread + rng.randf_range(-0.2, 0.2)
			# oaks spread sideways more than they climb
			a = lerpf(a, -PI * 0.5 + signf(a + PI * 0.5) * 1.2, 0.15)
			_grow_branch(rng, end, a, length * rng.randf_range(0.62, 0.8), thick * 0.6, level + 1)


func _cover_shapes() -> Array[PackedVector2Array]:
	return [_trunk]


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	queue_redraw()
	if _leaves_fx:
		LeafParticles.blow(_leaves_fx, global_position.x)


func _draw() -> void:
	var c := Color.BLACK
	var t := Weather.time
	var gust := Weather.gust_at(global_position.x)
	var wind := Weather.wind
	draw_colored_polygon(_trunk, c)
	for r in _roots:
		draw_colored_polygon(r, c)
	for b in _branches:
		var lvl: int = b.level
		# the further out, the more it moves
		var k := (lvl - 1) / 3.0
		var sway := Vector2(-wind * (2.0 + 9.0 * k * k) * (0.5 + 0.8 * gust) + sin(t * (1.1 + lvl * 0.4) + b.phase) * k * 2.2 * wind, 0)
		var s0: Vector2 = b.start + sway * (k - 0.33 if lvl > 1 else 0.0)
		var m: Vector2 = b.mid + sway * (k - 0.15)
		var e: Vector2 = b.end + sway * k
		var th: float = b.thick
		DrawKit.limb(self, s0, m, th, th * 0.8)
		DrawKit.limb(self, m, e, th * 0.8, th * 0.6)
		if leafless:
			continue
		for l in b.leaves:
			var leaf: Vector4 = l
			var flutter := sin(t * (7.0 + wind * 6.0) + leaf.w * 3.0) * (0.4 + wind) * 0.8
			var p := e + Vector2(leaf.x - wind * 2.5 * gust, leaf.y + flutter)
			var r := leaf.z * (1.0 + 0.06 * sin(t * 3.0 + leaf.w))
			draw_circle(p, r, c)
			# a ragged rim of single leaves
			for j in 3:
				var a := leaf.w + j * 2.1 + flutter * 0.3
				DrawKit.ellipse(self, p + Vector2.from_angle(a) * r, Vector2(2.6, 1.3) * size, a + flutter, c, 6)
	_draw_cover_outline()
