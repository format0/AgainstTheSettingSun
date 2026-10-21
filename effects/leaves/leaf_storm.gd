@icon("res://effects/effect_icon.svg")
class_name LeafStorm
extends Node2D
## Leaves, seeds and scraps of paper blowing through the picture on the wind: a few in a
## breeze, a stream in a storm. Some fly in front of the player, some behind.

@export var amount := 60
## More or fewer at the same wind.
@export_range(0.0, 2.0) var density := 1.0

var _back: GPUParticles2D
var _front: GPUParticles2D


func _ready() -> void:
	add_to_group("effects")
	_back = _make(Layers.ELEMENTS_BACK, 0.7)
	_front = _make(Layers.GRASS, 1.2)


func _make(z: int, scale_k: float) -> GPUParticles2D:
	var fx := LeafParticles.make(Vector2(40, 330), amount)
	fx.lifetime = 9.0
	fx.z_as_relative = false
	fx.z_index = z
	fx.preprocess = 6.0
	var pm := fx.process_material as ParticleProcessMaterial
	pm.scale_min = 0.6 * scale_k
	pm.scale_max = 1.3 * scale_k
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 120.0
	pm.spread = 30.0
	pm.damping_min = 0.0
	pm.damping_max = 5.0
	add_child(fx)
	return fx


func _process(_delta: float) -> void:
	var view := GameCamera.view_rect
	for fx in [_back, _front]:
		var p := fx as GPUParticles2D
		p.global_position = Vector2(view.end.x + 60.0, view.position.y + view.size.y * 0.45)
		var pm := p.process_material as ParticleProcessMaterial
		pm.gravity = Vector3(-Weather.wind * 220.0 * (0.5 + 0.6 * Weather.gust), 30.0, 0.0)
		p.amount_ratio = clampf((Weather.wind - 0.2) * 0.8 * density * maxf(Weather.storm, 0.4), 0.0, 1.0)


func set_effect_enabled(on: bool) -> void:
	_back.emitting = on
	_front.emitting = on
