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
var _far_flash := 0.0
var _far_x := 0.0
var _far_wait := 6.0
var _far_t := -1.0


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


func _process(delta: float) -> void:
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
	_mat.set_shader_parameter("afterglow", VFX.v("afterglow"))
	_mat.set_shader_parameter("sun_squash", VFX.v("sun_squash"))
	_update_far_lightning(delta, view.size)
	_mat.set_shader_parameter("far_flash", _far_flash)
	_mat.set_shader_parameter("far_x", _far_x)


## Now and then, once the sun is low, silent lightning flickers in the clouds far away.
func _update_far_lightning(delta: float, view: Vector2) -> void:
	_far_flash = 0.0
	if not VFX.on("heat_lightning") or Daylight.progress < 0.25:
		return
	if _far_t < 0.0:
		_far_wait -= delta
		if _far_wait <= 0.0:
			_far_t = 0.0
			_far_x = randf_range(0.1, 0.9) * view.x
		return
	_far_t += delta
	# two or three quick flickers in a fraction of a second
	_far_flash = maxf(0.0, sin(_far_t * 38.0)) * exp(-_far_t * 5.0)
	if _far_t > 0.22:
		_far_flash += maxf(0.0, sin((_far_t - 0.22) * 30.0)) * exp(-(_far_t - 0.22) * 6.0)
	if _far_t > 0.9:
		_far_t = -1.0
		_far_wait = randf_range(4.0, 14.0)
