@tool
@icon("res://elements/grass_field/grass_field_icon.svg")
class_name GrassField
extends Node2D
## A strip of grass along the ground: thousands of blades drawn in one go on the GPU,
## bending with the gusts and parting around the player's feet.
## The node's position is the left end of the strip, on the ground line.
## Also used for the tall foreground reeds (put it in a Parallax2D with a scroll scale above 1).

@export var width := 3000.0:
	set(v):
		width = v
		_rebuild()
@export_group("Blades")
@export var spacing_min := 0.9:
	set(v):
		spacing_min = v
		_rebuild()
@export var spacing_max := 2.6:
	set(v):
		spacing_max = v
		_rebuild()
@export var height_min := 3.0:
	set(v):
		height_min = v
		_rebuild()
@export var height_max := 26.0:
	set(v):
		height_max = v
		_rebuild()
## Chance of an extra-tall weed among the grass.
@export_range(0.0, 1.0) var tall_chance := 0.025:
	set(v):
		tall_chance = v
		_rebuild()
@export var tall_height := Vector2(26, 58)
@export var blade_width := 1.4
## Draw only clusters (with gaps), for sparse reeds.
@export var clustered := false:
	set(v):
		clustered = v
		_rebuild()
## How far below the node the blades start (hides their base).
@export var base_depth := 2.0
@export var grass_seed := 1:
	set(v):
		grass_seed = v
		_rebuild()
@export_group("Motion")
@export var wind_response := 1.0
@export var player_pushes := true

var blade_count := 0
var _mmi: MultiMeshInstance2D
var _mat: ShaderMaterial


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mmi == null:
		_mmi = MultiMeshInstance2D.new()
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://elements/grass_field/grass.gdshader")
		_mmi.material = _mat
		add_child(_mmi)
	var rng := RandomNumberGenerator.new()
	rng.seed = grass_seed
	var xs: Array[Vector4] = []
	var x := 0.0
	while x < width:
		x += rng.randf_range(spacing_min, spacing_max)
		var clump := 0.5 + 0.5 * sin(x * 0.013) * sin(x * 0.0041 + 1.3)
		if clustered and clump < 0.62:
			continue
		var tall := rng.randf() < tall_chance
		var h := rng.randf_range(tall_height.x, tall_height.y) if tall else lerpf(height_min, height_max, clump * rng.randf())
		var w := blade_width * (0.8 if tall else rng.randf_range(0.8, 1.4)) + h * 0.02
		xs.append(Vector4(x, h, w, rng.randf() * 100.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = _blade_mesh()
	mm.instance_count = xs.size()
	for i in xs.size():
		var b := xs[i]
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(b.z, b.y), 0.0, Vector2(b.x, base_depth)))
		var flex := clampf(0.25 + b.y / 45.0, 0.3, 1.2)
		mm.set_instance_custom_data(i, Color(global_position.x + b.x, b.w, b.y / b.z, flex))
	_mmi.multimesh = mm
	blade_count = xs.size()


func _blade_mesh() -> ArrayMesh:
	var verts := PackedVector2Array([Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(-0.3, -0.5), Vector2(0.3, -0.5), Vector2(0, -1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2, 2, 3, 4])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _mat == null:
		return
	_mat.set_shader_parameter("weather_time", Weather.time)
	_mat.set_shader_parameter("wind", Weather.wind)
	_mat.set_shader_parameter("wind_response", wind_response)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_mat.set_shader_parameter("player_x", player.global_position.x if (player and player_pushes) else -99999.0)
