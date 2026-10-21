@tool
@icon("res://enemies/dangler/dangler_icon.svg")
class_name Dangler
extends Node2D
## Something long and thin hanging head-down on a thread under a beam or a branch, arms
## dangling. When the player passes beneath it in the open it twitches, then drops on him,
## swinging toward him as it falls, and slowly climbs back. Bait it, step back, and slip
## past while it climbs. It doesn't sense a player standing in shadow. The node's position
## is where the thread is fixed.

## Where it waits, below the anchor.
@export var rest_drop := 70.0:
	set(v):
		rest_drop = v
		queue_redraw()
## How far it drops (its head ends up this far below the anchor).
@export var strike_drop := 330.0:
	set(v):
		strike_drop = v
		queue_redraw()
## Horizontal reach of its senses.
@export var sense_width := 60.0
## Seconds between noticing and dropping.
@export var warning_time := 0.3

enum Mode { WAIT, TWITCH, DROP, HANG, CLIMB }

## For the ambience and the debug panel (treated like an enemy's state).
var state := Enemy.State.PATROL
var dead := false
var _mode := Mode.WAIT
var _y := 0.0
var _vy := 0.0
var _timer := 0.0
var _sway := 0.0
var _aim := 0.0
var _voice: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.ENEMIES
	_y = rest_drop
	if Engine.is_editor_hint():
		return
	add_to_group("enemies")
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 900.0
	add_child(_voice)


func hear(_at: Vector2) -> void:
	pass


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
		_y = rest_drop
		queue_redraw()
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	# it swings on its thread toward the player as it falls, so running underneath is no escape
	if p and (_mode == Mode.TWITCH or _mode == Mode.DROP):
		_aim = move_toward(_aim, clampf(p.global_position.x - global_position.x, -70.0, 70.0), 250.0 * delta)
	elif _mode == Mode.CLIMB or _mode == Mode.WAIT:
		_aim = move_toward(_aim, 0.0, 40.0 * delta)
	_sway = _aim + sin(Weather.time * 1.1 + global_position.x) * (2.0 + Weather.wind * 6.0) - Weather.wind * 6.0 * Weather.gust_at(global_position.x)
	match _mode:
		Mode.WAIT:
			state = Enemy.State.PATROL
			if p and not p.dead and not p.in_shadow and absf(p.global_position.x - (global_position.x + _sway)) < sense_width \
					and p.global_position.y > global_position.y + _y and p.global_position.y < global_position.y + strike_drop + 80.0:
				_mode = Mode.TWITCH
				_timer = warning_time
				_say(SoundBank.chitter(), -4.0)
		Mode.TWITCH:
			state = Enemy.State.ALERT
			_timer -= delta
			if _timer <= 0.0:
				_mode = Mode.DROP
				_vy = 400.0
				_say(SoundBank.shriek(), -2.0)
		Mode.DROP:
			_vy += 2400.0 * delta
			_y = minf(_y + _vy * delta, strike_drop)
			if _y >= strike_drop:
				_mode = Mode.HANG
				_timer = 1.4
		Mode.HANG:
			_timer -= delta
			if _timer <= 0.0:
				_mode = Mode.CLIMB
		Mode.CLIMB:
			state = Enemy.State.SEARCH
			_y = move_toward(_y, rest_drop, 70.0 * delta)
			if _y <= rest_drop:
				_mode = Mode.WAIT
	if p and not p.dead and (_mode == Mode.DROP or _mode == Mode.HANG):
		var body := Rect2(global_position + Vector2(_sway - 10.0, _y - 12.0), Vector2(20, 64))
		if body.intersects(Rect2(p.global_position + Vector2(-9, -38), Vector2(18, 36))):
			p.die("caught")
	queue_redraw()


func _say(stream: AudioStream, db: float) -> void:
	_voice.stream = stream
	_voice.volume_db = db
	_voice.pitch_scale = randf_range(1.1, 1.4)
	_voice.play()


func _draw() -> void:
	var c := Color.BLACK
	var t := Weather.time
	var twitch := sin(t * 40.0) * 2.0 if _mode == Mode.TWITCH else 0.0
	var head := Vector2(_sway + twitch, _y)
	draw_line(Vector2.ZERO, head + Vector2(0, -26), c, 1.0)
	# legs gripping the thread, folded above the body
	for s: float in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([head + Vector2(0, -24), head + Vector2(s * 9.0, -34), head + Vector2(s * 3.0, -40)]), c, 1.6)
	# body hanging head-down
	DrawKit.limb(self, head + Vector2(0, -26), head + Vector2(0, -2), 6.0, 8.0)
	DrawKit.ellipse(self, head + Vector2(0, 4), Vector2(4.5, 6.0), 0.0, c, 10)
	# arms dangling below, swinging, reaching out when it drops
	var reach := 1.0 if _mode == Mode.DROP or _mode == Mode.HANG else 0.0
	for s: float in [-1.0, 1.0]:
		var swing := sin(t * 1.7 + s) * 0.15
		var a := PI * 0.5 + s * (0.25 + reach * 0.6) + swing
		var elbow := head + Vector2(s * 3.0, 6.0) + Vector2.from_angle(a) * 16.0
		var hand := elbow + Vector2.from_angle(a - s * 0.3) * 18.0
		DrawKit.limb(self, head + Vector2(s * 3.0, 6.0), elbow, 2.6, 2.0)
		DrawKit.limb(self, elbow, hand, 2.0, 1.2)
		for f in 3:
			draw_line(hand, hand + Vector2.from_angle(a + (f - 1) * 0.3) * 6.0, c, 0.9)
	if not Engine.is_editor_hint():
		var glow := 0.35 + (0.65 if _mode != Mode.WAIT else 0.0)
		draw_circle(head + Vector2(-2, 7), 1.1, Color(1.0, 0.9, 0.7, glow))
		draw_circle(head + Vector2(2, 7), 1.1, Color(1.0, 0.9, 0.7, glow))
	else:
		DrawKit.editor_link(self, Vector2(0, rest_drop), Vector2(0, strike_drop), DrawKit.EDITOR_ENEMY)
		DrawKit.editor_box(self, Rect2(-sense_width, strike_drop - 40, sense_width * 2.0, 60), DrawKit.EDITOR_ENEMY, "dangler drops here")
