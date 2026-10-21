@icon("res://effects/effect_icon.svg")
class_name WeatherController
extends Node
## Drives the shared Weather state for this level: storm strength and the gusting wind.
## Every effect, element and creature reads Weather; leave this node out for a calm level.

@export_range(0.0, 2.0, 0.01) var storm := 1.0
@export_range(0.0, 2.0, 0.01) var wind_strength := 1.0
## Let the storm swell and ease slowly over a couple of minutes.
@export var slow_swell := true


func _ready() -> void:
	process_priority = -100


func _process(delta: float) -> void:
	Weather.time += delta
	var t := Weather.time
	var s := storm * ((0.88 + 0.12 * sin(t * 0.05)) if slow_swell else 1.0)
	Weather.storm = s
	Weather.gust = clampf(0.72 + 0.22 * sin(t * 0.23) + 0.16 * sin(t * 0.71 + 1.0) + 0.08 * sin(t * 1.9), 0.3, 1.3)
	Weather.wind = (0.35 + 0.45 * minf(s, 1.6)) * Weather.gust * wind_strength
	Weather.wind_angle = 0.06 + 0.3 * Weather.wind
	Weather.wind_acc += tan(Weather.wind_angle) * delta
