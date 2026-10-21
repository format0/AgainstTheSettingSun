@tool
@icon("res://environment/hanging_chains/hanging_chains_icon.svg")
class_name HangingChains
extends Node2D
## Chains, hooks and torn cables hanging from above and swinging in the wind, each on its own
## beat. Scenery only. The node's position is the line they hang from; `drops` lists
## x positions and lengths (x, length).

@export var drops := PackedVector2Array([Vector2(0, 120), Vector2(40, 80), Vector2(70, 160)]):
	set(v):
		drops = v
		_reset()
## Hooks at the ends of some chains.
@export var hooks := true

var _angle := PackedFloat32Array()
var _speed := PackedFloat32Array()


func _ready() -> void:
	z_index = Layers.ELEMENTS
	_reset()


func _reset() -> void:
	_angle.resize(drops.size())
	_speed.resize(drops.size())
	for i in drops.size():
		_angle[i] = randf_range(-0.05, 0.05)
		_speed[i] = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for i in drops.size():
		var length := maxf(drops[i].y, 10.0)
		var k := 9.81 * 60.0 / length
		var force := -Weather.wind * 0.9 * (0.3 + Weather.gust_at(global_position.x + drops[i].x)) + sin(Weather.time * 1.7 + i * 1.3) * 0.25 * Weather.wind
		_speed[i] += (-k * sin(_angle[i]) * 0.6 - _speed[i] * 0.4 + force) * delta
		_angle[i] += _speed[i] * delta
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	for i in drops.size():
		var top := Vector2(drops[i].x, 0)
		var a := _angle[i] if i < _angle.size() else 0.0
		var end := top + Vector2.from_angle(PI * 0.5 + a) * drops[i].y
		if i % 3 == 2:
			# a torn cable instead of a chain
			var mid := top.lerp(end, 0.5) + Vector2(sin(Weather.time * 3.0 + i) * 3.0, 0)
			draw_polyline(PackedVector2Array([top, mid, end]), c, 1.6, true)
			draw_line(end, end + Vector2(-3, 5), c, 1.0)
			draw_line(end, end + Vector2(3, 6), c, 1.0)
		else:
			DrawKit.chain(self, top, end, 6.0, 1.7)
			if hooks and i % 2 == 0:
				draw_rect(Rect2(end.x - 3, end.y - 1, 6, 5), c)
				draw_arc(end + Vector2(0, 9), 4.5, -PI * 0.1, PI * 1.2, 10, c, 2.0)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	var r := Rect2(-6, 0, 12, 12)
	for d in drops:
		r = r.expand(Vector2(d.x + 6.0, d.y + 10.0)).expand(Vector2(d.x - 6.0, 0))
	return r


## The end of each chain: drag it to move the chain along and change its length.
func _editor_handles() -> Array[Dictionary]:
	var h: Array[Dictionary] = []
	for i in drops.size():
		h.append({"id": i, "pos": drops[i], "props": ["drops"]})
	return h


func _editor_drag(id: Variant, p: Vector2) -> void:
	var d := drops.duplicate()
	d[id] = Vector2(p.x, maxf(10.0, p.y))
	drops = d
