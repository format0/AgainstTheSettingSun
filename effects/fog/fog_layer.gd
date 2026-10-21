@icon("res://effects/effect_icon.svg")
class_name FogLayer
extends Node2D
## Drifting fog. Use a BANK behind the level (z_index Layers.FOG_BANK) and/or GROUND fog
## in front of it (Layers.GROUND_FOG). Thicker when the storm is stronger.

enum Mode { BANK, GROUND }

@export var mode := Mode.BANK
@export_range(0.0, 1.0) var density := 0.3
## How fast the fog pattern moves with the camera (1 = with the level).
@export var parallax := 0.6

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("effects")
	process_priority = 10
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://effects/fog/fog.gdshader")
	_rect.material = _mat
	add_child(_rect)


func _process(_delta: float) -> void:
	var view := GameCamera.view_rect
	global_position = view.position
	_rect.size = view.size
	var ground := Level.current.ground_y if Level.current else 635.0
	var amount := density * (0.7 + 0.45 * minf(Weather.storm, 1.6)) * VFX.v("fog" if mode == Mode.BANK else "ground_fog")
	# as the air cools after sunset, mist rises from the ground
	amount *= 1.0 + VFX.v("evening_mist") * smoothstep(0.35, 0.85, Daylight.progress) * (0.9 if mode == Mode.GROUND else 0.35)
	_mat.set_shader_parameter("view_size", view.size)
	_mat.set_shader_parameter("mode", float(mode))
	_mat.set_shader_parameter("density", amount)
	_mat.set_shader_parameter("weather_time", Weather.time)
	_mat.set_shader_parameter("wind_acc", Weather.wind_acc)
	_mat.set_shader_parameter("cam_x", view.position.x)
	_mat.set_shader_parameter("parallax", parallax)
	_mat.set_shader_parameter("ground_y", ground - view.position.y)
	_mat.set_shader_parameter("flash", Weather.flash)
	_mat.set_shader_parameter("sun_pos", Weather.sun_screen_pos)
	_mat.set_shader_parameter("light", Daylight.light())
	var lamps := PackedVector3Array()
	for p in StreetLamp.lights_near(view):
		lamps.append(Vector3(p.x - view.position.x, p.y - view.position.y, p.z))
	_mat.set_shader_parameter("lamps", lamps)
