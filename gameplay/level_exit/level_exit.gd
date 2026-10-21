@tool
@icon("res://gameplay/level_exit/level_exit_icon.svg")
class_name LevelExit
extends Zone
## The goal of the level. Reaching it ends the level and leads to the next one.


func _on_player(player: Player) -> void:
	if Level.current and not player.dead:
		Level.current.player_escaped()


func _draw() -> void:
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), DrawKit.EDITOR_GAMEPLAY, "EXIT")
