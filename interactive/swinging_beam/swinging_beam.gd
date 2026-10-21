@tool
@icon("res://interactive/swinging_beam/swinging_beam_icon.svg")
class_name SwingingBeam
extends AnimatableBody2D
## Steel beams hanging on chains that swing in the wind like a pendulum; the player can jump
## on them and is carried along. The harder the storm, the wider the swing.
## The node's position is the pivot (where the chain is fixed, can be above the screen).

## Beam rectangles relative to the pivot. Each gets its own collision box.
@export var beams: Array[Rect2] = [Rect2(-80, 300, 160, 22)]:
	set(v):
		beams = v
		_rebuild()
@export_group("Swing")
@export var swing_strength := 1.0
## Seconds for one full swing.
@export var period := 5.5
@export var damping := 0.25
@export_group("Look")
## Weeds and torn cable ends dangling from the beams.
@export var hanging_weeds := true

var _angle := 0.0
var _speed := 0.0
var _creak: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.MACHINERY
	sync_to_physics = true
	add_to_group("rain_surfaces")
	set_meta("surface", "metal")
	_rebuild()
	if not Engine.is_editor_hint():
		_creak = AudioStreamPlayer2D.new()
		_creak.stream = SoundBank.chain_rattle()
		_creak.max_distance = 800.0
		_creak.volume_db = -60.0
		add_child(_creak)
		_creak.play()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c is CollisionShape2D and c.has_meta("generated"):
			c.queue_free()
	for r in beams:
		var shape := CollisionShape2D.new()
		shape.set_meta("generated", true)
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		add_child(shape)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var k := pow(TAU / period, 2.0)
	var force := (-Weather.wind * 0.010 * (0.3 + Weather.gust_at(global_position.x)) + sin(Weather.time * 1.13) * 0.006 * Weather.wind) * swing_strength
	_speed += (-k * _angle - damping * _speed + force) * delta
	_angle += _speed * delta
	rotation = _angle
	_creak.volume_db = linear_to_db(clampf(absf(_speed) * 6.0, 0.001, 0.5)) - 8.0
	queue_redraw()


func get_rain_edges() -> Array:
	var out := []
	for r in beams:
		out.append([global_transform * r.position, global_transform * Vector2(r.end.x, r.position.y)])
	return out


func _draw() -> void:
	var c := Color.BLACK
	var prev_top := Vector2.ZERO
	for i in beams.size():
		var r: Rect2 = beams[i]
		var top := r.position.y
		var hook := Vector2(r.get_center().x, top - 30.0)
		DrawKit.chain(self, Vector2(r.position.x + r.size.x * 0.12, top), hook, 6.0, 1.6)
		DrawKit.chain(self, Vector2(r.end.x - r.size.x * 0.12, top), hook, 6.0, 1.6)
		draw_rect(Rect2(hook.x - 6, hook.y - 14, 12, 11), c)
		draw_arc(hook + Vector2(0, -2), 4.5, -PI * 0.1, PI * 1.1, 10, c, 2.2)
		# chain up to the pivot or to the beam above
		var up := prev_top if i > 0 else Vector2.ZERO
		DrawKit.chain(self, hook + Vector2(0, -14), up, 8.0, 2.2)
		draw_rect(Rect2(r.position.x - 2, top, r.size.x + 4, 3), c)
		draw_rect(Rect2(r.position.x, top + 2, r.size.x, r.size.y - 4), c)
		draw_rect(Rect2(r.position.x - 2, r.end.y - 3, r.size.x + 4, 3), c)
		DrawKit.bolts(self, Vector2(r.position.x + 3, top), Vector2(r.end.x - 3, top), 12.0, 1.2)
		if hanging_weeds:
			for k in 3:
				var x := r.position.x + r.size.x * (0.2 + k * 0.31)
				DrawKit.vine(self, Vector2(x, r.end.y), 9.0 + k * 7.0, k * 2.1 + i)
		prev_top = Vector2(r.get_center().x, r.end.y)
	draw_circle(Vector2.ZERO, 4.0, c)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	var r := Rect2(-8, 0, 16, 16)
	for b in beams:
		r = r.merge(b)
	return r


## The far corner of each beam sets its size.
func _editor_handles() -> Array[Dictionary]:
	var h: Array[Dictionary] = []
	for i in beams.size():
		h.append({"id": i, "pos": beams[i].end, "props": ["beams"]})
	return h


func _editor_drag(id: Variant, p: Vector2) -> void:
	var b := beams.duplicate()
	b[id] = Rect2(b[id].position, (p - b[id].position).max(Vector2(16, 6)))
	beams = b
