@tool
@icon("res://interactive/lever/lever_icon.svg")
class_name Lever
extends Node2D
## A rusty lever. Stand next to it and press the action button to throw it; it switches
## every node in `targets` (doors, hatches, platforms, hammers...). In the editor an orange
## line shows what it drives. The node's position is where it stands (floor) or hangs (wall).

enum Style { FLOOR, WALL }

@export var targets: Array[NodePath] = []:
	set(v):
		targets = v
		queue_redraw()
@export var pulled := false:
	set(v):
		pulled = v
		_angle = _target_angle()
		queue_redraw()
## Rusted: it can be thrown only once.
@export var one_way := false
@export var style := Style.FLOOR:
	set(v):
		style = v
		queue_redraw()

var _angle := -0.6
var _speed := 0.0
var _highlight := 0.0
var _focused := false
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.MACHINERY
	_angle = _target_angle()
	if Engine.is_editor_hint():
		return
	add_to_group("interactables")
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 900.0
	add_child(_sound)
	var saved: Variant = Level.recall(self)
	if saved != null:
		pulled = saved
	if pulled:
		_restore.call_deferred()


func _restore() -> void:
	Mechanism.drive(self, targets, true, true)


func _target_angle() -> float:
	return 0.6 if pulled else -0.6


func can_interact(_player: Player) -> bool:
	return not (one_way and pulled)


func get_interact_position() -> Vector2:
	return global_position + (Vector2(0, -14) if style == Style.FLOOR else Vector2.ZERO)


func set_highlight(on: bool) -> void:
	_focused = on


func interact(_player: Player) -> void:
	pulled = not pulled
	_angle = -_target_angle()
	_speed = 0.0
	Level.remember(self, pulled)
	_sound.stream = SoundBank.lever()
	_sound.pitch_scale = randf_range(0.9, 1.05)
	_sound.play()
	await get_tree().create_timer(0.12).timeout
	Mechanism.drive(self, targets, pulled)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	# a heavy handle with a little spring at the end of its throw
	var goal := _target_angle()
	_speed += ((goal - _angle) * 220.0 - _speed * 18.0) * delta
	_angle += _speed * delta
	_highlight = move_toward(_highlight, 1.0 if _focused and can_interact(null) else 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var pivot := Vector2(0, -8)
	var dir := Vector2.from_angle(-PI * 0.5 + _angle)
	if style == Style.FLOOR:
		draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(11, 0), Vector2(9, -9), Vector2(-9, -9)]), c)
		draw_rect(Rect2(-13, -2, 26, 2), c)
		draw_arc(pivot, 9.0, -PI * 0.92, -PI * 0.08, 12, c, 2.0)
	else:
		pivot = Vector2.ZERO
		draw_rect(Rect2(-8, -16, 16, 32), c)
		DrawKit.bolts(self, Vector2(-9, -14), Vector2(-9, 14), 9.0, 1.4)
		DrawKit.bolts(self, Vector2(9, -14), Vector2(9, 14), 9.0, 1.4)
	var tip := pivot + dir * 26.0
	DrawKit.limb(self, pivot, tip, 3.4, 2.4)
	draw_circle(tip, 3.6, c)
	draw_circle(pivot, 3.2, c)
	if not Engine.is_editor_hint() and can_interact(null):
		Mechanism.draw_glint(self, tip, _highlight)
	Mechanism.draw_links(self, targets)
	if Engine.is_editor_hint():
		DrawKit.editor_caption(self, Vector2(-14, 12), DrawKit.EDITOR_INTERACTIVE, "lever")

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-14, -32, 28, 34)
