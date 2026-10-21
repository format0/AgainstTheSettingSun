@tool
extends RefCounted
## Shape handles on the selected level elements: the diamonds an element asks for in its
## _editor_handles() (a corner for its size, a pole top, the end of a chain...). Dragging
## one calls the element's _editor_drag(id, local point), which sets its properties; on
## release the change becomes one undo step. Shift snaps to 8 px.
##
##   func _editor_handles() -> Array[Dictionary]
##       [{"id": "size", "pos": Vector2 (local), "props": ["size"]}, ...]
##       "props" (the properties a drag changes) defaults to [id].
##   func _editor_drag(id: Variant, p: Vector2) -> void

const ElementBounds := preload("res://addons/level_tools/element_bounds.gd")
const SIZE := 6.5
const PICK := 10.0

var plugin: EditorPlugin
var _target: Node2D
var _handle := {}
var _before := {}
var _hover_node: Node2D
var _hover_id: Variant = null


func is_dragging() -> bool:
	return _target != null


static func _targets() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is Node2D and n.is_inside_tree() and ElementBounds.is_element(n) and n.has_method("_editor_handles"):
			out.append(n)
	return out


static func _to_screen(n: Node2D) -> Transform2D:
	return n.get_viewport_transform() * n.get_global_transform()


## Handle ids can be names or indices; a String never equals an int here (GDScript would
## raise an error comparing them).
static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


static func _props(h: Dictionary) -> Array:
	return h.get("props", [h.id])


func draw(overlay: Control) -> void:
	for n in _targets():
		var xf := _to_screen(n)
		for h: Dictionary in n._editor_handles():
			var hot := (n == _hover_node and _same(h.id, _hover_id)) or (n == _target and _same(h.id, _handle.get("id")))
			var c := xf * (h.pos as Vector2)
			var r := SIZE + (1.5 if hot else 0.0)
			var outer := PackedVector2Array([c + Vector2(0, -r - 2), c + Vector2(r + 2, 0), c + Vector2(0, r + 2), c + Vector2(-r - 2, 0)])
			var inner := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			overlay.draw_colored_polygon(outer, Color(0, 0, 0, 0.8))
			overlay.draw_colored_polygon(inner, Color(0.55, 1.0, 0.85) if hot else Color(0.35, 0.85, 0.75))
			if hot:
				overlay.draw_string(ThemeDB.fallback_font, c + Vector2(12, -10), _caption(n, h), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 1.0, 0.9))


## "size 120, 40" for the handle under the mouse or being dragged.
func _caption(n: Node2D, h: Dictionary) -> String:
	var parts := PackedStringArray()
	for p: String in _props(h):
		var v: Variant = n.get(p)
		if v is Array or v is PackedFloat32Array or v is PackedVector2Array:
			if h.id is int and h.id < v.size():
				v = v[h.id]
			else:
				continue
		if v is Vector2:
			parts.append("%s %d, %d" % [p, roundi(v.x), roundi(v.y)])
		elif v is int or (v is float and is_equal_approx(v, roundf(v))):
			parts.append("%s %d" % [p, roundi(v)])
		elif v is float:
			parts.append("%s %.2f" % [p, v])
		elif v is Rect2:
			parts.append("%s %d × %d" % [p, roundi(v.size.x), roundi(v.size.y)])
	return "   ".join(parts)


## Returns true when the event was used (the editor then ignores it).
func input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _target:
			if not is_instance_valid(_target) or not _target.is_inside_tree():
				_target = null
				return false
			var p := _to_screen(_target).affine_inverse() * mm.position
			p = (p / 8.0).round() * 8.0 if mm.shift_pressed else p.round()
			_target._editor_drag(_handle.id, p)
			_target.queue_redraw()
			plugin.update_overlays()
			return true
		var hit := _pick(mm.position)
		var node: Node2D = hit[0]
		var id: Variant = hit[1].get("id") if node else null
		if node != _hover_node or not _same(id, _hover_id):
			_hover_node = node
			_hover_id = id
			plugin.update_overlays()
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var hit := _pick(mb.position)
			if hit[0] == null:
				return false
			_target = hit[0]
			_handle = hit[1]
			_before.clear()
			for p: String in _props(_handle):
				_before[p] = _copy(_target.get(p))
			return true
		elif _target:
			_commit()
			_target = null
			_handle = {}
			plugin.update_overlays()
			return true
	return false


func _pick(at: Vector2) -> Array:
	var best: Array = [null, {}]
	var best_d := PICK
	for n in _targets():
		var xf := _to_screen(n)
		for h: Dictionary in n._editor_handles():
			var d := (xf * (h.pos as Vector2)).distance_to(at)
			if d < best_d:
				best_d = d
				best = [n, h]
	return best


static func _copy(v: Variant) -> Variant:
	return v.duplicate() if v is Array else v


func _commit() -> void:
	if not is_instance_valid(_target):
		return
	var changed := false
	for p: String in _before:
		changed = changed or _target.get(p) != _before[p]
	if not changed:
		return
	var ur := plugin.get_undo_redo()
	ur.create_action("Change %s of %s" % [", ".join(PackedStringArray(_before.keys())), _target.name], UndoRedo.MERGE_DISABLE, _target)
	for p: String in _before:
		ur.add_do_property(_target, p, _copy(_target.get(p)))
		ur.add_undo_property(_target, p, _before[p])
	# some properties have no setter that redraws
	ur.add_do_method(_target, "queue_redraw")
	ur.add_undo_method(_target, "queue_redraw")
	ur.add_do_method(plugin, "update_overlays")
	ur.add_undo_method(plugin, "update_overlays")
	ur.commit_action(false)
