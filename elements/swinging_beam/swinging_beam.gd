@tool
@icon("res://elements/swinging_beam/swinging_beam_icon.svg")
class_name SwingingBeam
extends AnimatableBody2D
## Steel beams hanging from a cable that swing in the wind like a pendulum.
## The node's position is the pivot (where the cable is fixed, can be above the screen).
## The player is carried along when standing on a beam.
##
## Without a texture the beams and cables are drawn as silhouettes. With a texture
## (for example a beam painted into the level art) only the image is drawn.

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
@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
@export var texture_offset := Vector2.ZERO:
	set(v):
		texture_offset = v
		queue_redraw()

var _angle := 0.0
var _speed := 0.0


func _ready() -> void:
	sync_to_physics = true
	add_to_group("rain_surfaces")
	_rebuild()


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


func get_rain_edges() -> Array:
	var out := []
	for r in beams:
		out.append([global_transform * r.position, global_transform * Vector2(r.end.x, r.position.y)])
	return out


func _draw() -> void:
	if texture:
		draw_texture(texture, texture_offset)
		draw_rect(Rect2(texture_offset.x + 118, texture_offset.y - 90, 3.2, 94), Color.BLACK)
		draw_rect(Rect2(texture_offset.x + 139, texture_offset.y - 90, 3.2, 94), Color.BLACK)
		return
	for r in beams:
		var top := r.position.y
		draw_line(Vector2.ZERO, Vector2(r.position.x + r.size.x * 0.2, top), Color.BLACK, 2.0)
		draw_line(Vector2.ZERO, Vector2(r.end.x - r.size.x * 0.2, top), Color.BLACK, 2.0)
		draw_rect(r, Color.BLACK)
		# flange lip so it reads as an I-beam
		draw_rect(Rect2(r.position.x - 2, top, r.size.x + 4, 3), Color.BLACK)
		draw_rect(Rect2(r.position.x - 2, r.end.y - 3, r.size.x + 4, 3), Color.BLACK)
	draw_circle(Vector2.ZERO, 3.0, Color.BLACK)
