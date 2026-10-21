@tool
class_name Enemy
extends CharacterBody2D
## Base for the creatures that roam the levels. Touching one is death.
##
## Every creature walks back and forth between `patrol_left` and `patrol_right` (measured
## from where it was placed), stopping to look around at the ends, at walls and at edges.
## Blind creatures do nothing else. Hunters (`hunts`) also look out for the player: when
## one sees him it freezes, shrieks and gives chase. It loses him when he hides in front of
## a Cover (and no light is on him), when something solid comes between them, or when he
## gets out of reach; then it searches for a while and goes back to its rounds. A hunter
## that hasn't spotted you walks right past you while you stand in a shadow; a blind one
## bumps into you wherever you are. Noises (a hard landing, a crash, a grinding gate)
## make hunters walk over to see what it was.
## Creatures can't jump: they stop at edges and walls. Loud landings and crashes make
## hunters turn and look. The node's position is between the feet.

enum State { PATROL, LOOK, ALERT, CHASE, SEARCH, RETURN, ATTACK, INVESTIGATE, DEAD }

@export_group("Patrol")
## How far it walks to the left and right of where it was placed.
@export var patrol_left := 120.0:
	set(v):
		patrol_left = v
		queue_redraw()
@export var patrol_right := 120.0:
	set(v):
		patrol_right = v
		queue_redraw()
@export var walk_speed := 38.0
## Seconds it stands at each end of its round.
@export var pause_time := 1.6
@export_range(-1, 1, 2) var start_facing := 1
@export_group("Hunting")
@export var hunts := false
@export var sight_range := 340.0:
	set(v):
		sight_range = v
		queue_redraw()
@export var chase_speed := 118.0
## Seconds between seeing the player and running at him.
@export var reaction_time := 0.7
## Seconds it keeps searching after losing him.
@export var search_time := 3.5
@export_group("Body")
@export var body_size := Vector2(24, 64)
@export var eye_height := 58.0
@export var gravity := 1200.0

var state := State.PATROL
var facing := 1
var dead := false
## 0..1 animation helpers for the drawing code.
var stride := 0.0
var alertness := 0.0
var lunge := 0.0

var _home := Vector2.ZERO
var _timer := 0.0
var _unseen := 0.0
var _last_seen := Vector2.ZERO
var _look_turns := 0
var _blocked := false
var _voice: AudioStreamPlayer2D
var _feet: AudioStreamPlayer2D
var _shape: CollisionShape2D
var _death_t := 0.0
var _breath_wait := 4.0
var _noise_x := 0.0


