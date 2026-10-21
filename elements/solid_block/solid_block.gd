@tool
@icon("res://elements/solid_block/solid_block_icon.svg")
class_name SolidBlock
extends StaticBody2D
## A rectangle the player can stand on and collide with. The node's position is its top-left corner.
## Turn off `visible_fill` when the shape is already painted in a backdrop image.
## Rain splashes on its top edge.

@export var size := Vector2(120, 24):
	set(v):
		size = v
		_rebuild()
@export var visible_fill := true:
	set(v):
		visible_fill = v
		queue_redraw()
## Also accept rain splashes on its top edge.
@export var catches_rain := true

var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("rain_surfaces")
	_rebuild()


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


## Top edges that rain can hit, as [start, end] pairs in world space.
func get_rain_edges() -> Array:
	if not catches_rain:
		return []
	var a := global_transform * Vector2.ZERO
	var b := global_transform * Vector2(size.x, 0)
	return [[a, b]]


func _draw() -> void:
	if visible_fill:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	elif Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 1.0, 0.8, 0.5), false, 1.0)
