@tool
@icon("res://elements/power_line/power_line_icon.svg")
class_name PowerLine
extends Node2D
## Wooden poles with wires that sag and sway in the wind. Crows can perch on the wires.
## The node's position is the foot of the first pole; pole_x lists every pole relative to it.

@export var pole_x := PackedFloat32Array([0, 300, 580, 890, 1190]):
	set(v):
		pole_x = v
		queue_redraw()
@export var pole_height := 196.0:
	set(v):
		pole_height = v
		queue_redraw()
@export var arm_half := 24.0
@export var sag := 26.0


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _wire_sag(span: int, side: int) -> float:
	return sag + sin(Weather.time * 1.6 + span * 1.3 + side) * 2.2 * Weather.wind


## World y of a perching wire (side 0 = left arm, 1 = right arm) at a world x, or NAN if no wire is there.
func perch_y(world_x: float, side: int) -> float:
	var lx := world_x - global_position.x
	var off := arm_half if side == 1 else -arm_half
	for s in pole_x.size() - 1:
		var x0 := pole_x[s] + off
		var x1 := pole_x[s + 1] + off
		if lx >= x0 and lx <= x1:
			var u := (lx - x0) / (x1 - x0)
			return global_position.y - pole_height - 4.0 + 4.0 * _wire_sag(s, side) * u * (1.0 - u)
	return NAN


## A random perch x in world space, at least `min_distance` away from `avoid_x`.
func random_perch_x(avoid_x: float, min_distance: float) -> float:
	for i in 12:
		var s := randi() % maxi(1, pole_x.size() - 1)
		var x := global_position.x + lerpf(pole_x[s] + 35.0, pole_x[s + 1] - 35.0, randf())
		if absf(x - avoid_x) > min_distance:
			return x
	return global_position.x + pole_x[0] + 40.0


func _draw() -> void:
	var top := -pole_height
	for x in pole_x:
		draw_rect(Rect2(x - 2.6, top - 16.0, 5.2, pole_height + 16.0), Color.BLACK)
		draw_rect(Rect2(x - 31.0, top - 2.0, 62.0, 4.0), Color.BLACK)
		draw_rect(Rect2(x - 15.0, top + 6.0, 30.0, 2.5), Color.BLACK)
		for ix in [-25.5, 22.5]:
			draw_rect(Rect2(x + ix, top - 6.0, 3.0, 5.0), Color.BLACK)
		draw_rect(Rect2(x - 1.5, top - 22.0, 3.0, 7.0), Color.BLACK)
	for s in pole_x.size() - 1:
		var a := pole_x[s]
		var b := pole_x[s + 1]
		for side in 2:
			var off := arm_half if side == 1 else -arm_half
			_draw_wire(Vector2(a + off, top - 4.0), Vector2(b + off, top - 4.0), _wire_sag(s, side))
		_draw_wire(Vector2(a, top - 20.0), Vector2(b, top - 20.0), 17.0 + sin(Weather.time * 1.3 + s) * 1.6 * Weather.wind)


func _draw_wire(p0: Vector2, p1: Vector2, wire_sag: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		pts.append(p0.lerp(p1, u) + Vector2(0, 4.0 * wire_sag * u * (1.0 - u)))
	draw_polyline(pts, Color.BLACK, 1.15, true)
