@icon("res://creatures/bats/bats_icon.svg")
class_name Bats
extends Node2D
## Bats come out when the sun is low and flit across the sky in twos and threes, jinking
## left and right the way bats do. Put one anywhere in a level; it follows the view.

## How far the sun must have set before the first bats appear (0..1).
@export_range(0.0, 1.0) var starts_at := 0.4
@export var max_bats := 7

var _bats: Array[Dictionary] = []
var _wait := 3.0


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.CREATURES


func _process(delta: float) -> void:
	var view := GameCamera.view_rect
	var dusk := Daylight.progress - starts_at
	_wait -= delta
	if VFX.on("bats") and dusk > 0.0 and _wait <= 0.0 and _bats.size() < max_bats:
		_wait = randf_range(4.0, 12.0) / (1.0 + dusk * 4.0)
		var from_left := randf() < 0.5
		var y := view.position.y + randf_range(80, view.size.y * 0.55)
		for i in randi_range(1, 3):
			var x := view.position.x - 20.0 if from_left else view.end.x + 20.0
			_bats.append({"p": Vector2(x - i * 30.0 * (1 if from_left else -1), y + randf_range(-25, 25)),
				"v": Vector2((1.0 if from_left else -1.0) * randf_range(110, 170), randf_range(-20, 20)),
				"jink": 0.0, "phase": randf() * TAU, "size": randf_range(0.8, 1.2)})
	for b in _bats:
		b.jink -= delta
		if b.jink <= 0.0:
			# a sudden turn after a moth
			b.jink = randf_range(0.12, 0.45)
			b.v += Vector2(randf_range(-60, 60), randf_range(-90, 90))
			b.v.y = clampf(b.v.y, -110.0, 110.0)
		b.v.x += -Weather.wind * 30.0 * delta
		b.p += b.v * delta
		b.phase += delta * 22.0
	_bats = _bats.filter(func(b): return b.p.x > view.position.x - 120.0 and b.p.x < view.end.x + 120.0 and b.p.y > view.position.y - 100.0)
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	for b in _bats:
		var p: Vector2 = b.p
		var s: float = b.size
		var flap := sin(b.phase)
		var dir := signf(b.v.x)
		DrawKit.ellipse(self, p, Vector2(3.0, 1.8) * s, 0.0, c, 8)
		for side: float in [-1.0, 1.0]:
			var tip := p + Vector2(side * 9.0 * s, -flap * 6.0 * s)
			var elbow := p + Vector2(side * 5.0 * s, -flap * 3.5 * s - 1.5)
			# two triangles, so a wing seen edge-on never fails to draw
			var root := p + Vector2(side * 1.5, -1)
			var trail := p + Vector2(side * 6.0 * s, 1.5 - flap * 2.0)
			draw_primitive(PackedVector2Array([root, elbow, tip]), PackedColorArray([c, c, c]), PackedVector2Array())
			draw_primitive(PackedVector2Array([root, tip, trail]), PackedColorArray([c, c, c]), PackedVector2Array())
		draw_circle(p + Vector2(dir * 2.8 * s, -1.2), 1.4 * s, c)
