@tool
extends EditorPlugin
## Level Tools: helpers for designing levels in the 2D view.
##  - Terrain and Roof: drag their points, click between two points to add one, right-click
##    a point to remove it (all undoable).
##  - "Sky" in the 2D toolbar: the level's sky and distant scenery behind it while editing,
##    as the game shows them, so the black silhouettes can be seen.
##  - "Collision" in the 2D toolbar: show the collision shapes the elements build for
##    themselves (hidden by default, they cover the artwork).
##  - Click any level element to select it (Shift adds to the selection) and drag it to move
##    it (Shift snaps to 8 px); the selection is outlined. The editor cannot pick these
##    custom-drawn nodes by itself. Rotate and scale them with the usual tools or the Inspector.
##  - Select the level's root to drag its spawn point (the Player goes with it).
## Nothing of this is saved into the scenes or runs in the game.

const PointPathEditor := preload("res://addons/level_tools/point_path_editor.gd")
const ElementBounds := preload("res://addons/level_tools/element_bounds.gd")
const EditorBackdrop := preload("res://addons/level_tools/editor_backdrop.gd")
const META_SECTION := "level_tools"

var _points: PointPathEditor
var _bar: HBoxContainer
var _sky_toggle: CheckBox
var _collision_toggle: CheckBox
var _moving: Array[Node2D] = []
var _move_from: Array[Vector2] = []
var _press_world := Vector2.ZERO
var _moved := false


func _enter_tree() -> void:
	_points = PointPathEditor.new()
	_points.plugin = self
	_bar = HBoxContainer.new()
	_bar.add_child(VSeparator.new())
	_sky_toggle = _toggle("Sky", "Show the level's sky and distant scenery behind it while editing.", "sky", true)
	_collision_toggle = _toggle("Collision", "Show the collision shapes that elements build for themselves.", "collision", false)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _bar)
	scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	EditorInterface.get_selection().selection_changed.connect(update_overlays)
	# the selection outline is drawn whatever is selected
	set_force_draw_over_forwarding_enabled()
	_on_scene_changed(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(update_overlays)
	scene_changed.disconnect(_on_scene_changed)
	get_tree().node_added.disconnect(_on_node_added)
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _bar)
	_bar.queue_free()
	var root := EditorInterface.get_edited_scene_root()
	if root:
		_remove_backdrop(root)
		_set_collision_visible(root, true)


func _toggle(text: String, tip: String, key: String, default: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.tooltip_text = tip
	c.button_pressed = EditorInterface.get_editor_settings().get_project_metadata(META_SECTION, key, default)
	c.toggled.connect(func(on: bool):
		EditorInterface.get_editor_settings().set_project_metadata(META_SECTION, key, on)
		_on_scene_changed(EditorInterface.get_edited_scene_root()))
	_bar.add_child(c)
	return c


# ------------------------------------------------------------------ point editing

func _handles(object: Object) -> bool:
	return PointPathEditor.property_for(object) != ""


func _edit(object: Object) -> void:
	_points.edit(object)
	update_overlays()


func _make_visible(visible: bool) -> void:
	if not visible:
		_points.edit(null)
	update_overlays()


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	_points.draw(overlay)


## Drawn whatever is selected: an outline round each selected level element.
func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is Node2D and ElementBounds.is_element(n) and n.is_inside_tree():
			var xf := (n as Node2D).get_viewport_transform() * (n as Node2D).get_global_transform()
			var r := ElementBounds.local_rect(n)
			var pts := PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end, xf * Vector2(r.position.x, r.end.y), xf * r.position])
			overlay.draw_polyline(pts, Color(0, 0, 0, 0.5), 3.0)
			overlay.draw_polyline(pts, Color(1.0, 0.8, 0.4, 0.85), 1.0)


## The 2D view only forwards its input to a plugin that handles the selected node, so with
## nothing (or something else) selected a click would never get here. Mouse input is taken
## before the editor sees it instead, over the 2D view only, and kept only when used.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	var vp := EditorInterface.get_editor_viewport_2d()
	var view := vp.get_parent() as Control if vp else null
	if view == null or not view.is_visible_in_tree():
		return
	var local: Vector2 = view.get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouse).position
	var busy := _points.is_dragging() or not _moving.is_empty()
	if not busy:
		if not Rect2(Vector2.ZERO, view.size).has_point(local):
			return
		# not through a dialog or menu lying over the view (the 2D editor's own overlay
		# sits next to the viewport, under the same parent)
		var hovered := view.get_viewport().gui_get_hovered_control()
		var area := view.get_parent()
		if hovered and hovered != view and not (area and area.is_ancestor_of(hovered)):
			return
	var ev := event.duplicate() as InputEventMouse
	ev.position = local
	if _points.input(ev) or _pick_and_move(ev):
		view.get_viewport().set_input_as_handled()


