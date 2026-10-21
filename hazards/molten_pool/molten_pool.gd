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
@export var light_reach := 110.0:
	set(v):
		light_reach = v
		_layout()
@export var embers := true

var _rect: ColorRect
var _mat: ShaderMaterial
var _glow: ColorRect
var _glow_mat: ShaderMaterial
var _haze: ColorRect
var _haze_mat: ShaderMaterial
var _embers: GPUParticles2D
var _bubbling: AudioStreamPlayer2D
var _steam: Array[Dictionary] = []
var _spark_wait := 1.0


func _ready() -> void:
	Game.no_occlude(self)
	add_to_group("light_sources")
	add_to_group("lamps")
	z_index = Layers.WATER
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
	if Engine.is_editor_hint():
		_layout()
		_editor_preview()
		return
	_haze = ColorRect.new()
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = preload("res://hazards/molten_pool/heat_haze.gdshader")
	_haze.material = _haze_mat
	_haze.z_as_relative = false
	_haze.z_index = Layers.HAZARD_GLOW - 1
	add_child(_haze)
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
	if _haze:
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


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# rain hissing into the hot metal: steam, lit orange from below
	if VFX.on("steam") and randf() < delta * (4.0 + 10.0 * Weather.storm) * size.x / 200.0:
		_steam.append({"p": Vector2(randf() * size.x, -4.0), "r": randf_range(6, 12), "age": 0.0, "life": randf_range(1.8, 3.2), "v": randf_range(18, 34)})
	for s in _steam:
		s.age += delta
		s.r += 9.0 * delta
		s.p += Vector2(-Weather.wind * 30.0 * minf(1.0, s.age), -s.v) * delta
	_steam = _steam.filter(func(s): return s.age < s.life)
	# a bubble bursts and throws sparks
	_spark_wait -= delta
	if _spark_wait <= 0.0:
		_spark_wait = randf_range(0.6, 2.2) * 200.0 / maxf(size.x, 60.0)
		if VFX.on("sparks"):
			get_tree().call_group("ember_emitters", "burst", global_position + Vector2(randf() * size.x, -2), randi_range(4, 12))
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_mat.set_shader_parameter("weather_time", Weather.time)
	_mat.set_shader_parameter("world_x", global_position.x)
	_glow_mat.set_shader_parameter("weather_time", Weather.time)
	_glow_mat.set_shader_parameter("intensity", (1.0 + (1.0 - Daylight.light()) * 0.6) * VFX.v("lamp_glow"))
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
	for s in _steam:
		var k: float = s.age / s.life
		var hot := 1.0 - smoothstep(0.0, 70.0, -s.p.y)
		var col := Color(0.75, 0.62, 0.55).lerp(Color(1.0, 0.55, 0.28), hot)
		col.a = 0.16 * smoothstep(0.0, 0.15, k) * (1.0 - k)
		DrawKit.draw_puff(self, s.p, s.r * 1.6, col)
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(Vector2(0, -light_reach), Vector2(size.x, light_reach)), Color(1, 0.7, 0.3, 0.5), "lit: no hiding")
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), DrawKit.EDITOR_HAZARD, "molten steel")

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": size}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = p.max(Vector2(20, 20))


## The molten steel glowing, still, brighter as the light goes.
func _editor_preview() -> void:
	_mat.set_shader_parameter("weather_time", 30.0)
	_mat.set_shader_parameter("world_x", global_position.x)
	_glow_mat.set_shader_parameter("weather_time", 30.0)
	_glow_mat.set_shader_parameter("intensity", 1.0 + (1.0 - Daylight.light()) * 0.6)
