@tool
@icon("res://creatures/frog/frog_icon.svg")
class_name Frog
extends Node2D
## A frog that sits in the grass, croaks (its throat puffs up) and hops around.
## It jumps away when the player comes close. Place it on the ground line.

@export var flee_distance := 85.0
@export var hop_interval := Vector2(1.5, 5.0)
@export var croak_interval := Vector2(3.0, 9.0)
## How far it may wander from where it was placed.
@export var territory := 260.0
@export var size := 1.15

var _home_x := 0.0
var _ground_y := 0.0
var _vel := Vector2.ZERO
var _in_air := false
var _facing := 1
var _wait := 2.0
var _croak := 4.0
var _sac := 0.0
var _voice: AudioStreamPlayer2D


func _ready() -> void:
	_home_x = position.x
	_ground_y = position.y
	_facing = 1 if randf() < 0.5 else -1
	_wait = randf_range(0.5, 4.0)
	_croak = randf_range(2.0, 8.0)
	if not Engine.is_editor_hint():
		z_as_relative = false
		z_index = Layers.CREATURES
		_voice = AudioStreamPlayer2D.new()
		_voice.stream = SoundBank.croak()
		_voice.max_distance = 900.0
		_voice.volume_db = -8.0
		add_child(_voice)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _in_air:
		_vel.y += 900.0 * delta
		position += _vel * delta
		if position.y >= _ground_y:
			position.y = _ground_y
			_in_air = false
			_wait = randf_range(hop_interval.x, hop_interval.y)
			get_tree().call_group("splash_emitters", "burst", global_position, 5 if Puddle.is_wet_at(global_position) else 3, 0.8)
		queue_redraw()
		return
	_croak -= delta
	if _croak < 0.0:
		_sac = maxf(0.0, sin(-_croak * 9.0))
		if _croak + delta >= 0.0 and _voice:
			_voice.pitch_scale = randf_range(0.9, 1.1)
			_voice.play()
		if _croak < -1.1:
			_croak = randf_range(croak_interval.x, croak_interval.y)
			_sac = 0.0
	_wait -= delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var away := 0.0
	if player and absf(player.global_position.x - global_position.x) < flee_distance and player.global_position.y > global_position.y - 120.0:
		away = signf(global_position.x - player.global_position.x)
		if away == 0.0:
			away = 1.0
	if _wait <= 0.0 or away != 0.0:
		var dir := away if away != 0.0 else (1.0 if randf() < 0.5 else -1.0)
		if away == 0.0 and absf(position.x + dir * 60.0 - _home_x) > territory:
			dir = -dir
		_facing = int(dir)
		_in_air = true
		_sac = 0.0
		_vel = Vector2(dir * randf_range(90.0, 170.0) * (1.3 if away != 0.0 else 1.0), -randf_range(170.0, 260.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing * size, size))
	var c := Color.BLACK
	if _in_air:
		var tilt := clampf(_vel.y / 500.0, -0.6, 0.6)
		draw_set_transform(Vector2.ZERO, tilt * signf(_vel.x) * _facing, Vector2(_facing * size, size))
		_ellipse(Vector2(0, -4), Vector2(8, 3.4), 0.0)
		_ellipse(Vector2(7, -5.2), Vector2(3.5, 2.6), 0.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -4), Vector2(-15, -1), Vector2(-19, 1.5), Vector2(-18, 2.6), Vector2(-14, 0.8), Vector2(-5, -1.5)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(5, -2), Vector2(10, 2), Vector2(11, 1.5), Vector2(7, -2.5)]), c)
	else:
		var body := PackedVector2Array()
		var curve := Curve2D.new()
		curve.add_point(Vector2(-7, 0), Vector2.ZERO, Vector2(-1.5, -5))
		curve.add_point(Vector2(1, -7.6), Vector2(-5, -0.4), Vector2(3, 0))
		curve.add_point(Vector2(7.2, -7.4), Vector2(-1.2, -1.2), Vector2(2, 0.8))
		curve.add_point(Vector2(9.6, -2.9), Vector2(0.8, -1.3))
		body = curve.tessellate(3)
		body.append_array(PackedVector2Array([Vector2(7.2, -1.6), Vector2(6.8, 0), Vector2(5.4, 0), Vector2(5.1, -1.6), Vector2(1, -1.2), Vector2(-1, 0)]))
		draw_colored_polygon(body, c)
		draw_circle(Vector2(5.3, -8.3), 1.5, c)
		_ellipse(Vector2(-3.8, -2.3), Vector2(4.3, 2.7), -0.3)
		_ellipse(Vector2(-0.6, -0.3), Vector2(3.6, 0.9), 0.0)
		if _sac > 0.02:
			draw_circle(Vector2(7.8, -2.3), _sac * 3.2, c)
	draw_set_transform(Vector2.ZERO)


func _ellipse(center: Vector2, radii: Vector2, angle: float) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := i * TAU / 14.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(angle))
	draw_colored_polygon(pts, Color.BLACK)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-11, -13, 22, 15)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "territory", "pos": Vector2(territory, 0)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	territory = maxf(0.0, absf(p.x))
