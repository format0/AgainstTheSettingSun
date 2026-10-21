class_name ScreenOverlay
extends CanvasLayer
## Fades to and from black and shows the few words the game ever says:
## the level title, and a line when the light is gone or the game is over.
## The Level creates one by itself.

var _black: ColorRect
var _title: Label
var _subtitle: Label
var _tween_black: Tween
var _tween_text: Tween


func _ready() -> void:
	layer = Layers.CANVAS_OVERLAY
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_title = _make_label(46, 14.0, 0.40)
	_subtitle = _make_label(18, 5.0, 0.40 + 0.075)


func _make_label(size: int, spacing: float, y: float) -> Label:
	var font := FontVariation.new()
	var base := SystemFont.new()
	base.font_names = PackedStringArray(["Cormorant Garamond", "Garamond", "Georgia", "Times New Roman", "Liberation Serif", "serif"])
	font.base_font = base
	font.spacing_glyph = int(spacing)
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.72))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y
	l.anchor_bottom = y
	l.offset_top = -40
	l.offset_bottom = 40
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func fade_to_black(seconds: float) -> void:
	await _fade(1.0, seconds)


func fade_from_black(seconds: float) -> void:
	_black.color.a = 1.0
	await _fade(0.0, seconds)


func _fade(alpha: float, seconds: float) -> void:
	if _tween_black:
		_tween_black.kill()
	_tween_black = create_tween()
	_tween_black.tween_property(_black, "color:a", alpha, seconds).set_trans(Tween.TRANS_SINE)
	await _tween_black.finished


## Level number and name, fading in over the opening and out again.
func show_title(title: String, subtitle: String) -> void:
	_title.add_theme_font_size_override("font_size", 46)
	_title.text = title
	_subtitle.text = subtitle.to_lower()
	_animate_text(1.2, 3.2, 2.0)


func clear_text() -> void:
	if _tween_text:
		_tween_text.kill()
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0


## A line of text that stays until the next level is loaded.
func show_message(text: String, subtitle := "") -> void:
	_title.add_theme_font_size_override("font_size", 30)
	_title.text = text
	_subtitle.text = subtitle
	_animate_text(2.0, -1.0, 0.0)


func _animate_text(fade_in: float, hold: float, fade_out: float) -> void:
	if _tween_text:
		_tween_text.kill()
	_tween_text = create_tween()
	_tween_text.tween_property(_title, "modulate:a", 0.9, fade_in)
	_tween_text.parallel().tween_property(_subtitle, "modulate:a", 0.7, fade_in * 1.4)
	if hold >= 0.0:
		_tween_text.tween_interval(hold)
		_tween_text.tween_property(_title, "modulate:a", 0.0, fade_out)
		_tween_text.parallel().tween_property(_subtitle, "modulate:a", 0.0, fade_out)
