class_name Mechanism
extends RefCounted
## How switches talk to machines. A switch (Lever, PressurePlate) has a list of `targets`;
## each target gets set_active(on, instant) when the switch changes. Anything with that
## method can be a target: SlidingGate, TrapDoor, MovingPlatform, SteamHammer, DropLoad,
## FallingTree... In the editor every switch draws an orange dashed line to its targets.


static func drive(from: Node, targets: Array[NodePath], on: bool, instant := false) -> void:
	for path in targets:
		var n := from.get_node_or_null(path)
		if n and n.has_method("set_active"):
			n.set_active(on, instant)


## Editor only: dashed lines from a switch to its targets. Call from _draw().
static func draw_links(from: Node2D, targets: Array[NodePath]) -> void:
	if not Engine.is_editor_hint():
		return
	for path in targets:
		var n := from.get_node_or_null(path) as Node2D
		if n:
			DrawKit.editor_link(from, Vector2.ZERO, from.to_local(n.global_position), DrawKit.EDITOR_INTERACTIVE)


## The faint glint that marks something the player can use. Brighter when in reach.
static func draw_glint(ci: CanvasItem, at: Vector2, highlight: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Weather.time * 3.0)
	var a := (0.10 + 0.45 * highlight * (0.7 + 0.3 * pulse)) * maxf(Daylight.light(), 0.35)
	ci.draw_circle(at, 5.0 + 3.0 * highlight, Color(1.0, 0.72, 0.42, a * 0.25))
	ci.draw_circle(at, 1.6 + highlight, Color(1.0, 0.85, 0.65, a))
