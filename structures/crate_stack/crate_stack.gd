@tool
@icon("res://structures/crate_stack/crate_stack_icon.svg")
class_name CrateStack
extends StaticBody2D
## Old wooden crates stacked against each other, to climb on. They don't move (for a crate
## that can be pushed, use PushCrate). Each column is a number of crates; the node's
## position is the bottom-left corner.

@export var stacks := PackedInt32Array([2, 1]):
	set(v):
		stacks = v
		_rebuild()
@export var crate_size := 32.0:
	set(v):
		crate_size = v
		_rebuild()
@export var stack_seed := 1:
	set(v):
		stack_seed = v
		_rebuild()
@export var surface := "wood"

var _crates: Array[Rect2] = []


func _ready() -> void:
	z_index = Layers.ELEMENTS
	add_to_group("rain_surfaces")
	_rebuild()


func _rebuild() -> void:
	_crates.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = stack_seed
	var x := 0.0
	for n in stacks:
		var w := crate_size * rng.randf_range(0.9, 1.15)
		for k in n:
			var s := Vector2(w, crate_size * rng.randf_range(0.85, 1.0))
			var off := rng.randf_range(-2.0, 2.0) if k > 0 else 0.0
			var y := 0.0
			for r in _crates:
				if absf(r.get_center().x - (x + w * 0.5)) < w * 0.5:
					y = minf(y, r.position.y)
			_crates.append(Rect2(Vector2(x + off, y - s.y), s))
		x += w + 1.0
	if not is_inside_tree():
		return
	for ch in get_children():
		if ch is CollisionShape2D:
			ch.queue_free()
	for r in _crates:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		cs.shape = rect
		cs.position = r.get_center()
		add_child(cs)
	queue_redraw()


func get_rain_edges() -> Array:
	var out := []
	for r in _crates:
		out.append([global_transform * r.position, global_transform * Vector2(r.end.x, r.position.y)])
	return out


func _draw() -> void:
	for r in _crates:
		PushCrate.draw_crate(self, r, int(r.position.x * 3.0 + r.position.y))

# ------------------------------------------------------------------ editor (Level Tools)

func _editor_rect() -> Rect2:
	var h := 0
	for k in stacks:
		h = maxi(h, k)
	return Rect2(0, -h * crate_size, stacks.size() * crate_size, h * crate_size)


func _editor_handles() -> Array[Dictionary]:
	return [{"id": "crate_size", "pos": Vector2(stacks.size() * crate_size, 0)}]


func _editor_drag(_id: Variant, p: Vector2) -> void:
	crate_size = maxf(12.0, p.x / maxf(1.0, stacks.size()))
