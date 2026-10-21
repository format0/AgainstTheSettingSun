class_name WindowRoom
extends Node2D
## The dark room on the title screen: a tall window with its bars, a sheer curtain and a heavy
## drape, and on the sill a cat watching the rain, a candle and a vase of dried grasses.
## Everything is drawn in screen coordinates (the node sits where the camera is). The glass
## itself is a child with the rain shader.

const OPENING := Rect2(170, 34, 1026, 556)
## The candle and the vase are drawn this much larger than their sketches.
const PROP_SCALE := 1.45
## Where the cat sits on the sill, and how big it is (about a quarter of the window's height).
const CAT_SEAT := Vector2(505, 586)
const CAT_HEIGHT := 150.0

var show_cat := true
var show_vase := true

var glass: ColorRect
var _glass_mat: ShaderMaterial
var _glow: Node2D
var _puff: Texture2D
var _flame := 1.0
var _flinch := 0.0
var _ear_twitch := 0.0
var _look := 0.0
var _look_target := 0.0
var _look_wait := 3.0
var _stems: Array[Vector3] = []
var _curtain_seed := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 70
	add_to_group("lightning_listeners")
	_puff = DrawKit.puff_texture()
	glass = ColorRect.new()
	glass.position = OPENING.position
	glass.size = OPENING.size
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.z_index = -5
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = preload("res://title/rain_glass.gdshader")
	_glass_mat.set_shader_parameter("rect_size", OPENING.size)
	glass.material = _glass_mat
	add_child(glass)
	Game.no_occlude(glass)
	# the candle's light is drawn additively over the room
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.z_index = 2
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	Game.no_occlude(_glow)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 6:
		_stems.append(Vector3(rng.randf_range(-6, 6), rng.randf_range(60, 95), rng.randf() * TAU))


func set_glass(rain: float, focus: float, time: float) -> void:
	_glass_mat.set_shader_parameter("rain", rain)
	_glass_mat.set_shader_parameter("focus", focus)
	_glass_mat.set_shader_parameter("time", time)


func on_lightning(_x: float, strength: float) -> void:
	_flinch = maxf(_flinch, strength)


func _process(delta: float) -> void:
	_flame = 0.85 + 0.1 * sin(Weather.time * 9.0) * sin(Weather.time * 4.3) + randf() * 0.06
	_flinch = move_toward(_flinch, 0.0, delta * 0.8)
	_ear_twitch = move_toward(_ear_twitch, 0.0, delta * 6.0)
	if randf() < delta * 0.25:
		_ear_twitch = 1.0
	_look_wait -= delta
	if _look_wait <= 0.0:
		_look_wait = randf_range(2.5, 7.0)
		_look_target = randf_range(-1.0, 1.0)
	_look = lerpf(_look, _look_target, 1.0 - exp(-delta * 2.0))
	queue_redraw()
	_glow.queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var o := OPENING
	var t := Weather.time
	# the room around the window
	draw_rect(Rect2(-200, -200, 1766, o.position.y + 200), c)
	draw_rect(Rect2(-200, o.end.y, 1766, 600), c)
	draw_rect(Rect2(-200, o.position.y, o.position.x + 200, o.size.y), c)
	draw_rect(Rect2(o.end.x, o.position.y, 600, o.size.y), c)
	# the frame: a casing with a moulded inner edge, a centre post, a transom and glazing bars
	draw_rect(Rect2(o.position, Vector2(o.size.x, 12)), c)
	draw_rect(Rect2(o.position, Vector2(12, o.size.y)), c)
	draw_rect(Rect2(o.end.x - 12, o.position.y, 12, o.size.y), c)
	for k in 3:
		draw_rect(Rect2(o.position + Vector2(12 + k * 2, 12 + k * 2), Vector2(o.size.x - 24 - k * 4, 1.2)), c)
	var mid := o.get_center().x
	var transom := o.position.y + 140.0
	draw_rect(Rect2(mid - 8, o.position.y, 16, o.size.y), c)
	draw_rect(Rect2(o.position.x, transom - 7, o.size.x, 14), c)
	for x: float in [o.position.x + o.size.x * 0.25, o.position.x + o.size.x * 0.75]:
		draw_rect(Rect2(x - 2.5, o.position.y, 5, o.size.y), c)
	var lower_mid := (transom + o.end.y) * 0.5
	draw_rect(Rect2(o.position.x, lower_mid - 2.5, o.size.x, 5), c)
	# the casement frames inside the outer frame, and the latch
	draw_rect(Rect2(mid - 14, transom, 6, o.end.y - transom), c)
	draw_rect(Rect2(mid + 8, transom, 6, o.end.y - transom), c)
	var latch := Vector2(mid + 8, transom + 150)
	draw_rect(Rect2(latch + Vector2(-2, -10), Vector2(10, 20)), c)
	draw_colored_polygon(PackedVector2Array([latch + Vector2(6, -3), latch + Vector2(30, 2), latch + Vector2(31, 5), latch + Vector2(6, 3)]), c)
	# the sill, a little proud of the wall
	draw_rect(Rect2(o.position.x - 36, o.end.y - 4, o.size.x + 72, 18), c)
	_draw_curtains(c, t)
	if show_vase:
		var vb := Vector2(OPENING.end.x - 110, OPENING.end.y - 4)
		draw_set_transform(vb * (1.0 - PROP_SCALE), 0.0, Vector2.ONE * PROP_SCALE)
		_draw_vase(c, t)
	var cb := Vector2(OPENING.end.x - 190, OPENING.end.y - 4)
	draw_set_transform(cb * (1.0 - PROP_SCALE), 0.0, Vector2.ONE * PROP_SCALE)
	_draw_candle(c)
	draw_set_transform(Vector2.ZERO)
	if show_cat:
		_draw_cat(c, t)


