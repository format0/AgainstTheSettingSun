@tool
@icon("res://interactive/pressure_plate/pressure_plate_icon.svg")
class_name PressurePlate
extends Area2D
## A loose stone slab or an iron plate in the floor. While something heavy stands on it (the
## player, a creature, a crate) it switches its `targets` on; it switches them off again when
## the weight is gone, unless it `latches`. The node's position is the middle of its top.

@export var targets: Array[NodePath] = []:
	set(v):
		targets = v
		queue_redraw()
@export var width := 44.0:
	set(v):
		width = v
		_rebuild()
## Stays down once pressed.
@export var latches := false
@export var iron := true:
	set(v):
		iron = v
		queue_redraw()
## Who can press it: the player, creatures, crates.
@export var player_presses := true
@export var enemies_press := true
@export var crates_press := true

var pressed := false
var _sink := 0.0
var _shape: CollisionShape2D
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.MACHINERY
	_rebuild()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = (Layers.BODY_PLAYER if player_presses else 0) | (Layers.BODY_ENEMIES if enemies_press else 0) | (Layers.BODY_MOVABLES if crates_press else 0)
	monitorable = false
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 900.0
	add_child(_sound)
	var saved: Variant = Level.recall(self)
	if saved == true:
		pressed = true
		_sink = 1.0
		_restore.call_deferred()


func _restore() -> void:
	Mechanism.drive(self, targets, true, true)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 6.0, 10)
	_shape.shape = rect
	_shape.position = Vector2(0, -5)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var weight := false
	for b in get_overlapping_bodies():
		if b is Player and (b as Player).dead:
			continue
		weight = true
	if weight != pressed and not (latches and pressed):
		pressed = weight
		_sound.stream = SoundBank.clank() if iron else SoundBank.stone_thud()
		_sound.pitch_scale = 1.3 if pressed else 1.1
		_sound.play()
		Mechanism.drive(self, targets, pressed)
		if latches:
			Level.remember(self, true)
	_sink = move_toward(_sink, 1.0 if pressed else 0.0, delta * 10.0)
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var y := _sink * 4.0
	if iron:
		draw_rect(Rect2(-width * 0.5, y - 4, width, 5), c)
		DrawKit.bolts(self, Vector2(-width * 0.5 + 3, y - 4), Vector2(width * 0.5 - 3, y - 4), 9.0, 1.2)
	else:
		draw_colored_polygon(DrawKit.rough_rect(Rect2(-width * 0.5, y - 5, width, 7), 3, 1.0, 5.0), c)
	draw_rect(Rect2(-width * 0.5 - 4, 0, width + 8, 6), c)
	Mechanism.draw_links(self, targets)
	if Engine.is_editor_hint():
		DrawKit.editor_caption(self, Vector2(-width * 0.5, -10), DrawKit.EDITOR_INTERACTIVE, "plate")

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-width * 0.5, -8, width, 10)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "width", "pos": Vector2(width * 0.5, -4)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	width = maxf(12.0, absf(p.x) * 2.0)
