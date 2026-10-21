@tool
extends RefCounted
## Where each level element is, so it can be clicked in the 2D view (custom-drawn nodes give
## the editor no outline of their own). Every element says so itself:
##   _editor_rect() -> Rect2               its box, in its own coordinates (required)
##   _editor_hit(p) -> DrawKit.EditorHit    optional: SHAPE where the click is on the drawn
##                                          shape, BOX, AREA (picked last) or MISS
## See CLAUDE.md for the whole editor contract of an element.

## Scripts in these folders are level elements.
const FOLDERS := ["res://cover/", "res://structures/", "res://interactive/", "res://hazards/",
	"res://environment/", "res://creatures/", "res://enemies/", "res://gameplay/"]
## Elements that follow the view and have no place of their own.
const SKIP := ["Bats", "Starlings", "MothSwarm"]


static func class_of(node: Node) -> String:
	var sc := node.get_script() as Script
	return String(sc.get_global_name()) if sc else ""


static func is_element(node: Node) -> bool:
	var sc := node.get_script() as Script
	if sc == null or not node is Node2D:
		return false
	var path := sc.resource_path
	for f in FOLDERS:
		if path.begins_with(f):
			return not class_of(node) in SKIP
	return false


## The element's box in its own coordinates.
static func local_rect(n: Node2D) -> Rect2:
	if n.has_method("_editor_rect"):
		return n._editor_rect()
	return Rect2(-12, -12, 24, 24)


## How strongly the element claims a click at this world point: 0 when it is not there,
## otherwise a weight (the smallest wins). A hit on a drawn shape (a wall, a trunk, the
## ground) beats a hit on a box, and large areas come last.
static func hit_weight(n: Node2D, world: Vector2) -> float:
	var local := n.get_global_transform().affine_inverse() * world
	var r := local_rect(n)
	var hit := DrawKit.EditorHit.BOX if r.has_point(local) else DrawKit.EditorHit.MISS
	if n.has_method("_editor_hit"):
		hit = n._editor_hit(local)
	var area := maxf(r.size.x * r.size.y, 1.0) * absf(n.get_global_transform().determinant())
	match hit:
		DrawKit.EditorHit.SHAPE:
			return area * 0.05
		DrawKit.EditorHit.BOX:
			return area
		DrawKit.EditorHit.AREA:
			return area * 1e6
	return 0.0
