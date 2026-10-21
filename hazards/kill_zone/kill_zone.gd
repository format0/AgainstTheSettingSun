@tool
@icon("res://hazards/kill_zone/kill_zone_icon.svg")
class_name KillZone
extends Zone
## Invisible deadly area, for the bottom of an abyss or a ravine. Enemies die here too.

## How the player dies: "fell", "crushed", "drowned", "burned", "caught".
@export var cause := "fell"


func _on_player(player: Player) -> void:
	player.die(cause)


func _on_enemy(enemy: Enemy) -> void:
	enemy.die()


func _draw() -> void:
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), DrawKit.EDITOR_HAZARD, "kill: " + cause)
