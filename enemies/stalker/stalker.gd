@tool
@icon("res://enemies/stalker/stalker_icon.svg")
class_name Stalker
extends Enemy
## A tall, gaunt thing that walks hunched on legs that bend the wrong way, long arms
## dragging past its knees. It hunts: when it sees you it straightens up, shrieks and
## comes after you with long strides. Hide in the shadow of something black and it loses you.


func _init() -> void:
	hunts = true
	body_size = Vector2(22, 66)
	eye_height = 56.0
	walk_speed = 34.0
	chase_speed = 120.0


func _draw_body(o: Vector2, ink: Color) -> void:
	var c := ink
	var final := ink == Color.BLACK
	var t := Weather.time
	var fall := clampf(_death_t * 2.2, 0.0, 1.0)
	draw_set_transform(o, -facing * fall * PI * 0.48, Vector2(facing, 1.0))
	var chase := 1.0 if state == State.CHASE else 0.0
	var rear := alertness * (1.0 - chase) * 0.6
	var lean := 0.35 + chase * 0.35 - rear * 0.5 + lunge * 0.3
	var breathe := sin(t * 2.2 + get_instance_id()) * 0.8
	var ph := stride * PI
	var step_len := 9.0 + chase * 7.0
	var hip := Vector2(0, -31.0 - absf(sin(ph)) * 1.5 + breathe * 0.2 - rear * 4.0)
	# legs: digitigrade, knees pointing backwards
	for i in 2:
		var p := ph + i * PI
		var foot := Vector2(sin(p) * step_len, -maxf(0.0, cos(p)) * 6.0)
		if state != State.PATROL and state != State.CHASE and state != State.RETURN:
			foot = Vector2((i - 0.5) * 8.0, 0)
		var knee := _ik(hip + Vector2(i * 2.0 - 1.0, 0), foot + Vector2(-3, -4), 17.0, 17.0, 1.0)
		var dark := c
		DrawKit.limb(self, hip, knee, 6.0, 3.6, dark)
		DrawKit.limb(self, knee, foot + Vector2(-3, -4), 3.4, 2.0, dark)
		DrawKit.limb(self, foot + Vector2(-3, -4), foot + Vector2(4, 0), 2.0, 1.4, dark)
	# torso: a curved spine with a hump
	var shoulder := hip + Vector2.from_angle(-PI * 0.5 + lean) * 26.0 + Vector2(0, breathe * 0.3)
	var hump := hip.lerp(shoulder, 0.6) + Vector2(-5.0, -5.0)
	var torso := PackedVector2Array([hip + Vector2(-5, 3), hump + Vector2(-4, -1), shoulder + Vector2(-3, -5), shoulder + Vector2(5, 1), hip.lerp(shoulder, 0.5) + Vector2(5, 2), hip + Vector2(4, 4)])
	draw_colored_polygon(torso, c)
	# vertebrae ridge
	for k in 4:
		var q := hip.lerp(hump, 0.3 + k * 0.25) + Vector2(-4.5, -2.0)
		draw_circle(q, 1.6, c)
	# neck and head, thrust forward
	var look := sin(t * 0.7 + get_instance_id()) * 0.2 if state == State.LOOK or state == State.SEARCH else 0.0
	var head := shoulder + Vector2.from_angle(-0.2 + lean * 0.7 + look) * 11.0
	DrawKit.limb(self, shoulder, head, 4.0, 3.0, c)
	DrawKit.ellipse(self, head + Vector2(2.5, 0), Vector2(6.0, 3.6), 0.25 + lean * 0.3 + look, c, 12)
	draw_colored_polygon(PackedVector2Array([head + Vector2(5, 1), head + Vector2(10, 3 + lunge * 2.0), head + Vector2(5, 3.5)]), c)
	# arms: long, swinging, reaching forward when it hunts
	for i in 2:
		var p := ph + i * PI + PI * 0.5
		var swing := sin(p) * (0.25 + chase * 0.2) * (1.0 - rear)
		var reach := chase * 0.9 + lunge * 1.3 + rear * 0.6
		var arm_a := PI * 0.5 - 0.15 - reach + swing
		var elbow := shoulder + Vector2.from_angle(arm_a) * 17.0
		var hand := elbow + Vector2.from_angle(arm_a + 0.25 - reach * 0.2) * 19.0
		DrawKit.limb(self, shoulder + Vector2(0, 1), elbow, 3.6, 2.6, c)
		DrawKit.limb(self, elbow, hand, 2.6, 1.8, c)
		for f in 3:
			var fa := arm_a + 0.2 + (f - 1) * 0.25
			draw_line(hand, hand + Vector2.from_angle(fa) * (6.0 + f), c, 1.0)
	draw_set_transform(Vector2.ZERO)
	if not final:
		return
	var eye_pos := head + Vector2(4.5, -1.0)
	if fall < 0.5:
		draw_eyes(Vector2(eye_pos.x * facing, eye_pos.y), 2.5)


func _ik(hip: Vector2, foot: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := foot - hip
	var l := clampf(d.length(), 0.01, l1 + l2 - 0.01)
	var a := acos(clampf((l1 * l1 + l * l - l2 * l2) / (2.0 * l1 * l), -1.0, 1.0))
	return hip + Vector2.from_angle(d.angle() + a * bend) * l1
