class_name Player
extends CharacterBody2D
## The runner. Movement values come from the 2014 C version, which ran at 33 ticks per second:
## 1.2 px/tick² acceleration, 4 px/tick top speed, 22 px/tick jump, 15 px/tick terminal velocity.
## Converted here to pixels per second. The origin of this node is between the feet.
##
## Controls: left/right to run, up to jump, one action button to pull levers, push and
## pull crates and use anything else in the "interactables" group.
## Standing in front of a black shape (a Cover) hides him from enemies, unless a light is on him.

signal landed(fall_speed: float)
signal died(cause: String)

@export_group("Running")
@export var run_speed := 132.0
@export var acceleration := 1307.0
@export var ground_friction := 1307.0
## Slow-down when something pushed him faster than run_speed.
@export var overspeed_braking := 653.0

@export_group("Jumping")
@export var jump_velocity := 726.0
@export var gravity := 1307.0
@export var max_fall_speed := 495.0
## A jump pressed this long before landing still counts.
@export var jump_buffer := 0.12
## A jump pressed this long after running off an edge still counts.
@export var coyote_time := 0.08

@export_group("Hands")
## How far away an interactable can be used.
@export var reach := 34.0
## Running speed while pushing or pulling a crate.
@export var grab_speed := 62.0

var facing := 1
var dead := false
var cause_of_death := ""
## True while he stands in front of a Cover and no light falls on him (enemies can't see him).
var in_shadow := false
var grabbed: Node2D
## For testing: nothing can kill him.
var invulnerable := false
## The body he is standing on (crates and bridges want to know).
var standing_on: Object

var _buffer := 0.0
var _coyote := 0.0
var _was_on_floor := false
var _frozen := false
var _auto_run := 0
var _focus: Node2D
var _death_time := 0.0
var _rim := 0.0
var _rim_material: ShaderMaterial

@onready var runner: RunnerAnimator = $Runner
@onready var steps: AudioStreamPlayer2D = $Steps


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.BODY_PLAYER
	collision_mask = Layers.BODY_WORLD
	z_index = Layers.PLAYER
	runner.footstep.connect(_on_footstep)
	_rim_material = ShaderMaterial.new()
	_rim_material.shader = preload("res://player/silhouette_rim.gdshader")
	runner.material = _rim_material


