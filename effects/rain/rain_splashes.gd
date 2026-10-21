@icon("res://effects/effect_icon.svg")
class_name RainSplashes
extends Node2D
## Tiny droplets bouncing up where rain hits the ground, the tops of SolidBlocks and
## SwingingBeams, and the player's hat. Water gathers at the ends of edges and drips down.
## Other nodes can make splashes too:
## get_tree().call_group("splash_emitters", "burst", position, count, power)

@export var rate_per_storm := 300.0
@export var max_particles := 1800
@export var color := Color(0.86, 0.80, 0.74)

var _p: Array[Dictionary] = []
var _edges: Array = []
var _edge_timer := 0.0
var _drips: Array[Dictionary] = []


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
	k *= VFX.v("splashes")
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
	_update_drips(delta, view)
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


## Drops that collect at the ends of beams, roofs and ledges, swell, fall and splash.
func _update_drips(delta: float, view: Rect2) -> void:
	if VFX.on("drips") and Weather.storm > 0.05:
		for e in _edges:
			for end in [e[0], e[1]]:
				var p: Vector2 = end
				if p.x < view.position.x or p.x > view.end.x or p.y < view.position.y or p.y > view.end.y:
					continue
				if randf() < delta * 0.5 * minf(Weather.storm, 1.5):
					var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, 6), p + Vector2(0, 700), Layers.BODY_WORLD)
					var hit := get_world_2d().direct_space_state.intersect_ray(q)
					var floor_y: float = hit.position.y if not hit.is_empty() else p.y + 700.0
					_drips.append({"p": p + Vector2(0, 2), "vy": 0.0, "hang": randf_range(0.2, 0.7), "floor": floor_y})
	for d in _drips:
		if d.hang > 0.0:
			d.hang -= delta
		else:
			d.vy += 900.0 * delta
			d.p.y += d.vy * delta
			if d.p.y >= d.floor:
				burst(Vector2(d.p.x, d.floor), 3, 0.5, 0.8)
				d.hang = -99.0
	_drips = _drips.filter(func(d): return d.hang > -50.0)


func _emit(expected: float, spawn: Callable) -> void:
	var n := expected
	while n > 0.0:
		if randf() < n:
			spawn.call()
		n -= 1.0


func _draw() -> void:
	var dc := color
	dc.a = 0.6 * (0.35 + 0.65 * Daylight.light())
	for d in _drips:
		var p: Vector2 = d.p
		if d.hang > 0.0:
			draw_circle(p, 1.2 + (0.7 - d.hang) * 0.8, dc)
		else:
			draw_line(p - Vector2(0, minf(d.vy * 0.012, 6.0)), p, dc, 1.4)
	for p in _p:
		var s: float = p.size
		var c := color
		c.a = 0.55 * p.life / p.max * (0.35 + 0.65 * Daylight.light())
		draw_rect(Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), c)
