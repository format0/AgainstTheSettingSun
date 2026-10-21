@icon("res://creatures/starlings/starlings_icon.svg")
class_name Starlings
extends Node2D
## A murmuration: a great flock of starlings flying home over the horizon in the evening,
## swelling, folding and thinning as it turns. Put one anywhere in a level; it lives in the
## sky above the far scenery and drifts across once, while the sun goes down.

## The part of the sunset (0..1) during which the flock crosses the sky.
@export_range(0.0, 1.0) var starts_at := 0.15
@export_range(0.0, 1.0) var ends_at := 0.55
@export var birds := 260
## Height of the flock's path on the screen (0 = top, 1 = bottom).
@export_range(0.1, 0.7) var height := 0.32
@export var from_left := true

var _seeds := PackedVector3Array()


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.DISTANT_FAR + 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in birds:
		# a point in a disc, denser towards the middle
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (0.6 + 0.4 * rng.randf())
		_seeds.append(Vector3(cos(a) * r, sin(a) * r, rng.randf() * TAU))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var u := inverse_lerp(starts_at, ends_at, Daylight.progress)
	if not VFX.on("flocks") or u <= 0.0 or u >= 1.0:
		return
	var view := GameCamera.view_rect
	var t := Weather.time
	var dir := 1.0 if from_left else -1.0
	# the flock's path: across the screen in a long, slow arc, a little parallax with the view
	var cx := lerpf(-0.25, 1.25, u) if from_left else lerpf(1.25, -0.25, u)
	var centre := view.position + Vector2(cx * view.size.x - view.position.x * 0.04 * dir, view.size.y * (height + 0.06 * sin(u * 7.0)))
	# the shape breathes and folds: stretched, squeezed and turned by slow waves
	var w := 120.0 + 70.0 * sin(t * 0.23) + 40.0 * sin(t * 0.61 + 1.0)
	var h := 40.0 + 22.0 * sin(t * 0.31 + 2.0)
	var turn := 0.35 * sin(t * 0.17) + 0.12 * sin(t * 0.53)
	var col := Color(0.05, 0.02, 0.02, 0.9 * smoothstep(0.0, 0.08, u) * smoothstep(1.0, 0.92, u))
	for s in _seeds:
		var q := Vector2(s.x * w, s.y * h)
		# a wave of density running through the flock
		q.x += sin(s.y * 3.0 + t * 0.9) * 26.0
		q.y += sin(s.x * 4.0 + t * 1.1) * 14.0 + sin(s.x * 9.0 - t * 2.0) * 4.0
		var p := centre + q.rotated(turn)
		var flap := sin(t * 18.0 + s.z * 7.0)
		draw_line(p + Vector2(-1.8, -flap * 1.1), p, col, 1.3)
		draw_line(p, p + Vector2(1.8, -flap * 1.1), col, 1.3)
