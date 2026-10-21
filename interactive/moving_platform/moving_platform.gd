@tool
@icon("res://interactive/moving_platform/moving_platform_icon.svg")
class_name MovingPlatform
extends AnimatableBody2D
## Old machinery that carries the player: a girder hanging from chains, a lift cage, or a
## pallet on ropes. It moves by `travel` when a switch turns it on (or back and forth all
## the time in LOOP mode). Hanging styles draw their chains up to a pulley or a rail
## `hang_height` above. The node's position is the top-left corner at the start.

enum Mode { ON_SIGNAL, LOOP, LOOP_WHEN_ACTIVE }
enum Style { GIRDER, CAGE, PALLET, SLAB }

@export var size := Vector2(110, 14):
	set(v):
		size = v
		_rebuild()
@export var travel := Vector2(0, -150):
	set(v):
		travel = v
		queue_redraw()
@export var mode := Mode.ON_SIGNAL
@export var active := false
## Pixels per second.
@export var speed := 55.0
## Seconds it waits at each end in the loop modes.
@export var pause := 1.2
@export var style := Style.GIRDER:
	set(v):
		style = v
		queue_redraw()
## Chains or ropes reach this far above the platform's start (0 = none).
@export var hang_height := 260.0:
	set(v):
		hang_height = v
		queue_redraw()
## Swing a little in the wind.
@export var wind_sway := 1.0

var _origin := Vector2.ZERO
var _t := 0.0
var _dir := 1.0
var _wait := 0.0
var _shape: CollisionShape2D
var _sound: AudioStreamPlayer2D
var _sway := 0.0


func _ready() -> void:
	z_index = Layers.MACHINERY
	sync_to_physics = true
	add_to_group("rain_surfaces")
	_rebuild()
	_origin = position
	_wait = pause
	if Engine.is_editor_hint():
		return
	set_meta("surface", "wood" if style == Style.PALLET else "metal")
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = SoundBank.chain_rattle()
	_sound.max_distance = 900.0
	_sound.volume_db = -80.0
	add_child(_sound)
	_sound.play()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	queue_redraw()


func set_active(on: bool, instant := false) -> void:
	if on and not active:
		_wait = pause
	active = on
	if instant and mode == Mode.ON_SIGNAL:
		_t = 1.0 if on else 0.0
		position = _origin + travel * _t


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var length := maxf(travel.length(), 1.0)
	var before := _t
	match mode:
		Mode.ON_SIGNAL:
			_t = move_toward(_t, 1.0 if active else 0.0, speed / length * delta)
		Mode.LOOP, Mode.LOOP_WHEN_ACTIVE:
			if mode == Mode.LOOP or active:
				if _wait > 0.0:
					_wait -= delta
				else:
					_t += _dir * speed / length * delta
					if _t >= 1.0 or _t <= 0.0:
						_t = clampf(_t, 0.0, 1.0)
						_dir = -_dir
						_wait = pause
	var eased := smoothstep(0.0, 1.0, _t) * 0.6 + _t * 0.4
	var target := _origin + travel * eased
	var moving := before != _t
	_sway += ((-Weather.wind * 3.0 * (0.4 + Weather.gust_at(global_position.x)) * wind_sway if hang_height > 0.0 else 0.0) - _sway) * delta * 1.5
	position = target + Vector2(_sway, 0)
	_sound.volume_db = lerpf(_sound.volume_db, -10.0 if moving else -60.0, delta * 8.0)
	queue_redraw()


func get_rain_edges() -> Array:
	return [[global_transform * Vector2.ZERO, global_transform * Vector2(size.x, 0)]]


func _anchor_local(x: float) -> Vector2:
	# where a chain is fixed above: a fixed pulley for vertical travel, a trolley on a rail otherwise
	var base := _origin if is_inside_tree() and not Engine.is_editor_hint() else position
	var world_top := base.y - hang_height + minf(travel.y, 0.0)
	return Vector2(x - _sway, world_top - position.y)


