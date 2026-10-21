@icon("res://effects/effect_icon.svg")
class_name SkyEffect
extends CanvasLayer
## The sunset sky behind everything, with drifting storm clouds and lightning glow.
## Also tells the other effects where the sun is (for light shafts).

## Sun position on screen when the camera is at the start of the level.
@export var sun_screen_position := Vector2(455, 618)
## How much the sun drifts as the camera moves (0 = fixed on screen).
@export var sun_parallax := 0.05
@export_range(0.2, 0.7) var cloud_cover := 0.4

var _mat: ShaderMaterial


func _ready() -> void:
	layer = Layers.CANVAS_SKY
	add_to_group("effects")
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://effects/sky/sky.gdshader")
	rect.material = _mat
	add_child(rect)


func _process(_delta: float) -> void:
	var view := GameCamera.view_rect
	# the sun sinks below the horizon as the level goes on
	var sink := Vector2(0, smoothstep(0.1, 0.9, Daylight.progress) * 230.0)
	var sun := sun_screen_position + sink - Vector2(view.position.x * sun_parallax, view.position.y)
	Weather.sun_screen_pos = sun
	_mat.set_shader_parameter("view_size", view.size)
	_mat.set_shader_parameter("weather_time", Weather.time)
	_mat.set_shader_parameter("cam_x", view.position.x)
	_mat.set_shader_parameter("sun_pos", sun)
	_mat.set_shader_parameter("flash", Weather.flash)
	_mat.set_shader_parameter("bolt_x", Weather.bolt_screen_x)
	_mat.set_shader_parameter("storm", Weather.storm)
	_mat.set_shader_parameter("cloud_cover", cloud_cover)
	_mat.set_shader_parameter("dusk", Daylight.progress)
	_mat.set_shader_parameter("sun_glow", VFX.v("sun_glow"))
