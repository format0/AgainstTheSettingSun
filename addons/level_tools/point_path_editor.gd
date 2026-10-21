@tool
extends RefCounted
## Point handles for nodes that are shaped by a line of points: a Terrain (`points`), a
## Roof (`profile`) and RustyPipes (`path`). Drag a point to move it, click the small dot between two points to add
## one there, right-click a point to remove it. Hold Shift while dragging to snap to 8 px.
## A Level gets one handle, its spawn point (the Player is moved with it).
## Every change is one undo step.

const KINDS := {"Terrain": "points", "Roof": "profile", "RustyPipes": "path", "Level": "spawn_point"}
const HANDLE := 6.0
const PICK := 9.0

var plugin: EditorPlugin
var target: Node
var _prop := ""
var _drag := -1
var _hover := -1
var _hover_mid := -1
var _before := PackedVector2Array()


static func property_for(object: Object) -> String:
	if not object is CanvasItem:
		return ""
	var sc := (object as Node).get_script() as Script
	while sc:
		var n := String(sc.get_global_name())
		if KINDS.has(n):
			return KINDS[n]
		sc = sc.get_base_script()
	return ""


func edit(object: Object) -> void:
	target = object as Node
	_prop = property_for(object)
	_drag = -1
	_hover = -1
	_hover_mid = -1


func is_dragging() -> bool:
	return _drag >= 0


## The spawn point is a single Vector2; the outlines are arrays.
func _single() -> bool:
	return _prop == "spawn_point"


func _points() -> PackedVector2Array:
	if _single():
		return PackedVector2Array([target.get(_prop)])
	return target.get(_prop)


func _apply(pts: PackedVector2Array) -> void:
	if _single():
		target.set(_prop, pts[0])
		var player := _player()
		if player:
			player.position = pts[0]
	else:
		target.set(_prop, pts)


func _player() -> Node2D:
	return target.find_child("Player", false, false) as Node2D


func _to_screen() -> Transform2D:
	# a Level root may be a plain Node: its points are in world coordinates
	var g := (target as Node2D).get_global_transform() if target is Node2D else Transform2D.IDENTITY
	return (target as CanvasItem).get_viewport_transform() * g


func draw(overlay: Control) -> void:
	if not is_instance_valid(target) or _prop == "" or not target.is_inside_tree():
		return
	var xf := _to_screen()
	var pts := _points()
	if _single():
		var sp := xf * pts[0]
		var hot := _hover == 0 or _drag == 0
		overlay.draw_line(sp + Vector2(0, -44), sp, Color(0, 0, 0, 0.7), 4.0)
		overlay.draw_line(sp + Vector2(0, -44), sp, Color(0.5, 0.9, 1.0), 2.0)
		overlay.draw_circle(sp, HANDLE + 3.5, Color(0, 0, 0, 0.8))
		overlay.draw_circle(sp, HANDLE + 2.0, Color(0.55, 0.95, 1.0) if hot else Color(0.4, 0.8, 1.0))
		overlay.draw_string(ThemeDB.fallback_font, sp + Vector2(12, -30), "spawn", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.95, 1.0))
		return
	if pts.size() < 2:
		return
	var screen := PackedVector2Array()
	for p in pts:
		screen.append(xf * p)
	# the outline, so the shape can be followed even where it is black on black
	overlay.draw_polyline(screen, Color(0, 0, 0, 0.6), 4.0)
	overlay.draw_polyline(screen, Color(1.0, 0.75, 0.3, 0.95), 2.0)
	# a dot between two points adds one there
	for i in screen.size() - 1:
		var m := (screen[i] + screen[i + 1]) * 0.5
		var on := i == _hover_mid
		overlay.draw_circle(m, 6.0 if on else 4.5, Color(0, 0, 0, 0.7))
		overlay.draw_circle(m, 5.0 if on else 3.2, Color(1.0, 0.9, 0.7, 0.95 if on else 0.75))
		if on:
			overlay.draw_line(m + Vector2(-2.5, 0), m + Vector2(2.5, 0), Color.BLACK, 1.2)
			overlay.draw_line(m + Vector2(0, -2.5), m + Vector2(0, 2.5), Color.BLACK, 1.2)
	for i in screen.size():
		var hot := i == _hover or i == _drag
		var r := HANDLE + (2.0 if hot else 0.0)
		overlay.draw_circle(screen[i], r + 1.5, Color(0, 0, 0, 0.8))
		overlay.draw_circle(screen[i], r, Color(1.0, 0.55, 0.15) if hot else Color(1.0, 0.82, 0.5))
	if _drag >= 0:
		var p := pts[_drag]
		overlay.draw_string(ThemeDB.fallback_font, screen[_drag] + Vector2(10, -10), "%d, %d" % [roundi(p.x), roundi(p.y)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.9, 0.75))


