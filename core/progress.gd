class_name Progress
extends RefCounted
## Which chapters the player has reached, kept between sessions (user://progress.cfg).
## The title screen offers to continue from the last one and lists them as chapters.

const CHAPTERS := [
	["res://levels/level_01/level_01.tscn", "I", "the fields"],
	["res://levels/level_02/level_02.tscn", "II", "the works"],
	["res://levels/level_03/level_03.tscn", "III", "the quarry"],
]
const FILE := "user://progress.cfg"

static var _reached := -1


## Index of the furthest chapter reached (0 = only the first).
static func reached() -> int:
	if _reached < 0:
		_reached = 0
		var cfg := ConfigFile.new()
		if cfg.load(FILE) == OK:
			_reached = clampi(int(cfg.get_value("progress", "reached", 0)), 0, CHAPTERS.size() - 1)
	return _reached


## Note that a level has been started; unlocks it as a chapter.
static func reach(scene_path: String) -> void:
	for i in CHAPTERS.size():
		if CHAPTERS[i][0] == scene_path and i > reached():
			_reached = i
			var cfg := ConfigFile.new()
			cfg.set_value("progress", "reached", i)
			cfg.save(FILE)
