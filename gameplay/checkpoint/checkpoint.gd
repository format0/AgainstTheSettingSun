@tool
@icon("res://gameplay/checkpoint/checkpoint_icon.svg")
class_name Checkpoint
extends Zone
## When the player walks through, this is where he comes back after dying.
## Everything that changed before (levers, broken bridges, fallen trees) stays changed.
## The sun keeps setting, so dying still costs time.


func _on_player(player: Player) -> void:
	if Level.current and not player.dead:
		Level.current.reach_checkpoint(Vector2(global_position.x + size.x * 0.5, player.global_position.y))
		set_deferred("monitoring", false)


func _draw() -> void:
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), DrawKit.EDITOR_GAMEPLAY, "checkpoint")
