@icon("res://effects/effect_icon.svg")
class_name Ambience
extends Node
## Background sound: rain hiss and rumble that follow the storm, gusting wind,
## and thunder after lightning (closer strikes are louder, crack, and arrive sooner).

@export_range(-40.0, 6.0) var volume_db := 0.0
@export var rain := true
@export var wind := true
@export var thunder := true

var _hiss: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _wind_filter: AudioEffectBandPassFilter
var _wind_bus := -1


func _ready() -> void:
	add_to_group("effects")
	add_to_group("lightning_listeners")
	if rain:
		_hiss = _loop(SoundBank.rain_hiss(), "Master")
		_rumble = _loop(SoundBank.rain_rumble(), "Master")
	if wind:
		_wind_bus = AudioServer.get_bus_index("Wind")
		if _wind_bus < 0:
			AudioServer.add_bus()
			_wind_bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(_wind_bus, "Wind")
			AudioServer.set_bus_send(_wind_bus, "Master")
			_wind_filter = AudioEffectBandPassFilter.new()
			_wind_filter.resonance = 0.6
			AudioServer.add_bus_effect(_wind_bus, _wind_filter)
		else:
			_wind_filter = AudioServer.get_bus_effect(_wind_bus, 0) as AudioEffectBandPassFilter
		_wind = _loop(SoundBank.wind_noise(), "Wind")


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
	if _wind:
		_fade(_wind, 0.35 * Weather.wind * Weather.gust * (0.5 + 0.5 * s), 1.0 - exp(-delta * 4.0))
		if _wind_filter:
			_wind_filter.cutoff_hz = 280.0 + Weather.wind * Weather.gust * 700.0


func _fade(p: AudioStreamPlayer, linear: float, k: float) -> void:
	var target := linear_to_db(maxf(linear, 0.0001)) + volume_db
	p.volume_db = lerpf(p.volume_db, target, k)


## Called through the "lightning_listeners" group.
func on_lightning(screen_x: float, strength: float) -> void:
	if not thunder:
		return
	var delay := lerpf(2.4, 0.3, strength)
	var pan := clampf(screen_x / GameCamera.view_rect.size.x * 2.0 - 1.0, -1.0, 1.0)
	_one_shot(SoundBank.thunder(randi() % 3), delay, linear_to_db(0.5 + 0.6 * strength), pan)
	if strength > 0.75:
		_one_shot(SoundBank.thunder_crack(), delay - 0.05, linear_to_db(0.5 * strength), pan)


func _one_shot(stream: AudioStream, delay: float, db: float, pan: float) -> void:
	await get_tree().create_timer(maxf(delay, 0.0)).timeout
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = db + volume_db
	p.max_distance = 100000.0
	p.attenuation = 0.0
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
