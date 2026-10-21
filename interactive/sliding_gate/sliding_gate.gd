@tool
@icon("res://interactive/sliding_gate/sliding_gate_icon.svg")
class_name SlidingGate
extends Node2D
## A heavy door that slides open in its guides when a switch says so: a steel plate, an
## iron portcullis or wooden boards. Lying flat with direction LEFT or RIGHT it is a sliding
## cover over a hole in the floor. A vertical door crushes whatever is under it when it shuts.
## Its grinding can be heard far: hunters come to see. The node's position is the top-left
## corner of the closed door.

enum Direction { UP, DOWN, LEFT, RIGHT }
enum Style { PLATE, PORTCULLIS, PLANKS }

@export var size := Vector2(22, 110):
	set(v):
		size = v
		queue_redraw()
@export var direction := Direction.UP:
	set(v):
		direction = v
		queue_redraw()
## Open at the start. Switches then toggle it.
@export var open := false:
	set(v):
		open = v
		if not is_inside_tree() or Engine.is_editor_hint():
			_offset = _travel() if open else 0.0
		queue_redraw()
## Swap what on and off mean (a lever that closes the door).
@export var inverted := false
@export var speed := 80.0
## How far it slides. 0 = its own length minus a bit.
@export var travel := 0.0:
	set(v):
		travel = v
		queue_redraw()
@export var style := Style.PLATE:
	set(v):
		style = v
		queue_redraw()
## How far the grinding carries (enemies within come to look). 0 = silent.
@export var noise_radius := 650.0
@export var draw_frame := true:
	set(v):
		draw_frame = v
		queue_redraw()

var _offset := 0.0
var _body: AnimatableBody2D
var _sound: AudioStreamPlayer2D
var _moving := false


func _ready() -> void:
	z_index = Layers.MACHINERY
	_offset = _travel() if open else 0.0
	if Engine.is_editor_hint():
		return
	_body = AnimatableBody2D.new()
	_body.sync_to_physics = true
	_body.collision_layer = Layers.BODY_WORLD
	_body.set_meta("surface", "metal" if style != Style.PLANKS else "wood")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = size * 0.5
	_body.add_child(cs)
	add_child(_body)
	_body.position = _dir() * _offset
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 1000.0
	add_child(_sound)


func _travel() -> float:
	if travel > 0.0:
		return travel
	return (size.y if direction <= Direction.DOWN else size.x) - 6.0


func _dir() -> Vector2:
	match direction:
		Direction.UP:
			return Vector2.UP
		Direction.DOWN:
			return Vector2.DOWN
		Direction.LEFT:
			return Vector2.LEFT
	return Vector2.RIGHT


func set_active(on: bool, instant := false) -> void:
	open = on != inverted
	if instant:
		_offset = _travel() if open else 0.0
		if _body:
			_body.position = _dir() * _offset


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _body == null:
		return
	var goal := _travel() if open else 0.0
	var was := _offset
	_offset = move_toward(_offset, goal, speed * delta)
	var moving := _offset != was
	if moving and not _moving:
		_sound.stream = SoundBank.grind()
		_sound.play()
		var p := get_tree().get_first_node_in_group("player") as Player
		if p:
			p.make_noise(global_position + size * 0.5, noise_radius)
	elif not moving and _moving:
		_sound.stream = SoundBank.clank()
		_sound.play()
		if not open and direction == Direction.UP:
			get_tree().call_group("dust_emitters", "burst", global_position + Vector2(size.x * 0.5, size.y), 10, size.x)
	_moving = moving
	_body.position = _dir() * _offset
	if moving and not open and direction == Direction.UP:
		_crush_check()
	queue_redraw()


func _crush_check() -> void:
	var r := Rect2(global_position + _dir() * _offset, size).grow_individual(-2, 0, -2, 0)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead and r.intersects(Rect2(p.global_position + Vector2(-8, -38), Vector2(16, 36))):
		p.die("crushed")
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead and r.has_point(en.global_position + Vector2(0, -10)):
			en.die()


func _draw() -> void:
	var c := Color.BLACK
	var t := _travel()
	var leaf := Rect2(_dir() * _offset, size)
	if draw_frame:
		if direction <= Direction.DOWN:
			var y0 := minf(0.0, _dir().y * t)
			var y1 := maxf(size.y, size.y + _dir().y * t)
			draw_rect(Rect2(-6, y0 - 4, 5, y1 - y0 + 4), c)
			draw_rect(Rect2(size.x + 1, y0 - 4, 5, y1 - y0 + 4), c)
			draw_rect(Rect2(-10, y0 - 10, size.x + 20, 8), c)
			DrawKit.bolts(self, Vector2(-8, y0 - 10), Vector2(size.x + 8, y0 - 10), 8.0, 1.3)
		else:
			var x0 := minf(0.0, _dir().x * t)
			var x1 := maxf(size.x, size.x + _dir().x * t)
			draw_rect(Rect2(x0 - 4, size.y, x1 - x0 + 8, 4), c)
	match style:
		Style.PLATE:
			draw_rect(leaf, c)
			var ribs := maxi(1, int((size.y if direction <= Direction.DOWN else size.x) / 30.0))
			for k in ribs:
				if direction <= Direction.DOWN:
					var y := leaf.position.y + size.y * (k + 0.5) / ribs
					draw_rect(Rect2(leaf.position.x - 2, y - 2, size.x + 4, 4), c)
				else:
					var x := leaf.position.x + size.x * (k + 0.5) / ribs
					draw_rect(Rect2(x - 2, leaf.position.y - 2, 4, size.y + 4), c)
		Style.PORTCULLIS:
			var bars := maxi(2, int(size.x / 7.0))
			for k in bars:
				var x := leaf.position.x + size.x * k / (bars - 1.0)
				draw_line(Vector2(x, leaf.position.y), Vector2(x, leaf.end.y), c, 2.6)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, leaf.end.y), Vector2(x + 2.5, leaf.end.y), Vector2(x, leaf.end.y + 7)]), c)
			for k in 3:
				var y := leaf.position.y + size.y * (0.12 + k * 0.38)
				draw_rect(Rect2(leaf.position.x - 2, y - 2, size.x + 4, 4), c)
		Style.PLANKS:
			var boards := maxi(1, int(size.x / 9.0))
			for k in boards:
				var w := size.x / boards
				draw_rect(Rect2(leaf.position.x + k * w + 0.6, leaf.position.y + (k % 2) * 2.0, w - 1.2, size.y - (k % 2) * 2.0), c)
			draw_rect(Rect2(leaf.position.x - 2, leaf.position.y + size.y * 0.2, size.x + 4, 4), c)
			draw_rect(Rect2(leaf.position.x - 2, leaf.position.y + size.y * 0.75, size.x + 4, 4), c)
	if Engine.is_editor_hint():
		draw_rect(Rect2(_dir() * t, size), DrawKit.EDITOR_INTERACTIVE, false, 1.0)
		DrawKit.editor_caption(self, Vector2(0, -14), DrawKit.EDITOR_INTERACTIVE, "gate")

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": size}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = p.max(Vector2(6, 6))
