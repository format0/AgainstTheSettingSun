@tool
@icon("res://structures/solid_block/solid_block_icon.svg")
class_name SolidBlock
extends StaticBody2D
## A rectangle the player can stand on and collide with. The node's position is its top-left corner.
## Pick a style for its outline: plain, broken concrete, wooden planks, riveted steel or earth.
## Rain splashes on its top edge.

enum Style { PLAIN, CONCRETE, PLANKS, STEEL, EARTH, INVISIBLE }

@export var size := Vector2(120, 24):
	set(v):
		size = v
		_rebuild()
@export var style := Style.PLAIN:
	set(v):
		style = v
		queue_redraw()
## Footstep sound: grass, dirt, stone, wood, metal. Empty = the level's ground surface.
@export var surface := ""
@export var detail_seed := 1:
	set(v):
		detail_seed = v
		queue_redraw()
## Also accept rain splashes on its top edge.
@export var catches_rain := true

var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("rain_surfaces")
	z_index = Layers.ELEMENTS
	if surface == "":
		match style:
			Style.CONCRETE:
				surface = "stone"
			Style.PLANKS:
				surface = "wood"
			Style.STEEL:
				surface = "metal"
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	queue_redraw()


## Top edges that rain can hit, as [start, end] pairs in world space.
func get_rain_edges() -> Array:
	if not catches_rain:
		return []
	var a := global_transform * Vector2.ZERO
	var b := global_transform * Vector2(size.x, 0)
	return [[a, b]]


func _draw() -> void:
	var c := Color.BLACK
	var r := Rect2(Vector2.ZERO, size)
	var rng := RandomNumberGenerator.new()
	rng.seed = detail_seed
	match style:
		Style.INVISIBLE:
			if Engine.is_editor_hint():
				draw_rect(r, Color(0.3, 1.0, 0.8, 0.5), false, 1.0)
		Style.PLAIN:
			draw_rect(r, c)
		Style.CONCRETE:
			draw_colored_polygon(DrawKit.rough_rect(r, detail_seed, 2.5, 7.0), c)
			# rebar stubs bent out of the broken top
			for i in int(size.x / 70.0):
				if rng.randf() < 0.6:
					var x := rng.randf_range(8, size.x - 8)
					var bend := rng.randf_range(-6, 6)
					draw_polyline(PackedVector2Array([Vector2(x, 0), Vector2(x + bend * 0.3, -6), Vector2(x + bend, -rng.randf_range(9, 16))]), c, 1.4)
		Style.PLANKS:
			draw_rect(Rect2(0, 3, size.x, size.y - 3), c)
			var x := 0.0
			while x < size.x:
				var w := rng.randf_range(14, 22)
				var lift := rng.randf_range(-1.2, 0.6)
				draw_rect(Rect2(x + 0.6, lift, minf(w, size.x - x) - 1.2, 4.0), c)
				x += w
			draw_line(Vector2(-3, size.y * 0.5), Vector2(size.x + 3, size.y * 0.5), c, 3.0)
		Style.STEEL:
			draw_rect(r, c)
			draw_rect(Rect2(-2, -1, size.x + 4, 3), c)
			DrawKit.bolts(self, Vector2(4, -1.5), Vector2(size.x - 4, -1.5), 11.0, 1.4)
		Style.EARTH:
			var pts := PackedVector2Array([Vector2(0, size.y)])
			var x := 0.0
			while x <= size.x:
				pts.append(Vector2(x, rng.randf_range(-2.0, 1.0) if x > 0.0 and x < size.x else 0.0))
				x += 6.0
			pts.append(Vector2(size.x, size.y))
			draw_colored_polygon(pts, c)
			for i in int(size.x / 9.0):
				var gx := rng.randf_range(0, size.x)
				draw_line(Vector2(gx, 0), Vector2(gx - 1.5, -rng.randf_range(3, 8)), c, 1.0)

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "size", "pos": size}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	size = p.max(Vector2(8, 8))
