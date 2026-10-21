@icon("res://effects/effect_icon.svg")
class_name DistantScenery
extends Node2D
## Two parallax layers of hazy silhouettes behind the level (see far_silhouettes.gd and
## mid_silhouettes.gd). Pick the setting that matches the level.

enum Setting { FIELDS, INDUSTRY, QUARRY }

@export var setting := Setting.INDUSTRY
@export var far_scroll := 0.22
@export var mid_scroll := 0.5
@export var show_far := true
@export var show_mid := true


func _ready() -> void:
	add_to_group("effects")
	if show_far:
		var far := FarSilhouettes.new()
		far.scroll_scale = far_scroll
		far.setting = setting
		_add_layer(far, far_scroll, Layers.DISTANT_FAR)
	if show_mid:
		var mid := MidSilhouettes.new()
		mid.scroll_scale = mid_scroll
		mid.setting = setting
		_add_layer(mid, mid_scroll, Layers.DISTANT_MID)


func _add_layer(content: Node2D, scroll: float, z: int) -> void:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, 1.0)
	p.z_as_relative = false
	p.z_index = z
	p.add_child(content)
	add_child(p)
