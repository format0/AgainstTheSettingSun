@tool
@icon("res://enemies/burrower/burrower_icon.svg")
class_name Burrower
extends Node2D
## Something that lives under soft ground. All you see is a mound where the earth twitches
## and the grass shivers. It hears footsteps and landings: shortly after, a crown of hooked
## limbs bursts up where the sound was, then sinks back. Jump clean over its patch, or keep
## running and never stop on it: it feels someone standing still on its patch. The node's
## position is the middle of its patch, on the ground.

@export var patch_width := 110.0:
	set(v):
		patch_width = v
		queue_redraw()
## Seconds between hearing a step and bursting up.
@export var delay := 0.45

enum Mode { BURIED, RISING, UP, SINKING }

var state := Enemy.State.PATROL
var dead := false
var _mode := Mode.BURIED
var _x := 0.0
var _target := 0.0
var _still := 0.0
var _timer := 0.0
var _rise := 0.0
var _voice: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.ENEMIES
	if Engine.is_editor_hint():
		return
	add_to_group("enemies")
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 900.0
	add_child(_voice)


## Footsteps and landings within its patch tell it where to strike.
func hear(at: Vector2) -> void:
	if dead or _mode != Mode.BURIED:
		return
	var local := at - global_position
	if absf(local.x) > patch_width * 0.5 + 10.0 or absf(local.y) > 20.0:
		return
	_target = clampf(local.x, -patch_width * 0.5, patch_width * 0.5)
	_mode = Mode.RISING
	_timer = delay
	_voice.stream = SoundBank.stone_thud()
	_voice.pitch_scale = 0.5
	_voice.play()


func die() -> void:
	dead = true
	remove_from_group("enemies")
	queue_free()


func burn() -> void:
	die()


func drown() -> void:
	die()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	match _mode:
		Mode.BURIED:
			state = Enemy.State.PATROL
			_x = move_toward(_x, sin(Weather.time * 0.4) * patch_width * 0.3, 10.0 * delta)
			# someone standing still on its patch: it feels the weight
			var pl := get_tree().get_first_node_in_group("player") as Player
			var rel := pl.global_position - global_position if pl else Vector2.INF
			if pl and not pl.dead and pl.is_on_floor() and absf(rel.x) < patch_width * 0.5 and absf(rel.y) < 20.0 and absf(pl.velocity.x) < 20.0:
				_still += delta
				if _still > 0.35:
					_still = 0.0
					hear(pl.global_position)
			else:
				_still = 0.0
		Mode.RISING:
			state = Enemy.State.ALERT
			_x = move_toward(_x, _target, 160.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_mode = Mode.UP
				_timer = 1.1
				_x = _target
				_voice.stream = SoundBank.shriek()
				_voice.pitch_scale = 0.55
				_voice.play()
				get_tree().call_group("dust_emitters", "burst", global_position + Vector2(_x, 0), 22, 40.0)
				get_tree().call_group("game_camera", "shake", 2.5)
		Mode.UP:
			_rise = move_toward(_rise, 1.0, delta * 9.0)
			_timer -= delta
			if _timer <= 0.0:
				_mode = Mode.SINKING
		Mode.SINKING:
			_rise = move_toward(_rise, 0.0, delta * 1.5)
			if _rise <= 0.0:
				_mode = Mode.BURIED
	if _rise > 0.4:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and not p.dead:
			var r := Rect2(global_position + Vector2(_x - 22, -54 * _rise), Vector2(44, 54 * _rise + 4))
			if r.intersects(Rect2(p.global_position + Vector2(-9, -38), Vector2(18, 38))):
				p.die("caught")
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var t := Weather.time
	var w := patch_width
	# the mound and the restless earth over it
	var twitch := (sin(t * 23.0) * 0.8 if _mode == Mode.RISING else sin(t * 2.0 + _x) * 0.3)
	var mound := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var x := lerpf(-w * 0.5 - 8.0, w * 0.5 + 8.0, u)
		var bump := exp(-pow((x - _x) / 18.0, 2.0)) * (3.5 + twitch + (5.0 if _mode == Mode.RISING else 0.0))
		mound.append(Vector2(x, 1.0 - bump - sin(u * PI) * 2.0))
	mound.append(Vector2(w * 0.5 + 8.0, 4.0))
	mound.append(Vector2(-w * 0.5 - 8.0, 4.0))
	draw_colored_polygon(mound, c)
	for k in 7:
		var x := _x + (k - 3) * 5.0
		var shiver := sin(t * (14.0 if _mode == Mode.RISING else 3.0) + k) * (2.0 if _mode == Mode.RISING else 0.6)
		draw_line(Vector2(x, -2), Vector2(x + shiver - Weather.wind * 2.0, -9.0 - (k * 5) % 6), c, 1.0)
	if _rise > 0.0:
		# a crown of hooked limbs bursting out of the ground
		var h := 54.0 * _rise
		for k in 7:
			var a := -PI * 0.5 + (k - 3) * 0.28
			var base := Vector2(_x + (k - 3) * 4.0, 2)
			var mid := base + Vector2.from_angle(a) * h * 0.6
			var tip := mid + Vector2.from_angle(a + (0.6 if k < 3 else -0.6 if k > 3 else 0.0)) * h * 0.45
			DrawKit.limb(self, base, mid, 5.0, 3.0)
			DrawKit.limb(self, mid, tip, 3.0, 0.8)
		DrawKit.ellipse(self, Vector2(_x, -h * 0.25), Vector2(10, h * 0.3 + 2.0), 0.0, c, 12)
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(-w * 0.5, -56, w, 56), DrawKit.EDITOR_ENEMY, "burrower")
