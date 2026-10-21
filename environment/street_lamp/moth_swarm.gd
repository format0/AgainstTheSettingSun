class_name MothSwarm
extends Node2D
## Moths circling a lamp's bulbs. They scatter when the lamp goes dark.

var lamp: StreetLamp
var count := 7
var _moths: Array[Dictionary] = []


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.LAMP_LIGHT + 1
	for i in count:
		_moths.append({
			"bulb": i % maxi(1, lamp.bulbs.size()), "a": randf() * TAU, "r": randf_range(6, 30),
			"speed": randf_range(1.5, 4.5) * (1.0 if randf() < 0.5 else -1.0), "phase": randf() * TAU, "pos": Vector2.ZERO,
		})


func _process(delta: float) -> void:
	var I := lamp.intensity
	for m in _moths:
		var b: Vector2 = lamp.bulbs[m.bulb]
		m.a += m.speed * delta * (0.6 + 0.8 * I)
		var r: float = m.r * (2.2 if I < 0.3 else 1.0) + sin(Weather.time * 3.0 + m.phase) * 4.0
		var target := b + Vector2(cos(m.a) * r - Weather.wind * 4.0, 4.0 + sin(m.a * 1.3) * r * 0.6)
		m.pos += (target - m.pos) * minf(1.0, delta * 8.0) + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
	queue_redraw()


func _draw() -> void:
	for m in _moths:
		var w := 1.6 + sin(Weather.time * 40.0 + m.phase) * 1.2
		var p: Vector2 = m.pos
		draw_rect(Rect2(p.x - w, p.y - 0.7, w * 2.0, 1.4), Color.BLACK)
		draw_rect(Rect2(p.x - 0.5, p.y - 0.5, 1.0, 1.6), Color.BLACK)
