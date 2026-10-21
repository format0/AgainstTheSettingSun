@tool
@icon("res://cover/water_tower/water_tower_icon.svg")
class_name WaterTower
extends Cover
## An old water tower: a barrel tank with a pointed roof on splayed, cross-braced legs and a
## ladder. Only the tank hides the player (from a catwalk or platform at that height).
## The node's position is the middle between the feet of the legs.

@export var height := 230.0:
	set(v):
		height = v
		queue_redraw()
@export var tank_size := Vector2(62, 96):
	set(v):
		tank_size = v
		queue_redraw()
@export var leg_spread := 70.0:
	set(v):
		leg_spread = v
		queue_redraw()


func _ready() -> void:
	z_index = Layers.COVER


func _tank() -> PackedVector2Array:
	var top := -height
	var w := tank_size.x * 0.5
	var pts := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(w + sin(u * PI) * 4.0, top + tank_size.y * u))
	for i in range(n, -1, -1):
		var u := float(i) / n
		pts.append(Vector2(-w - sin(u * PI) * 4.0, top + tank_size.y * u))
	return pts


func _cover_shapes() -> Array[PackedVector2Array]:
	return [_tank()]


func _draw() -> void:
	var c := Color.BLACK
	var top := -height
	var base := top + tank_size.y
	var w := tank_size.x * 0.5
	draw_colored_polygon(_tank(), c)
	# hoops
	for k in 4:
		var y := top + tank_size.y * (0.15 + k * 0.23)
		draw_rect(Rect2(-w - 5.0, y - 1.5, tank_size.x + 10.0, 3.0), c)
	# roof and finial
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 6, top + 2), Vector2(w + 6, top + 2), Vector2(0, top - 26)]), c)
	draw_line(Vector2(0, top - 26), Vector2(0, top - 36), c, 2.0)
	draw_circle(Vector2(0, top - 37), 2.5, c)
	# legs and bracing
	var legs := [-leg_spread, -leg_spread * 0.35, leg_spread * 0.35, leg_spread]
	var tops := [-w + 4.0, -w * 0.3, w * 0.3, w - 4.0]
	for i in 4:
		draw_line(Vector2(legs[i], 0), Vector2(tops[i], base), c, 3.5 if i % 3 == 0 else 2.2)
	var y := 0.0
	var step := (base) / 4.0
	for k in 4:
		var y0 := y
		var y1 := y + step
		var u0 := y0 / base
		var u1 := y1 / base
		var l0 := lerpf(legs[0], tops[0], u0)
		var r0 := lerpf(legs[3], tops[3], u0)
		var l1 := lerpf(legs[0], tops[0], u1)
		var r1 := lerpf(legs[3], tops[3], u1)
		draw_line(Vector2(l0, y0), Vector2(r1, y1), c, 1.3)
		draw_line(Vector2(r0, y0), Vector2(l1, y1), c, 1.3)
		draw_line(Vector2(l1, y1), Vector2(r1, y1), c, 2.0)
		y = y1
	# ladder
	var lx := w * 0.55
	draw_line(Vector2(lx + 10, 0), Vector2(lx, base), c, 1.4)
	draw_line(Vector2(lx + 18, 0), Vector2(lx + 8, base), c, 1.4)
	var r := 0.0
	while r > base:
		var u := r / base
		draw_line(Vector2(lx + 10 - u * 10, r), Vector2(lx + 18 - u * 10, r), c, 1.2)
		r -= 9.0
	# catwalk ring
	draw_rect(Rect2(-w - 12.0, base - 1.0, tank_size.x + 24.0, 3.0), c)
	for k in 7:
		var rx := lerpf(-w - 11.0, w + 11.0, k / 6.0)
		draw_line(Vector2(rx, base), Vector2(rx, base - 12.0), c, 1.2)
	draw_line(Vector2(-w - 12.0, base - 12.0), Vector2(w + 12.0, base - 12.0), c, 1.4)
	_draw_cover_outline()
