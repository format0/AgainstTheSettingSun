@tool
@icon("res://creatures/fireflies/fireflies_icon.svg")
class_name Fireflies
extends Node2D
## Fireflies over the grass, blinking on and off as the light goes. Heavy rain keeps most of
## them down. The node's position is the top-left corner of the area they drift in.

@export var size := Vector2(400, 110):
	set(v):
		size = v
		queue_redraw()
@export var count := 24
## They begin to show when the sun has set this far.
@export_range(0.0, 1.0) var starts_at := 0.25

var _flies: Array[Dictionary] = []


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.HAZARD_GLOW
	if Engine.is_editor_hint():
		return
	Game.no_occlude(self)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in count:
		_flies.append({"home": Vector2(randf() * size.x, randf() * size.y), "phase": randf() * TAU, "speed": randf_range(0.2, 0.6),
			"blink": randf_range(0.0, 4.0), "period": randf_range(2.5, 5.0)})


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		DrawKit.editor_box(self, Rect2(Vector2.ZERO, size), Color(0.8, 1.0, 0.4, 0.6), "fireflies")
		return
	if not VFX.on("fireflies"):
		return
	var amount := smoothstep(starts_at, starts_at + 0.3, Daylight.progress) * (1.0 - 0.45 * clampf(Weather.storm, 0.0, 1.5))
	if amount <= 0.01:
		return
	var t := Weather.time
	for f in _flies:
		var ph: float = f.phase
		var p: Vector2 = f.home + Vector2(sin(t * f.speed + ph) * 30.0 + cos(t * f.speed * 0.6 + ph * 2.0) * 14.0 - Weather.wind * 6.0,
			sin(t * f.speed * 1.3 + ph * 1.7) * 12.0)
		var cyc := fmod(t + float(f.blink), float(f.period))
		var on := smoothstep(0.0, 0.25, cyc) * (1.0 - smoothstep(0.7, 1.2, cyc))
		var a := on * amount
		if a < 0.02:
			continue
		draw_circle(p, 11.0, Color(0.55, 0.75, 0.2, 0.05 * a))
		draw_circle(p, 5.0, Color(0.65, 0.9, 0.3, 0.14 * a))
		draw_circle(p, 2.4, Color(0.8, 1.0, 0.45, 0.45 * a))
		draw_circle(p, 1.3, Color(1.0, 1.0, 0.75, 1.0 * a))

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _editor_hit(p: Vector2) -> DrawKit.EditorHit:
	return DrawKit.EditorHit.AREA if _editor_rect().has_point(p) else DrawKit.EditorHit.MISS


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": size}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = p.max(Vector2(20, 20))
