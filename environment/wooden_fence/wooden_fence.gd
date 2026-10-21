@tool
@icon("res://environment/wooden_fence/wooden_fence_icon.svg")
class_name WoodenFence
extends Node2D
## An old field fence: weathered posts, rails that have come loose, a strand of barbed wire.
## Scenery only, the player runs past it. The node's position is the foot of the first post.

@export var length := 240.0:
	set(v):
		length = v
		queue_redraw()
@export var height := 34.0:
	set(v):
		height = v
		queue_redraw()
@export_range(0.0, 1.0) var decay := 0.4:
	set(v):
		decay = v
		queue_redraw()
@export var barbed_wire := true:
	set(v):
		barbed_wire = v
		queue_redraw()
@export var fence_seed := 1:
	set(v):
		fence_seed = v
		queue_redraw()


func _ready() -> void:
	z_index = Layers.ELEMENTS_BACK


func _process(_delta: float) -> void:
	if barbed_wire and not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var c := Color.BLACK
	var rng := RandomNumberGenerator.new()
	rng.seed = fence_seed
	var posts := maxi(2, int(length / 46.0) + 1)
	var tops: Array[Vector2] = []
	for i in posts:
		var x := length * i / (posts - 1)
		var lean := rng.randf_range(-0.25, 0.25) * decay
		var h := height * rng.randf_range(0.9, 1.1)
		var top := Vector2(x, 0) + Vector2.from_angle(-PI * 0.5 + lean) * h
		DrawKit.limb(self, Vector2(x, 2), top, 4.5, 3.6)
		tops.append(top)
	for i in posts - 1:
		for k in 2:
			var u := 0.3 + k * 0.42
			var a := Vector2(tops[i].x, 0).lerp(tops[i], u)
			var b := Vector2(tops[i + 1].x, 0).lerp(tops[i + 1], u)
			if rng.randf() < decay * 0.5:
				# a rail that came loose at one end and hangs down
				draw_line(a, a.lerp(b, 0.7) + Vector2(0, height * u * 0.9), c, 3.0)
			elif rng.randf() > decay * 0.3:
				draw_line(a, b, c, 3.0)
	if barbed_wire:
		for i in posts - 1:
			var a := tops[i] + Vector2(0, 3)
			var b := tops[i + 1] + Vector2(0, 3)
			var sag := 3.0 + sin(Weather.time * 2.0 + i) * Weather.wind * 1.2
			var pts := DrawKit.rope_points(a, b, sag, 10)
			draw_polyline(pts, c, 0.9, true)
			for k in range(1, 10, 2):
				var p := pts[k]
				draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), c, 0.9)
				draw_line(p + Vector2(-2, 2), p + Vector2(2, -2), c, 0.9)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(0, -height, length, height)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": Vector2(length, -height), "props": ["length", "height"]}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	length = maxf(20.0, p.x)
	height = maxf(10.0, -p.y)
