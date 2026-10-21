@tool
@icon("res://enemies/watcher/watcher_icon.svg")
class_name Watcher
extends Node2D
## A hunched thing perched high up, with one great pale eye that throws a beam of light,
## sweeping slowly back and forth. It never moves and can't hurt you itself, but its beam
## takes away your shadow, and if it falls on you it screams, and every hunter within
## earshot comes to that spot. The node's position is its feet on the perch.

## The sweep, in degrees (0 = straight right, 90 = straight down).
@export var sweep_from := 25.0
@export var sweep_to := 110.0
## Seconds for one sweep.
@export var sweep_time := 6.0
@export var beam_length := 420.0
## Half the opening of the beam, in degrees.
@export var beam_width := 8.0
## Hunters within this distance of the player come when it screams.
@export var alarm_radius := 900.0

var state := Enemy.State.PATROL
var dead := false
var _angle := 0.0
var _t := 0.0
var _cooldown := 0.0
var _flare := 0.0
var _voice: AudioStreamPlayer2D
var _beam: Node2D


func _ready() -> void:
	z_index = Layers.ENEMIES
	_angle = deg_to_rad(sweep_from)
	if Engine.is_editor_hint():
		return
	add_to_group("enemies")
	add_to_group("light_sources")
	add_to_group("lamps")
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 1600.0
	add_child(_voice)
	# the beam is drawn behind the solid things, so they cut it and the player shows in it
	_beam = Node2D.new()
	_beam.z_as_relative = false
	_beam.z_index = Layers.COVER + 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = mat
	_beam.draw.connect(_draw_beam)
	add_child(_beam)
	Game.no_occlude(_beam)


func _eye() -> Vector2:
	return global_position + Vector2(10, -34)


func hear(_at: Vector2) -> void:
	pass


func die() -> void:
	dead = true
	remove_from_group("enemies")
	remove_from_group("light_sources")
	remove_from_group("lamps")
	queue_free()


func burn() -> void:
	die()


func drown() -> void:
	die()


## Inside the beam and not hidden behind something solid.
func illuminates(world_pos: Vector2) -> bool:
	var d := world_pos - _eye()
	if d.length() > beam_length or d.length() < 4.0:
		return false
	if absf(wrapf(d.angle() - _angle, -PI, PI)) > deg_to_rad(beam_width) * 1.2:
		return false
	var q := PhysicsRayQueryParameters2D.create(_eye(), world_pos, Layers.BODY_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func get_light_points() -> Array[Vector3]:
	var e := _eye()
	return [Vector3(e.x, e.y, 0.6 + _flare)]


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_t += delta / sweep_time
	var u := 0.5 - 0.5 * cos(_t * PI)
	_angle = deg_to_rad(lerpf(sweep_from, sweep_to, u))
	_cooldown -= delta
	_flare = move_toward(_flare, 0.0, delta)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead and _cooldown <= 0.0 and illuminates(p.global_position + Vector2(0, -24)):
		_cooldown = 4.0
		_flare = 1.0
		_voice.stream = SoundBank.shriek()
		_voice.pitch_scale = 0.7
		_voice.volume_db = 4.0
		_voice.play()
		state = Enemy.State.ALERT
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e.has_method("hear") and (e as Node2D).global_position.distance_to(p.global_position) < alarm_radius:
				e.hear(p.global_position)
	elif _cooldown < 2.0:
		state = Enemy.State.PATROL
	queue_redraw()
	_beam.queue_redraw()


func _draw_beam() -> void:
	var e := _eye() - global_position
	var w := deg_to_rad(beam_width)
	var space := get_world_2d().direct_space_state
	var root := Color(0.75, 0.82, 0.9, 0.45 + _flare * 0.4)
	var hot := Color(0.9, 0.95, 1.0, 0.35 + _flare * 0.4)
	var n := 24
	# each ray of the fan stops at the first solid thing, so beams and girders cast shadows
	var ends := PackedVector2Array()
	var reach := PackedFloat32Array()
	for i in n + 1:
		var a := _angle - w + 2.0 * w * i / n
		var to := e + Vector2.from_angle(a) * beam_length
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + e, global_position + to, Layers.BODY_WORLD))
		var k := 1.0
		if not hit.is_empty():
			k = clampf(((hit.position as Vector2) - global_position - e).length() / beam_length, 0.0, 1.0)
		ends.append(e + (to - e) * k)
		reach.append(k)
	# a fan of triangles so the colours blend from the eye outwards
	for i in n:
		var c1 := Color(0.35, 0.42, 0.55, 0.0).lerp(root, (1.0 - reach[i]) * 0.6)
		var c2 := Color(0.35, 0.42, 0.55, 0.0).lerp(root, (1.0 - reach[i + 1]) * 0.6)
		_beam.draw_polygon(PackedVector2Array([e, ends[i], ends[i + 1]]), PackedColorArray([root, c1, c2]))
		# the hot core in the middle third of the beam
		var u := absf(float(i) + 0.5 - n * 0.5) / (n * 0.5)
		if u < 0.4:
			var m1 := e + (ends[i] - e) * minf(1.0, 0.7 / maxf(reach[i], 0.001))
			var m2 := e + (ends[i + 1] - e) * minf(1.0, 0.7 / maxf(reach[i + 1], 0.001))
			var cc := Color(hot.r, hot.g, hot.b, hot.a * (1.0 - u / 0.4))
			_beam.draw_polygon(PackedVector2Array([e, m1, m2]), PackedColorArray([cc, Color(0.4, 0.5, 0.6, 0.0), Color(0.4, 0.5, 0.6, 0.0)]))
	_beam.draw_circle(e, 9.0, Color(0.8, 0.88, 1.0, 0.2 + _flare * 0.3))


