@icon("res://effects/effect_icon.svg")
class_name Ambience
extends Node
## Background sound: rain hiss and rumble that follow the storm, drips nearby, gusting wind,
## thunder after lightning (closer strikes are louder, crack, and arrive sooner), a quiet
## pad of music, crickets as the light goes, and a heartbeat when something hunts you
## or the darkness is close.

@export_range(-40.0, 6.0) var volume_db := 0.0
@export var rain := true
@export var wind := true
@export var thunder := true
@export var music := true
@export_range(-40.0, 0.0) var music_db := -15.0
## Crickets start as the sun goes down (nature levels).
@export var crickets := false
## Heard from inside behind a window: the rain, wind and thunder come muffled through the
## glass, and drops tap on the pane close by.
@export var indoors := false

var _drip_players: Array[AudioStreamPlayer2D] = []
var _drip_next := 0
var _hiss: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _wind_filter: AudioEffectBandPassFilter
var _wind_bus := -1
var _music: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _music_task := -1
var _music_built: AudioStreamWAV


func _ready() -> void:
	add_to_group("effects")
	add_to_group("lightning_listeners")
	var outside := _indoor_bus() if indoors else "Master"
	if rain:
		_hiss = _loop(SoundBank.rain_hiss(), outside)
		_rumble = _loop(SoundBank.rain_rumble(), outside)
	if wind:
		_wind_bus = AudioServer.get_bus_index("Wind")
		if _wind_bus < 0:
			AudioServer.add_bus()
			_wind_bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(_wind_bus, "Wind")
			AudioServer.set_bus_send(_wind_bus, outside)
			_wind_filter = AudioEffectBandPassFilter.new()
			_wind_filter.resonance = 0.6
			AudioServer.add_bus_effect(_wind_bus, _wind_filter)
		else:
			_wind_filter = AudioServer.get_bus_effect(_wind_bus, 0) as AudioEffectBandPassFilter
		AudioServer.set_bus_send(_wind_bus, outside)
		_wind = _loop(SoundBank.wind_noise(), "Wind")
	if crickets:
		_crickets = _loop(SoundBank.crickets(), "Master")
	_heart = _loop(SoundBank.heartbeat(), "Master")
	if music:
		if SoundBank.music_pad():
			_start_music()
		else:
			_music_task = WorkerThreadPool.add_task(_build_music)


## A bus that sounds like hearing it through a closed window.
func _indoor_bus() -> String:
	if AudioServer.get_bus_index("Indoors") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Indoors")
		AudioServer.set_bus_send(i, "Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 950.0
		AudioServer.add_bus_effect(i, lp)
	return "Indoors"


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		SoundBank.store_music_pad(_music_built)


func _build_music() -> void:
	_music_built = SoundBank.build_music_pad()


func _start_music() -> void:
	_music = _loop(SoundBank.music_pad(), "Master")


func _loop(stream: AudioStream, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	var s := Weather.storm
	var smooth := 1.0 - exp(-delta * 2.0)
	if _hiss:
		_fade(_hiss, 0.30 * s, smooth)
		_fade(_rumble, 0.55 * minf(s, 1.6), smooth)
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		SoundBank.store_music_pad(_music_built)
		_start_music()
	if _music:
		_fade(_music, db_to_linear(music_db) * (0.6 + 0.4 * Daylight.light()), 1.0 - exp(-delta * 0.3))
	if _crickets:
		_fade(_crickets, 0.5 * smoothstep(0.35, 0.8, Daylight.progress) * (1.0 - 0.6 * minf(s, 1.0)), smooth)
	var hunted := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == Enemy.State.CHASE or e.state == Enemy.State.ALERT:
			hunted = true
			break
	_fade(_heart, maxf(0.45 if hunted else 0.0, Daylight.urgency() * 0.6), 1.0 - exp(-delta * 3.0))
	_heart.pitch_scale = lerpf(_heart.pitch_scale, 1.35 if hunted else 1.0 + Daylight.urgency() * 0.3, delta)
	_drips(delta, s)
	if _wind:
		_fade(_wind, 0.35 * Weather.wind * Weather.gust * (0.5 + 0.5 * s), 1.0 - exp(-delta * 4.0))
		if _wind_filter:
			_wind_filter.cutoff_hz = 280.0 + Weather.wind * Weather.gust * 700.0


## Water dripping off gutters, branches and girders somewhere near: single plinks,
## left and right, more of them the harder it rains. Indoors: drops tapping on the pane.
func _drips(delta: float, storm: float) -> void:
	if indoors:
		if randf() < delta * (8.0 + 14.0 * storm):
			_tap()
		return
	if not VFX.on("drips") or storm < 0.05 or randf() > delta * (1.5 + 6.0 * storm):
		return
	if _drip_players.is_empty():
		for i in 4:
			var d := AudioStreamPlayer2D.new()
			d.max_distance = 100000.0
			d.attenuation = 0.0
			add_child(d)
			_drip_players.append(d)
	var p: AudioStreamPlayer2D = _drip_players[_drip_next]
	_drip_next = (_drip_next + 1) % _drip_players.size()
	var view := GameCamera.view_rect
	p.stream = SoundBank.drip(randi() % 4)
	p.pitch_scale = randf_range(0.85, 1.25)
	p.volume_db = volume_db - randf_range(14.0, 24.0)
	p.global_position = Vector2(view.position.x + randf() * view.size.x, view.get_center().y)
	p.play()


func _tap() -> void:
	if _drip_players.size() < 6:
		var d := AudioStreamPlayer2D.new()
		d.max_distance = 100000.0
		d.attenuation = 0.0
		add_child(d)
		_drip_players.append(d)
	var p: AudioStreamPlayer2D = _drip_players[_drip_next % _drip_players.size()]
	_drip_next += 1
	var view := GameCamera.view_rect
	p.stream = SoundBank.glass_tap(randi() % 4)
	p.pitch_scale = randf_range(0.8, 1.3)
	p.volume_db = volume_db - randf_range(16.0, 30.0)
	p.global_position = Vector2(view.position.x + randf() * view.size.x, view.get_center().y)
	p.play()


func _fade(p: AudioStreamPlayer, linear: float, k: float) -> void:
	var target := linear_to_db(maxf(linear, 0.0001)) + volume_db
	p.volume_db = lerpf(p.volume_db, target, k)


## Called through the "lightning_listeners" group.
func on_lightning(screen_x: float, strength: float) -> void:
	if not thunder:
		return
	var delay := lerpf(2.4, 0.3, strength)
	var pan := clampf(screen_x / GameCamera.view_rect.size.x * 2.0 - 1.0, -1.0, 1.0)
	_one_shot(SoundBank.thunder(randi() % 3), delay, linear_to_db(0.5 + 0.6 * strength) + (4.0 if indoors else 0.0), pan)
	if strength > 0.75:
		_one_shot(SoundBank.thunder_crack(), delay - 0.05, linear_to_db(0.5 * strength), pan)


func _one_shot(stream: AudioStream, delay: float, db: float, pan: float) -> void:
	await get_tree().create_timer(maxf(delay, 0.0)).timeout
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = db + volume_db
	p.max_distance = 100000.0
	p.attenuation = 0.0
	if indoors:
		p.bus = "Indoors"
	add_child(p)
	var view := GameCamera.view_rect
	p.global_position = Vector2(view.get_center().x + pan * view.size.x * 0.5, view.get_center().y)
	p.play()
	p.finished.connect(p.queue_free)


func set_effect_enabled(on: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	for c in get_children():
		if c is AudioStreamPlayer:
			c.stream_paused = not on
