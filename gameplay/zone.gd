@tool
class_name Zone
extends Area2D
## Base for invisible rectangles that react when the player (or an enemy) walks in:
## Checkpoint, LevelExit, KillZone. The node's position is the top-left corner.

@export var size := Vector2(60, 200):
	set(v):
		size = v
		_rebuild()

var _shape: CollisionShape2D


func _ready() -> void:
	_rebuild()
	collision_layer = 0
	collision_mask = Layers.BODY_PLAYER | Layers.BODY_ENEMIES
	monitorable = false
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_on_player(body)
	elif body is Enemy:
		_on_enemy(body)


func _on_player(_player: Player) -> void:
	pass


func _on_enemy(_enemy: Enemy) -> void:
	pass

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


## An invisible zone is picked only where nothing else is.
func _editor_hit(p: Vector2) -> DrawKit.EditorHit:
	return DrawKit.EditorHit.AREA if _editor_rect().has_point(p) else DrawKit.EditorHit.MISS


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": size}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = p.max(Vector2(8, 8))
