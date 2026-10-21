@tool
@icon("res://hazards/drop_load/drop_load_icon.svg")
class_name DropLoad
extends Node2D
## A heavy load hanging from a rusty chain: a bundle of girders, a concrete block, an old
## engine. When it is released (by a switch, or as a trap when the player passes beneath)
## the chain snaps and it falls, crushing anything below, and then lies there as something
## to climb on. The node's position is the top of the chain; the load hangs `chain_length` below.

enum Load { GIRDERS, CONCRETE, ENGINE, CRATES }
enum Trigger { SIGNAL, PLAYER_BELOW }

@export var cargo := Load.CONCRETE:
	set(v):
		cargo = v
		queue_redraw()
@export var size := Vector2(80, 44):
	set(v):
		size = v
		queue_redraw()
@export var chain_length := 160.0:
	set(v):
		chain_length = v
		queue_redraw()
## Where its bottom comes to rest, measured down from the node.
@export var floor_depth := 420.0:
	set(v):
		floor_depth = v
		queue_redraw()
@export var trigger := Trigger.SIGNAL
## PLAYER_BELOW: seconds between the chain starting to give and the drop.
@export var warning_time := 0.35

enum State { HANGING, SNAPPING, FALLING, DOWN }

var state := State.HANGING
var _y := 0.0
var _vy := 0.0
var _timer := 0.0
var _body: AnimatableBody2D
var _sound: AudioStreamPlayer2D
var _swing := 0.0


func _ready() -> void:
	z_index = Layers.MACHINERY
	_y = chain_length
	if Engine.is_editor_hint():
		return
	_body = AnimatableBody2D.new()
	_body.sync_to_physics = true
	_body.set_meta("surface", "stone" if cargo == Load.CONCRETE else ("wood" if cargo == Load.CRATES else "metal"))
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = Vector2(0, size.y * 0.5)
	_body.add_child(cs)
	add_child(_body)
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 1300.0
	add_child(_sound)
	if Level.recall(self) == true:
		state = State.DOWN
		_y = floor_depth - size.y
	_body.position = Vector2(0, _y)


func set_active(on: bool, _instant := false) -> void:
	if on and state == State.HANGING:
		_snap(0.12)


func _snap(delay: float) -> void:
	state = State.SNAPPING
	_timer = delay
	_sound.stream = SoundBank.chain_snap()
	_sound.play()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match state:
		State.HANGING:
			_swing = sin(Weather.time * 1.1) * Weather.wind * 1.5 - Weather.wind * 2.0 * Weather.gust_at(global_position.x)
			if trigger == Trigger.PLAYER_BELOW:
				var p := get_tree().get_first_node_in_group("player") as Player
				if p and not p.dead and absf(p.global_position.x - global_position.x) < size.x * 0.5 + 30.0 and p.global_position.y > global_position.y + _y:
					_snap(warning_time)
		State.SNAPPING:
			_timer -= delta
			_swing = randf_range(-1.5, 1.5)
			if _timer <= 0.0:
				state = State.FALLING
		State.FALLING:
			_vy += 1500.0 * delta
			var before := _y
			_y = minf(_y + _vy * delta, floor_depth - size.y)
			_crush_check(before)
			if _y >= floor_depth - size.y:
				_land()
	_body.position = Vector2(_swing, _y)
	queue_redraw()


func _crush_check(before: float) -> void:
	var top := global_position.y + before
	var bottom := global_position.y + _y + size.y
	var x0 := global_position.x - size.x * 0.5 + 2.0
	var x1 := global_position.x + size.x * 0.5 - 2.0
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead and p.global_position.x > x0 - 8.0 and p.global_position.x < x1 + 8.0 and p.global_position.y > top and p.global_position.y - 38.0 < bottom:
		p.die("crushed")
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead and en.global_position.x > x0 - 6.0 and en.global_position.x < x1 + 6.0 and en.global_position.y > top and en.global_position.y - 20.0 < bottom:
			en.die()


