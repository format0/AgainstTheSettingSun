@tool
@icon("res://interactive/trap_door/trap_door_icon.svg")
class_name TrapDoor
extends Node2D
## A hinged hatch in the floor. When a switch opens it, it drops away and whoever stands on
## it falls through: lure a creature onto it, then pull the lever. It can also be the lid
## over a pit that you close to get across. The node's position is the hinge.

enum Hinge { LEFT, RIGHT }

@export var width := 70.0:
	set(v):
		width = v
		queue_redraw()
@export var hinge := Hinge.LEFT:
	set(v):
		hinge = v
		queue_redraw()
@export var open := false:
	set(v):
		open = v
		if not is_inside_tree() or Engine.is_editor_hint():
			_angle = _goal()
		queue_redraw()
@export var inverted := false
@export var style_wood := false:
	set(v):
		style_wood = v
		queue_redraw()

var _angle := 0.0
var _spin := 0.0
var _body: AnimatableBody2D
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.MACHINERY
	_angle = _goal()
	if Engine.is_editor_hint():
		return
	_body = AnimatableBody2D.new()
	_body.sync_to_physics = true
	_body.set_meta("surface", "wood" if style_wood else "metal")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 8)
	cs.shape = rect
	cs.position = Vector2(_side() * width * 0.5, 4)
	_body.add_child(cs)
	add_child(_body)
	_body.rotation = _angle
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 1000.0
	add_child(_sound)


func _side() -> float:
	return 1.0 if hinge == Hinge.LEFT else -1.0


func _goal() -> float:
	return PI * 0.5 * _side() if open else 0.0


func set_active(on: bool, instant := false) -> void:
	var was := open
	open = on != inverted
	if instant:
		_angle = _goal()
		_spin = 0.0
	elif was != open and _sound:
		_sound.stream = SoundBank.clank()
		_sound.play()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _body == null:
		return
	var goal := _goal()
	if open:
		# falls open under its own weight and bounces on its stop
		_spin += 14.0 * _side() * delta
		_angle += _spin * delta
		if absf(_angle) >= absf(goal):
			_angle = goal
			_spin = -_spin * 0.3
	else:
		_angle = move_toward(_angle, 0.0, 1.6 * delta)
		_spin = 0.0
	_body.rotation = _angle
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	draw_set_transform(Vector2.ZERO, _angle)
	var s := _side()
	if style_wood:
		var n := int(width / 12.0)
		for k in n:
			draw_rect(Rect2(Vector2(s * width * k / n, 0.0) + (Vector2(-width / n, 0) if s < 0 else Vector2.ZERO), Vector2(width / n - 1.2, 6)), c)
		draw_rect(Rect2(minf(0.0, s * width), 6, width, 2.5), c)
	else:
		draw_rect(Rect2(minf(0.0, s * width), 0, width, 6), c)
		DrawKit.bolts(self, Vector2(s * 4, 6.5), Vector2(s * (width - 4), 6.5), 10.0, 1.3)
	draw_rect(Rect2(minf(s * 4.0, s * width * 0.6), 6, width * 0.56, 3), c)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, 4.0, c)
	if Engine.is_editor_hint():
		DrawKit.editor_caption(self, Vector2(s * 4.0 - (40.0 if s < 0 else 0.0), -6), DrawKit.EDITOR_INTERACTIVE, "trap door")
