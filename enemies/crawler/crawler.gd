@tool
@icon("res://enemies/crawler/crawler_icon.svg")
class_name Crawler
extends Enemy
## A long, low, many-legged thing with a ridge of spines on its back, feeling its way with
## long feelers. It is blind and just walks its round, back and forth. Jump over it, or
## wait in a corner until it turns.

@export var segments := 7


func _init() -> void:
	hunts = false
	body_size = Vector2(64, 30)
	eye_height = 16.0
	walk_speed = 46.0
	pause_time = 0.8


func _draw_body(o: Vector2, ink: Color) -> void:
	var c := ink
	var t := Weather.time
	var fall := clampf(_death_t * 2.0, 0.0, 1.0)
	draw_set_transform(o + Vector2(0, fall * 4.0), 0.0, Vector2(facing, 1.0 - fall * 0.5))
	var length := body_size.x
	var pts := PackedVector2Array()
	var ph := stride * PI * 1.6
	for i in segments:
		var u := float(i) / (segments - 1)
		var x := lerpf(-length * 0.5, length * 0.5, u)
		var y := -13.0 - sin(u * PI) * 5.0 + sin(ph * 0.5 + u * 4.0) * 1.2
		pts.append(Vector2(x, y))
	# legs, a pair per segment, rippling front to back
	for i in segments:
		var base := pts[i]
		for side in 2:
			var p := ph - i * 0.9 + side * PI
			var foot := Vector2(base.x + sin(p) * 5.0 + (side * 4.0 - 2.0), -maxf(0.0, cos(p)) * 3.0)
			var knee := base.lerp(foot, 0.5) + Vector2(-3.0, -7.0 - side * 2.0)
			var col := c if side == 0 else Color(c, c.a * 0.85)
			draw_polyline(PackedVector2Array([base, knee, foot]), col, 1.6)
	# body segments and spines
	for i in segments:
		var p := pts[i]
		var r := 6.5 + sin(float(i) / (segments - 1) * PI) * 3.5
		DrawKit.ellipse(self, p, Vector2(r * 1.15, r * 0.85), 0.0, c, 12)
		var spine := r + 4.0 + (i % 2) * 4.0 + sin(t * 1.3 + i) * 0.6
		DrawKit.limb(self, p + Vector2(0, -r * 0.6), p + Vector2(-2.5, -spine - r * 0.4), 2.6, 0.6, c)
	# head with feelers that sweep the ground ahead
	var head := pts[segments - 1] + Vector2(7, 1)
	DrawKit.ellipse(self, head, Vector2(7, 5), 0.2, c, 12)
	for k in 2:
		var sweep := sin(t * (4.0 + k) + k * 2.0) * 0.35
		var a := -0.5 + sweep + k * 0.5
		var mid := head + Vector2.from_angle(a) * 10.0
		var tip := mid + Vector2.from_angle(a + 0.6 + sweep) * 12.0
		draw_polyline(PackedVector2Array([head + Vector2(4, 0), mid, tip]), c, 1.0)
	draw_line(head + Vector2(5, 3), head + Vector2(10, 7), c, 1.6)
	# tail
	draw_polyline(PackedVector2Array([pts[0], pts[0] + Vector2(-8, 2), pts[0] + Vector2(-14, -3 + sin(t * 2.0) * 2.0)]), c, 2.2)
	draw_set_transform(Vector2.ZERO)