func _land() -> void:
	state = State.DOWN
	_swing = 0.0
	Level.remember(self, true)
	_sound.stream = SoundBank.heavy_impact()
	_sound.play()
	get_tree().call_group("game_camera", "shake", 8.0)
	get_tree().call_group("dust_emitters", "burst", global_position + Vector2(0, floor_depth), 34, size.x)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		p.make_noise(global_position + Vector2(0, floor_depth), 600.0)


func _draw() -> void:
	var c := Color.BLACK
	if Engine.is_editor_hint():
		_y = chain_length
	var top := Vector2(0, _y)
	draw_rect(Rect2(-14, -6, 28, 8), c)
	draw_circle(Vector2(0, 2), 6.0, c)
	if state == State.HANGING or state == State.SNAPPING:
		DrawKit.chain(self, Vector2(0, 4), top + Vector2(_swing, -10), 8.0, 2.4)
		DrawKit.chain(self, top + Vector2(_swing, -10), top + Vector2(_swing - size.x * 0.35, 0), 6.0, 1.6)
		DrawKit.chain(self, top + Vector2(_swing, -10), top + Vector2(_swing + size.x * 0.35, 0), 6.0, 1.6)
	else:
		# the broken end of the chain dangling from the pulley
		var sway := sin(Weather.time * 2.0) * 3.0 * Weather.wind
		DrawKit.chain(self, Vector2(0, 4), Vector2(sway, 46), 8.0, 2.4)
	var r := Rect2(Vector2(-size.x * 0.5 + (_swing if state != State.DOWN else 0.0), _y), size)
	match cargo:
		Load.CONCRETE:
			draw_colored_polygon(DrawKit.rough_rect(r, 5, 2.5, 7.0), c)
			draw_polyline(PackedVector2Array([r.position + Vector2(r.size.x * 0.3, 0), r.position + Vector2(r.size.x * 0.27, -9), r.position + Vector2(r.size.x * 0.34, -13)]), c, 1.4)
		Load.GIRDERS:
			for k in 3:
				var y := r.position.y + k * r.size.y / 3.0
				draw_rect(Rect2(r.position.x - k * 4.0, y, r.size.x + 8.0, r.size.y / 3.0 - 2.0), c)
			draw_rect(Rect2(r.position.x + r.size.x * 0.2, r.position.y - 2, 6, r.size.y + 4), c)
			draw_rect(Rect2(r.end.x - r.size.x * 0.2 - 6, r.position.y - 2, 6, r.size.y + 4), c)
		Load.ENGINE:
			draw_rect(Rect2(r.position + Vector2(4, 6), r.size - Vector2(8, 6)), c)
			for k in 4:
				draw_rect(Rect2(r.position.x + 8 + k * (r.size.x - 16) / 4.0, r.position.y, (r.size.x - 16) / 4.0 - 3, 9), c)
			draw_circle(r.position + Vector2(r.size.x - 2, r.size.y * 0.6), r.size.y * 0.32, c)
			draw_polyline(PackedVector2Array([r.position + Vector2(4, r.size.y * 0.3), r.position + Vector2(-8, r.size.y * 0.5), r.position + Vector2(-6, r.size.y + 4)]), c, 3.0)
		Load.CRATES:
			var w := r.size.x / 2.0
			PushCrate.draw_crate(self, Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(w - 1, r.size.y * 0.5)), 3)
			PushCrate.draw_crate(self, Rect2(r.position + Vector2(w, r.size.y * 0.5), Vector2(w, r.size.y * 0.5)), 4)
			PushCrate.draw_crate(self, Rect2(r.position + Vector2(w * 0.5, 0), Vector2(w, r.size.y * 0.5 - 1)), 5)
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(-size.x * 0.5, floor_depth - size.y, size.x, size.y), DrawKit.EDITOR_HAZARD, "lands here")
		DrawKit.editor_caption(self, Vector2(10, -8), DrawKit.EDITOR_HAZARD, "drops: " + ["switch", "trap"][trigger])
