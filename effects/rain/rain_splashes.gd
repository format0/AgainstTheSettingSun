@icon("res://effects/effect_icon.svg")
class_name RainSplashes
extends Node2D
## Tiny droplets bouncing up where rain hits the ground, the tops of SolidBlocks and
## SwingingBeams, and the player's hat. Other nodes can make splashes too:
## get_tree().call_group("splash_emitters", "burst", position, count, power)

@export var rate_per_storm := 300.0
@export var max_particles := 1800
@export var color := Color(0.86, 0.80, 0.74)

var _p: Array[Dictionary] = []
var _edges: Array = []
var _edge_timer := 0.0


func _ready() -> void:
	add_to_group("effects")
	add_to_group("splash_emitters")
	z_as_relative = false
	z_index = Layers.SPLASHES


func burst(pos: Vector2, count: int, power: float, size: float = 1.0) -> void:
	for i in count:
		if _p.size() >= max_particles:
			return
		var life := randf_range(0.16, 0.34)
		_p.append({"pos": pos, "vel": Vector2(randf_range(-60, 45) - Weather.wind * 40.0, -randf_range(50, 150) * power),
			"life": life, "max": life, "size": randf_range(0.9, 1.6) * size})


func _process(delta: float) -> void:
	var view := GameCamera.view_rect
	var k := Weather.storm * delta
	var ground := Level.current.ground_y if Level.current else 635.0
	var ground_hit := func():
		var d := randf()
		burst(Vector2(view.position.x + randf() * view.size.x, ground + 2.0 + d * d * 46.0), 2 + randi() % 2, 0.6 + d * 0.6, 0.7 + d * 0.9)
	_emit(rate_per_storm * k, ground_hit)
	_edge_timer -= delta
	if _edge_timer <= 0.0:
		_edge_timer = 0.25
		_edges.clear()
		for n in get_tree().get_nodes_in_group("rain_surfaces"):
			if n.has_method("get_rain_edges"):
				_edges.append_array(n.get_rain_edges())
	for e in _edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		if maxf(a.x, b.x) < view.position.x or minf(a.x, b.x) > view.end.x or a.y >= ground - 1.0:
			continue
		_emit(absf(b.x - a.x) * 0.9 * k, func(): burst(a.lerp(b, randf()), 2, 0.7, 0.9))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_emit(9.0 * k, func(): burst(player.global_position + Vector2(randf_range(-9, 9), -47), 2, 0.55, 0.8))
	for p in _p:
		var v: Vector2 = p.vel
		v.y += 900.0 * delta
		p.vel = v
		p.pos += v * delta
		p.life -= delta
	_p.assign(_p.filter(func(p): return p.life > 0.0))
	queue_redraw()


func _emit(expected: float, spawn: Callable) -> void:
	var n := expected
	while n > 0.0:
		if randf() < n:
			spawn.call()
		n -= 1.0


func _draw() -> void:
	for p in _p:
		var s: float = p.size
		var c := color
		c.a = 0.55 * p.life / p.max
		draw_rect(Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), c)
