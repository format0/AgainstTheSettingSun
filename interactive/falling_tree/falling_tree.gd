@tool
@icon("res://interactive/falling_tree/falling_tree_icon.svg")
class_name FallingTree
extends Node2D
## A rotten tree that comes down: creaks, leans, falls and crushes whatever is under it, then
## lies there as a bridge or a ramp. It can be a trap (it falls when the player comes close),
## a tool (push it with the action button, or drop it with a switch) or both.
## The node's position is the foot of the trunk. Set `fall_angle` so the crown lands where
## you want: the editor shows a dashed outline of where it will lie.

enum Trigger { PUSH, PROXIMITY, SIGNAL }

@export var height := 230.0:
	set(v):
		height = v
		_grow()
@export var trunk_width := 20.0:
	set(v):
		trunk_width = v
		_grow()
## 1 = falls to the right, -1 = to the left.
@export_range(-1, 1, 2) var fall_direction := 1:
	set(v):
		fall_direction = v
		queue_redraw()
## Degrees from upright when it comes to rest.
@export_range(30.0, 110.0) var fall_angle := 84.0:
	set(v):
		fall_angle = v
		queue_redraw()
@export var trigger := Trigger.PROXIMITY
## PROXIMITY: how close (horizontally, on the side it falls to) the player must come.
@export var trigger_distance := 70.0
## Seconds of creaking between the trigger and the fall.
@export var warning_time := 0.9
@export var tree_seed := 3:
	set(v):
		tree_seed = v
		_grow()

enum State { STANDING, CREAKING, FALLING, FALLEN }

var state := State.STANDING
var _angle := 0.0
var _spin := 0.0
var _timer := 0.0
var _branches: Array[Dictionary] = []
var _body: StaticBody2D
var _sound: AudioStreamPlayer2D
var _focused := false
var _highlight := 0.0
var _bounced := 0


func _ready() -> void:
	z_index = Layers.ELEMENTS
	_grow()
	if Engine.is_editor_hint():
		return
	if trigger == Trigger.PUSH:
		add_to_group("interactables")
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 1400.0
	add_child(_sound)
	_body = StaticBody2D.new()
	_body.set_meta("surface", "wood")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(trunk_width * 0.8, height * 0.9)
	cs.shape = rect
	cs.position = Vector2(0, -height * 0.45 - trunk_width * 0.3)
	_body.add_child(cs)
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_body)
	if Level.recall(self) == true:
		_land(true)


func _grow() -> void:
	_branches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	for i in 7:
		var u := rng.randf_range(0.45, 0.95)
		var side := 1.0 if i % 2 == 0 else -1.0
		var a := -PI * 0.5 + side * rng.randf_range(0.35, 0.9)
		var length := rng.randf_range(0.18, 0.32) * height * (1.1 - u * 0.5)
		_branches.append({"u": u, "a": a, "len": length, "w": trunk_width * rng.randf_range(0.25, 0.4), "twig": rng.randf_range(-0.6, 0.6), "phase": rng.randf() * TAU})
	queue_redraw()


# ------------------------------------------------------------------ triggering

func can_interact(_player: Player) -> bool:
	return state == State.STANDING


func get_interact_position() -> Vector2:
	return global_position + Vector2(-fall_direction * trunk_width * 0.6, -22)


func set_highlight(on: bool) -> void:
	_focused = on


func interact(_player: Player) -> void:
	_start_creaking()


func set_active(on: bool, _instant := false) -> void:
	if on and state == State.STANDING:
		_start_creaking()


func _start_creaking() -> void:
	if state != State.STANDING:
		return
	state = State.CREAKING
	_timer = warning_time
	_sound.stream = SoundBank.wood_creak()
	_sound.play()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	match state:
		State.STANDING:
			if trigger == Trigger.PROXIMITY:
				var p := get_tree().get_first_node_in_group("player") as Player
				if p and not p.dead:
					var dx := (p.global_position.x - global_position.x) * fall_direction
					if dx > -10.0 and dx < trigger_distance and absf(p.global_position.y - global_position.y) < 120.0:
						_start_creaking()
			_highlight = move_toward(_highlight, 1.0 if _focused else 0.0, delta * 4.0)
		State.CREAKING:
			_timer -= delta
			_angle = deg_to_rad(2.0) * fall_direction * (1.0 - _timer / warning_time) + sin(Weather.time * 30.0) * 0.004
			if _timer <= 0.0:
				state = State.FALLING
				_spin = 0.15 * fall_direction
				_sound.stream = SoundBank.wood_snap()
				_sound.play()
		State.FALLING:
			# a falling pole: angular acceleration grows with the lean
			_spin += 3.4 * sin(absf(_angle) + 0.05) * fall_direction * delta * 9.81 / (height / 100.0)
			_angle += _spin * delta
			_crush_check()
			var goal := deg_to_rad(fall_angle) * fall_direction
			if absf(_angle) >= absf(goal):
				_angle = goal
				if _bounced < 1 and absf(_spin) > 0.8:
					_spin = -_spin * 0.18
					_bounced += 1
					_impact()
				else:
					_land(false)
	queue_redraw()


