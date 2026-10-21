@icon("res://effects/effect_icon.svg")
class_name WetGround
extends PostEffect
## Makes the ground look wet: a faint reflection of the sky everywhere and real
## reflections with rain ripples in every Puddle node of the level.

@export_range(0.0, 0.3) var sheen := 0.07


func _ready() -> void:
	_setup(preload("res://effects/post/wet_ground.gdshader"), Layers.CANVAS_WET_GROUND)


func _process(_delta: float) -> void:
	var view := GameCamera.view_rect
	var ground := Level.current.ground_y if Level.current else 635.0
	material.set_shader_parameter("view_size", view.size)
	material.set_shader_parameter("horizon", ground + 1.0 - view.position.y)
	material.set_shader_parameter("weather_time", Weather.time)
	material.set_shader_parameter("cam_x", view.position.x)
	material.set_shader_parameter("storm", Weather.storm)
	material.set_shader_parameter("sheen", sheen)
	var data: Array[Vector4] = []
	for node in get_tree().get_nodes_in_group("puddles"):
		var p := node as Puddle
		var sx := p.global_position.x - view.position.x
		if data.size() < 8 and sx > -p.half_width - 50.0 and sx < view.size.x + p.half_width + 50.0:
			data.append(Vector4(sx, p.half_width, p.depth_offset, float(p.get_instance_id() % 97)))
	while data.size() < 8:
		data.append(Vector4.ZERO)
	material.set_shader_parameter("puddles", data)
