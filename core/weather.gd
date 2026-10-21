@tool
class_name Weather
extends RefCounted
## Shared weather state that every effect, element and creature reads.
##
## A WeatherController node in the level writes these values each frame.
## Without one, the world stays calm with the defaults below.
## The wind always blows toward -x, out of the setting sun.

static var time := 0.0
## 0 = calm, 1 = storm, 2 = wild.
static var storm := 0.0
## Current wind strength, roughly 0..1.4.
static var wind := 0.3
## Slow swell of the wind, 0.3..1.3.
static var gust := 1.0
## Slant of falling rain in radians.
static var wind_angle := 0.1
## Running integral of tan(wind_angle); lets rain drift smoothly when the wind changes.
static var wind_acc := 0.0
## Lightning flash brightness, 0..1.
static var flash := 0.0
## Screen x of the current lightning bolt.
static var bolt_screen_x := 0.0
## Where the sun is on screen (set by the Sky effect, used by light shafts).
static var sun_screen_pos := Vector2(560, 622)


## Local gust strength at a world x: waves that travel with the wind, visible in grass and trees.
static func gust_at(x: float) -> float:
	return 0.55 + 0.30 * sin(x * 0.0085 + time * 1.9) + 0.15 * sin(x * 0.023 + time * 3.7)


static func reset() -> void:
	time = 0.0
	wind_acc = 0.0
	flash = 0.0
