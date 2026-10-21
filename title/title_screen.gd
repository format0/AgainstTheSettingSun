class_name TitleScreen
extends Node2D
## The title screen: a dark room, a tall window streaming with rain, and beyond it the fields
## under a low, slowly setting sun. The title glows on the wall beneath the window, with a
## few words to choose from. Choosing a chapter pulls the focus from the drops on the glass
## out to the fields, and the view moves through the window into the game.
##
## ← → (or ↑ ↓) choose, Space or Enter confirms, Esc goes back. Esc in a level returns here.

## How the sun moves while the title is shown (Daylight.progress from, to, over seconds).
@export var sun_from := 0.04
@export var sun_to := 0.3
@export var sun_seconds := 300.0

var _room: WindowRoom
var _layer: CanvasLayer
var _title: Label
var _menu: HBoxContainer
var _hint: Label
var _items: Array = []   # [label text, callable]
var _labels: Array[Label] = []
var _sel := 0
var _shown := false
var _leaving := false
var _t := 0.0
var _rain := 0.85
var _focus := 0.0


func _enter_tree() -> void:
	Weather.reset()
	Daylight.progress = sun_from


func _ready() -> void:
	if Game.instance == null:
		Game.start_with(scene_file_path)
		return
	var cam := get_tree().get_first_node_in_group("game_camera") as Node2D
	_room = WindowRoom.new()
	_room.position = cam.global_position if cam else Vector2.ZERO
	add_child(_room)
	Game.mark_occluders(self)
	_build_text()
	Game.instance.overlay.fade_from_black(4.0)
	_main_menu()


func _build_text() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	Game.no_occlude(_layer)
	_title = _label("Against the Setting Sun", 56, 7.0, Color(1.0, 0.84, 0.64))
	_title.anchor_top = 0.835
	_title.anchor_bottom = 0.835
	_title.offset_top = -40
	_title.offset_bottom = 40
	_title.modulate.a = 0.0
	_menu = HBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 46)
	_menu.anchor_left = 0.0
	_menu.anchor_right = 1.0
	_menu.anchor_top = 0.935
	_menu.anchor_bottom = 0.935
	_menu.offset_top = -14
	_menu.offset_bottom = 14
	_menu.modulate.a = 0.0
	_layer.add_child(_menu)
	_hint = _label("arrows choose  ·  space begins", 11, 2.0, Color(0.9, 0.7, 0.55))
	_hint.anchor_top = 0.985
	_hint.anchor_bottom = 0.985
	_hint.offset_top = -10
	_hint.offset_bottom = 6
	_hint.modulate.a = 0.0
	# the title comes up slowly out of the dark, then the words below it
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_title, "modulate:a", 1.0, 3.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _shown = true)
	tw.tween_property(_menu, "modulate:a", 1.0, 1.6)
	tw.parallel().tween_property(_hint, "modulate:a", 0.35, 2.5)


static func _serif(spacing: float) -> FontVariation:
	var font := FontVariation.new()
	var base := SystemFont.new()
	base.font_names = PackedStringArray(["Cormorant Garamond", "EB Garamond", "Garamond", "Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"])
	font.base_font = base
	font.spacing_glyph = int(spacing)
	return font


func _label(text: String, size: int, spacing: float, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _serif(spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l


# ------------------------------------------------------------------ menu

func _main_menu() -> void:
	var items := []
	var reached := Progress.reached()
	if reached > 0:
		items.append(["continue", func(): _start(reached)])
		items.append(["begin again", func(): _start(0)])
		items.append(["chapters", _chapters])
	else:
		items.append(["begin", func(): _start(0)])
	if not OS.has_feature("web"):
		items.append(["leave", func(): get_tree().quit()])
	_set_items(items, 0)


func _chapters() -> void:
	var items := []
	for i in Progress.reached() + 1:
		var ch: Array = Progress.CHAPTERS[i]
		var idx := i
		items.append(["%s · %s" % [ch[1], ch[2]], func(): _start(idx)])
	items.append(["back", _main_menu])
	_set_items(items, Progress.reached())


func _set_items(items: Array, sel: int) -> void:
	_items = items
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for it in items:
		var l := Label.new()
		l.text = it[0]
		l.add_theme_font_override("font", _serif(4.0))
		l.add_theme_font_size_override("font_size", 19)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu.add_child(l)
		_labels.append(l)
	_sel = clampi(sel, 0, items.size() - 1)
	_style_items()


func _style_items() -> void:
	for i in _labels.size():
		var on := i == _sel
		_labels[i].add_theme_color_override("font_color", Color(1.0, 0.86, 0.66) if on else Color(0.72, 0.5, 0.38))
		_labels[i].modulate.a = 1.0 if on else 0.55
		_labels[i].text = ("·  %s  ·" if on else "%s") % _items[i][0]


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed() or event.is_echo():
		return
	if not _shown:
		# any key brings the words up at once
		_title.modulate.a = 1.0
		_menu.modulate.a = 1.0
		_hint.modulate.a = 0.35
		_shown = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + _items.size()) % _items.size()
		_style_items()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % _items.size()
		_style_items()
	elif event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		(_items[_sel][1] as Callable).call()
	elif event.is_action_pressed("ui_cancel"):
		_main_menu()
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ leaving

func _start(chapter: int) -> void:
	if _leaving:
		return
	_leaving = true
	var path: String = Progress.CHAPTERS[chapter][0]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 0.0, 1.2)
	tw.tween_property(_menu, "modulate:a", 0.0, 0.8)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.6)
	# the eye leaves the drops and finds the fields; the room falls away behind
	tw.tween_property(self, "_focus", 1.0, 2.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_rain", 0.35, 2.6)
	tw.tween_method(_push, 0.0, 1.0, 3.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(2.2).timeout
	await Game.instance.overlay.fade_to_black(1.6)
	Game.instance.load_level.call_deferred(path)


## Moving towards the window: the room grows around its centre (the far fields hardly change).
func _push(k: float) -> void:
	var pivot := WindowRoom.OPENING.get_center()
	var s := 1.0 + k * 1.6
	var cam := get_tree().get_first_node_in_group("game_camera") as Node2D
	var origin := cam.global_position if cam else Vector2.ZERO
	_room.scale = Vector2(s, s)
	_room.position = origin + pivot - pivot * s


func _process(delta: float) -> void:
	if _room == null:
		return
	_t += delta
	Daylight.progress = lerpf(sun_from, sun_to, smoothstep(0.0, sun_seconds, _t))
	Game.instance.lens_level = 0.0
	_room.set_glass(_rain, _focus, Weather.time)
	if _shown and not _leaving:
		# the title breathes with the candle
		_title.modulate.a = 0.92 + 0.08 * sin(Weather.time * 0.8)
