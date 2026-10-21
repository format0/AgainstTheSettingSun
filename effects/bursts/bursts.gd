class_name Bursts
extends Node2D
## Short-lived particles thrown out by events: dust and grit when something heavy lands,
## embers from hot metal, leaves shaken from a falling tree. The Level makes one of each.
## Anyone can call: get_tree().call_group("dust_emitters", "burst", position, count, width)
## (or "ember_emitters" / "leaf_emitters").

enum Kind { DUST, EMBERS, LEAVES }

var kind := Kind.DUST
var _p: Array[Dictionary] = []


static func create(k: Kind) -> Bursts:
	var b := Bursts.new()
	b.kind = k
	b.name = ["Dust", "Embers", "Leaves"][k]
	return b


func _ready() -> void:
	Game.no_occlude(self)
	add_to_group(["dust_emitters", "ember_emitters", "leaf_emitters"][kind])
	z_as_relative = false
	match kind:
		Kind.DUST:
			z_index = Layers.SPLASHES
		Kind.EMBERS:
			z_index = Layers.HAZARD_GLOW
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = mat
		Kind.LEAVES:
			z_index = Layers.CREATURES


func burst(pos: Vector2, count: int, width := 20.0) -> void:
	for i in mini(count, 120):
		var life := 0.0
		var vel := Vector2.ZERO
		var size := 1.0
		var start := pos
		match kind:
			Kind.DUST:
				start = pos + Vector2(randf_range(-0.5, 0.5) * width, randf_range(-3, 0))
				vel = Vector2(randf_range(-60, 60), -randf_range(10, 70))
				life = randf_range(0.6, 1.6)
				size = randf_range(3, 9) if i % 3 != 0 else randf_range(0.8, 1.8)
			Kind.EMBERS:
				vel = Vector2(randf_range(-90, 90), -randf_range(40, 220))
				life = randf_range(0.4, 1.4)
				size = randf_range(0.8, 2.0)
			Kind.LEAVES:
				start = pos + Vector2(randf_range(-0.5, 0.5) * width, randf_range(-30, 10))
				vel = Vector2(randf_range(-80, 80), -randf_range(20, 120))
				life = randf_range(2.0, 4.0)
				size = randf_range(2.5, 4.0)
		_p.append({"pos": start, "vel": vel, "life": life, "max": life, "size": size, "chip": i % 3 == 0, "spin": randf() * TAU})


func _process(delta: float) -> void:
	if _p.is_empty():
		return
	for p in _p:
		var v: Vector2 = p.vel
		match kind:
			Kind.DUST:
				if p.chip:
					v.y += 900.0 * delta
				else:
					v = v * (1.0 - delta * 2.5) + Vector2(-Weather.wind * 40.0, -6.0) * delta
					p.size += delta * 10.0
			Kind.EMBERS:
				v = v * (1.0 - delta * 1.2) + Vector2(-Weather.wind * 80.0, 60.0) * delta
			Kind.LEAVES:
				v = v * (1.0 - delta * 2.0) + Vector2(-Weather.wind * 120.0, 60.0) * delta
				p.spin += delta * 6.0
		p.vel = v
		p.pos += v * delta
		p.life -= delta
	_p = _p.filter(func(p): return p.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for p in _p:
		var k: float = p.life / p.max
		var pos: Vector2 = p.pos
		var s: float = p.size
		match kind:
			Kind.DUST:
				if p.chip:
					draw_rect(Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), Color.BLACK)
				else:
					draw_circle(pos, s, Color(0.42, 0.30, 0.24, 0.22 * k * (0.3 + 0.7 * Daylight.light())))
			Kind.EMBERS:
				draw_circle(pos, s, Color(1.0, 0.55 + 0.3 * k, 0.2, k))
			Kind.LEAVES:
				draw_set_transform(pos, p.spin, Vector2(s, s * 0.5))
				draw_circle(Vector2.ZERO, 1.0, Color.BLACK)
				draw_set_transform(Vector2.ZERO)
