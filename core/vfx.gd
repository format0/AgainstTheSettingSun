class_name VFX
extends RefCounted
## The look of the game in numbers: bloom, softness, light shafts, haze, rain, grading and the
## little living things. Every effect reads its value from here each frame, so changing one
## in the F1 panel shows at once. The panel saves them to user://vfx.cfg.
##
## Each entry: [default, min, max, label, group]. Min and max of 0 and 1 with an integer
## default make an on/off switch in the panel.

const SETTINGS := {
	# light
	"bloom": [1.0, 0.0, 3.0, "Bloom", "Light"],
	"bloom_threshold": [0.72, 0.3, 1.0, "Bloom threshold", "Light"],
	"bloom_wide": [1.0, 0.0, 3.0, "Wide bloom (haze glow)", "Light"],
	"rays": [1.0, 0.0, 3.0, "Light shafts", "Light"],
	"rays_length": [0.96, 0.8, 0.99, "Shaft length", "Light"],
	"lamp_glow": [1.0, 0.0, 3.0, "Lamp and fire glow", "Light"],
	"sun_glow": [1.0, 0.0, 2.5, "Sun glow", "Light"],
	# softness
	"softness": [0.6, 0.0, 1.0, "Edge softening", "Softness"],
	"diffusion": [0.18, 0.0, 0.8, "Diffusion (dreamy)", "Softness"],
	"haze": [1.0, 0.0, 2.0, "Distance haze", "Softness"],
	"fog": [1.0, 0.0, 2.5, "Fog bank", "Softness"],
	"ground_fog": [1.0, 0.0, 2.5, "Ground fog", "Softness"],
	# grade
	"exposure": [1.06, 0.6, 1.6, "Exposure", "Grade"],
	"warmth": [0.25, -0.5, 1.0, "Warmth (golden)", "Grade"],
	"saturation": [1.12, 0.5, 1.8, "Saturation", "Grade"],
	"contrast": [1.0, 0.7, 1.4, "Contrast", "Grade"],
	"vignette": [0.5, 0.0, 1.0, "Vignette", "Grade"],
	"chroma": [1.0, 0.0, 3.0, "Colour fringing", "Grade"],
	"lens_rain": [1.0, 0.0, 2.0, "Raindrops on the lens", "Grade"],
	# film
	"grain": [0.05, 0.0, 0.25, "Film grain", "Film"],
	"grain_size": [1.6, 0.8, 4.0, "Grain size", "Film"],
	"grain_color": [0.35, 0.0, 1.0, "Colour in the grain", "Film"],
	"halation": [0.0, 0.0, 1.5, "Halation (red glow round lights)", "Film"],
	"film_flicker": [0.0, 0.0, 1.0, "Exposure flicker", "Film"],
	# sundown
	"sunset_red": [1.0, 0.0, 2.0, "Reddening as the sun sets", "Sundown"],
	"blue_hour": [1.0, 0.0, 2.0, "Blue hour (cold shadows at night)", "Sundown"],
	"afterglow": [1.0, 0.0, 2.0, "Afterglow on the clouds", "Sundown"],
	"sun_squash": [1.0, 0.0, 1.5, "Sun flattening at the horizon", "Sundown"],
	"heat_lightning": [1, 0, 1, "Silent lightning far away", "Sundown"],
	"evening_mist": [1.0, 0.0, 2.0, "Mist rising at dusk", "Sundown"],
	# weather
	"rain": [1.0, 0.0, 2.0, "Rain amount", "Weather"],
	"rain_shelter": [1, 0, 1, "Rain stops under roofs", "Weather"],
	"rain_gusts": [1.0, 0.0, 2.0, "Gust sheets in the rain", "Weather"],
	"drips": [1, 0, 1, "Drips from edges", "Weather"],
	"splashes": [1.0, 0.0, 2.0, "Splashes", "Weather"],
	"leaves": [1.0, 0.0, 2.5, "Blowing leaves", "Weather"],
	# life
	"bats": [1, 0, 1, "Bats at dusk", "Life"],
	"flocks": [1, 0, 1, "Starlings going home", "Life"],
	"fireflies": [1, 0, 1, "Fireflies", "Life"],
	"motes": [1, 0, 1, "Dust in the light", "Life"],
	"steam": [1, 0, 1, "Steam from hot things", "Life"],
	"smoke": [1.0, 0.0, 2.0, "Chimney smoke", "Life"],
	"sparks": [1, 0, 1, "Sparks from molten steel", "Life"],
}

static var _values := {}
static var _loaded := false


## The current value of a setting.
static func v(key: String) -> float:
	if not _loaded:
		load_settings()
	return float(_values.get(key, SETTINGS[key][0]))


## True for an on/off setting that is on.
static func on(key: String) -> bool:
	return v(key) >= 0.5


static func set_value(key: String, value: float) -> void:
	if not _loaded:
		load_settings()
	_values[key] = value


static func is_switch(key: String) -> bool:
	var s: Array = SETTINGS[key]
	return s[0] is int and float(s[1]) == 0.0 and float(s[2]) == 1.0


static func reset() -> void:
	_values.clear()
	for k in SETTINGS:
		_values[k] = float(SETTINGS[k][0])


static func load_settings() -> void:
	_loaded = true
	reset()
	var cfg := ConfigFile.new()
	if cfg.load("user://vfx.cfg") == OK:
		for k in SETTINGS:
			_values[k] = float(cfg.get_value("vfx", k, _values[k]))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in SETTINGS:
		cfg.set_value("vfx", k, v(k))
	cfg.save("user://vfx.cfg")


## All values as text, to paste into a message or into SETTINGS as new defaults.
static func dump() -> String:
	var lines := PackedStringArray()
	for k in SETTINGS:
		lines.append("%s = %s" % [k, snappedf(v(k), 0.001)])
	return "\n".join(lines)
