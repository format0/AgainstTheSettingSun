class_name Player
extends CharacterBody2D
## The runner. Movement values come from the 2014 C version, which ran at 33 ticks per second:
## 1.2 px/tick² acceleration, 4 px/tick top speed, 22 px/tick jump, 15 px/tick terminal velocity.
## Converted here to pixels per second. The origin of this node is between the feet.

signal landed(fall_speed: float)

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

@export_group("Wind")
## Headwind push in px/s² at full wind. 0 keeps the original feel.
@export var wind_push := 0.0

var facing := 1
var _buffer := 0.0
var _coyote := 0.0
var _was_on_floor := false

@onready var runner: RunnerAnimator = $Runner
@onready var steps: AudioStreamPlayer2D = $Steps


func _ready() -> void:
	add_to_group("player")
	runner.footstep.connect(_on_footstep)


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	_buffer = jump_buffer if Input.is_action_just_pressed("jump") else maxf(0.0, _buffer - delta)
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)

	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		var target := dir * run_speed
		var braking := absf(velocity.x) > run_speed and signf(velocity.x) == signf(dir)
		velocity.x = move_toward(velocity.x, target, (overspeed_braking if braking else acceleration) * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	if wind_push > 0.0:
		velocity.x -= wind_push * Weather.wind * delta

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_velocity
		_buffer = 0.0
		_coyote = 0.0
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	var fall_speed := velocity.y
	var x_before := global_position.x
	move_and_slide()
	if is_on_ceiling() and velocity.y < 66.0:
		velocity.y = 66.0
	if is_on_floor() and not _was_on_floor:
		_on_landed(fall_speed)
	_was_on_floor = is_on_floor()

	runner.face(facing)
	runner.advance(global_position.x - x_before, is_on_floor(), velocity.y)


func _on_landed(fall_speed: float) -> void:
	landed.emit(fall_speed)
	var wet := Puddle.is_wet_at(global_position.x)
	get_tree().call_group("splash_emitters", "burst", global_position, 12 if wet else 6, 0.6 + fall_speed / 800.0)
	_play_step(wet)


func _on_footstep() -> void:
	var wet := Puddle.is_wet_at(global_position.x)
	get_tree().call_group("splash_emitters", "burst", global_position - Vector2(facing * 6, 0), 8 if wet else 3, 1.0 if wet else 0.6)
	_play_step(wet)


func _play_step(wet: bool) -> void:
	steps.stream = SoundBank.step(wet)
	steps.pitch_scale = randf_range(0.85, 1.15)
	steps.play()
