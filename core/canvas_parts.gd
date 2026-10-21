class_name CanvasParts
extends RefCounted
## Pieces of a drawing whose shape never changes, each recorded once into its own canvas item
## under the owner. Animating them means moving them (one transform per piece), never
## redrawing them: the shapes are built and triangulated once, not every frame.
##
## Used by the trees, whose hundreds of branches and thousands of leaves only sway.

var items: Array[RID] = []
var _owner: CanvasItem
var _layer := -1


func _init(owner: CanvasItem) -> void:
	_owner = owner


## A new, empty piece. Draw into it once with the RenderingServer canvas_item_add_* calls.
func add(material: Material = null) -> RID:
	var rid := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rid, _owner.get_canvas_item())
	RenderingServer.canvas_item_set_visibility_layer(rid, _owner.visibility_layer)
	if material:
		RenderingServer.canvas_item_set_material(rid, material.get_rid())
	items.append(rid)
	return rid


## Keep the pieces in the same visibility layers as the owner (the Game marks solid things
## after they are built, so the light shafts see them as solid).
func sync_layers() -> void:
	if _layer == _owner.visibility_layer:
		return
	_layer = _owner.visibility_layer
	for rid in items:
		RenderingServer.canvas_item_set_visibility_layer(rid, _layer)


func clear() -> void:
	for rid in items:
		RenderingServer.free_rid(rid)
	items.clear()
	_layer = -1


## A polygon recorded as triangles (triangulated here, once).
static func add_polygon(rid: RID, points: PackedVector2Array, col := Color.BLACK) -> void:
	var idx := Geometry2D.triangulate_polygon(points)
	if idx.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(points.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_triangle_array(rid, idx, points, cols)


## True when a rectangle (in the owner's coordinates) is on screen, with a margin.
static func on_screen(owner: Node2D, local_rect: Rect2, margin := 80.0) -> bool:
	var r := Rect2(owner.global_position + local_rect.position, local_rect.size).grow(margin)
	return r.intersects(GameCamera.view_rect)
