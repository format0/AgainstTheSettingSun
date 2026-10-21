@tool
@icon("res://creatures/cat/stray_cat_icon.svg")
class_name StrayCat
extends Node2D
## A thin stray cat that wanders along a ledge, a beam or the ground, sits and washes, and
## twitches its tail. It keeps away from the player and darts off when he comes close.
## It follows whatever surface is under it. The node's position is where it starts.

@export var wander_left := 80.0
@export var wander_right := 80.0
@export var shy_distance := 110.0

enum Mode { SIT, WALK, RUN }

var _mode := Mode.SIT
var _home := 0.0
var _facing := 1
var _timer := 2.0
var _target := 0.0
var _stride := 0.0
var _speed := 0.0


func _ready() -> void:
	z_index = Layers.CREATURES
	_home = position.x
	_target = position.x
	_timer = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and _mode != Mode.RUN and p.global_position.distance_to(global_position) < shy_distance:
		_mode = Mode.RUN
		var away := signf(global_position.x - p.global_position.x)
		_target = _home + (wander_right if away > 0.0 else -wander_left) * 1.5
	_timer -= delta
	match _mode:
		Mode.SIT:
			_speed = 0.0
			if _timer <= 0.0:
				_mode = Mode.WALK
				_target = _home + randf_range(-wander_left, wander_right)
		Mode.WALK, Mode.RUN:
			_speed = 150.0 if _mode == Mode.RUN else 26.0
			var dx := _target - position.x
			_facing = 1 if dx > 0.0 else -1
			var step := signf(dx) * minf(absf(dx), _speed * delta)
			if _ground_ok(global_position.x + step * 3.0):
				position.x += step
				_stride += absf(step) / 7.0
			else:
				dx = 0.0
			if absf(dx) < 2.0:
				_mode = Mode.SIT
				_timer = randf_range(3.0, 8.0)
	_snap_to_ground()
	queue_redraw()


func _ground_ok(x: float) -> bool:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - 10), Vector2(x, global_position.y + 14), Layers.BODY_WORLD)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _snap_to_ground() -> void:
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -10), global_position + Vector2(0, 30), Layers.BODY_WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = hit.position.y


func _draw() -> void:
	var c := Color.BLACK
	var t := Weather.time
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1))
	var tail_sway := sin(t * 2.2) * 0.4 + (sin(t * 9.0) * 0.3 if _mode == Mode.SIT and fmod(t, 6.0) < 1.0 else 0.0)
	if _mode == Mode.SIT:
		DrawKit.ellipse(self, Vector2(-1, -7), Vector2(5.5, 7.0), 0.15, c, 12)
		draw_circle(Vector2(2, -15), 3.6, c)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -17), Vector2(1, -21.5), Vector2(2.5, -17.5)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(3, -17.5), Vector2(4.5, -21.5), Vector2(5, -16.5)]), c)
		draw_polyline(PackedVector2Array([Vector2(-5, -2), Vector2(-11, 0), Vector2(-14, -4 + tail_sway * 4.0), Vector2(-13, -9 + tail_sway * 6.0)]), c, 1.8)
		draw_line(Vector2(2, -4), Vector2(3, 0), c, 1.6)
	else:
		var run := 1.0 if _mode == Mode.RUN else 0.0
		var ph := _stride * PI
		DrawKit.ellipse(self, Vector2(0, -8 - run), Vector2(8.0 + run * 2.0, 3.6), 0.0, c, 12)
		draw_circle(Vector2(8 + run * 2.0, -11 - run), 3.2, c)
		draw_colored_polygon(PackedVector2Array([Vector2(7, -13 - run), Vector2(8, -17 - run), Vector2(9.5, -13.5 - run)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(9.5, -13.5 - run), Vector2(11, -17 - run), Vector2(11.5, -12.5 - run)]), c)
		for i in 4:
			var bx := 5.0 if i < 2 else -5.0
			var a := sin(ph + i * PI * 0.5 + (PI if i % 2 == 1 else 0.0)) * (0.5 + run * 0.4)
			draw_line(Vector2(bx, -7), Vector2(bx, -7) + Vector2.from_angle(PI * 0.5 + a) * 8.0, c, 1.5)
		draw_polyline(PackedVector2Array([Vector2(-7, -9), Vector2(-12, -12 + tail_sway * 2.0), Vector2(-16, -18 + tail_sway * 3.0 + run * 6.0)]), c, 1.8)
	draw_set_transform(Vector2.ZERO)
