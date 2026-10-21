@tool
@icon("res://interactive/push_crate/push_crate_icon.svg")
class_name PushCrate
extends CharacterBody2D
## Something heavy to move around: a wooden crate, an oil drum or a log. Walk into it to push
## it, hold the action button to grab it and pull. It falls off edges, floats in DeepWater
## (and drifts with its current), presses PressurePlates and blocks enemies.
## Use it as a step to climb higher or a raft to cross water.
## The node's position is the middle of its bottom edge.

enum Kind { CRATE, DRUM, LOG }

@export var kind := Kind.CRATE:
	set(v):
		kind = v
		_rebuild()
@export var size := Vector2(38, 36):
	set(v):
		size = v
		_rebuild()
@export var floats := true
@export var gravity := 1200.0
@export var crate_seed := 1

var surface := "wood"
var _push := 0.0
var _drag := 0.0
var _held := false
var _focused := false
var _highlight := 0.0
var _shape: CollisionShape2D
var _scrape: AudioStreamPlayer2D
var _was_in_water := false
var _bob := 0.0


func _ready() -> void:
	z_index = Layers.MACHINERY
	_rebuild()
	if Engine.is_editor_hint():
		return
	process_priority = -5
	collision_layer = Layers.BODY_WORLD | Layers.BODY_MOVABLES
	collision_mask = Layers.BODY_WORLD
	floor_snap_length = 4.0
	add_to_group("interactables")
	add_to_group("rain_surfaces")
	surface = "metal" if kind == Kind.DRUM else "wood"
	var saved: Variant = Level.recall(self)
	if saved is Vector2:
		global_position = saved
	_scrape = AudioStreamPlayer2D.new()
	_scrape.stream = SoundBank.scrape(kind == Kind.DRUM)
	_scrape.max_distance = 700.0
	_scrape.volume_db = -80.0
	add_child(_scrape)
	_scrape.play()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0, -size.y * 0.5)
	queue_redraw()


# ------------------------------------------------------------------ the player's hands

func can_interact(player: Player) -> bool:
	return player.is_on_floor() and absf(player.global_position.y - global_position.y) < 12.0


func get_interact_position() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var side := signf(p.global_position.x - global_position.x) if p else 1.0
	return global_position + Vector2(side * size.x * 0.5, -18)


func set_highlight(on: bool) -> void:
	_focused = on


func interact(player: Player) -> void:
	_held = true
	player.grab(self)


func release(_player: Player) -> void:
	_held = false
	_drag = 0.0


## The player walks into it.
func push(vx: float) -> void:
	_push = vx


## The player holds it and moves (called every frame while held).
func drag(vx: float) -> void:
	_drag = vx


# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var water := DeepWater.find_at(global_position) if floats else null
	if water:
		var surface_y := water.surface_y(global_position.x)
		var player := get_tree().get_first_node_in_group("player") as Player
		var loaded := player and player.standing_on == self
		var float_line := surface_y + size.y * (0.62 if loaded else 0.45) + sin(Weather.time * 1.6 + crate_seed) * 1.5
		var depth := global_position.y - float_line
		velocity.y += (-depth * 30.0 - velocity.y * 4.0) * delta
		velocity.x = lerpf(velocity.x, water.current - Weather.wind * 6.0, delta * 0.8)
		if _push != 0.0:
			velocity.x = _push * 0.7
		_bob = sin(Weather.time * 1.3 + crate_seed) * 0.05 * (0.5 + Weather.wind)
		if not _was_in_water and velocity.y > 60.0:
			get_tree().call_group("splash_emitters", "burst", global_position, 20, 1.4)
		_was_in_water = true
	else:
		_was_in_water = false
		_bob = 0.0
		velocity.y = minf(velocity.y + gravity * delta, 600.0)
		if _held:
			velocity.x = _drag
		elif _push != 0.0:
			velocity.x = _push
		else:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		velocity.x += _tip() * delta
	_push = 0.0
	var falling := velocity.y > 200.0
	move_and_slide()
	if falling and is_on_floor():
		get_tree().call_group("dust_emitters", "burst", global_position, 8, size.x)
		get_tree().call_group("game_camera", "shake", 1.5)
	var sliding := is_on_floor() and absf(get_real_velocity().x) > 5.0
	_scrape.volume_db = lerpf(_scrape.volume_db, -8.0 if sliding else -70.0, delta * 12.0)
	if absf(get_real_velocity().x) > 1.0 or absf(get_real_velocity().y) > 1.0:
		Level.remember(self, global_position)
	_highlight = move_toward(_highlight, 1.0 if _focused else 0.0, delta * 4.0)
	rotation = _bob
	queue_redraw()


