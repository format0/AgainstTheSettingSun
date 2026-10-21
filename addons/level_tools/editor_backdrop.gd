@tool
extends Node2D
## What a level looks like behind its playfield, shown only in the editor: the level's sky and
## its two layers of distant scenery, as the game would show them if its camera stood where
## the editor view is. The plugin adds one to an open level (not saved with the scene) and
## takes it away again. Nothing here moves on its own; it is only redrawn when the view or
## the level's sky settings change, so editing stays light.

const GAME_VIEW := Vector2(1366, 768)

var level: Node
var _sky: Node2D
var _sky_mat: ShaderMaterial
var _layers: Array[Node2D] = []     # parallax wrappers (far, mid)
var _content: Array[Node2D] = []    # FarSilhouettes, MidSilhouettes
var _scrolls: Array[float] = []
var _last_view := Rect2()
var _last_key := ""
var _refs := {}
var _check := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = -100
	_sky = Node2D.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://addons/level_tools/sky_preview.gdshader")
	_sky.material = _sky_mat
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	_build_layers()


func _settings_key() -> String:
	# rebuild when the level's distant scenery, sky or sunset start change
	var d := _find("DistantScenery")
	var s := _find("SkyEffect")
	var parts := [level.get("start_progress") if level else 0.0]
	if d:
		parts.append_array([d.setting, d.far_scroll, d.mid_scroll, d.far_opacity, d.mid_opacity, d.show_far, d.show_mid])
	if s:
		parts.append_array([s.sun_screen_position, s.sun_parallax, s.cloud_cover])
	var w := _find("WeatherController")
	if w:
		parts.append(w.storm)
	return str(parts)


## The level's node with this script class (looked up once, then kept).
func _find(class_name_: String) -> Node:
	var n: Node = _refs.get(class_name_)
	if is_instance_valid(n) and n.is_inside_tree():
		return n
	_refs.erase(class_name_)
	if level == null:
		return null
	for c in level.find_children("*", "", true, false):
		var sc := c.get_script() as Script
		if sc and String(sc.get_global_name()) == class_name_:
			_refs[class_name_] = c
			return c
	return null


func _build_layers() -> void:
	for l in _layers:
		l.queue_free()
	_layers.clear()
	_content.clear()
	_scrolls.clear()
	var d := _find("DistantScenery")
	if d == null:
		return
	var specs := []
	if d.show_far:
		specs.append([FarSilhouettes.new(), d.far_scroll, Layers.DISTANT_FAR, d.far_opacity])
	if d.show_mid:
		specs.append([MidSilhouettes.new(), d.mid_scroll, Layers.DISTANT_MID, d.mid_opacity])
	for sp in specs:
		var content: Node2D = sp[0]
		content.scroll_scale = sp[1]
		content.setting = d.setting
		# the layer is flattened first and faded as a whole, like in the game
		var group := CanvasGroup.new()
		group.self_modulate = Color(1, 1, 1, sp[3])
		group.add_child(content)
		var wrap := Node2D.new()
		wrap.z_as_relative = false
		wrap.z_index = sp[2]
		wrap.add_child(group)
		add_child(wrap)
		_layers.append(wrap)
		_content.append(content)
		_scrolls.append(sp[1])


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or level == null:
		return
	# the level's settings are looked at a few times a second, the view every frame
	_check -= delta
	var key := _last_key
	if _check <= 0.0:
		_check = 0.3
		key = _settings_key()
	if key != _last_key:
		_last_key = key
		_apply_settings()
		_build_layers()
		_last_view = Rect2()
	var view := get_viewport_transform().affine_inverse() * get_viewport_rect()
	if view.is_equal_approx(_last_view):
		return
	_last_view = view
	# the game camera that would show this part of the level (it keeps to the level's height)
	var cam := Vector2(view.get_center().x - GAME_VIEW.x * 0.5, 0.0)
	GameCamera.view_rect = view
	for i in _layers.size():
		_layers[i].position.x = view.position.x * (1.0 - _scrolls[i])
		_content[i].queue_redraw()
	var s := _find("SkyEffect")
	var sun := Vector2(455, 618)
	var par := 0.05
	if s:
		sun = s.sun_screen_position
		par = s.sun_parallax
	var sink := Vector2(0, smoothstep(0.1, 0.9, Daylight.progress) * 230.0)
	_sky_mat.set_shader_parameter("game_cam", cam)
	_sky_mat.set_shader_parameter("cam_x", cam.x)
	_sky_mat.set_shader_parameter("sun_pos", sun + sink - Vector2(cam.x * par, 0.0))
	_sky.queue_redraw()


func _apply_settings() -> void:
	Daylight.progress = float(level.get("start_progress")) if level.get("start_progress") != null else 0.0
	var w := _find("WeatherController")
	Weather.storm = w.storm if w else 1.0
	var s := _find("SkyEffect")
	_sky_mat.set_shader_parameter("view_size", GAME_VIEW)
	_sky_mat.set_shader_parameter("dusk", Daylight.progress)
	_sky_mat.set_shader_parameter("storm", Weather.storm)
	_sky_mat.set_shader_parameter("cloud_cover", s.cloud_cover if s else 0.4)
	_sky_mat.set_shader_parameter("weather_time", 30.0)


func _draw_sky() -> void:
	# one rectangle over whatever the editor shows, a little larger
	_sky.draw_rect(_last_view.grow(64.0), Color.WHITE)
