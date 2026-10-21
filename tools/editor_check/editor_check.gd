@tool
extends EditorPlugin
## Smoke test of the level elements in the real editor (run it with tools/editor_check.sh).
## For each scene in EDITOR_CHECK_SCENES (comma-separated) it:
##  - opens it in the 2D view (where the editor last left it) and screenshots it at three
##    points of the sunset (the Level Tools time preview), to
##    EDITOR_CHECK_OUT + "_<scene>_<time>.png";
##  - selects every level element, drags each of its handles 8 px through _editor_drag and
##    puts it back, and checks that its box has an area;
##  - once, drags a handle in view with real mouse events and undoes it, as a user would.
## Then it prints "CHECK all passed" (or the failures) and quits. Nothing is saved.

const ElementBounds := preload("res://addons/level_tools/element_bounds.gd")

var _failures := PackedStringArray()
var _mouse_tested := false


func _enter_tree() -> void:
	if OS.get_environment("EDITOR_CHECK_SCENES") != "":
		_run.call_deferred()


func _run() -> void:
	await _wait(5.0)
	for path in OS.get_environment("EDITOR_CHECK_SCENES").split(",", false):
		await _check_scene(path)
	for f in _failures:
		print("CHECK failed: ", f)
	print("CHECK all passed" if _failures.is_empty() else "CHECK %d failures" % _failures.size())
	# leave without "save changes?" questions: the scenes were only looked at
	EditorInterface.get_base_control().get_tree().quit(0 if _failures.is_empty() else 1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fail(what: String) -> void:
	_failures.append(what)


func _check_scene(path: String) -> void:
	EditorInterface.open_scene_from_path(path)
	EditorInterface.set_main_screen_editor("2D")
	await _wait(4.0)
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != path:
		_fail("%s did not open" % path)
		return
	var tools := _level_tools()
	if tools == null:
		_fail("the Level Tools plugin is not running")
		return
	var name := path.get_file().get_basename()
	for t in [0.0, 0.6, 1.0]:
		tools._time.value = t
		await _wait(1.5)
		_shot("%s_%.1f" % [name, t])
	tools._time.value = float(root.get("start_progress")) if root.get("start_progress") != null else 0.0
	var count := 0
	for n in root.find_children("*", "Node2D", true, true):
		if n.owner == root and ElementBounds.is_element(n):
			count += 1
			await _check_element(n)
	print("CHECK %s: %d elements" % [name, count])
	if not _mouse_tested:
		await _mouse_test(root)


func _check_element(n: Node2D) -> void:
	var label := "%s (%s)" % [n.name, ElementBounds.class_of(n)]
	if not n.get_script().is_tool():
		_fail("%s is not @tool" % label)
		return
	if not n.has_method("_editor_rect") or not ElementBounds.local_rect(n).has_area():
		_fail("%s has no box to click" % label)
	if not n.has_method("_editor_handles"):
		return
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(n)
	for h: Dictionary in n._editor_handles():
		var props: Array = h.get("props", [h.id])
		var before := {}
		for p: String in props:
			before[p] = n.get(p)
		n._editor_drag(h.id, (h.pos as Vector2) + Vector2(8, 8))
		var still := false
		for h2: Dictionary in n._editor_handles():
			still = still or (typeof(h2.id) == typeof(h.id) and h2.id == h.id)
		if not still:
			_fail("%s lost handle %s after dragging it" % [label, h.id])
		for p: String in props:
			n.set(p, before[p])
	await get_tree().process_frame


## A real drag on the first handle in view, then undo.
func _mouse_test(root: Node) -> void:
	for n in root.find_children("*", "Node2D", true, true):
		if n.owner != root or not ElementBounds.is_element(n) or not n.has_method("_editor_handles"):
			continue
		var handles: Array = n._editor_handles()
		if handles.is_empty():
			continue
		var h: Dictionary = handles[0]
		var world: Vector2 = n.get_global_transform() * (h.pos as Vector2)
		var screen: Vector2 = n.get_viewport_transform() * world
		var view := EditorInterface.get_editor_viewport_2d().get_parent() as Control
		if not Rect2(Vector2(40, 40), view.size - Vector2(80, 80)).has_point(screen):
			continue
		var props: Array = h.get("props", [h.id])
		var before := {}
		for p: String in props:
			before[p] = n.get(p)
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(n)
		await _wait(0.5)
		_mouse(screen, false, false)
		_mouse(screen, true, true)
		for k in 4:
			_mouse(screen + Vector2(6, 4) * (k + 1), false, true)
		_mouse(screen + Vector2(24, 16), true, false)
		await _wait(0.5)
		_shot("handles")
		var changed := false
		for p: String in props:
			changed = changed or n.get(p) != before[p]
		print("CHECK mouse drag on %s handle %s: %s" % [n.name, h.id, "changed" if changed else "NOT changed"])
		if not changed:
			_fail("dragging %s's handle %s with the mouse changed nothing" % [n.name, h.id])
		var ur := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(n))
		ur.undo()
		for p: String in props:
			if n.get(p) != before[p]:
				_fail("undo did not restore %s.%s" % [n.name, p])
		_mouse_tested = true
		return


func _level_tools() -> EditorPlugin:
	for n in EditorInterface.get_base_control().get_tree().root.find_children("*", "EditorPlugin", true, false):
		if n.get_script() and n.get_script().resource_path == "res://addons/level_tools/level_tools.gd":
			return n
	return null


func _shot(name: String) -> void:
	var out := OS.get_environment("EDITOR_CHECK_OUT")
	if out != "":
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])


## A mouse event at a point of the 2D view, sent through the window like a user's.
func _mouse(at: Vector2, button: bool, down: bool) -> void:
	var view := EditorInterface.get_editor_viewport_2d().get_parent() as Control
	var gp := view.get_global_transform_with_canvas() * at
	var e: InputEventMouse
	if button:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		e = b
	else:
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		e = m
	e.position = gp
	e.global_position = gp
	Input.parse_input_event(e)
