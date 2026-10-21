@tool
@icon("res://hazards/molten_pool/molten_pool_icon.svg")
class_name MoltenPool
extends Node2D
## A pit of molten steel still glowing in the dark of the old foundry: bubbling surface,
## drifting crust, embers rising, shimmering air, and an orange light on everything above it.
## Touching it is death. Its light also takes away your shadow: near it, enemies see you.
## The node's position is the top-left corner at the surface.

@export var size := Vector2(220, 70):
	set(v):
		size = v
		_layout()
## How far up its light reaches (it reveals the player inside this).
@export var light_reach := 110.0
@export var embers := true

var _rect: ColorRect
var _mat: ShaderMaterial
var _glow: ColorRect
var _glow_mat: ShaderMaterial
var _haze: ColorRect
var _haze_mat: ShaderMaterial
var _embers: GPUParticles2D
var _bubbling: AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("light_sources")
	add_to_group("lamps")
	z_index = Layers.WATER
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_haze = ColorRect.new()
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = preload("res://hazards/molten_pool/heat_haze.gdshader")
	_haze.material = _haze_mat
	_haze.z_as_relative = false
	_haze.z_index = Layers.HAZARD_GLOW - 1
	add_child(_haze)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://hazards/molten_pool/molten.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_glow = ColorRect.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = preload("res://hazards/molten_pool/glow.gdshader")
	_glow.material = _glow_mat
	_glow.z_as_relative = false
	_glow.z_index = Layers.HAZARD_GLOW
	add_child(_glow)
	if embers:
		_embers = EmberParticles.make(Vector2(size.x * 0.5, 4), int(size.x / 6.0))
		_embers.position = Vector2(size.x * 0.5, 2)
		add_child(_embers)
	_bubbling = AudioStreamPlayer2D.new()
	_bubbling.stream = SoundBank.bubbling()
	_bubbling.max_distance = 700.0
	_bubbling.volume_db = -8.0
	add_child(_bubbling)
	_bubbling.play()
	_layout()


func _layout() -> void:
	if _rect:
		_rect.position = Vector2(0, -8)
		_rect.size = size + Vector2(0, 8)
		_mat.set_shader_parameter("rect_size", _rect.size)
		_glow.position = Vector2(-80, -light_reach * 2.2)
		_glow.size = Vector2(size.x + 160, light_reach * 2.2 + 6)
		_glow_mat.set_shader_parameter("rect_size", _glow.size)
		_glow_mat.set_shader_parameter("surface_y", light_reach * 2.2)
		_haze.position = Vector2(0, -90)
		_haze.size = Vector2(size.x, 86)
	queue_redraw()


func illuminates(world_pos: Vector2) -> bool:
	var local := world_pos - global_position
	return local.x > -50.0 and local.x < size.x + 50.0 and local.y > -light_reach and local.y < 20.0


## For the rain and fog: a few points of light along the surface.
func get_light_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := clampi(int(size.x / 120.0) + 1, 1, 3)
	for i in n:
		var x := global_position.x + size.x * (i + 0.5) / n
		out.append(Vector3(x, global_position.y - 10.0, 0.8))
	return out


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_mat.set_shader_parameter("weather_time", Weather.time)
	_mat.set_shader_parameter("world_x", global_position.x)
	_glow_mat.set_shader_parameter("weather_time", Weather.time)
	_glow_mat.set_shader_parameter("intensity", 1.0 + (1.0 - Daylight.light()) * 0.6)
	_haze_mat.set_shader_parameter("weather_time", Weather.time)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead:
		var local := p.global_position - global_position
		if local.x > 2.0 and local.x < size.x - 2.0 and local.y > -2.0:
			p.die("burned")
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead:
			var local := en.global_position - global_position
			if local.x > 0.0 and local.x < size.x and local.y > -2.0:
				en.burn()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.45, 0.1, 0.8))
		DrawKit.editor_box(self, Rect2(Vector2(0, -light_reach), Vector2(size.x, light_reach)), Color(1, 0.7, 0.3, 0.5), "lit: no hiding")
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), DrawKit.EDITOR_HAZARD, "molten steel")
