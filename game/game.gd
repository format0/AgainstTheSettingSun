class_name Game
extends Node
## The frame around the levels. It loads a level into its own viewport and turns what the
## level draws into the final picture, the way the original WebGL version did:
##
##   level ──► bright parts (½) ──► blur ──► blur ──► wide blur (¼) ──► blur ─┐
##     │                                                                     ├──► final pass ──► screen
##     └─ silhouettes only (½, same level seen again) ──► sun glow ──► shafts ┘
##
## The silhouette view also tells the rain where roofs are, so it stops under them.
## Running a level scene on its own (F6) starts a Game around it by itself.

static var instance: Game
static var _pending := ""

const VIEW := Vector2i(1366, 768)
const OCCLUDER_BIT := 2

@export_file("*.tscn") var first_level := "res://levels/level_01/level_01.tscn"

## The viewport the level lives in.
var world: SubViewport
## The level's solid silhouettes only (alpha = covered), at half size.
var occluders: SubViewport
var level: Node
var level_path := ""
var overlay: ScreenOverlay
## Light-shaft strength asked for by the level's LightShafts node.
var rays_level := 1.0
## Lens-rain limit asked for by the level's CameraLens node.
var lens_level := 1.0

var _passes := {}
var _final: ColorRect
var _final_mat: ShaderMaterial
var _panel: VfxPanel


## Start the game around a level that was run on its own.
static func start_with(path: String) -> void:
	_pending = path
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = load("res://game/game.tscn").instantiate()
	var old := tree.current_scene
	tree.root.add_child.call_deferred(g)
	tree.set_deferred("current_scene", g)
	if old:
		old.queue_free()


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_build()
	get_tree().root.size_changed.connect(_resize)
	_resize()
	overlay = ScreenOverlay.new()
	add_child(overlay)
	_panel = VfxPanel.new()
	add_child(_panel)
	load_level(_pending if _pending != "" else first_level)
	_pending = ""


# ------------------------------------------------------------------ levels

func load_level(path: String) -> void:
	if level:
		world.remove_child(level)
		level.queue_free()
		level = null
	level_path = path
	overlay.clear_text()
	var scene := load(path) as PackedScene
	level = scene.instantiate()
	world.add_child(level)


func reload_level() -> void:
	load_level.call_deferred(level_path)


# ------------------------------------------------------------------ the picture

func _build() -> void:
	# viewports nested so that each one renders before the one that reads it
	var far_v := _pass("BloomFarV", 4, preload("res://game/shaders/blur.gdshader"))
	add_child(far_v)
	var far_h := _pass("BloomFarH", 4, preload("res://game/shaders/blur.gdshader"))
	far_v.add_child(far_h)
	var near_v := _pass("BloomNearV", 2, preload("res://game/shaders/blur.gdshader"))
	far_h.add_child(near_v)
	var near_h := _pass("BloomNearH", 2, preload("res://game/shaders/blur.gdshader"))
	near_v.add_child(near_h)
	var bright := _pass("Bright", 2, preload("res://game/shaders/bright.gdshader"))
	near_h.add_child(bright)

	world = SubViewport.new()
	world.name = "World"
	world.audio_listener_enable_2d = true
	world.handle_input_locally = true
	world.size_2d_override = VIEW
	world.size_2d_override_stretch = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	bright.add_child(world)

	var rays := _pass("Rays", 2, preload("res://game/shaders/rays.gdshader"))
	world.add_child(rays)
	var rays_src := _pass("RaysSource", 2, preload("res://game/shaders/rays_source.gdshader"))
	rays.add_child(rays_src)
	occluders = SubViewport.new()
	occluders.name = "Occluders"
	occluders.transparent_bg = true
	occluders.world_2d = world.world_2d
	occluders.canvas_cull_mask = OCCLUDER_BIT
	occluders.size_2d_override = VIEW
	occluders.size_2d_override_stretch = true
	occluders.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	rays_src.add_child(occluders)

	_mat(bright).set_shader_parameter("src", world.get_texture())
	_mat(near_h).set_shader_parameter("src", bright.get_texture())
	_mat(near_v).set_shader_parameter("src", near_h.get_texture())
	_mat(far_h).set_shader_parameter("src", near_v.get_texture())
	_mat(far_v).set_shader_parameter("src", far_h.get_texture())
	_mat(rays_src).set_shader_parameter("occluders", occluders.get_texture())
	_mat(rays).set_shader_parameter("src", rays_src.get_texture())

	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_final = ColorRect.new()
	_final.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_mat = ShaderMaterial.new()
	_final_mat.shader = preload("res://game/shaders/final.gdshader")
	_final.material = _final_mat
	layer.add_child(_final)
	_final_mat.set_shader_parameter("scene", world.get_texture())
	_final_mat.set_shader_parameter("bloom_near", near_v.get_texture())
	_final_mat.set_shader_parameter("bloom_far", far_v.get_texture())
	_final_mat.set_shader_parameter("rays", rays.get_texture())


func _pass(pass_name: String, divider: int, shader: Shader) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = pass_name
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.set_meta("divider", divider)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = shader
	rect.material = m
	vp.add_child(rect)
	_passes[pass_name] = vp
	return vp


