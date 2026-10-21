class_name Level
extends Node2D
## Base script for every level scene.
##
## A level is: this root node with its settings, a GameCamera, a Player, and any mix of
## elements, creatures and effects as children. Effects you don't add simply don't run.

## The level being played (there is only ever one).
static var current: Level

@export var level_width := 3000.0
@export var level_height := 768.0
## World y of the walkable ground; effects use it for splashes, fog and reflections.
@export var ground_y := 635.0
## Where the player starts (and restarts with the restart action).
@export var spawn_point := Vector2(300, 560)

@onready var player: Node2D = get_tree().get_first_node_in_group("player")


func _enter_tree() -> void:
	current = self
	Weather.reset()


func _ready() -> void:
	if player:
		player.global_position = spawn_point
	get_tree().call_group("game_camera", "snap_to_target")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
