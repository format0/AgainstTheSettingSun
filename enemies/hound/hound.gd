@tool
@icon("res://enemies/hound/hound_icon.svg")
class_name Hound
extends Enemy
## A starved, long-legged hound with a narrow skull and a ribcage you could count. It hunts
## and it is faster than you: break its line of sight, hide, or put something between you
## that it can't cross.


func _init() -> void:
	hunts = true
	body_size = Vector2(46, 36)
	eye_height = 30.0
	walk_speed = 42.0
	chase_speed = 150.0
	reaction_time = 0.5
	sight_range = 300.0


func _draw_body(o: Vector2, ink: Color) -> void:
	var c := ink
	var final := ink == Color.BLACK
	var t := Weather.time
	var fall := clampf(_death_t * 2.0, 0.0, 1.0)
	draw_set_transform(o + Vector2(0, -fall * 2.0), facing * fall * PI * 0.5, Vector2(facing, 1.0))
	var chase := 1.0 if state == State.CHASE else 0.0
	var ph := stride * PI * (1.0 + chase * 0.3)
	var bound := sin(ph * 2.0) * chase * 3.0
	var hip := Vector2(-16, -26 + bound * 0.5)
	var chest := Vector2(14, -27 - bound * 0.5 - alertness * 2.0)
	# legs: a trot when walking, a bounding gallop when running
	for i in 4:
		var front := i >= 2
		var base := chest if front else hip
		var p := ph + (0.0 if i % 2 == 0 else PI) + (PI * 0.5 if front and chase < 0.5 else 0.0)
		if chase > 0.5:
			p = ph + (0.0 if front else PI * 0.8) + (i % 2) * 0.3
		var still := state == State.LOOK or state == State.SEARCH or state == State.ALERT
		var foot := Vector2(base.x + sin(p) * (7.0 + chase * 9.0), -maxf(0.0, cos(p)) * (4.0 + chase * 6.0))
		if still:
			foot = Vector2(base.x + (i % 2) * 4.0 - 2.0, 0)
		var knee := base.lerp(foot, 0.45) + (Vector2(4, -2) if front else Vector2(-6, -1))
		var hock := base.lerp(foot, 0.8) + (Vector2(-1, 0) if front else Vector2(-4, -1))
		var col := c if i % 2 == 0 else Color(c, c.a * 0.9)
		DrawKit.limb(self, base, knee, 5.0, 2.6, col)
		DrawKit.limb(self, knee, hock, 2.4, 1.8, col)
		DrawKit.limb(self, hock, foot, 1.8, 1.6, col)
	# body: deep chest, tucked belly, spine
	var body := PackedVector2Array([hip + Vector2(-6, -3), hip.lerp(chest, 0.5) + Vector2(0, -6), chest + Vector2(4, -6), chest + Vector2(7, 2),
		chest + Vector2(0, 10), hip.lerp(chest, 0.55) + Vector2(0, 2), hip + Vector2(2, 3)])
	draw_colored_polygon(body, c)
	# ribs showing through on the outline
	for k in 4:
		var q := chest + Vector2(-3.0 - k * 4.0, 9.0 - k * 2.2)
		draw_circle(q, 1.4, c)
	# tail, low and thin
	var tail_sway := sin(t * 3.0) * 2.0 + chase * 6.0
	draw_polyline(PackedVector2Array([hip + Vector2(-6, -1), hip + Vector2(-14, 4 - tail_sway * 0.3), hip + Vector2(-20, 10 - tail_sway)]), c, 2.0)
	# neck and long skull, low when sniffing, high when alert
	var sniff := (sin(t * 5.0) * 2.0 if state == State.SEARCH else 0.0)
	var neck_a := -0.35 - alertness * 0.4 + (0.5 if state == State.PATROL or state == State.RETURN else 0.0) + chase * 0.25
	var head := chest + Vector2(4, -4) + Vector2.from_angle(neck_a) * 14.0 + Vector2(0, sniff)
	DrawKit.limb(self, chest + Vector2(4, -4), head, 6.0, 4.0, c)
	var snout := head + Vector2.from_angle(neck_a + 0.5) * 13.0
	DrawKit.limb(self, head, snout, 5.5, 2.4, c)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-2, -2), head + Vector2(-5, -9), head + Vector2(1, -3)]), c)
	if state == State.ATTACK or (chase > 0.5 and sin(t * 9.0) > 0.0):
		draw_line(head + Vector2(2, 2), snout + Vector2(1, 4), c, 1.6)
	draw_set_transform(Vector2.ZERO)
	if not final:
		return
	if fall < 0.5:
		var e := head + Vector2.from_angle(neck_a + 0.5) * 3.0 + Vector2(0, -2)
		draw_eyes(Vector2(e.x * facing, e.y), 0.0)