func _mat(vp: SubViewport) -> ShaderMaterial:
	return (vp.get_child(0) as ColorRect).material as ShaderMaterial


func _resize() -> void:
	var size := get_tree().root.size
	size = Vector2i(maxi(size.x, 320), maxi(size.y, 180))
	world.size = size
	occluders.size = size / 2
	for n in _passes:
		var vp: SubViewport = _passes[n]
		vp.size = size / int(vp.get_meta("divider"))
	var half := Vector2(size / 2)
	var quarter := Vector2(size / 4)
	_mat(_passes.Bright).set_shader_parameter("texel", Vector2(1.0, 1.0) / Vector2(size))
	_mat(_passes.BloomNearH).set_shader_parameter("dir", Vector2(1.0 / half.x, 0.0))
	_mat(_passes.BloomNearV).set_shader_parameter("dir", Vector2(0.0, 1.0 / half.y))
	_mat(_passes.BloomFarH).set_shader_parameter("dir", Vector2(2.2 / quarter.x, 0.0))
	_mat(_passes.BloomFarV).set_shader_parameter("dir", Vector2(0.0, 2.2 / quarter.y))
	_final_mat.set_shader_parameter("scene_texel", Vector2(1.0, 1.0) / Vector2(size))
	_final_mat.set_shader_parameter("aspect", float(size.x) / float(size.y))


func _process(_delta: float) -> void:
	occluders.canvas_transform = world.canvas_transform
	var sun := Weather.sun_screen_pos
	_mat(_passes.Bright).set_shader_parameter("threshold", VFX.v("bloom_threshold"))
	_mat(_passes.Bright).set_shader_parameter("wide", VFX.v("bloom_wide"))
	var rays_src := _mat(_passes.RaysSource)
	rays_src.set_shader_parameter("sun", sun)
	rays_src.set_shader_parameter("view", Vector2(VIEW))
	rays_src.set_shader_parameter("strength", VFX.v("sun_glow") * Daylight.light())
	var rays := _mat(_passes.Rays)
	rays.set_shader_parameter("sun_uv", sun / Vector2(VIEW))
	rays.set_shader_parameter("length_k", VFX.v("rays_length"))
	var m := _final_mat
	m.set_shader_parameter("weather_time", Weather.time)
	m.set_shader_parameter("flash", Weather.flash)
	m.set_shader_parameter("bloom", VFX.v("bloom"))
	m.set_shader_parameter("bloom_wide", VFX.v("bloom_wide"))
	m.set_shader_parameter("rays_amount", VFX.v("rays") * rays_level * (1.0 - smoothstep(0.45, 0.9, Daylight.progress)))
	m.set_shader_parameter("softness", VFX.v("softness"))
	m.set_shader_parameter("diffusion", VFX.v("diffusion"))
	m.set_shader_parameter("lens_rain", minf(lens_level, 0.35 + 0.55 * Weather.storm) * VFX.v("lens_rain"))
	m.set_shader_parameter("chroma", VFX.v("chroma"))
	m.set_shader_parameter("exposure", VFX.v("exposure"))
	m.set_shader_parameter("warmth", VFX.v("warmth") * Daylight.light())
	m.set_shader_parameter("saturation", VFX.v("saturation"))
	m.set_shader_parameter("contrast", VFX.v("contrast"))
	m.set_shader_parameter("vignette", VFX.v("vignette"))
	m.set_shader_parameter("grain", VFX.v("grain"))
	m.set_shader_parameter("darkness", Daylight.urgency())
	var pr := Daylight.progress
	m.set_shader_parameter("red_shift", VFX.v("sunset_red") * smoothstep(0.08, 0.6, pr) * (1.0 - 0.5 * smoothstep(0.8, 1.0, pr)))
	m.set_shader_parameter("night", VFX.v("blue_hour") * smoothstep(0.6, 0.95, pr))
	m.set_shader_parameter("motes", 1.0 if VFX.on("motes") else 0.0)
	m.set_shader_parameter("wind", Weather.wind)


func _input(event: InputEvent) -> void:
	if world and not (event is InputEventMouse and _panel.visible):
		world.push_input(event)


## Mark everything solid in a level so the silhouette view draws it. Glows, fog, rain and
## other effects are left out (they carry the meta "no_occlude" or sit in the "effects" group).
static func mark_occluders(root: Node) -> void:
	_mark(root)


static func _mark(n: Node) -> void:
	if n.has_meta("no_occlude"):
		return
	if n.is_in_group("effects") and not n is DistantScenery:
		return
	if n is CanvasItem and not n is CanvasLayer:
		var ci := n as CanvasItem
		ci.visibility_layer = ci.visibility_layer | OCCLUDER_BIT
	for c in n.get_children():
		_mark(c)


## Keep an effect node (a glow, a fog, a light) out of the silhouette view.
static func no_occlude(n: Node) -> void:
	n.set_meta("no_occlude", true)
	if n is CanvasItem:
		(n as CanvasItem).visibility_layer = 1
