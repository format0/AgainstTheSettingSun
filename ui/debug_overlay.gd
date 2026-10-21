class_name DebugOverlay
extends CanvasLayer
## F1 shows frame rate, storm values and a numbered list of the level's effects.
## Press the key next to an effect to switch that effect off and on, to see what it adds and costs.

const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
const KEY_NAMES := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]

var _label: Label
var _effects: Array[Node] = []


func _ready() -> void:
	layer = Layers.CANVAS_UI
	visible = false
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.02, 0.78)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.74))
	panel.add_child(_label)
	add_child(panel)
	await get_tree().process_frame
	_effects = get_tree().get_nodes_in_group("effects")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible
	elif visible and event is InputEventKey and event.pressed and not event.echo:
		var n := KEYS.find(event.keycode)
		if n >= 0 and n < _effects.size():
			_toggle(_effects[n])


func _toggle(e: Node) -> void:
	var on := not _is_on(e)
	if e.has_method("set_effect_enabled"):
		e.set_effect_enabled(on)
	if "visible" in e:
		e.visible = on
	e.set_meta("effect_on", on)


func _is_on(e: Node) -> bool:
	return e.get_meta("effect_on", true)


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray()
	lines.append("%d fps   storm %.2f   wind %.2f" % [Engine.get_frames_per_second(), Weather.storm, Weather.wind])
	var drops := 0
	for e in _effects:
		if e is RainLayer and _is_on(e):
			drops += e.visible_drops
	lines.append("raindrops %d   (L lightning, R restart)" % drops)
	lines.append("")
	for i in mini(KEYS.size(), _effects.size()):
		var e := _effects[i]
		lines.append("%s  %s %s" % [KEY_NAMES[i], "■" if _is_on(e) else "□", e.name])
	_label.text = "\n".join(lines)
