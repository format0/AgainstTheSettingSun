@icon("res://effects/effect_icon.svg")
class_name RainLayer
extends Node2D
## A sheet of rain at a range of depths. Use two: a far one behind the level (depth 0..0.45,
## z_index Layers.RAIN_FAR) and a near one in front of everything (0.45..1, Layers.RAIN_NEAR).
## The number of drops follows the storm strength. Drops glint inside lamp light.

@export_range(0.0, 1.0) var depth_min := 0.0
@export_range(0.0, 1.0) var depth_max := 0.45
## Drops on screen at storm strength 1.
@export var drops_per_storm := 23000
## Upper limit (storm 2 doubles the count up to this).
@export var max_drops := 46000
@export_range(0.0, 2.0) var opacity := 1.0

var visible_drops := 0
var _mm: MultiMesh
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("effects")
	process_priority = 10
	var verts := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_custom_data = true
	_mm.mesh = mesh
	_mm.instance_count = max_drops
	_mm.custom_aabb = AABB(Vector3(-400, -300, -1), Vector3(2600, 1600, 2))
	var rng := RandomNumberGenerator.new()
	for i in max_drops:
		_mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
		_mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = _mm
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://effects/rain/rain.gdshader")
	mmi.material = _mat
	add_child(mmi)


func _process(_delta: float) -> void:
	var view := GameCamera.view_rect
	global_position = view.position
	visible_drops = clampi(int(drops_per_storm * Weather.storm), 0, max_drops)
	_mm.visible_instance_count = visible_drops
	_mat.set_shader_parameter("view_size", view.size)
	_mat.set_shader_parameter("weather_time", Weather.time)
	_mat.set_shader_parameter("cam_x", view.position.x)
	_mat.set_shader_parameter("wind_acc", Weather.wind_acc)
	_mat.set_shader_parameter("wind_angle", Weather.wind_angle)
	_mat.set_shader_parameter("depth_min", depth_min)
	_mat.set_shader_parameter("depth_max", depth_max)
	_mat.set_shader_parameter("flash", Weather.flash)
	_mat.set_shader_parameter("opacity", opacity)
	var ground := Level.current.ground_y if Level.current else 635.0
	_mat.set_shader_parameter("ground_y", ground - view.position.y)
	var lamps := PackedVector3Array()
	for p in StreetLamp.lights_near(view):
		lamps.append(Vector3(p.x - view.position.x, p.y - view.position.y, p.z))
	_mat.set_shader_parameter("lamps", lamps)
