@tool
@icon("res://hazards/steam_hammer/steam_hammer_icon.svg")
class_name SteamHammer
extends Node2D
## A steam hammer still pounding away in the empty works: it rises slowly with a hiss, hangs,
## then slams down. Time your run beneath it, or stop it with a switch (set_active(false)
## jams it at the top). Its head can be stood on. The node's position is the middle of the
## anvil, on the floor.

@export var stroke := 120.0:
	set(v):
		stroke = v
		queue_redraw()
@export var head_size := Vector2(64, 44):
	set(v):
		head_size = v
		queue_redraw()
## Seconds for one blow.
@export var cycle := 3.0
## Where in its cycle it starts (0..1), to set hammers out of step.
@export_range(0.0, 1.0) var phase := 0.0
@export var running := true
## A switch turned on stops it (a lever that cuts the steam).
@export var inverted := false
## Frame height above the floor.
@export var frame_height := 280.0:
	set(v):
		frame_height = v
		queue_redraw()

var _t := 0.0
var _lift := 1.0
var _head: AnimatableBody2D
var _sound: AudioStreamPlayer2D
var _was_down := false
var _steam: Array[Dictionary] = []


func _ready() -> void:
	z_index = Layers.MACHINERY
	_t = phase * cycle
	if Engine.is_editor_hint():
		return
	_head = AnimatableBody2D.new()
	_head.sync_to_physics = true
	_head.set_meta("surface", "metal")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = head_size
	cs.shape = rect
	cs.position = Vector2(0, -head_size.y * 0.5)
	_head.add_child(cs)
	add_child(_head)
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 1300.0
	add_child(_sound)
	_place()


func set_active(on: bool, _instant := false) -> void:
	running = on != inverted


## 1 = up, 0 = down, over one cycle: rise 45%, wait 25%, slam 5%, rest 25%.
func _lift_at(u: float) -> float:
	if u < 0.45:
		return smoothstep(0.0, 1.0, u / 0.45)
	if u < 0.70:
		return 1.0
	if u < 0.75:
		var k := (u - 0.70) / 0.05
		return 1.0 - k * k
	return 0.0


func _place() -> void:
	_head.position = Vector2(0, -8.0 - _lift * stroke)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var before := _lift
	if running:
		_t = fmod(_t + delta, cycle)
		_lift = _lift_at(_t / cycle)
	else:
		_lift = move_toward(_lift, 1.0, delta * 0.6)
	var falling := _lift < before - 0.001
	if falling:
		_crush_check()
	var down := _lift < 0.02
	if down and not _was_down:
		_impact()
	if not running and before < _lift and absf(before - _lift) > 0.0001 and randf() < 0.1:
		_puff()
	_was_down = down
	if running and _t / cycle < 0.45 and randf() < delta * 14.0:
		_puff()
	_place()
	for s in _steam:
		s.age += delta
		s.p += (s.v + Vector2(-Weather.wind * 40.0, 0)) * delta
		s.r += 22.0 * delta
	_steam = _steam.filter(func(s): return s.age < 1.6)
	queue_redraw()


func _crush_check() -> void:
	var bottom := global_position.y - 8.0 - _lift * stroke
	var r := Rect2(global_position.x - head_size.x * 0.5 + 3, bottom - 30.0, head_size.x - 6, 32.0)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead and r.intersects(Rect2(p.global_position + Vector2(-8, -38), Vector2(16, 38))):
		if p.global_position.y > bottom - 4.0:
			p.die("crushed")
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead and r.has_point(en.global_position + Vector2(0, -8)):
			en.die()


func _impact() -> void:
	_sound.stream = SoundBank.hammer_blow()
	_sound.pitch_scale = randf_range(0.92, 1.05)
	_sound.play()
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		var d := p.global_position.distance_to(global_position)
		get_tree().call_group("game_camera", "shake", clampf(6.0 - d / 120.0, 0.0, 6.0))
	get_tree().call_group("dust_emitters", "burst", global_position + Vector2(0, -6), 14, head_size.x)
	get_tree().call_group("ember_emitters", "burst", global_position + Vector2(0, -8), 10)
	for k in 6:
		_puff()


func _puff() -> void:
	var top := -frame_height + 40.0
	_steam.append({"p": Vector2(randf_range(-10, 10), top + 10.0), "v": Vector2(randf_range(-30, 30), randf_range(-30, 5)), "age": 0.0, "r": randf_range(4, 8)})


func _draw() -> void:
	var c := Color.BLACK
	var hx := head_size.x * 0.5
	var head_y := -8.0 - _lift * stroke
	# anvil block
	draw_colored_polygon(PackedVector2Array([Vector2(-hx - 10, 0), Vector2(hx + 10, 0), Vector2(hx + 4, -8), Vector2(-hx - 4, -8)]), c)
	# frame: two columns and a crown with the steam cylinder
	for s: float in [-1.0, 1.0]:
		var x: float = s * (hx + 22.0)
		draw_rect(Rect2(x - 7, -frame_height, 14, frame_height), c)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 14, 0), Vector2(x + 14, 0), Vector2(x + 7, -20), Vector2(x - 7, -20)]), c)
		DrawKit.limb(self, Vector2(x, -frame_height * 0.5), Vector2(x + s * 30.0, 0), 4.0, 4.0)
	draw_rect(Rect2(-hx - 34, -frame_height - 14, head_size.x + 68, 18), c)
	draw_rect(Rect2(-18, -frame_height - 64, 36, 52), c)
	draw_rect(Rect2(-22, -frame_height - 68, 44, 6), c)
	DrawKit.bolts(self, Vector2(-hx - 30, -frame_height - 14), Vector2(hx + 30, -frame_height - 14), 10.0, 1.5)
	# a pipe snaking off to the side
	draw_polyline(PackedVector2Array([Vector2(18, -frame_height - 40), Vector2(60, -frame_height - 40), Vector2(60, -frame_height + 30), Vector2(hx + 60, -frame_height + 30)]), c, 5.0)
	# piston rod and head
	var top := -frame_height + 4.0
	draw_rect(Rect2(-5, top, 10, head_y - head_size.y - top + 2.0), c)
	draw_rect(Rect2(-hx, head_y - head_size.y, head_size.x, head_size.y), c)
	draw_rect(Rect2(-hx - 4, head_y - head_size.y + 6, head_size.x + 8, 6), c)
	draw_rect(Rect2(-hx + 4, head_y - 4, head_size.x - 8, 4), c)
	for s in _steam:
		var a: float = 0.22 * (1.0 - s.age / 1.6) * maxf(Daylight.light(), 0.3)
		DrawKit.draw_puff(self, s.p, s.r * 1.6, Color(0.85, 0.78, 0.72, a))
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(-hx, -8.0 - stroke - head_size.y, head_size.x, stroke + head_size.y), DrawKit.EDITOR_HAZARD, "crushes")