func _draw() -> void:
	var c := Color.BLACK
	var t := Weather.time
	# a hunched body on long folded legs, a long neck and a head that turns with the beam
	DrawKit.limb(self, Vector2(-4, 0), Vector2(-8, -10), 2.0, 2.0)
	DrawKit.limb(self, Vector2(-8, -10), Vector2(-2, -16), 2.0, 2.0)
	DrawKit.limb(self, Vector2(5, 0), Vector2(8, -9), 2.0, 2.0)
	DrawKit.limb(self, Vector2(8, -9), Vector2(3, -16), 2.0, 2.0)
	DrawKit.ellipse(self, Vector2(-1, -20), Vector2(11, 7), -0.25 + sin(t * 1.5) * 0.03, c, 14)
	var head := Vector2(10, -34)
	DrawKit.limb(self, Vector2(4, -24), head + Vector2(-3, 3), 4.0, 3.0)
	DrawKit.ellipse(self, head, Vector2(7, 5), _angle * 0.3, c, 12)
	for k in 4:
		draw_line(Vector2(-10 + k * 4, -26), Vector2(-14 + k * 4, -33 - k), c, 1.2)
	if Engine.is_editor_hint():
		var e := head
		for a: float in [sweep_from, sweep_to]:
			DrawKit.editor_link(self, e, e + Vector2.from_angle(deg_to_rad(a)) * beam_length, DrawKit.EDITOR_ENEMY)
		DrawKit.editor_caption(self, Vector2(-20, 14), DrawKit.EDITOR_ENEMY, "watcher (alarm)")
	else:
		draw_circle(head + Vector2(2, -1), 2.6, Color(0.85, 0.92, 1.0, 0.9))

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-22, -52, 44, 52)


func _editor_handles() -> Array[Dictionary]:
	var eye := Vector2(10, -34)
	return [{"id": "from", "pos": eye + Vector2.from_angle(deg_to_rad(sweep_from)) * beam_length, "props": ["sweep_from", "beam_length"]},
		{"id": "to", "pos": eye + Vector2.from_angle(deg_to_rad(sweep_to)) * beam_length, "props": ["sweep_to", "beam_length"]}]


## Dragging the end of a beam sets its angle and the beam's length.
func _editor_drag(id: Variant, p: Vector2) -> void:
	var d := p - Vector2(10, -34)
	if id == "from":
		sweep_from = roundf(rad_to_deg(d.angle()))
	else:
		sweep_to = roundf(rad_to_deg(d.angle()))
	beam_length = maxf(40.0, roundf(d.length()))
	queue_redraw()
