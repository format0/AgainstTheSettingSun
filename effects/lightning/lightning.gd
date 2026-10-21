@icon("res://effects/effect_icon.svg")
class_name LightningEffect
extends CanvasLayer
## Branching lightning bolts far behind the scenery, with a multi-pulse flash.
## Anything in the "lightning_listeners" group gets on_lightning(screen_x, strength):
## the camera shakes, the ambience plays thunder after a delay that depends on distance.

@export var min_interval := 7.0
@export var max_interval := 16.0
## No automatic strikes below this storm strength.
@export var min_storm := 0.25

var _segments: Array[PackedVector2Array] = []
var _widths: PackedFloat32Array = []
var _life := 0.0
var _t := 0.0
var _wait := 5.0
var _pulses := [[0.0, 1.0], [0.09, 0.4], [0.16, 0.95], [0.30, 0.55]]
var _canvas: Node2D


func _ready() -> void:
	layer = Layers.CANVAS_LIGHTNING
	add_to_group("effects")
	_canvas = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = mat
	_canvas.draw.connect(_draw_bolt)
	add_child(_canvas)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("strike_lightning"):
		strike()
	if _life > 0.0:
		_t += delta
		_life -= delta
		var f := 0.0
		for p in _pulses:
			var k: float = _t - p[0]
			if k >= 0.0:
				f = maxf(f, p[1] * exp(-k * 16.0))
		Weather.flash = f
	else:
		Weather.flash = 0.0
		if Weather.storm > min_storm:
			_wait -= delta
			if _wait <= 0.0:
				strike()
	_canvas.queue_redraw()


## Strike now. screen_x < 0 picks a random spot.
func strike(screen_x: float = -1.0) -> void:
	var w := GameCamera.view_rect.size.x
	var x := screen_x if screen_x >= 0.0 else randf_range(200.0, w - 200.0)
	Weather.bolt_screen_x = x
	_segments.clear()
	_widths.clear()
	_subdivide(Vector2(x, 30), Vector2(x + randf_range(-160, 160), randf_range(470, 590)), 2.2, 8)
	_life = 0.55
	_t = 0.0
	_wait = randf_range(min_interval, max_interval) / maxf(0.3, Weather.storm)
	var strength := randf_range(0.35, 1.0)
	get_tree().call_group("lightning_listeners", "on_lightning", x, strength)


func _subdivide(a: Vector2, b: Vector2, width: float, level: int) -> void:
	if level == 0:
		_segments.append(PackedVector2Array([a, b]))
		_widths.append(width)
		return
	var mid := (a + b) * 0.5 + Vector2(randf_range(-1, 1) * absf(b.y - a.y) * 0.32, randf_range(-0.05, 0.05) * (b.y - a.y))
	_subdivide(a, mid, width, level - 1)
	_subdivide(mid, b, width, level - 1)
	if level > 2 and randf() < 0.28 and width > 0.7:
		_subdivide(mid, mid + Vector2(randf_range(-120, 120), randf_range(40, 160)), width * 0.5, level - 2)


func _draw_bolt() -> void:
	if _life <= 0.0:
		return
	var a := clampf(Weather.flash * 1.4, 0.0, 1.0)
	for pass_ in [[9.0, 0.10, Color(0.7, 0.75, 1.0)], [3.5, 0.35, Color(0.8, 0.84, 1.0)], [1.2, 1.0, Color.WHITE]]:
		var col: Color = pass_[2]
		col.a = pass_[1] * a
		for i in _segments.size():
			_canvas.draw_line(_segments[i][0], _segments[i][1], col, pass_[0] * _widths[i] * 0.6 * 2.0, true)
