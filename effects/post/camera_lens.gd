@icon("res://effects/effect_icon.svg")
class_name CameraLens
extends PostEffect
## The "camera": glow around lights, raindrops on the lens, colour fringing, grading,
## vignette and grain. Put it last; every part can be switched off or tuned here.

@export_range(0.0, 2.0) var bloom := 1.0
@export_range(0.0, 1.0) var bloom_threshold := 0.78
@export var lens_rain := true
## Lens rain grows with the storm up to this.
@export_range(0.0, 1.5) var lens_rain_max := 1.0
@export_range(0.0, 3.0) var fringe := 1.0
@export_range(0.0, 1.0) var vignette := 0.55
@export_range(0.0, 0.2) var grain := 0.05


func _ready() -> void:
	_setup(preload("res://effects/post/camera_lens.gdshader"), Layers.CANVAS_LENS)


func _process(_delta: float) -> void:
	var size := GameCamera.view_rect.size
	material.set_shader_parameter("weather_time", Weather.time)
	material.set_shader_parameter("flash", Weather.flash)
	material.set_shader_parameter("bloom", bloom)
	material.set_shader_parameter("bloom_threshold", bloom_threshold)
	material.set_shader_parameter("lens_rain", minf(lens_rain_max, 0.35 + 0.55 * Weather.storm) if lens_rain else 0.0)
	material.set_shader_parameter("fringe", fringe)
	material.set_shader_parameter("vignette", vignette)
	material.set_shader_parameter("grain", grain)
	material.set_shader_parameter("aspect", size.x / size.y)
	material.set_shader_parameter("darkness", Daylight.urgency())