## Returns true when the event was used for the handles (the editor then ignores it).
func input(event: InputEvent) -> bool:
	if not is_instance_valid(target) or _prop == "" or not target.is_inside_tree():
		return false
	var xf := _to_screen()
	var pts := _points()
	if event is InputEventMouseMotion:
		var mpos: Vector2 = event.position
		if _drag >= 0:
			var p := xf.affine_inverse() * mpos
			p = (p / 8.0).round() * 8.0 if event.shift_pressed else p.round()
			pts[_drag] = p
			_apply(pts)
			plugin.update_overlays()
			return true
		var h := _pick_point(pts, xf, mpos)
		var hm := -1 if h >= 0 or _single() else _pick_mid(pts, xf, mpos)
		if h != _hover or hm != _hover_mid:
			_hover = h
			_hover_mid = hm
			plugin.update_overlays()
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var i := _pick_point(pts, xf, mb.position)
				if i >= 0:
					_drag = i
					_before = pts.duplicate()
					return true
				var m := -1 if _single() else _pick_mid(pts, xf, mb.position)
				if m >= 0:
					var np := pts.duplicate()
					np.insert(m + 1, ((pts[m] + pts[m + 1]) * 0.5).round())
					_commit("Add %s point" % _kind(), pts, np)
					# keep dragging the new point straight away
					_drag = m + 1
					_before = np.duplicate()
					return true
			elif _drag >= 0:
				var after := _points()
				if after != _before:
					_commit("Move %s point" % _kind(), _before, after, false)
				_drag = -1
				plugin.update_overlays()
				return true
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not _single():
			var i := _pick_point(pts, xf, mb.position)
			if i >= 0:
				if pts.size() > 2:
					var np := pts.duplicate()
					np.remove_at(i)
					_hover = -1
					_commit("Remove %s point" % _kind(), pts, np)
				return true
	return false


func _kind() -> String:
	return {"points": "terrain", "profile": "roof", "path": "pipe", "spawn_point": "spawn"}[_prop]


func _pick_point(pts: PackedVector2Array, xf: Transform2D, at: Vector2) -> int:
	var best := -1
	var best_d := PICK
	for i in pts.size():
		var d := (xf * pts[i]).distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best


func _pick_mid(pts: PackedVector2Array, xf: Transform2D, at: Vector2) -> int:
	for i in pts.size() - 1:
		if ((xf * pts[i] + xf * pts[i + 1]) * 0.5).distance_to(at) < PICK * 0.8:
			return i
	return -1


## One undo step from `before` to `after`. When `apply` is false the change is already on
## the node (a finished drag) and is only recorded.
func _commit(action: String, before: PackedVector2Array, after: PackedVector2Array, apply := true) -> void:
	var ur := plugin.get_undo_redo()
	ur.create_action(action, UndoRedo.MERGE_DISABLE, target)
	if _single():
		ur.add_do_property(target, _prop, after[0])
		ur.add_undo_property(target, _prop, before[0])
		var player := _player()
		if player:
			ur.add_do_property(player, "position", after[0])
			ur.add_undo_property(player, "position", before[0])
	else:
		ur.add_do_property(target, _prop, after)
		ur.add_undo_property(target, _prop, before)
	ur.add_do_method(plugin, "update_overlays")
	ur.add_undo_method(plugin, "update_overlays")
	ur.commit_action(apply)