func _draw_curtains(c: Color, t: float) -> void:
	var o := OPENING
	# the rod and its rings
	draw_rect(Rect2(o.position.x - 60, o.position.y - 14, o.size.x + 120, 5), c)
	draw_circle(Vector2(o.position.x - 60, o.position.y - 11.5), 6, c)
	draw_circle(Vector2(o.end.x + 60, o.position.y - 11.5), 6, c)
	# a sheer curtain on the left, breathing in the draught: the world shows through it
	var sway := sin(t * 0.6) * 4.0 + sin(t * 1.7) * 1.5
	var pts := PackedVector2Array()
	var top := o.position.y - 10
	var bottom := o.end.y - 4
	var left := o.position.x - 50
	pts.append(Vector2(left, top))
	var n := 18
	for i in n + 1:
		var u := float(i) / n
		var x := lerpf(o.position.x + 165, o.position.x + 120, u * u) + sin(u * 9.0 + t * 0.8) * 3.0 + sway * u
		pts.append(Vector2(x, lerpf(top, bottom, u)))
	pts.append(Vector2(left, bottom))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	for k in 5:
		var fx := o.position.x - 30 + k * 32.0
		var fold := PackedVector2Array()
		for i in 11:
			var u := float(i) / 10.0
			fold.append(Vector2(fx + sin(u * 6.0 + k + t * 0.7) * 3.0 + sway * u * (0.4 + k * 0.12) - u * k * 4.0, lerpf(top, bottom, u)))
		draw_polyline(fold, Color(0, 0, 0, 0.35), 9.0)
	# a heavy drape on the right, hardly moving
	var drape := PackedVector2Array([Vector2(o.end.x + 70, top), Vector2(o.end.x - 70, top)])
	for i in 13:
		var u := float(i) / 12.0
		drape.append(Vector2(o.end.x - 70 + 40 * u * u + sin(u * 5.0 + 1.0) * 6.0 + sin(t * 0.4) * 1.5 * u, lerpf(top, bottom + 10, u)))
	drape.append(Vector2(o.end.x + 70, bottom + 10))
	draw_colored_polygon(drape, c)
	# the tie-back gathering it
	draw_rect(Rect2(o.end.x - 46, o.position.y + 300, 40, 7), c)


