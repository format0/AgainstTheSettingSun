@tool
@icon("res://environment/fire_barrel/fire_barrel_icon.svg")
class_name FireBarrel
extends Node2D
## An oil drum with a fire burning in it: flames bent by the wind, sparks, a warm flickering
## light on the rain. Someone lit it long ago... Its light takes away the player's shadow
## (enemies see you close to it). The node's position is the foot of the drum.

@export var light_radius := 100.0
@export var drum_height := 34.0:
	set(v):
		drum_height = v
		queue_redraw()

var intensity := 1.0
var _light: ColorRect
var _mat: ShaderMaterial
var _embers: GPUParticles2D
var _crackle: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.ELEMENTS
	if Engine.is_editor_hint():
		return
	add_to_group("light_sources")
	add_to_group("lamps")
	_light = ColorRect.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.z_as_relative = false
	_light.z_index = Layers.LAMP_LIGHT
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://environment/fire_barrel/point_light.gdshader")
	_light.material = _mat
	var s := light_radius * 3.2
	_light.position = Vector2(-s * 0.5, -drum_height - s * 0.5)
	_light.size = Vector2(s, s)
	_mat.set_shader_parameter("rect_size", _light.size)
	_mat.set_shader_parameter("center", Vector2(s * 0.5, s * 0.5 - 8.0))
	_mat.set_shader_parameter("radius", light_radius)
	add_child(_light)
	Game.no_occlude(_light)
	_embers = EmberParticles.make(Vector2(8, 2), 14)
	_embers.position = Vector2(0, -drum_height - 6)
	add_child(_embers)
	_crackle = AudioStreamPlayer2D.new()
	_crackle.stream = SoundBank.fire_crackle()
	_crackle.max_distance = 600.0
	_crackle.volume_db = -10.0
	add_child(_crackle)
	_crackle.play()


func illuminates(world_pos: Vector2) -> bool:
	return world_pos.distance_to(global_position + Vector2(0, -drum_height)) < light_radius


func get_light_points() -> Array[Vector3]:
	var p := global_position + Vector2(0, -drum_height - 10)
	return [Vector3(p.x, p.y, intensity * 0.9)]


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	intensity = 0.8 + 0.12 * sin(Weather.time * 13.0) * sin(Weather.time * 7.3) + 0.08 * randf()
	_mat.set_shader_parameter("intensity", intensity * (1.0 + (1.0 - Daylight.light()) * 0.5) * VFX.v("lamp_glow"))
	_mat.set_shader_parameter("weather_time", Weather.time)
	(_embers.process_material as ParticleProcessMaterial).gravity = Vector3(-Weather.wind * 90.0, -20.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var h := drum_height
	draw_rect(Rect2(-12, -h, 24, h), c)
	for k in 3:
		draw_rect(Rect2(-13.5, -h + h * (0.12 + k * 0.38) - 1.5, 27, 3), c)
	draw_rect(Rect2(-13, -h - 2, 26, 3), c)
	if Engine.is_editor_hint():
		return
	# flames, bent downwind, drawn as glowing tongues over the rim
	var t := Weather.time
	for i in 5:
		var x := -9.0 + i * 4.5
		var tall := 10.0 + 8.0 * absf(sin(t * (6.0 + i) + i * 1.7)) + 4.0 * intensity
		var lean := -Weather.wind * 7.0 * (0.6 + Weather.gust_at(global_position.x)) + sin(t * 9.0 + i) * 2.0
		var tip := Vector2(x + lean, -h - 2 - tall)
		var col := Color(1.0, 0.55 + 0.25 * sin(t * 11.0 + i), 0.15, 0.85)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5, -h - 1), Vector2(x + 3.5, -h - 1), tip]), col)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1.5, -h - 1), Vector2(x + 1.5, -h - 1), Vector2(x + lean * 0.6, -h - 2 - tall * 0.55)]), Color(1.0, 0.92, 0.6, 0.9))
