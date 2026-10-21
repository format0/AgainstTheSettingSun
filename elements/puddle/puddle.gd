@tool
@icon("res://elements/puddle/puddle_icon.svg")
class_name Puddle
extends Node2D
## A puddle on the ground. Place it where the ground is; the WetGround effect turns it into
## a rippling reflection, and the player splashes and sounds wet when running through it.

@export var half_width := 80.0:
	set(v):
		half_width = v
		queue_redraw()
## Small vertical shift so neighbouring puddles don't look identical.
@export var depth_offset := 3.0


func _enter_tree() -> void:
	add_to_group("puddles")


static func is_wet_at(world_x: float) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for p in tree.get_nodes_in_group("puddles"):
		var puddle := p as Puddle
		if puddle and absf(world_x - puddle.global_position.x) < puddle.half_width * 0.85:
			return true
	return false


func _draw() -> void:
	if Engine.is_editor_hint():   # only an outline in the editor; the effect draws the water
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(half_width, 5.0))
		draw_arc(Vector2.ZERO, 1.0, 0, TAU, 48, Color(0.4, 0.7, 1.0, 0.8), 0.3)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