## Click an element to select it and drag to move it. Anything else goes to the editor.
func _pick_and_move(event: InputEvent) -> bool:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or not root is CanvasItem:
		return false
	var to_world := (root as CanvasItem).get_viewport_transform().affine_inverse()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.alt_pressed or mb.ctrl_pressed or mb.meta_pressed:
				return false
			var world := to_world * mb.position
			var hit := _pick(root, world)
			if hit == null:
				return false
			var sel := EditorInterface.get_selection()
			if mb.shift_pressed:
				sel.add_node(hit)
			elif not hit in sel.get_selected_nodes():
				sel.clear()
				sel.add_node(hit)
				EditorInterface.edit_node(hit)
			_moving.clear()
			_move_from.clear()
			for n in sel.get_selected_nodes():
				if n is Node2D and ElementBounds.is_element(n):
					_moving.append(n)
					_move_from.append((n as Node2D).global_position)
			_press_world = world
			_moved = false
			update_overlays()
			return true
		elif not _moving.is_empty():
			if _moved:
				var ur := get_undo_redo()
				ur.create_action("Move %s" % ("elements" if _moving.size() > 1 else _moving[0].name), UndoRedo.MERGE_DISABLE, root)
				for i in _moving.size():
					ur.add_do_property(_moving[i], "global_position", _moving[i].global_position)
					ur.add_undo_property(_moving[i], "global_position", _move_from[i])
				ur.add_do_method(self, "update_overlays")
				ur.add_undo_method(self, "update_overlays")
				ur.commit_action(false)
			_moving.clear()
			return true
	if event is InputEventMouseMotion and not _moving.is_empty():
		var mm := event as InputEventMouseMotion
		var delta := to_world * mm.position - _press_world
		if not _moved and delta.length() * (root as CanvasItem).get_viewport_transform().get_scale().x < 3.0:
			return true   # a click, not a drag yet
		_moved = true
		for i in _moving.size():
			var p := _move_from[i] + delta
			_moving[i].global_position = (p / 8.0).round() * 8.0 if mm.shift_pressed else p.round()
		update_overlays()
		return true
	return false


## The element under a point: the smallest one there (a crow before the power line it sits on,
## anything before the ground).
func _pick(root: Node, world: Vector2) -> Node2D:
	var best: Node2D = null
	var best_area := INF
	for n in root.find_children("*", "Node2D", true, true):
		if not ElementBounds.is_element(n) or not (n as Node2D).is_visible_in_tree() or n.owner != root:
			continue
		var w := ElementBounds.hit_weight(n, world)
		if w > 0.0 and w < best_area:
			best_area = w
			best = n
	return best


# ------------------------------------------------------------------ the open level

func _on_scene_changed(root: Node) -> void:
	if root == null:
		return
	_set_collision_visible(root, _collision_toggle.button_pressed)
	if _is_level(root) and _sky_toggle.button_pressed:
		_ensure_backdrop(root)
	else:
		_remove_backdrop(root)


func _is_level(root: Node) -> bool:
	var sc := root.get_script() as Script
	while sc:
		if String(sc.get_global_name()) == "Level":
			return true
		sc = sc.get_base_script()
	return false


func _ensure_backdrop(root: Node) -> void:
	for c in root.get_children(true):
		if c.get_script() == EditorBackdrop:
			return
	var b := EditorBackdrop.new()
	b.name = "EditorBackdrop"
	b.level = root
	# an internal child without an owner: drawn in the editor, never saved
	root.add_child(b, false, Node.INTERNAL_MODE_FRONT)


func _remove_backdrop(root: Node) -> void:
	for c in root.get_children(true):
		if c.get_script() == EditorBackdrop:
			root.remove_child(c)
			c.queue_free()


## Collision shapes that elements create in code (they have no owner) are hidden in the editor
## unless asked for; shapes placed by hand in a scene are left alone.
func _set_collision_visible(root: Node, on: bool) -> void:
	for n in root.find_children("*", "CollisionShape2D", true, false) + root.find_children("*", "CollisionPolygon2D", true, false):
		if n.owner == null:
			(n as Node2D).visible = on


func _on_node_added(node: Node) -> void:
	if not (node is CollisionShape2D or node is CollisionPolygon2D) or node.owner != null:
		return
	var root := EditorInterface.get_edited_scene_root()
	if root and root.is_ancestor_of(node):
		(node as Node2D).visible = _collision_toggle.button_pressed
