class_name Level
extends Node2D
## Base script for every level scene.
##
## A level is: this root node with its settings, a GameCamera, a Player, a LevelExit and any
## mix of environment, cover, structures, interactive elements, hazards, enemies and effects.
##
## The sun sets while you play (Daylight.progress goes from start_progress to 1). Dying sends
## you back to the last Checkpoint, but the sun keeps setting. When the light is gone the
## level starts over from the beginning.

enum State { PLAYING, DYING, ESCAPED, DARK }

## The level being played (there is only ever one).
static var current: Level

@export var level_title := "I"
@export var level_subtitle := ""
## The scene that follows when the player reaches the LevelExit. Empty = the end of the game.
@export_file("*.tscn") var next_level := ""
@export var level_width := 3000.0
@export var level_height := 768.0
## World y of the main ground; effects use it for splashes, fog and reflections.
@export var ground_y := 635.0
## Where the player starts.
@export var spawn_point := Vector2(300, 560)
## Footstep sound where the floor doesn't say otherwise: grass, dirt, stone, wood, metal.
@export var ground_surface := "grass"

@export_group("Sunset")
## Seconds of play until the light is gone.
@export var sunset_seconds := 420.0
@export_range(0.0, 0.9) var start_progress := 0.0

var state := State.PLAYING
## Saved states of elements (levers, broken bridges, fallen trees...), keyed by node path.
var memory := {}
var overlay: ScreenOverlay

var _respawned := false

@onready var player: Player = get_tree().get_first_node_in_group("player")


func _enter_tree() -> void:
	current = self
	Weather.reset()
	var r := _respawn_data()
	if r.get("scene", "") == scene_file_path:
		memory = (r.memory as Dictionary).duplicate(true)
		Daylight.progress = r.progress
		_respawned = true
	else:
		_clear_respawn()
		Daylight.progress = start_progress


func _ready() -> void:
	overlay = ScreenOverlay.new()
	add_child(overlay)
	for k: Bursts.Kind in [Bursts.Kind.DUST, Bursts.Kind.EMBERS, Bursts.Kind.LEAVES]:
		add_child(Bursts.create(k))
	var r := _respawn_data()
	if player:
		player.global_position = r.pos if _respawned else spawn_point
	get_tree().call_group("game_camera", "snap_to_target")
	if _respawned:
		overlay.fade_from_black(1.2)
	else:
		overlay.fade_from_black(3.0)
		overlay.show_title(level_title, level_subtitle)


func _process(delta: float) -> void:
	if state == State.PLAYING or state == State.DYING:
		Daylight.progress = minf(1.0, Daylight.progress + delta / maxf(sunset_seconds, 1.0))
		if Daylight.progress >= 1.0 and state == State.PLAYING:
			_light_gone()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_clear_respawn()
		get_tree().reload_current_scene()
	elif state == State.ESCAPED and next_level == "" and event.is_action_pressed("action"):
		_clear_respawn()
		get_tree().change_scene_to_file("res://levels/level_01/level_01.tscn")


# ------------------------------------------------------------------ memory

## Store the state of an element so it survives a respawn at a later checkpoint.
static func remember(node: Node, value: Variant) -> void:
	if current and current.is_ancestor_of(node):
		current.memory[str(current.get_path_to(node))] = value


## The state stored by remember(), or `default` when there is none.
static func recall(node: Node, default: Variant = null) -> Variant:
	if current and current.is_ancestor_of(node):
		return current.memory.get(str(current.get_path_to(node)), default)
	return default


# ------------------------------------------------------------------ progress

func reach_checkpoint(at: Vector2) -> void:
	if state != State.PLAYING:
		return
	_store_respawn(at, memory.duplicate(true))


func player_died(_cause: String) -> void:
	if state != State.PLAYING:
		return
	state = State.DYING
	var r := _respawn_data()
	if r.get("scene", "") != scene_file_path:
		_store_respawn(spawn_point, {})
		r = _respawn_data()
	r.deaths = int(r.get("deaths", 0)) + 1
	await get_tree().create_timer(1.8).timeout
	await overlay.fade_to_black(1.0)
	r.progress = Daylight.progress
	Engine.set_meta("respawn", r)
	get_tree().reload_current_scene()


func player_escaped() -> void:
	if state != State.PLAYING:
		return
	state = State.ESCAPED
	_clear_respawn()
	if player:
		player.escape()
	await overlay.fade_to_black(2.5)
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
	else:
		overlay.show_message("the sun has set behind you", "you made it through")


func _light_gone() -> void:
	state = State.DARK
	_clear_respawn()
	if player:
		player.freeze()
	overlay.show_message("the light is gone")
	await overlay.fade_to_black(4.0)
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


func _store_respawn(at: Vector2, mem: Dictionary) -> void:
	var r := _respawn_data()
	var deaths := int(r.get("deaths", 0)) if r.get("scene", "") == scene_file_path else 0
	Engine.set_meta("respawn", {"scene": scene_file_path, "pos": at, "memory": mem, "progress": Daylight.progress, "deaths": deaths})


static func _clear_respawn() -> void:
	if Engine.has_meta("respawn"):
		Engine.remove_meta("respawn")


static func _respawn_data() -> Dictionary:
	return Engine.get_meta("respawn", {}) as Dictionary
