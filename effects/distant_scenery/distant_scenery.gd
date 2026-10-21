@icon("res://effects/effect_icon.svg")
class_name DistantScenery
extends Node2D
## Two parallax layers of hazy silhouettes behind the level (see far_silhouettes.gd and
## mid_silhouettes.gd). Each layer is drawn opaque into a CanvasGroup, so the nearer one hides
## the farther one, and the group mixes in the colour of the sky behind it: the farther, the
## more the scenery fades into the sky. Pick the setting that matches the level.

enum Setting { FIELDS, INDUSTRY, QUARRY }

@export var setting := Setting.INDUSTRY
@export var far_scroll := 0.22
@export var mid_scroll := 0.5
## How solid each layer looks against the sky (the rest is the haze of the air between).
@export_range(0.0, 1.0) var far_opacity := 0.55
@export_range(0.0, 1.0) var mid_opacity := 0.78
@export var show_far := true
@export var show_mid := true

var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	add_to_group("effects")
	if show_far:
		var far := FarSilhouettes.new()
		far.scroll_scale = far_scroll
		far.setting = setting
		_add_layer(far, far_scroll, Layers.DISTANT_FAR, far_opacity)
	if show_mid:
		var mid := MidSilhouettes.new()
		mid.scroll_scale = mid_scroll
		mid.setting = setting
		_add_layer(mid, mid_scroll, Layers.DISTANT_MID, mid_opacity)


func _add_layer(content: Node2D, scroll: float, z: int, opacity: float) -> void:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, 1.0)
	p.z_as_relative = false
	p.z_index = z
	var group := CanvasGroup.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://effects/distant_scenery/haze_layer.gdshader")
	mat.set_shader_parameter("haze", 1.0 - opacity)
	group.material = mat
	_materials.append(mat)
	group.add_child(content)
	p.add_child(group)
	add_child(p)


func _process(_delta: float) -> void:
	for m in _materials:
		m.set_shader_parameter("view_size", GameCamera.view_rect.size)
		m.set_shader_parameter("sun_pos", Weather.sun_screen_pos)
		m.set_shader_parameter("dusk", Daylight.progress)
		m.set_shader_parameter("storm", Weather.storm)
		m.set_shader_parameter("sun_glow", VFX.v("sun_glow"))
		m.set_shader_parameter("sun_squash", VFX.v("sun_squash"))
		m.set_shader_parameter("flash", Weather.flash)