func _draw_vase(c: Color, t: float) -> void:
	var base := Vector2(OPENING.end.x - 110, OPENING.end.y - 4)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-9, 0), base + Vector2(-11, -14), base + Vector2(-7, -24), base + Vector2(-4, -30),
		base + Vector2(4, -30), base + Vector2(7, -24), base + Vector2(11, -14), base + Vector2(9, 0)]), c)
	for s in _stems:
		var stem_base := base + Vector2(s.x * 0.4, -28)
		var lean := s.x * 0.06 + sin(t * 0.5 + s.z) * 0.02
		var tip := stem_base + Vector2(sin(lean) * s.y, -cos(lean) * s.y)
		draw_line(stem_base, tip, c, 1.1)
		DrawKit.ellipse(self, tip + Vector2(sin(lean) * 5.0, -5), Vector2(1.8, 6.0), lean, c, 8)


func _candle_tip() -> Vector2:
	return Vector2(OPENING.end.x - 190, OPENING.end.y - 4 - 66 * PROP_SCALE)


func _draw_candle(c: Color) -> void:
	var base := Vector2(OPENING.end.x - 190, OPENING.end.y - 4)
	# a brass holder with a drip tray and a ring handle, a tall candle with runs of wax
	draw_colored_polygon(PackedVector2Array([base + Vector2(-22, 0), base + Vector2(-19, -5), base + Vector2(19, -5), base + Vector2(22, 0)]), c)
	draw_rect(Rect2(base + Vector2(-4, -12), Vector2(8, 8)), c)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-9, -12), base + Vector2(9, -12), base + Vector2(7, -16), base + Vector2(-7, -16)]), c)
	draw_arc(base + Vector2(26, -6), 6.0, -PI * 0.5, PI * 0.9, 12, c, 2.4)
	draw_rect(Rect2(base + Vector2(-6, -64), Vector2(12, 50)), c)
	draw_colored_polygon(PackedVector2Array([base + Vector2(5, -62), base + Vector2(8.5, -56), base + Vector2(7.5, -40), base + Vector2(5, -44)]), c)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -60), base + Vector2(-9, -52), base + Vector2(-8, -46), base + Vector2(-6, -50)]), c)
	draw_line(base + Vector2(0, -64), base + Vector2(0.6, -68), c, 1.3)


