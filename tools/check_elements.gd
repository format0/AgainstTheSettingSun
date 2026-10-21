extends SceneTree
## Checks that every level element keeps the rules in CLAUDE.md, so it can be built in the
## editor like the others. Run from the project folder:
##     godot --headless -s tools/check_elements.gd
## Prints one line per problem and exits with 1 when there is any (0 when all is well).
##
## For each script with a class_name in the element folders:
##  - it is @tool and (unless other elements extend it) has an @icon;
##  - it answers _editor_rect() with a box that has an area;
##  - _process/_physics_process start by asking Engine.is_editor_hint();
##  - with _editor_handles() it also has _editor_drag(), and dragging each handle to where
##    it already is leaves the element as it was (the handle shows the true value);
##  - warns when _ready() returns in the editor before building a shader-lit child (the
##    editor would show less than the game).

const FOLDERS := ["res://cover/", "res://structures/", "res://interactive/", "res://hazards/",
	"res://environment/", "res://creatures/", "res://enemies/", "res://gameplay/"]
## Follow the view or live only inside another element: no place of their own in a level.
const NOT_PLACED := ["Bats", "Starlings", "MothSwarm"]

var _problems := 0
var _warnings := 0


func _initialize() -> void:
	var scripts := {}
	for c in ProjectSettings.get_global_class_list():
		var path: String = c.path
		for f in FOLDERS:
			if path.begins_with(f):
				scripts[c["class"]] = path
	var bases := {}
	for cls in scripts:
		var base := (load(scripts[cls]) as Script).get_base_script()
		if base:
			bases[String(base.get_global_name())] = true
	var names := scripts.keys()
	names.sort()
	for cls: String in names:
		if cls in NOT_PLACED:
			continue
		var script := load(scripts[cls]) as Script
		if not ClassDB.is_parent_class(script.get_instance_base_type(), "Node2D"):
			continue
		_check(cls, script, bases.has(cls))
	print("%d element scripts checked: %d problems, %d warnings" % [names.size(), _problems, _warnings])
	quit(1 if _problems > 0 else 0)


func _problem(cls: String, what: String) -> void:
	_problems += 1
	print("PROBLEM %s: %s" % [cls, what])


func _warn(cls: String, what: String) -> void:
	_warnings += 1
	print("warning %s: %s" % [cls, what])


func _check(cls: String, script: Script, is_base: bool) -> void:
	var src := script.source_code
	if not script.is_tool():
		_problem(cls, "not @tool: it is invisible in the editor")
		return
	if not is_base and not src.contains("@icon("):
		_problem(cls, "no @icon")
	for fn in ["_process", "_physics_process"]:
		var body := _body(src, fn)
		if body != "" and not body.left(400).contains("is_editor_hint"):
			_problem(cls, "%s does not check Engine.is_editor_hint() first (it would run in the editor)" % fn)
	var ready := _body(src, "_ready")
	var early := ready.find("if Engine.is_editor_hint():\n\t\treturn")
	if early >= 0 and ready.find("ShaderMaterial.new()", early) > 0:
		_warn(cls, "_ready() returns in the editor before building its shader-lit parts; build them in the editor too and give it _editor_preview()")
	if is_base and not _has(script, "_editor_rect"):
		return
	var node := script.new() as Node2D
	if node == null:
		_problem(cls, "cannot be created")
		return
	if not node.has_method("_editor_rect"):
		_problem(cls, "no _editor_rect(): it cannot be clicked in the 2D view")
	else:
		var r: Rect2 = node._editor_rect()
		if not r.has_area() and not is_base:
			_problem(cls, "_editor_rect() has no area: %s" % r)
	if node.has_method("_editor_handles"):
		if not node.has_method("_editor_drag"):
			_problem(cls, "_editor_handles() without _editor_drag()")
		else:
			_check_handles(cls, node)
	node.free()


## Dragging a handle onto itself must change nothing.
func _check_handles(cls: String, node: Node2D) -> void:
	for h: Dictionary in node._editor_handles():
		if not h.has("id") or not h.get("pos") is Vector2:
			_problem(cls, "handle without id or pos: %s" % h)
			continue
		var props: Array = h.get("props", [h.id])
		var before := {}
		for p: String in props:
			if not p in node:
				_problem(cls, "handle %s names a property it doesn't have: %s" % [h.id, p])
				return
			before[p] = node.get(p)
		node._editor_drag(h.id, (h.pos as Vector2).round())
		for p: String in props:
			if not _close(before[p], node.get(p)):
				_problem(cls, "handle %s doesn't show %s where it is: %s became %s" % [h.id, p, before[p], node.get(p)])
			node.set(p, before[p])


static func _close(a: Variant, b: Variant) -> bool:
	if a is float or a is int:
		return absf(float(a) - float(b)) <= 1.0
	if a is Vector2:
		return (a as Vector2).distance_to(b) <= 1.5
	if a is PackedVector2Array or a is PackedFloat32Array or a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _close(a[i], b[i]):
				return false
		return true
	if a is Rect2:
		return _close((a as Rect2).position, (b as Rect2).position) and _close((a as Rect2).size, (b as Rect2).size)
	return a == b


static func _has(script: Script, method: String) -> bool:
	for m in script.get_script_method_list():
		if m.name == method:
			return true
	return false


## The text of a function in this script, or "" when it has none.
static func _body(src: String, fn: String) -> String:
	var at := src.find("\nfunc %s(" % fn)
	if at < 0:
		return ""
	var end := src.find("\nfunc ", at + 1)
	return src.substr(at, (end if end > 0 else src.length()) - at)
