@tool
@icon("res://interactive/collapsing_bridge/collapsing_bridge_icon.svg")
class_name CollapsingBridge
extends StaticBody2D
## An old rope bridge of wooden planks over a ravine. Rotten planks give way a moment after
## you step on them and tumble into the depth; with `collapses` every plank does, so you
## have to keep running. Some planks can be missing from the start.
## The node's position is the left anchor; `end` is the right anchor relative to it.

@export var end := Vector2(320, 0):
	set(v):
		end = v
		_rebuild()
@export var sag := 22.0:
	set(v):
		sag = v
		_rebuild()
@export var plank_width := 13.0:
	set(v):
		plank_width = v
		_rebuild()
## Indices of planks that are already gone.
@export var missing := PackedInt32Array():
	set(v):
		missing = v
		_rebuild()
## Every plank breaks shortly after it is stepped on. Otherwise only the `rotten` ones do.
@export var collapses := true
@export var rotten := PackedInt32Array()
## Seconds a plank holds once it feels a foot.
@export var hold_time := 0.38
@export var bridge_seed := 2

var _planks: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	z_index = Layers.ELEMENTS
	set_meta("surface", "wood")
	add_to_group("rain_surfaces")
	_rebuild()
	if Engine.is_editor_hint():
		return
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 1000.0
	add_child(_sound)
	var saved: Variant = Level.recall(self)
	if saved is Array:
		for i in saved:
			if i < _planks.size():
				_break(i, true)


func _deck_point(u: float) -> Vector2:
	return Vector2.ZERO.lerp(end, u) + Vector2(0, 4.0 * sag * u * (1.0 - u))


func _rebuild() -> void:
	for p in _planks:
		if is_instance_valid(p.get("shape")):
			p.shape.queue_free()
	_planks.clear()
	var count := maxi(2, int(end.length() / (plank_width + 2.5)))
	var rng := RandomNumberGenerator.new()
	rng.seed = bridge_seed
	for i in count:
		var u := (i + 0.5) / count
		var p := _deck_point(u)
		var tangent := (_deck_point(u + 0.01) - _deck_point(u - 0.01)).angle()
		var plank := {"pos": p, "angle": tangent + rng.randf_range(-0.05, 0.05), "broken": missing.has(i), "timer": -1.0,
			"len": plank_width * rng.randf_range(0.85, 1.0), "drop": rng.randf_range(0.0, 2.0)}
		if is_inside_tree():
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(end.length() / count + 0.6, 6)
			cs.shape = rect
			cs.position = p + Vector2(0, 3)
			cs.rotation = tangent
			cs.disabled = plank.broken
			add_child(cs)
			plank.shape = cs
		_planks.append(plank)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.standing_on == self:
		var lx := to_local(p.global_position).x
		for i in _planks.size():
			var pl: Dictionary = _planks[i]
			if pl.broken or pl.timer >= 0.0:
				continue
			if absf(pl.pos.x - lx) < plank_width * 1.2 and (collapses or rotten.has(i)):
				pl.timer = hold_time * randf_range(0.8, 1.2)
				_creak()
	for i in _planks.size():
		var pl: Dictionary = _planks[i]
		if pl.timer >= 0.0 and not pl.broken:
			pl.timer -= delta
			if pl.timer < 0.0:
				_break(i, false)
	for d in _debris:
		d.vel += Vector2(-Weather.wind * 20.0, 900.0) * delta
		d.pos += d.vel * delta
		d.angle += d.spin * delta
	_debris = _debris.filter(func(d): return d.pos.y < 900.0)
	queue_redraw()


func _creak() -> void:
	if not _sound.playing:
		_sound.stream = SoundBank.wood_creak()
		_sound.pitch_scale = randf_range(1.3, 1.7)
		_sound.play()


func _break(i: int, instant: bool) -> void:
	var pl: Dictionary = _planks[i]
	if pl.broken and not instant:
		return
	pl.broken = true
	if pl.has("shape"):
		(pl.shape as CollisionShape2D).set_deferred("disabled", true)
	var gone: Array = []
	for k in _planks.size():
		if _planks[k].broken and not missing.has(k):
			gone.append(k)
	Level.remember(self, gone)
	if instant:
		return
	_debris.append({"pos": pl.pos, "vel": Vector2(randf_range(-30, 30), randf_range(-40, 20)), "angle": pl.angle, "spin": randf_range(-6, 6), "len": pl.len})
	_sound.stream = SoundBank.wood_snap()
	_sound.pitch_scale = randf_range(1.2, 1.6)
	_sound.play()
	get_tree().call_group("dust_emitters", "burst", global_position + pl.pos, 5, plank_width)


func get_rain_edges() -> Array:
	return [[global_transform * Vector2.ZERO, global_transform * end]]


func _draw() -> void:
	var c := Color.BLACK
	var sway := sin(Weather.time * 1.4) * Weather.wind * 1.5
	# anchor posts with the ropes tied round them
	for a: Vector2 in [Vector2.ZERO, end]:
		draw_rect(Rect2(a.x - 3, a.y - 30, 6, 44), c)
		draw_circle(a + Vector2(0, -30), 3.5, c)
	# hand ropes and the ropes under the deck
	var hand := DrawKit.rope_points(Vector2(0, -28), end + Vector2(0, -28), sag + 2.0 + sway, 20)
	draw_polyline(hand, c, 1.4, true)
	var deck := PackedVector2Array()
	for i in 21:
		var u := i / 20.0
		deck.append(_deck_point(u) + Vector2(0, 5))
	draw_polyline(deck, c, 1.6, true)
	for i in _planks.size():
		var pl: Dictionary = _planks[i]
		if i % 2 == 0:
			var hp: Vector2 = hand[clampi(int(round(float(pl.pos.x) / end.x * 20.0)), 0, 20)]
			draw_line(pl.pos, hp, c, 0.9)
		if pl.broken:
			continue
		var shake := Vector2(0, randf_range(-0.6, 0.6)) if pl.timer >= 0.0 else Vector2.ZERO
		_plank(pl.pos + shake, pl.angle, pl.len)
	for d in _debris:
		_plank(d.pos, d.angle, d.len)
	if Engine.is_editor_hint():
		DrawKit.editor_caption(self, Vector2(0, -36), DrawKit.EDITOR_INTERACTIVE, "collapsing bridge" if collapses else "rope bridge")


func _plank(at: Vector2, angle: float, length: float) -> void:
	draw_set_transform(at, angle)
	draw_rect(Rect2(-length * 0.5, 0, length, 5), Color.BLACK)
	draw_set_transform(Vector2.ZERO)
