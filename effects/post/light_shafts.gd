@icon("res://effects/effect_icon.svg")
class_name LightShafts
extends PostEffect
## Shafts of sunlight between the silhouettes. Needs a SkyEffect in the level (it knows where the sun is).

@export_range(0.0, 1.5) var strength := 0.38
@export_range(8, 64) var samples := 48


func _ready() -> void:
	_setup(preload("res://effects/post/light_shafts.gdshader"), Layers.CANVAS_LIGHT_SHAFTS)
	if Game.instance:
		# the Game draws real shafts through the gaps between silhouettes; this sets their strength
		visible = false
		Game.instance.rays_level = strength / 0.38
		set_process(false)


func _process(_delta: float) -> void:
	var size := GameCamera.view_rect.size
	material.set_shader_parameter("sun_uv", Weather.sun_screen_pos / size)
	material.set_shader_parameter("aspect", size.x / size.y)
	material.set_shader_parameter("strength", strength * (1.0 - smoothstep(0.35, 0.85, Daylight.progress)))
	material.set_shader_parameter("samples", samples)