func _draw_cat(c: Color, t: float) -> void:
	# a cat sitting on the sill with its back to us, watching the rain: broad haunches,
	# narrow shoulders, a round head with fur at the cheeks, ears that turn and flatten
	var k := CAT_HEIGHT / 150.0
	var b := CAT_SEAT
	var crouch := _flinch * 6.0
	var breathe := 1.0 + 0.012 * sin(t * 1.6)
	# the body, one side mirrored onto the other through a smooth curve
	var side := [Vector2(0, 0), Vector2(40, 0), Vector2(46, -8), Vector2(47, -22), Vector2(42, -38), Vector2(33, -54),
		Vector2(27, -70), Vector2(25, -84), Vector2(21, -96), Vector2(14, -104), Vector2(0, -106)]
	var right := _smooth(side, 4)
	var body := PackedVector2Array()
	for i in range(right.size() - 1, -1, -1):
		var p: Vector2 = right[i]
		body.append(b + Vector2(-p.x * breathe, p.y + (crouch if p.y < -40.0 else 0.0)) * k)
	for p: Vector2 in right:
		body.append(b + Vector2(p.x * breathe, p.y + (crouch if p.y < -40.0 else 0.0)) * k)
	draw_colored_polygon(body, c)
	# the head, turning a little now and then; fur sticking out at the cheeks
	var head := b + Vector2(_look * 7.0, -118.0 + crouch * 1.6) * k
	var hp := PackedVector2Array()
	for i in 28:
		var a := float(i) / 28.0 * TAU
		var r := Vector2(27, 23) * k
		var p := Vector2(cos(a) * r.x, sin(a) * r.y)
		if sin(a) > 0.1:
			p.x *= 1.0 + 0.12 * sin(a)        # wider at the jaw
			if absf(cos(a)) > 0.55 and i % 2 == 0:
				p += Vector2(signf(cos(a)) * 3.5, 1.5) * k   # cheek tufts
		hp.append(head + p.rotated(_look * 0.12))
	draw_colored_polygon(hp, c)
	# ears: curved, a tuft at the tip; flattened sideways when the thunder comes
	for s: float in [-1.0, 1.0]:
		var twitch := _ear_twitch * 0.3 if s > 0.0 else 0.0
		var a := -PI * 0.5 + s * (0.32 + _flinch * 1.0) + twitch
		var root := head + Vector2(s * 13.0, -12.0) * k
		var dir := Vector2.from_angle(a)
		var length := (26.0 - _flinch * 9.0) * k
		var tip := root + dir * length
		var across := dir.orthogonal() * s
		var ear := PackedVector2Array([root - across * 11.0 * k, root.lerp(tip, 0.55) - across * 6.5 * k + dir * 1.0, tip,
			root.lerp(tip, 0.6) + across * 3.0 * k, root + across * 7.0 * k])
		draw_colored_polygon(ear, c)
		draw_line(tip, tip + dir * 4.0 * k, c, 1.0)
	# the tail: wrapped along the sill, the tip lifting against the glass and twitching
	var swish := sin(t * 1.1) * 0.5 + sin(t * 2.9) * 0.25
	var tail := PackedVector2Array()
	var widths := PackedFloat32Array()
	var n := 18
	for i in n:
		var u := float(i) / (n - 1)
		var lift := smoothstep(0.55, 1.0, u)
		var p := b + Vector2(34.0 + u * 64.0 - lift * lift * 16.0, -4.0 - lift * 34.0) * k
		p += Vector2(sin(swish * 2.0) * 7.0, -absf(swish) * 3.0) * lift * lift * k
		tail.append(p)
		widths.append(lerpf(13.0, 6.0, u) * k)
	for i in n - 1:
		DrawKit.limb(self, tail[i], tail[i + 1], widths[i], widths[i + 1])
	draw_circle(tail[n - 1], widths[n - 1] * 0.5, c)


## A smooth curve through some points (Catmull-Rom), `steps` points per span.
func _smooth(pts: Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for j in steps:
			var u := float(j) / steps
			var u2 := u * u
			var u3 := u2 * u
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	out.append(pts[pts.size() - 1])
	return out


func _draw_glow() -> void:
	var tip := _candle_tip()
	var f := _flame
	# the flame: a bright core, the tongue swaying in the draught
	var sway := sin(Weather.time * 2.3) * 1.5 + sin(Weather.time * 7.0) * 0.6
	var flame := PackedVector2Array()
	for i in 15:
		var a := float(i) / 14.0 * TAU
		var r := Vector2(4.6, 11.0 * f)
		var p := Vector2(sin(a) * r.x, -cos(a) * r.y)
		if p.y < 0.0:
			p.x *= 1.0 + p.y / (r.y * 1.3)
			p.x += sway * (-p.y / r.y)
		flame.append(tip + Vector2(0, -9) + p)
	_glow.draw_colored_polygon(flame, Color(1.0, 0.6, 0.22, 0.95))
	_glow.draw_circle(tip + Vector2(0, -7), 3.0, Color(1.0, 0.96, 0.8, 1.0))
	# its light: a small halo, a wide warm pool on the sill and the wall below
	for k in 4:
		var r := (26.0 + k * 85.0) * (0.95 + 0.05 * f)
		_glow.draw_texture_rect(_puff, Rect2(tip + Vector2(0, -6 + k * 18.0) - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(1.0, 0.48, 0.16, (0.34 - k * 0.07) * f))
	# the front edge of the sill catches the light either side of the candle
	var sill := OPENING.end.y - 4.0
	for i in 16:
		var u := float(i) / 15.0
		var x := tip.x + (u - 0.5) * 240.0
		var a := exp(-pow((u - 0.5) * 3.5, 2.0)) * 0.3 * f
		_glow.draw_line(Vector2(x, sill + 0.5), Vector2(x + 15.0, sill + 0.5), Color(1.0, 0.55, 0.22, a), 1.2)
