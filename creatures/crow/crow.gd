@tool
@icon("res://creatures/crow/crow_icon.svg")
class_name Crow
extends Node2D
## A crow that perches on a PowerLine. When the player comes close it caws and flies off,
## circles for a while, then lands again somewhere away from the player.
## Without a power line it just sits where it was placed.

enum State { PERCHED, FLYING, LANDING }

@export var power_line: PowerLine
@export var startle_distance := 140.0
@export var max_speed := 230.0

var state := State.PERCHED
var _vel := Vector2.ZERO
var _facing := 1
var _phase := 0.0
var _look := 0.0
var _timer := 3.0
var _target := Vector2.ZERO
var _perch_x := 0.0
var _side := 0
var _voice: AudioStreamPlayer2D


func _ready() -> void:
	_phase = randf() * TAU
	_facing = 1 if randf() < 0.5 else -1
	_side = randi() % 2
	_perch_x = global_position.x
	if Engine.is_editor_hint():
		return
	z_as_relative = false
	z_index = Layers.CREATURES
	_voice = AudioStreamPlayer2D.new()
	_voice.stream = SoundBank.caw()
	_voice.max_distance = 1200.0
	_voice.volume_db = -6.0
	add_child(_voice)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase += delta * (2.0 if state == State.PERCHED else 16.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	match state:
		State.PERCHED:
			_perched(delta, player)
		State.FLYING, State.LANDING:
			_fly(delta, player)
	queue_redraw()


func _perched(delta: float, player: Node2D) -> void:
	if power_line:
		var y := power_line.perch_y(_perch_x, _side)
		if not is_nan(y):
			global_position = Vector2(_perch_x, y)
	_timer -= delta
	if _timer < 0.0:
		_timer = randf_range(2.0, 7.0)
		if randf() < 0.5:
			_facing = -_facing
		_look = randf_range(-1.0, 1.0)
	if player and absf(player.global_position.x - global_position.x) < startle_distance and player.global_position.y < global_position.y + 230.0:
		state = State.FLYING
		var away := signf(global_position.x - player.global_position.x)
		_vel = Vector2((away if away != 0.0 else 1.0) * randf_range(110.0, 190.0), -randf_range(140.0, 230.0))
		_timer = randf_range(5.0, 10.0)
		_target = global_position + Vector2(_vel.x * 1.5, -150.0)
		if _voice and randf() < 0.7:
			_voice.pitch_scale = randf_range(0.9, 1.1)
			_voice.play()


func _fly(delta: float, player: Node2D) -> void:
	if state == State.FLYING:
		_timer -= delta
		if global_position.distance_to(_target) < 60.0:
			_target = Vector2(global_position.x + randf_range(-350.0, 350.0), randf_range(150.0, 380.0))
		if _timer < 0.0 and power_line:
			_perch_x = power_line.random_perch_x(player.global_position.x if player else -9999.0, 320.0)
			_side = randi() % 2
			state = State.LANDING
	if state == State.LANDING:
		var y := power_line.perch_y(_perch_x, _side)
		_target = Vector2(_perch_x, (y if not is_nan(y) else global_position.y) - 2.0)
	var accel := (_target - global_position) * 1.4 - _vel * 0.9 + Vector2(-Weather.wind * 30.0, sin(_phase * 0.25) * 40.0)
	_vel += accel * delta
	_vel = _vel.limit_length(max_speed)
	global_position += _vel * delta
	if absf(_vel.x) > 8.0:
		_facing = 1 if _vel.x > 0.0 else -1
	if state == State.LANDING and global_position.distance_to(_target) < 7.0:
		state = State.PERCHED
		_timer = randf_range(2.0, 6.0)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1))
	var c := Color.BLACK
	if state == State.PERCHED:
		var bob := sin(_phase) * 0.4
		_ellipse(Vector2(0, -5 + bob), Vector2(6.6, 3.6), -0.38)
		draw_circle(Vector2(5, -9.4 + bob), 2.6, c)
		draw_colored_polygon(PackedVector2Array([Vector2(7, -10 + bob), Vector2(10.6 + _look, -9 + bob), Vector2(7.3, -8.3 + bob)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(-4.5, -3.2 + bob), Vector2(-11.5, 0.8), Vector2(-10, 2), Vector2(-3.5, -1.6 + bob)]), c)
		draw_rect(Rect2(-0.4, -2, 0.9, 2), c)
		draw_rect(Rect2(1.6, -2, 0.9, 2), c)
	else:
		var tip := -11.0 * sin(_phase)
		_ellipse(Vector2.ZERO, Vector2(7.4, 2.7), 0.0)
		draw_circle(Vector2(6.7, -1.2), 2.4, c)
		draw_colored_polygon(PackedVector2Array([Vector2(8.6, -1.8), Vector2(12, -1), Vector2(8.8, -0.4)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -0.5), Vector2(-12.5, -2.5), Vector2(-12.5, 2.2), Vector2(-6, 0.8)]), c)
		# the wing, as two triangles (a flapping wing folds through itself, which a polygon can't do)
		var cols := PackedColorArray([c, c, c])
		draw_primitive(PackedVector2Array([Vector2(2.5, -1), Vector2(-1, tip * 0.7 - 1), Vector2(-2.5, -0.6)]), cols, PackedVector2Array())
		draw_primitive(PackedVector2Array([Vector2(-1, tip * 0.7 - 1), Vector2(-7, tip), Vector2(-4.5, tip * 0.45)]), cols, PackedVector2Array())
	draw_set_transform(Vector2.ZERO)


func _ellipse(center: Vector2, radii: Vector2, angle: float) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := i * TAU / 14.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(angle))
	draw_colored_polygon(pts, Color.BLACK)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-13, -17, 26, 19)