func _ready() -> void:
	facing = start_facing
	z_index = Layers.ENEMIES
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect
	_shape.position = Vector2(0, -body_size.y * 0.5)
	add_child(_shape)
	if Engine.is_editor_hint():
		return
	if Level.recall(self) == "dead":
		queue_free()
		return
	add_to_group("enemies")
	collision_layer = Layers.BODY_ENEMIES
	collision_mask = Layers.BODY_WORLD
	floor_snap_length = 8.0
	_home = global_position
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 1100.0
	add_child(_voice)
	_feet = AudioStreamPlayer2D.new()
	_feet.max_distance = 600.0
	_feet.volume_db = -14.0
	add_child(_feet)
	_breath_wait = randf_range(2.0, 7.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if dead:
		_death_t += delta
		velocity.x *= 0.9
		velocity.y = minf(velocity.y + gravity * delta, 500.0)
		move_and_slide()
		queue_redraw()
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var sees := hunts and _sees(player)
	if sees:
		_last_seen = player.global_position
	var move := 0.0
	var speed := walk_speed
	match state:
		State.PATROL:
			move = facing
			var x := global_position.x - _home.x
			if (facing > 0 and x >= patrol_right) or (facing < 0 and x <= -patrol_left) or _path_blocked():
				_enter(State.LOOK)
				move = 0.0
		State.LOOK:
			_timer -= delta
			if hunts and _timer < pause_time * 0.5 and _look_turns == 0:
				# glance back over the shoulder
				facing = -facing
				_look_turns = 1
			if _timer <= 0.0:
				if _look_turns == 0:
					facing = -facing
				_enter(State.PATROL)
		State.ALERT:
			_timer -= delta
			facing = 1 if _last_seen.x >= global_position.x else -1
			if _timer <= 0.0:
				_enter(State.CHASE if sees else State.SEARCH)
		State.CHASE:
			speed = chase_speed
			var dx := _last_seen.x - global_position.x
			facing = 1 if dx >= 0.0 else -1
			move = facing if absf(dx) > 4.0 else 0.0
			_blocked = _path_blocked()
			if _blocked:
				move = 0.0
			if sees:
				_unseen = 0.0
			else:
				_unseen += delta
				if _unseen > 0.45:
					_enter(State.SEARCH)
		State.SEARCH:
			_timer -= delta
			if sees:
				_enter(State.ALERT, 0.25)
			elif fmod(_timer, 1.1) < delta:
				facing = -facing
			if _timer <= 0.0:
				_enter(State.RETURN)
		State.RETURN:
			var dx := _home.x - global_position.x
			if absf(dx) < 8.0 or global_position.x - _home.x > -patrol_left and global_position.x - _home.x < patrol_right:
				_enter(State.PATROL)
			else:
				facing = 1 if dx > 0.0 else -1
				move = facing
				if _path_blocked():
					_enter(State.LOOK)
					move = 0.0
		State.INVESTIGATE:
			var dx := _noise_x - global_position.x
			facing = 1 if dx >= 0.0 else -1
			move = facing
			speed = walk_speed * 1.7
			if absf(dx) < 30.0 or _path_blocked():
				move = 0.0
				_enter(State.SEARCH)
		State.ATTACK:
			_timer -= delta
			lunge = minf(1.0, lunge + delta * 6.0)
			if _timer <= 0.0:
				_enter(State.SEARCH)
	if hunts and sees and state in [State.PATROL, State.LOOK, State.SEARCH, State.RETURN, State.INVESTIGATE]:
		_enter(State.ALERT)
	velocity.x = move_toward(velocity.x, move * speed, 600.0 * delta)
	velocity.y = minf(velocity.y + gravity * delta, 600.0)
	var x_before := global_position.x
	move_and_slide()
	var moved := absf(global_position.x - x_before)
	stride += moved / maxf(body_size.y * 0.55, 1.0)
	alertness = move_toward(alertness, 1.0 if state in [State.ALERT, State.CHASE, State.ATTACK] else (0.4 if state == State.SEARCH else 0.0), delta * 3.0)
	if state != State.ATTACK:
		lunge = move_toward(lunge, 0.0, delta * 3.0)
	_step_sounds(moved)
	_ambient_voice(delta)
	_touch(player)
	queue_redraw()


func _enter(next: State, timer := -1.0) -> void:
	state = next
	_look_turns = 0
	match next:
		State.LOOK:
			_timer = pause_time
		State.ALERT:
			_timer = reaction_time if timer < 0.0 else timer
			velocity.x = 0.0
			_say(SoundBank.shriek() if hunts else SoundBank.chitter(), 0.0)
		State.CHASE:
			_unseen = 0.0
		State.SEARCH:
			_timer = search_time
		State.ATTACK:
			_timer = 1.4


## Can it see the player right now?
func _sees(player: Player) -> bool:
	if player == null or player.dead or player.in_shadow:
		return false
	var eye := global_position + Vector2(facing * 6.0, -eye_height)
	var target := player.global_position + Vector2(0, -24)
	var d := target - eye
	var reach := sight_range * Daylight.sight_factor() * (1.4 if LightSource.lit_at(target) else 1.0)
	if d.length() > reach:
		return false
	var hunting := state == State.CHASE or state == State.ALERT
	if not hunting and signf(d.x) != facing and absf(d.x) > 18.0:
		return false
	if absf(d.y) > absf(d.x) * 1.1 + 60.0:
		return false
	var q := PhysicsRayQueryParameters2D.create(eye, target, Layers.BODY_WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## A wall or a drop ahead.
func _path_blocked() -> bool:
	if is_on_wall():
		for i in get_slide_collision_count():
			if signf(get_slide_collision(i).get_normal().x) == -facing:
				return true
	if not is_on_floor():
		return false
	var front := global_position + Vector2(facing * (body_size.x * 0.5 + 6.0), -6.0)
	var q := PhysicsRayQueryParameters2D.create(front, front + Vector2(0, 30), Layers.BODY_WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _touch(player: Player) -> void:
	if player == null or player.dead:
		return
	# hunters find you by sight: one that hasn't seen you walks right past you in the shadow.
	# Blind creatures feel their way and always find you.
	if hunts and player.in_shadow and state not in [State.ALERT, State.CHASE, State.ATTACK]:
		return
	var mine := Rect2(global_position + Vector2(-body_size.x * 0.5 + 2.0 + facing * lunge * 10.0, -body_size.y + 4.0), body_size - Vector2(4, 4))
	var his := Rect2(player.global_position + Vector2(-9, -38), Vector2(18, 36))
	if mine.intersects(his):
		player.die("caught")
		_enter(State.ATTACK)
		_say(SoundBank.growl(), 2.0)


## A loud sound nearby (landing, crash, machinery): hunters go and look.
func hear(at: Vector2) -> void:
	if not hunts or dead or state in [State.ALERT, State.CHASE, State.ATTACK]:
		return
	facing = 1 if at.x >= global_position.x else -1
	_noise_x = at.x
	_enter(State.INVESTIGATE)
	_say(SoundBank.growl(), -6.0)


func _step_sounds(moved: float) -> void:
	if moved > 0.2 and is_on_floor() and fmod(stride, 1.0) < moved / maxf(body_size.y * 0.55, 1.0):
		_feet.stream = SoundBank.creature_step()
		_feet.pitch_scale = randf_range(0.7, 0.9) if state == State.CHASE else randf_range(0.55, 0.7)
		_feet.play()


func _ambient_voice(delta: float) -> void:
	_breath_wait -= delta
	if _breath_wait <= 0.0:
		_breath_wait = randf_range(4.0, 9.0)
		if not _voice.playing:
			_say(SoundBank.creature_breath(), -8.0)


func _say(stream: AudioStream, db: float) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.volume_db = db
	_voice.pitch_scale = randf_range(0.85, 1.1)
	_voice.play()


# ------------------------------------------------------------------ dying

func die() -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	Level.remember(self, "dead")
	_say(SoundBank.shriek(), 2.0)
	_voice.pitch_scale = 0.6


func drown() -> void:
	die()
	velocity = Vector2(0, 40)
	collision_mask = 0


func burn() -> void:
	die()
	get_tree().call_group("ember_emitters", "burst", global_position + Vector2(0, -20), 40)
	collision_mask = 0


# ------------------------------------------------------------------ drawing

## Black on black it would vanish in front of a Cover, so then a faint rim is drawn round it
## first (the body drawn a few times, shifted, in the rim colour), and the black body on top.
func _draw() -> void:
	if not Engine.is_editor_hint() and not dead:
		var c := global_position + Vector2(0, -body_size.y * 0.5)
		if Cover.hides(PackedVector2Array([c])):
			var rim := Color(1.0, 0.62, 0.42, 0.32)
			for o: Vector2 in [Vector2(1.6, 0), Vector2(-1.6, 0), Vector2(0, 1.6), Vector2(0, -1.6)]:
				_draw_body(o, rim)
	_draw_body(Vector2.ZERO, Color.BLACK)
	_draw_editor()


## Draw the creature with every shape shifted by `o` and filled with `ink`. Override this.
func _draw_body(_o: Vector2, _ink: Color) -> void:
	pass


# ------------------------------------------------------------------ drawing helpers

## Pale eyes that show where it looks; they flare when it has seen the player.
func draw_eyes(at: Vector2, spacing := 3.0) -> void:
	if dead and _death_t > 0.4:
		return
	var a := (0.4 + 0.6 * alertness) * (0.7 + 0.3 * (1.0 - Daylight.light()))
	var col := Color(1.0, 0.92, 0.75, a).lerp(Color(1.0, 0.55, 0.35, a), alertness)
	draw_circle(at, 1.3 + alertness * 0.6, col)
	draw_circle(at + Vector2(-spacing * facing, 0.4), 1.0 + alertness * 0.5, col)
	if alertness > 0.5:
		draw_circle(at, 5.0, Color(col, 0.08 * alertness))


func _draw_editor() -> void:
	if not Engine.is_editor_hint():
		return
	var col := DrawKit.EDITOR_ENEMY
	draw_line(Vector2(-patrol_left, 4), Vector2(patrol_right, 4), col, 1.5)
	draw_line(Vector2(-patrol_left, -2), Vector2(-patrol_left, 10), col, 1.5)
	draw_line(Vector2(patrol_right, -2), Vector2(patrol_right, 10), col, 1.5)
	if hunts:
		var eye := Vector2(start_facing * 6.0, -eye_height)
		var a := Vector2(start_facing * sight_range, -eye_height - sight_range * 0.35)
		var b := Vector2(start_facing * sight_range, -eye_height + sight_range * 0.35)
		draw_polyline(PackedVector2Array([a, eye, b]), Color(col, 0.5), 1.0)
	DrawKit.editor_caption(self, Vector2(-20, 18), col, ("hunter" if hunts else "patrol"))