func _draw() -> void:
	var c := Color.BLACK
	var hangs := hang_height > 0.0
	match style:
		Style.GIRDER:
			draw_rect(Rect2(-2, 0, size.x + 4, 3), c)
			draw_rect(Rect2(0, 2, size.x, size.y - 4), c)
			draw_rect(Rect2(-2, size.y - 3, size.x + 4, 3), c)
			DrawKit.bolts(self, Vector2(3, 0), Vector2(size.x - 3, 0), 12.0, 1.2)
			if hangs:
				var top := _anchor_local(size.x * 0.5)
				var hook := Vector2(size.x * 0.5, -34)
				DrawKit.chain(self, Vector2(8, 0), hook, 6.0, 1.6)
				DrawKit.chain(self, Vector2(size.x - 8, 0), hook, 6.0, 1.6)
				_hook_block(hook)
				DrawKit.chain(self, hook + Vector2(0, -14), top, 8.0, 2.2)
		Style.CAGE:
			var h := 64.0
			draw_rect(Rect2(0, 0, size.x, size.y), c)
			draw_rect(Rect2(0, -h, size.x, 5), c)
			for k in int(size.x / 9.0) + 1:
				var x := minf(k * 9.0, size.x - 1.5)
				draw_line(Vector2(x, -h), Vector2(x, 0), c, 1.5)
			draw_line(Vector2(0, -h * 0.5), Vector2(size.x, -h * 0.5), c, 2.0)
			if hangs:
				DrawKit.chain(self, Vector2(size.x * 0.5, -h), _anchor_local(size.x * 0.5), 8.0, 2.2)
		Style.PALLET:
			for k in int(size.x / 13.0):
				draw_rect(Rect2(k * 13.0 + 0.5, 0, 12.0, 4), c)
			draw_rect(Rect2(0, 4, size.x, size.y - 4), c)
			if hangs:
				var top := _anchor_local(size.x * 0.5)
				DrawKit.rope(self, Vector2(3, 1), top + Vector2(-2, 0), 0.0, 1.6)
				DrawKit.rope(self, Vector2(size.x - 3, 1), top + Vector2(2, 0), 0.0, 1.6)
		Style.SLAB:
			draw_colored_polygon(DrawKit.rough_rect(Rect2(Vector2.ZERO, size), 7, 1.5, 6.0), c)
			if hangs:
				DrawKit.chain(self, Vector2(10, 0), _anchor_local(10), 7.0, 1.8)
				DrawKit.chain(self, Vector2(size.x - 10, 0), _anchor_local(size.x - 10), 7.0, 1.8)
	if hangs and travel.x != 0.0:
		# the rail the trolley runs on
		var a := _anchor_local(0.0)
		var rail_y := a.y - 6.0
		var ox := _origin.x if not Engine.is_editor_hint() else position.x
		var x0 := ox + minf(travel.x, 0.0) - position.x - 30.0
		draw_rect(Rect2(x0, rail_y - 8, absf(travel.x) + size.x + 60.0, 8), c)
		draw_rect(Rect2(size.x * 0.5 - 14 - _sway, rail_y, 28, 9), c)
		draw_circle(Vector2(size.x * 0.5 - 8 - _sway, rail_y), 4.0, c)
		draw_circle(Vector2(size.x * 0.5 + 8 - _sway, rail_y), 4.0, c)
	elif hangs:
		var a := _anchor_local(size.x * 0.5)
		draw_circle(a, 9.0, c)
		draw_rect(Rect2(a.x - 26, a.y - 14, 52, 6), c)
	if Engine.is_editor_hint():
		draw_rect(Rect2(travel, size), DrawKit.EDITOR_INTERACTIVE, false, 1.0)
		DrawKit.editor_link(self, size * 0.5, travel + size * 0.5, DrawKit.EDITOR_INTERACTIVE)


func _hook_block(at: Vector2) -> void:
	var c := Color.BLACK
	draw_rect(Rect2(at.x - 7, at.y - 16, 14, 12), c)
	draw_arc(at + Vector2(0, -1), 5.0, -PI * 0.1, PI * 1.1, 10, c, 2.4)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).merge(Rect2(travel, size))


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": size}, {"id": "travel", "pos": travel + size * 0.5}]


func _editor_drag(id: Variant, p: Vector2) -> void:
	if id == "size":
		size = p.max(Vector2(16, 6))
	else:
		travel = p - (size * 0.5).round()
