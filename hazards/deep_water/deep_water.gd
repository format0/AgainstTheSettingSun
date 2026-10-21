@tool
@icon("res://hazards/deep_water/deep_water_icon.svg")
class_name DeepWater
extends Node2D
## Deep, dark water: a pond, a river, a flooded pit. The surface mirrors the sky and catches
## the rain. Whoever falls in drowns (enemies too). Crates, drums and logs float and drift
## with the `current`. The node's position is the top-left corner at the surface.

@export var size := Vector2(300, 160):
	set(v):
		size = v
		_layout()
## Horizontal drift for floating things, in pixels per second.
@export var current := 0.0
## How much of the sky it mirrors.
@export_range(0.0, 1.0) var reflection := 0.55

var _rect: ColorRect
var _mat: ShaderMaterial
var _inside := {}


func _ready() -> void:
	add_to_group("water")
	z_index = Layers.WATER
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://hazards/deep_water/water.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_layout()


func _layout() -> void:
	if _rect:
		_rect.position = Vector2(0, -6)
		_rect.size = size + Vector2(0, 6)
		_mat.set_shader_parameter("rect_size", _rect.size)
	queue_redraw()


## The water at a world position (below the surface), or null.
static func find_at(world_pos: Vector2) -> DeepWater:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("water"):
		var w := n as DeepWater
		var local := world_pos - w.global_position
		if local.x >= 0.0 and local.x <= w.size.x and local.y > -4.0 and local.y < w.size.y:
			return w
	return null


## World y of the (wavy) surface at a world x.
func surface_y(world_x: float) -> float:
	# same waves as the shader (whose rect starts 6 px above the node, surface 3 px into it)
	var wind := Weather.wind
	return global_position.y - 3.0 + sin(world_x * 0.045 + Weather.time * 1.8) * (0.6 + wind * 1.2) \
		+ sin(world_x * 0.12 - Weather.time * 2.9) * (0.3 + wind * 0.6)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var view := GameCamera.view_rect
	_mat.set_shader_parameter("view_size", view.size)
	_mat.set_shader_parameter("weather_time", Weather.time)
	_mat.set_shader_parameter("world_x", global_position.x)
	_mat.set_shader_parameter("wind", Weather.wind)
	_mat.set_shader_parameter("storm", Weather.storm)
	_mat.set_shader_parameter("light", Daylight.light())
	_mat.set_shader_parameter("reflect", reflection * (0.3 + 0.7 * Daylight.light()))
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		_check_body(p, p.global_position, p.velocity.y)
		if not p.dead and _inside.get(p, false) and p.global_position.y > surface_y(p.global_position.x) + 14.0:
			p.die("drowned")
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead:
			_check_body(en, en.global_position, en.velocity.y)
			if _inside.get(en, false) and en.global_position.y > surface_y(en.global_position.x) + 10.0:
				en.drown()


func _check_body(body: Node2D, pos: Vector2, vy: float) -> void:
	var local := pos - global_position
	var inside := local.x > 0.0 and local.x < size.x and local.y > -2.0 and local.y < size.y + 40.0
	if inside and not _inside.get(body, false):
		get_tree().call_group("splash_emitters", "burst", Vector2(pos.x, surface_y(pos.x)), 26, 1.0 + absf(vy) / 400.0, 1.4)
		var s := AudioStreamPlayer2D.new()
		s.stream = SoundBank.splash()
		s.max_distance = 1000.0
		add_child(s)
		s.global_position = pos
		s.play()
		s.finished.connect(s.queue_free)
	_inside[body] = inside


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.12, 0.85))
		draw_line(Vector2.ZERO, Vector2(size.x, 0), Color(0.6, 0.8, 1.0, 0.8), 1.5)
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), DrawKit.EDITOR_HAZARD, "deep water (drowns)")