func _crush_check() -> void:
	if absf(_angle) < deg_to_rad(25.0):
		return
	var tip := Vector2.from_angle(-PI * 0.5 + _angle) * height
	var a := global_position
	var b := global_position + tip
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead:
		for pt in [p.global_position + Vector2(0, -10), p.global_position + Vector2(0, -34)]:
			if Geometry2D.get_closest_point_to_segment(pt, a, b).distance_to(pt) < trunk_width * 0.5 + 8.0:
				p.die("crushed")
				break
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead:
			var pt := en.global_position + Vector2(0, -12)
			if Geometry2D.get_closest_point_to_segment(pt, a, b).distance_to(pt) < trunk_width * 0.5 + 10.0:
				en.die()


func _impact() -> void:
	var tip := global_position + Vector2.from_angle(-PI * 0.5 + _angle) * height
	_sound.stream = SoundBank.tree_crash()
	_sound.play()
	get_tree().call_group("game_camera", "shake", 7.0)
	get_tree().call_group("dust_emitters", "burst", global_position.lerp(tip, 0.6), 30, height * 0.6)
	get_tree().call_group("leaf_emitters", "burst", tip, 40)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.make_noise(tip, 500.0)


func _land(instant: bool) -> void:
	state = State.FALLEN
	_angle = deg_to_rad(fall_angle) * fall_direction
	if not instant and _bounced == 0:
		_impact()
	Level.remember(self, true)
	remove_from_group("interactables")
	_body.rotation = _angle
	_body.process_mode = Node.PROCESS_MODE_INHERIT


func _draw() -> void:
	var c := Color.BLACK
	var wind := Weather.wind
	var t := Weather.time
	var standing := state == State.STANDING or state == State.CREAKING
	# the root plate tears out of the ground on the far side as it falls
	if not standing:
		var lift := clampf(absf(_angle) / deg_to_rad(fall_angle), 0.0, 1.0)
		var back := Vector2(-fall_direction * trunk_width * 0.9, 0)
		DrawKit.ellipse(self, back * lift + Vector2(0, -trunk_width * 0.6 * lift), Vector2(trunk_width * 0.9, trunk_width * (0.4 + lift * 0.5)), _angle, c, 14)
		for k in 5:
			var a := _angle + PI * 0.5 + (k - 2) * 0.45
			DrawKit.limb(self, back * lift, back * lift + Vector2.from_angle(a) * trunk_width * 1.3, 2.4, 0.8)
	draw_set_transform(Vector2.ZERO, _angle)
	var w := trunk_width
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.75, 0), Vector2(-w * 0.5, -10), Vector2(-w * 0.32, -height * 0.85),
		Vector2(-w * 0.12, -height), Vector2(w * 0.12, -height), Vector2(w * 0.3, -height * 0.85), Vector2(w * 0.5, -10), Vector2(w * 0.8, 0)]), c)
	if standing:
		# roots holding on
		DrawKit.limb(self, Vector2(-w * 0.5, -4), Vector2(-w * 1.4, 1), 4.0, 1.0)
		DrawKit.limb(self, Vector2(w * 0.5, -4), Vector2(w * 1.5, 1), 4.0, 1.0)
	for b in _branches:
		var base := Vector2(0, -height * float(b.u))
		var sway := (-wind * 0.08 * (0.5 + Weather.gust_at(global_position.x)) + sin(t * 1.6 + float(b.phase)) * 0.03 * wind) if standing else 0.0
		var dir := Vector2.from_angle(float(b.a) + sway)
		var mid := base + dir * float(b.len) * 0.55
		var tip := base + dir * float(b.len)
		DrawKit.limb(self, base, mid, b.w, float(b.w) * 0.55)
		DrawKit.limb(self, mid, tip, float(b.w) * 0.55, 1.0)
		DrawKit.limb(self, mid, mid + Vector2.from_angle(float(b.a) + float(b.twig) + sway * 1.5) * float(b.len) * 0.4, float(b.w) * 0.4, 0.8)
	draw_set_transform(Vector2.ZERO)
	if not Engine.is_editor_hint() and trigger == Trigger.PUSH and state == State.STANDING:
		Mechanism.draw_glint(self, get_interact_position() - global_position, _highlight)
	if Engine.is_editor_hint():
		var a := deg_to_rad(fall_angle) * fall_direction
		DrawKit.editor_link(self, Vector2.ZERO, Vector2.from_angle(-PI * 0.5 + a) * height, DrawKit.EDITOR_INTERACTIVE)
		DrawKit.editor_caption(self, Vector2(6, -height - 4), DrawKit.EDITOR_INTERACTIVE, "falls " + ["push", "near", "switch"][trigger])
		if trigger == Trigger.PROXIMITY:
			draw_line(Vector2(trigger_distance * fall_direction, 0), Vector2(trigger_distance * fall_direction, -40), DrawKit.EDITOR_HAZARD, 1.0)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-35, -height, 70, height)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "height", "pos": Vector2(0, -height)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	height = maxf(60.0, -p.y)
