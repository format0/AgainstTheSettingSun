@tool
@icon("res://elements/windmill/windmill_icon.svg")
class_name Windmill
extends Node2D
## An old farm windmill whose wheel spins faster in the gusts. The node's position is the tower's foot.

@export var tower_height := 159.0:
	set(v):
		tower_height = v
		queue_redraw()
@export var wheel_radius := 33.0
@export var blades := 18

var _angle := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_angle += (1.0 + Weather.wind * 4.2 * (0.6 + 0.6 * Weather.gust)) * delta
	queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var top := -tower_height
	var hub := Vector2(0, top - 12.0)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(34.0 * s, 0), Vector2(6.0 * s, top), c, 2.2)
		draw_line(Vector2(12.0 * s, 0), Vector2(3.0 * s, top), c, 2.2)
	var y := 0.0
	while y > top + 10.0:
		var k0 := -y / tower_height
		var k1 := minf(1.0, (-y + 32.0) / tower_height)
		var w0 := 34.0 - 28.0 * k0
		var w1 := 34.0 - 28.0 * k1
		draw_line(Vector2(-w0, y), Vector2(w1, y - 32.0), c, 2.0)
		draw_line(Vector2(w0, y), Vector2(-w1, y - 32.0), c, 2.0)
		y -= 32.0
	draw_rect(Rect2(-14, top - 3, 28, 4), c)
	# tail vane points downwind (to the left)
	draw_colored_polygon(PackedVector2Array([hub, hub + Vector2(-62, -3), hub + Vector2(-62, 2)]), c)
	draw_colored_polygon(PackedVector2Array([hub + Vector2(-52, -14), hub + Vector2(-70, -16), hub + Vector2(-70, 14), hub + Vector2(-52, 8)]), c)
	for i in blades:
		var a := _angle + i * TAU / blades
		var b := a + 0.17
		draw_colored_polygon(PackedVector2Array([
			hub + Vector2.from_angle(a) * 7.0, hub + Vector2.from_angle(a) * wheel_radius,
			hub + Vector2.from_angle(b) * wheel_radius, hub + Vector2.from_angle(a + 0.05) * 7.0]), c)
	draw_circle(hub, 5.0, c)
	draw_arc(hub, 22.0, 0, TAU, 40, c, 1.6)
	draw_arc(hub, wheel_radius, 0, TAU, 48, c, 1.6)