func _physics_process(delta: float) -> void:
	if dead:
		_physics_dead(delta)
		return
	var dir := 0.0
	if _auto_run != 0:
		dir = _auto_run
	elif not _frozen:
		dir = Input.get_axis("move_left", "move_right")
	var jump_pressed := Input.is_action_just_pressed("jump") and not _frozen and _auto_run == 0
	_buffer = jump_buffer if jump_pressed else maxf(0.0, _buffer - delta)
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)

	_update_hands()
	var speed := grab_speed if grabbed else run_speed
	if dir != 0.0:
		if not grabbed:
			facing = 1 if dir > 0.0 else -1
		var target := dir * speed
		var braking := absf(velocity.x) > speed and signf(velocity.x) == signf(dir)
		velocity.x = move_toward(velocity.x, target, (overspeed_braking if braking else acceleration) * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	if _buffer > 0.0 and _coyote > 0.0 and not grabbed:
		velocity.y = -jump_velocity
		_buffer = 0.0
		_coyote = 0.0
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	var fall_speed := velocity.y
	var x_before := global_position.x
	move_and_slide()
	if is_on_ceiling() and velocity.y < 66.0:
		velocity.y = 66.0
	standing_on = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y < -0.7:
			standing_on = col.get_collider()
	_push_things(dir)
	if grabbed and grabbed.has_method("drag"):
		grabbed.drag(dir * speed)
	if is_on_floor() and not _was_on_floor:
		_on_landed(fall_speed)
	_was_on_floor = is_on_floor()

	in_shadow = Cover.hides(_body_points()) and not LightSource.lit_at(global_position + Vector2(0, -20))
	_rim = move_toward(_rim, 1.0 if in_shadow else 0.0, delta * 3.0)
	_rim_material.set_shader_parameter("rim", _rim)

	runner.face(facing)
	runner.advance(global_position.x - x_before, is_on_floor(), velocity.y)


## Points on the body that must all be in front of a cover to be hidden.
func _body_points() -> PackedVector2Array:
	var p := global_position
	return PackedVector2Array([p + Vector2(0, -38), p + Vector2(-5, -26), p + Vector2(5, -26), p + Vector2(0, -12), p + Vector2(0, -3)])


# ------------------------------------------------------------------ hands

func _update_hands() -> void:
	if grabbed:
		if not Input.is_action_pressed("action") or _frozen or not is_on_floor() \
				or absf(grabbed.global_position.x - global_position.x) > reach + 40.0:
			_release()
		return
	var best: Node2D = null
	var best_d := reach
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Node2D
		if it == null or not it.can_interact(self):
			continue
		var spot: Vector2 = it.get_interact_position()
		var d := (spot - (global_position + Vector2(0, -20))).length()
		if d < best_d:
			best_d = d
			best = it
	if best != _focus:
		if is_instance_valid(_focus) and _focus.has_method("set_highlight"):
			_focus.set_highlight(false)
		_focus = best
		if _focus and _focus.has_method("set_highlight"):
			_focus.set_highlight(true)
	if _focus and Input.is_action_just_pressed("action") and not _frozen:
		facing = 1 if _focus.get_interact_position().x >= global_position.x else -1
		_focus.interact(self)


## Called by things that can be held (crates) from their interact().
func grab(thing: Node2D) -> void:
	grabbed = thing
	facing = 1 if thing.global_position.x >= global_position.x else -1


func _release() -> void:
	if grabbed and grabbed.has_method("release"):
		grabbed.release(self)
	grabbed = null


## Walking into a pushable thing nudges it along.
func _push_things(dir: float) -> void:
	if dir == 0.0 or not is_on_floor():
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other and other != grabbed and other.has_method("push") and absf(c.get_normal().x) > 0.7 and signf(-c.get_normal().x) == signf(dir):
			other.push(dir * grab_speed)
			velocity.x = dir * grab_speed


# ------------------------------------------------------------------ sound and splashes

func _on_landed(fall_speed: float) -> void:
	landed.emit(fall_speed)
	var wet := Puddle.is_wet_at(global_position)
	get_tree().call_group("splash_emitters", "burst", global_position, 12 if wet else 6, 0.6 + fall_speed / 800.0)
	_play_step(wet, 1.0 + fall_speed / 600.0)
	if fall_speed > 380.0:
		make_noise(global_position, 160.0 + fall_speed * 0.3)


func _on_footstep() -> void:
	var wet := Puddle.is_wet_at(global_position)
	get_tree().call_group("splash_emitters", "burst", global_position - Vector2(facing * 6, 0), 8 if wet else 3, 1.0 if wet else 0.6)
	_play_step(wet, 1.0)


func _play_step(wet: bool, loudness: float) -> void:
	steps.stream = SoundBank.step("water" if wet else _floor_surface())
	steps.pitch_scale = randf_range(0.85, 1.15)
	steps.volume_db = -6.0 + linear_to_db(clampf(loudness, 0.3, 2.0))
	steps.play()


func _floor_surface() -> String:
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other and "surface" in other and other.surface != "":
			return other.surface
		if other and other.has_meta("surface"):
			return other.get_meta("surface")
	return Level.current.ground_surface if Level.current else "grass"


## Tell nearby enemies that something made a sound.
func make_noise(at: Vector2, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("hear") and (e as Node2D).global_position.distance_to(at) < radius:
			e.hear(at)


# ------------------------------------------------------------------ the end

## Kills the runner. cause: "fell", "caught", "crushed", "drowned", "burned".
func die(cause: String) -> void:
	if dead or invulnerable or Level.current and Level.current.state != Level.State.PLAYING:
		return
	dead = true
	cause_of_death = cause
	_release()
	_death_time = 0.0
	died.emit(cause)
	match cause:
		"burned":
			get_tree().call_group("ember_emitters", "burst", global_position + Vector2(0, -16), 60)
			steps.stream = SoundBank.sizzle()
			steps.volume_db = 0.0
			steps.play()
		"drowned":
			get_tree().call_group("splash_emitters", "burst", global_position + Vector2(0, -20), 30, 1.6)
			steps.stream = SoundBank.splash()
			steps.volume_db = 0.0
			steps.play()
		"crushed", "caught":
			get_tree().call_group("game_camera", "shake", 4.0)
			steps.stream = SoundBank.body_fall()
			steps.volume_db = 0.0
			steps.play()
	if Level.current:
		Level.current.player_died(cause)


func _physics_dead(delta: float) -> void:
	_death_time += delta
	match cause_of_death:
		"fell":
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
			velocity.x *= 0.98
			move_and_slide()
		"drowned":
			velocity = velocity.lerp(Vector2(0, 38), 1.0 - exp(-delta * 4.0))
			global_position += velocity * delta
			runner.rotation = sin(_death_time * 9.0) * 0.25 * exp(-_death_time)
			if randf() < delta * 6.0:
				get_tree().call_group("splash_emitters", "burst", global_position + Vector2(randf_range(-6, 6), -50 - _death_time * 38.0), 2, 0.4)
		"burned":
			global_position.y += 55.0 * delta
			runner.modulate = Color(1.0, 0.45, 0.1).lerp(Color.BLACK, minf(1.0, _death_time * 1.5))
		"crushed":
			runner.scale.y = move_toward(runner.scale.y, runner.draw_scale * 0.15, delta * 6.0)
		_:
			runner.rotation = move_toward(runner.rotation, -facing * PI * 0.47, delta * 7.0)
			velocity.x *= 0.9
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
			move_and_slide()


## The level is won: keep running out of the picture.
func escape() -> void:
	_release()
	_auto_run = facing


## Darkness: stop moving.
func freeze() -> void:
	_release()
	_frozen = true
