class_name LightSource
extends RefCounted
## Anything that gives off light (street lamps, molten steel, fire barrels) joins the
## "light_sources" group and has illuminates(world_pos) -> bool.
## Light cancels shadow: an enemy sees the player in the light even in front of a Cover.


static func lit_at(world_pos: Vector2) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("light_sources"):
		if n.illuminates(world_pos):
			return true
	return false
