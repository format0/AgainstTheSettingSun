class_name VfxPanel
extends CanvasLayer
## F1 opens a panel for trying out the look while playing: a slider or a switch for every
## setting in VFX (bloom, softness, light shafts, haze, rain, grading, the living things),
## the time of day, the storm, and switches for each of the level's effect nodes.
## Use the mouse; the arrow keys keep moving the runner. Settings are saved when the panel
## closes. "Copy" puts all values on the clipboard, to paste into a message.

var _box: VBoxContainer
var _stats: Label
var _sliders := {}
var _checks := {}
var _effects_box: VBoxContainer
var _effects_level: Node
var _sun: HSlider
var _sun_label: Label
var _storm: HSlider
var _storm_label: Label
var _freeze: CheckBox
var _god: CheckBox


func _ready() -> void:
	layer = Layers.CANVAS_UI + 10
	visible = false
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = -10
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.03, 0.024, 0.86)
	style.border_color = Color(0.96, 0.86, 0.74, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_box)

	_stats = _label("", 12, Color(0.96, 0.86, 0.74))
	_box.add_child(_stats)
	var buttons := HBoxContainer.new()
	for b in [["Copy", _copy], ["Reset", _reset], ["Strike lightning", _strike]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		buttons.add_child(btn)
	_box.add_child(buttons)

	_heading("Time and weather")
	var r := _slider_row("Sunset", 0.0, 1.0, 0.0)
	_sun = r[0]
	_sun_label = r[1]
	_sun.value_changed.connect(func(val: float): Daylight.progress = val)
	_freeze = _check("Stop the sun", false, func(_on: bool): pass)
	r = _slider_row("Storm", 0.0, 2.0, 1.0)
	_storm = r[0]
	_storm_label = r[1]
	_storm.value_changed.connect(_set_storm)
	_god = _check("Nothing can kill me", false, func(on: bool):
		var p := _player()
		if p:
			p.invulnerable = on)

	var group := ""
	for key in VFX.SETTINGS:
		var s: Array = VFX.SETTINGS[key]
		if s[4] != group:
			group = s[4]
			_heading(group)
		if VFX.is_switch(key):
			_checks[key] = _check(s[3], VFX.on(key), func(on: bool): VFX.set_value(key, 1.0 if on else 0.0))
		else:
			var row := _slider_row(s[3], float(s[1]), float(s[2]), VFX.v(key))
			var sl: HSlider = row[0]
			var lab: Label = row[1]
			sl.value_changed.connect(func(val: float):
				VFX.set_value(key, val)
				lab.text = "%.2f" % val)
			_sliders[key] = sl
	_heading("Effects in this level")
	_effects_box = VBoxContainer.new()
	_box.add_child(_effects_box)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _heading(text: String) -> void:
	var l := _label(text.to_upper(), 11, Color(1.0, 0.55, 0.2))
	_box.add_child(HSeparator.new())
	_box.add_child(l)


func _slider_row(text: String, lo: float, hi: float, val: float) -> Array:
	var row := HBoxContainer.new()
	var name_label := _label(text, 11, Color(0.75, 0.62, 0.52))
	name_label.custom_minimum_size.x = 120
	row.add_child(name_label)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = (hi - lo) / 200.0
	sl.value = val
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.focus_mode = Control.FOCUS_NONE
	row.add_child(sl)
	var v := _label("%.2f" % val, 11, Color(0.96, 0.86, 0.74))
	v.custom_minimum_size.x = 36
	row.add_child(v)
	_box.add_child(row)
	return [sl, v]


func _check(text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 11)
	c.toggled.connect(cb)
	_box.add_child(c)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible
		if not visible:
			VFX.save_settings()


func _process(_delta: float) -> void:
	if _freeze and _freeze.button_pressed:
		Daylight.progress = _sun.value
	if not visible:
		return
	_sun.set_value_no_signal(Daylight.progress)
	_sun_label.text = "%d%%" % int(Daylight.progress * 100.0)
	var p := _player()
	var hunting := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == Enemy.State.CHASE or e.state == Enemy.State.ALERT:
			hunting += 1
	_stats.text = "%d fps   storm %.2f   wind %.2f\nin shadow: %s   hunted by: %d" % [Engine.get_frames_per_second(), Weather.storm, Weather.wind,
		"yes" if p and p.in_shadow else "no", hunting]
	var lvl := Level.current
	if lvl != _effects_level:
		_effects_level = lvl
		_fill_effects()


func _fill_effects() -> void:
	for c in _effects_box.get_children():
		c.queue_free()
	if _effects_level == null:
		return
	var wc := _effects_level.find_children("*", "WeatherController", true, false)
	if not wc.is_empty():
		_storm.set_value_no_signal((wc[0] as WeatherController).storm)
		_storm_label.text = "%.2f" % _storm.value
	for e in get_tree().get_nodes_in_group("effects"):
		var c := CheckBox.new()
		c.text = e.name
		c.button_pressed = e.get_meta("effect_on", true)
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 11)
		var node: Node = e
		c.toggled.connect(func(on: bool):
			if node.has_method("set_effect_enabled"):
				node.set_effect_enabled(on)
			if "visible" in node:
				node.visible = on
			node.set_meta("effect_on", on))
		_effects_box.add_child(c)


func _set_storm(val: float) -> void:
	_storm_label.text = "%.2f" % val
	if _effects_level:
		for w in _effects_level.find_children("*", "WeatherController", true, false):
			(w as WeatherController).storm = val


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _copy() -> void:
	DisplayServer.clipboard_set(VFX.dump() + "\nsunset = %.2f\nstorm = %.2f" % [Daylight.progress, _storm.value])


func _reset() -> void:
	VFX.reset()
	for k in _sliders:
		(_sliders[k] as HSlider).value = VFX.v(k)
	for k in _checks:
		(_checks[k] as CheckBox).button_pressed = VFX.on(k)


func _strike() -> void:
	for l in get_tree().get_nodes_in_group("effects"):
		if l is LightningEffect:
			l.strike()
