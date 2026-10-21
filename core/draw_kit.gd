class_name DrawKit
extends RefCounted
## Drawing helpers shared by all the silhouettes: chains, ropes, trusses, tapered limbs,
## jagged outlines and rocks. Everything is drawn in black unless a colour is given.
## Call them from _draw(): DrawKit.chain(self, a, b)

const INK := Color.BLACK

static var _puff: Texture2D


## A soft round puff (steam, smoke, dust), drawn with draw_puff().
static func puff_texture() -> Texture2D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.5))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_puff = t
	return _puff


static func draw_puff(ci: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	ci.draw_texture_rect(puff_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


## A tapered stroke with round ends (arms, legs, branches, pipes).
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w0: float, w1: float, col := INK) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		ci.draw_circle(a, maxf(w0, w1) * 0.5, col)
		return
	var n := d.normalized().orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5]), col)
	ci.draw_circle(a, w0 * 0.5, col)
	ci.draw_circle(b, w1 * 0.5, col)


## A chain of alternating links from a to b. Links facing the viewer are rings, the others flat bars.
static func chain(ci: CanvasItem, a: Vector2, b: Vector2, link := 7.0, width := 2.0, col := INK) -> void:
	var d := b - a
	var length := d.length()
	if length < 1.0:
		return
	var dir := d / length
	var n := dir.orthogonal()
	var count := maxi(1, int(length / link))
	var step := length / count
	for i in count:
		var c := a + dir * (i + 0.5) * step
		if i % 2 == 0:
			var ring := PackedVector2Array()
			for k in 11:
				var t := k * TAU / 10.0
				ring.append(c + dir * cos(t) * step * 0.62 + n * sin(t) * width * 1.25)
			ci.draw_polyline(ring, col, maxf(1.0, width * 0.55), true)
		else:
			ci.draw_line(c - dir * step * 0.62, c + dir * step * 0.62, col, width * 0.8, true)


## A sagging rope or cable.
static func rope(ci: CanvasItem, a: Vector2, b: Vector2, sag := 10.0, width := 1.4, col := INK, segments := 14) -> void:
	ci.draw_polyline(rope_points(a, b, sag, segments), col, width, true)


static func rope_points(a: Vector2, b: Vector2, sag: float, segments := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var u := float(i) / segments
		pts.append(a.lerp(b, u) + Vector2(0, 4.0 * sag * u * (1.0 - u)))
	return pts


## A steel truss between two points: two chords and zig-zag diagonals.
static func truss(ci: CanvasItem, a: Vector2, b: Vector2, depth := 14.0, cell := 16.0, width := 1.6, col := INK) -> void:
	var d := b - a
	var length := d.length()
	if length < 1.0:
		return
	var dir := d / length
	var n := dir.orthogonal() * depth
	ci.draw_line(a, b, col, width * 1.6)
	ci.draw_line(a + n, b + n, col, width * 1.6)
	var count := maxi(1, int(length / cell))
	for i in count:
		var p0 := a + dir * (length * i / count)
		var p1 := a + dir * (length * (i + 1) / count)
		ci.draw_line(p0, p1 + n, col, width)
		ci.draw_line(p0 + n, p0, col, width * 0.8)
	ci.draw_line(b, b + n, col, width * 0.8)


static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, angle := 0.0, col := INK, points := 16) -> void:
	ci.draw_colored_polygon(ellipse_points(center, radii, angle, points), col)


static func ellipse_points(center: Vector2, radii: Vector2, angle := 0.0, points := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var t := i * TAU / points
		pts.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y).rotated(angle))
	return pts


## A rectangle whose edges are slightly broken (old concrete, rotten wood). Deterministic for a seed.
static func rough_rect(rect: Rect2, seed_value: int, amount := 2.0, step := 6.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var pts := PackedVector2Array()
	for side in 4:
		var p0: Vector2 = corners[side]
		var p1: Vector2 = corners[(side + 1) % 4]
		var length := p0.distance_to(p1)
		var n := (p1 - p0).normalized().orthogonal()
		var count := maxi(1, int(length / step))
		for i in count:
			var u := float(i) / count
			var jag := 0.0 if i == 0 else rng.randf_range(-amount, amount * 0.4)
			pts.append(p0.lerp(p1, u) + n * jag)
	return pts


## An irregular rounded blob (rocks, bushes, boulders). Flattened at the bottom when `flat_bottom`.
static func blob(center: Vector2, radius: Vector2, seed_value: int, roughness := 0.18, points := 18, flat_bottom := true) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	var phase := rng.randf() * TAU
	for i in points:
		var t := i * TAU / points
		var r := 1.0 + roughness * (sin(t * 3.0 + phase) * 0.5 + rng.randf_range(-0.5, 0.5))
		var p := Vector2(cos(t) * radius.x * r, sin(t) * radius.y * r)
		if flat_bottom:
			p.y = minf(p.y, radius.y * 0.15)
		pts.append(center + p)
	return pts


## A row of bolt heads sticking out of an edge, so the outline reads as riveted steel.
static func bolts(ci: CanvasItem, a: Vector2, b: Vector2, spacing := 12.0, size := 1.6, col := INK) -> void:
	var length := a.distance_to(b)
	var count := int(length / spacing)
	for i in count + 1:
		ci.draw_circle(a.lerp(b, float(i) / maxf(count, 1)), size, col)


## Hanging weeds or vines from a point, swaying with the wind (pure decoration).
static func vine(ci: CanvasItem, top: Vector2, length: float, phase: float, col := INK, width := 1.2) -> void:
	var pts := PackedVector2Array()
	var sway := -Weather.wind * 6.0 * (0.4 + Weather.gust_at(top.x)) + sin(Weather.time * 1.7 + phase) * 2.0
	for i in 9:
		var u := i / 8.0
		pts.append(top + Vector2(sway * u * u + sin(u * 5.0 + phase) * 1.5, length * u))
	ci.draw_polyline(pts, col, width, true)
	for i in range(2, 9, 2):
		var p := pts[i]
		var s := 1.0 if i % 4 == 0 else -1.0
		ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(3.5 * s + sway * 0.1, 1.5), p + Vector2(1.0 * s, 3.5)]), col)


# ------------------------------------------------------------------ editor markers

## Colours that tell the kinds of things apart in the editor.
const EDITOR_INTERACTIVE := Color(1.0, 0.6, 0.15, 0.9)
const EDITOR_HAZARD := Color(1.0, 0.25, 0.2, 0.9)
const EDITOR_ENEMY := Color(0.75, 0.45, 1.0, 0.9)
const EDITOR_COVER := Color(0.3, 0.9, 0.55, 0.8)
const EDITOR_GAMEPLAY := Color(0.3, 0.85, 1.0, 0.9)


## Outline and caption shown only in the editor.
static func editor_box(ci: CanvasItem, rect: Rect2, col: Color, caption := "") -> void:
	ci.draw_rect(rect, Color(col, col.a * 0.12), true)
	ci.draw_rect(rect, col, false, 1.0)
	if caption != "":
		ci.draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


static func editor_caption(ci: CanvasItem, at: Vector2, col: Color, caption: String) -> void:
	ci.draw_string(ThemeDB.fallback_font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


## Dashed line from a node to the things it drives (levers to doors and so on).
static func editor_link(ci: CanvasItem, from: Vector2, to: Vector2, col: Color) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / maxf(length, 0.001)
	var d := 0.0
	while d < length:
		ci.draw_line(from + dir * d, from + dir * minf(d + 6.0, length), col, 1.0)
		d += 10.0
	ci.draw_circle(to, 3.0, col)
