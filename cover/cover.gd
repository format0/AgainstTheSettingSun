@tool
class_name Cover
extends Node2D
## Base for big black shapes that stand behind the player: walls, water towers, old trees,
## containers. The player is drawn black too, so in front of one he disappears and
## enemies can't see him (unless a light falls on him). Use this to plan where the player hides.
##
## A subclass draws itself in _draw() and returns the hiding shapes from _cover_shapes().
## In the editor those shapes are outlined in green.

## Turn off for a shape that should only be scenery.
@export var hides_player := true:
	set(v):
		hides_player = v
		queue_redraw()


func _enter_tree() -> void:
	add_to_group("cover")


## Hiding shapes in local coordinates. Override this.
func _cover_shapes() -> Array[PackedVector2Array]:
	return []


## Hiding shapes in world coordinates.
func get_cover_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if not hides_player or not is_visible_in_tree():
		return out
	for s in _cover_shapes():
		out.append(global_transform * s)
	return out


## True when every point is in front of some cover (the points can be spread over several covers).
static func hides(points: PackedVector2Array) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var polys: Array[PackedVector2Array] = []
	for c in tree.get_nodes_in_group("cover"):
		polys.append_array(c.get_cover_polygons())
	if polys.is_empty():
		return false
	for p in points:
		var inside := false
		for poly in polys:
			if Geometry2D.is_point_in_polygon(p, poly):
				inside = true
				break
		if not inside:
			return false
	return true


## Call at the end of a subclass's _draw() so the editor shows where the player can hide.
func _draw_cover_outline() -> void:
	if not Engine.is_editor_hint() or not hides_player:
		return
	for s in _cover_shapes():
		var closed := s.duplicate()
		closed.append(s[0])
		draw_polyline(closed, DrawKit.EDITOR_COVER, 1.0)
	var shapes := _cover_shapes()
	if not shapes.is_empty() and not shapes[0].is_empty():
		DrawKit.editor_caption(self, shapes[0][0] + Vector2(2, 12), DrawKit.EDITOR_COVER, "cover")

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_hit(p: Vector2) -> DrawKit.EditorHit:
	for s in _cover_shapes():
		if Geometry2D.is_point_in_polygon(p, s):
			return DrawKit.EditorHit.SHAPE
	return DrawKit.EditorHit.BOX if _editor_rect().has_point(p) else DrawKit.EditorHit.MISS


## Subclasses return their box (in their own coordinates).
func _editor_rect() -> Rect2:
	return Rect2(-12, -12, 24, 24)
