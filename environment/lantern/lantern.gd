@tool
@icon("res://environment/lantern/lantern_icon.svg")
class_name Lantern
extends Node2D
## An oil lantern hanging from a hook on a rope or chain, swinging in the wind, its little
## flame guttering. Its light takes away the player's shadow nearby.
## The node's position is the hook; the lantern hangs `drop` below.

@export var drop := 40.0:
	set(v):
		drop = v
		_relayout()
@export var light_radius := 80.0:
	set(v):
		light_radius = v
		_relayout()
## It can go out for good as the night comes (0 = never).
@export_range(0.0, 1.0) var dies_at := 0.0:
	set(v):
		dies_at = v
		_relayout()

var intensity := 1.0
var _angle := 0.0
var _spin := 0.0
var _light: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("light_sources")
	add_to_group("lamps")
	_light = ColorRect.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.z_as_relative = false
	_light.z_index = Layers.LAMP_LIGHT
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://environment/fire_barrel/point_light.gdshader")
	_mat.set_shader_parameter("color", Color(1.0, 0.7, 0.35))
	_light.material = _mat
	_layout_light()
	add_child(_light)
	if Engine.is_editor_hint():
		_editor_preview()
		return
	Game.no_occlude(_light)


func _layout_light() -> void:
	var s := light_radius * 3.0
	_light.size = Vector2(s, s)
	_light.position = _lamp_pos() - _light.size * 0.5
	_mat.set_shader_parameter("radius", light_radius)
	_mat.set_shader_parameter("rect_size", _light.size)
	_mat.set_shader_parameter("center", Vector2(s * 0.5, s * 0.5))


func _relayout() -> void:
	queue_redraw()
	if _light and Engine.is_editor_hint():
		_layout_light()
		_editor_preview()


func _lamp_pos() -> Vector2:
	return Vector2.from_angle(PI * 0.5 + _angle) * drop


func illuminates(world_pos: Vector2) -> bool:
	return intensity > 0.3 and world_pos.distance_to(global_position + _lamp_pos()) < light_radius


func get_light_points() -> Array[Vector3]:
	var p := global_position + _lamp_pos()
	return [Vector3(p.x, p.y, intensity * 0.8)]


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var k := 9.81 * 60.0 / maxf(drop, 10.0)
	_spin += (-k * sin(_angle) * 0.5 - _spin * 0.5 - Weather.wind * 1.2 * Weather.gust_at(global_position.x) + sin(Weather.time * 1.9) * 0.4 * Weather.wind) * delta
	_angle += _spin * delta
	var on := dies_at <= 0.0 or Daylight.progress < dies_at
	var goal := (0.85 + 0.15 * sin(Weather.time * 17.0) * sin(Weather.time * 5.1)) if on else 0.0
	intensity = lerpf(intensity, goal, delta * 6.0)
	var lp := _lamp_pos()
	_light.position = lp - _light.size * 0.5
	_mat.set_shader_parameter("intensity", intensity * (1.0 + (1.0 - Daylight.light()) * 0.5) * VFX.v("lamp_glow"))
	_mat.set_shader_parameter("weather_time", Weather.time)
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var lp := _lamp_pos()
	draw_line(Vector2.ZERO, lp + Vector2(0, -12).rotated(_angle), c, 1.2)
	draw_set_transform(lp, _angle)
	draw_arc(Vector2(0, -12), 4.0, PI, TAU, 8, c, 1.4)
	draw_rect(Rect2(-7, -9, 14, 3), c)
	draw_rect(Rect2(-6, 6, 12, 4), c)
	for x: float in [-6.0, 5.0]:
		draw_rect(Rect2(x, -7, 1.4, 14), c)
	var flame := Color(1.0, 0.8, 0.45, intensity)
	DrawKit.ellipse(self, Vector2(0, 1), Vector2(2.0, 3.6 * (0.8 + intensity * 0.3)), 0.0, flame, 10)
	draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-14, 0, 28, drop + 24.0)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "drop", "pos": Vector2(0, drop)}, {"id": "light_radius", "pos": Vector2(light_radius, drop + 10.0)}]


func _editor_drag(id: Variant, p: Vector2) -> void:
	if id == "drop":
		drop = maxf(0.0, p.y)
	else:
		light_radius = maxf(10.0, absf(p.x))


## The lantern as it looks at the previewed time of day, hanging still.
func _editor_preview() -> void:
	intensity = 0.9 if dies_at <= 0.0 or Daylight.progress < dies_at else 0.0
	_mat.set_shader_parameter("intensity", intensity * (1.0 + (1.0 - Daylight.light()) * 0.5))
	_mat.set_shader_parameter("weather_time", 30.0)
	queue_redraw()