## When more than half of it hangs over an edge it tips and slides off (acceleration, px/s²).
func _tip() -> float:
	if not is_on_floor():
		return 0.0
	var space := get_world_2d().direct_space_state
	var hits := []
	for fx: float in [-0.45, 0.0, 0.45]:
		var from := global_position + Vector2(size.x * fx, -4.0)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 12), Layers.BODY_WORLD, [get_rid()])
		hits.append(not space.intersect_ray(q).is_empty())
	if hits[1]:
		return 0.0
	if hits[0] and not hits[2]:
		return 500.0
	if hits[2] and not hits[0]:
		return -500.0
	return 0.0


func get_rain_edges() -> Array:
	return [[global_transform * Vector2(-size.x * 0.5, -size.y), global_transform * Vector2(size.x * 0.5, -size.y)]]


func _draw() -> void:
	var r := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	match kind:
		Kind.CRATE:
			draw_crate(self, r, crate_seed)
		Kind.DRUM:
			draw_rect(Rect2(r.position + Vector2(1, 0), r.size - Vector2(2, 0)), Color.BLACK)
			for k in 3:
				draw_rect(Rect2(r.position.x - 1.5, r.position.y + r.size.y * (0.1 + k * 0.4) - 1.5, r.size.x + 3, 3), Color.BLACK)
			draw_rect(Rect2(r.position.x + r.size.x * 0.25, r.position.y - 2.5, 6, 3), Color.BLACK)
		Kind.LOG:
			var c := Color.BLACK
			DrawKit.ellipse(self, r.get_center(), r.size * 0.5, 0.0, c, 20)
			draw_rect(Rect2(r.position.x + r.size.y * 0.4, r.position.y, r.size.x - r.size.y * 0.8, r.size.y), c)
			# branch stubs and loose bark
			draw_line(r.position + Vector2(r.size.x * 0.3, 2), r.position + Vector2(r.size.x * 0.24, -8), c, 3.0)
			draw_line(r.position + Vector2(r.size.x * 0.7, 3), r.position + Vector2(r.size.x * 0.8, -5), c, 2.4)
	if not Engine.is_editor_hint():
		Mechanism.draw_glint(self, Vector2(0, -size.y * 0.5), _highlight * 0.8)
	else:
		DrawKit.editor_caption(self, Vector2(-size.x * 0.5, -size.y - 4), DrawKit.EDITOR_INTERACTIVE, "push")


## A wooden crate: boards with gaps showing the sky, a cross brace, nail heads on the edge.
static func draw_crate(ci: CanvasItem, r: Rect2, seed_value: int) -> void:
	var c := Color.BLACK
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var boards := maxi(2, int(r.size.y / 9.0))
	var bh := r.size.y / boards
	for k in boards:
		var inset := rng.randf_range(0.0, 1.2)
		ci.draw_rect(Rect2(r.position.x + inset, r.position.y + k * bh + 0.7, r.size.x - inset * 2.0, bh - 1.4), c)
	ci.draw_rect(Rect2(r.position.x - 1, r.position.y, 5, r.size.y), c)
	ci.draw_rect(Rect2(r.end.x - 4, r.position.y, 5, r.size.y), c)
	ci.draw_line(r.position + Vector2(3, r.size.y - 2), r.position + Vector2(r.size.x - 3, 2), c, 4.0)
	if rng.randf() < 0.4:
		# a broken corner
		ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x - 3, 0), r.position + Vector2(r.size.x + 3, -4), r.position + Vector2(r.size.x - 8, -1)]), c)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(size.x * 0.5, -size.y)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = Vector2(maxf(12.0, absf(p.x) * 2.0), maxf(12.0, -p.y))
