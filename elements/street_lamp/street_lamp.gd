@tool
@icon("res://elements/street_lamp/street_lamp_icon.svg")
class_name StreetLamp
extends Node2D
## A street lamp: light cone through the rain and fog, a pool of light on the ground,
## moths, and a hum. Each lamp has its own behaviour (steady, flickering, failing).
## The node's position is where the arms meet the post; bulbs are placed relative to it.
## Turn off `draw_post` when the lamp post is already painted into the level art.

enum Behaviour { STEADY, FLICKERING, FAILING }

@export var behaviour := Behaviour.STEADY
@export var bulbs := PackedVector2Array([Vector2(-17, 0), Vector2(17, 0)]):
	set(v):
		bulbs = v
		queue_redraw()
## Distance from the bulbs down to the ground.
@export var post_height := 132.0:
	set(v):
		post_height = v
		queue_redraw()
@export var draw_post := true:
	set(v):
		draw_post = v
		queue_redraw()
@export var light_color := Color(1.0, 0.76, 0.45)
@export_range(0, 20) var moth_count := 7
@export var hum := true

## Current brightness 0..1 (read by rain and fog).
var intensity := 1.0

var _target := 1.0
var _timer := 0.0
var _off_time := 0.0
var _light: ColorRect
var _moths: MothSwarm
var _buzz: AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("lamps")
	if Engine.is_editor_hint():
		return
	_light = ColorRect.new()
	_light.z_as_relative = false
	_light.z_index = Layers.LAMP_LIGHT
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://elements/street_lamp/lamp_light.gdshader")
	_light.material = mat
	add_child(_light)
	_layout_light()
	_moths = MothSwarm.new()
	_moths.lamp = self
	_moths.count = moth_count
	add_child(_moths)
	if hum:
		_buzz = AudioStreamPlayer2D.new()
		_buzz.stream = SoundBank.lamp_buzz()
		_buzz.max_distance = 700.0
		_buzz.volume_db = -14.0
		add_child(_buzz)
		_buzz.play()


func _layout_light() -> void:
	var left := 0.0
	var right := 0.0
	for b in bulbs:
		left = minf(left, b.x)
		right = maxf(right, b.x)
	var pos := Vector2(left - 120.0, -45.0)
	var size := Vector2(right - left + 240.0, post_height + 70.0)
	_light.position = pos
	_light.size = size
	var mat := _light.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("ground_y", post_height - pos.y)
	mat.set_shader_parameter("light_color", light_color)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_behaviour(delta)
	var mat := _light.material as ShaderMaterial
	var data: Array[Vector4] = []
	for i in 4:
		if i < bulbs.size():
			var p := bulbs[i] - _light.position
			data.append(Vector4(p.x, p.y, intensity, 1.0))
		else:
			data.append(Vector4.ZERO)
	mat.set_shader_parameter("bulbs", data)
	mat.set_shader_parameter("world_x", global_position.x)
	mat.set_shader_parameter("fog", 0.5 + 0.5 * clampf(Weather.storm, 0.0, 1.0))
	if _buzz:
		_buzz.volume_db = linear_to_db(maxf(intensity, 0.001)) - 14.0
	queue_redraw()


func _update_behaviour(delta: float) -> void:
	match behaviour:
		Behaviour.STEADY:
			intensity = 0.93 + 0.07 * sin(Weather.time * 37.0) * sin(Weather.time * 5.3)
		Behaviour.FLICKERING:
			_timer -= delta
			if _timer <= 0.0:
				_target = randf_range(0.0, 0.25) if randf() < 0.14 else randf_range(0.75, 1.05)
				_timer = randf_range(0.03, 0.14) if _target < 0.5 else randf_range(0.05, 1.1)
			intensity += (_target - intensity) * minf(1.0, delta * 40.0)
		Behaviour.FAILING:
			if _off_time > 0.0:
				_off_time -= delta
				if _off_time < 0.35:
					intensity = randf_range(0.6, 1.0) if randf() < 0.5 else 0.0
				else:
					intensity = 0.7 if randf() < 0.03 else 0.0
			else:
				intensity = 0.97 + 0.03 * randf()
				if randf() < delta / 9.0:
					_off_time = randf_range(1.2, 3.5)


## Bulb positions and brightness in world space, for effects that react to lamp light.
func get_light_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b in bulbs:
		var g := global_transform * b
		out.append(Vector3(g.x, g.y, intensity))
	return out


## All lit bulbs near a world rectangle (used by rain and fog shaders, max 6).
static func lights_near(rect: Rect2) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var tree := Engine.get_main_loop() as SceneTree
	for lamp in tree.get_nodes_in_group("lamps"):
		for p in lamp.get_light_points():
			if out.size() < 6 and p.x > rect.position.x - 200.0 and p.x < rect.end.x + 200.0:
				out.append(p)
	while out.size() < 6:
		out.append(Vector3(-9999, -9999, 0))
	return out


func _draw() -> void:
	var glow := light_color.lerp(Color.BLACK, 1.0 - clampf(intensity, 0.0, 1.0))
	if draw_post:
		draw_rect(Rect2(-2.0, -6.0, 4.0, post_height + 8.0), Color.BLACK)
		draw_rect(Rect2(-4.0, post_height - 18.0, 8.0, 18.0), Color.BLACK)
		for b in bulbs:
			var mid := Vector2(b.x * 0.5, -16.0)
			draw_polyline(PackedVector2Array([Vector2(0, -4), mid, b + Vector2(0, -9)]), Color.BLACK, 2.0)
			draw_colored_polygon(PackedVector2Array([b + Vector2(-6, -3), b + Vector2(6, -3), b + Vector2(3, -10), b + Vector2(-3, -10)]), Color.BLACK)
	for b in bulbs:
		draw_circle(b, 4.0, glow)
