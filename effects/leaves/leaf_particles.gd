class_name LeafParticles
extends RefCounted
## Builds the leaf particles trees shed and that blow across the level, all in black.


static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null:
		var img := Image.create(10, 5, false, Image.FORMAT_RGBA8)
		for y in 5:
			for x in 10:
				var d := Vector2((x - 4.5) / 5.0, (y - 2.0) / 2.5).length()
				img.set_pixel(x, y, Color(0, 0, 0, clampf((1.0 - d) * 3.0, 0.0, 1.0)))
		_texture = ImageTexture.create_from_image(img)
	return _texture


## Leaves falling from an area of `extents` around the emitter.
static func make(extents: Vector2, amount: int) -> GPUParticles2D:
	var fx := GPUParticles2D.new()
	Game.no_occlude(fx)
	fx.texture = texture()
	fx.amount = amount
	fx.lifetime = 7.0
	fx.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extents.x, extents.y, 0)
	pm.direction = Vector3(-1, 0, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 50.0
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.damping_min = 8.0
	pm.damping_max = 20.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.5
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	fx.process_material = pm
	fx.visibility_rect = Rect2(-2400, -800, 2800, 1600)
	return fx


## Call every frame: the wind carries the leaves, more of them in a storm.
static func blow(fx: GPUParticles2D, world_x: float, rate := 0.8) -> void:
	var pm := fx.process_material as ParticleProcessMaterial
	pm.gravity = Vector3(-Weather.wind * 170.0 * (0.5 + 0.7 * Weather.gust_at(world_x)), 35.0, 0.0)
	fx.amount_ratio = clampf(Weather.wind * maxf(Weather.storm, 0.3) * rate * VFX.v("leaves"), 0.0, 1.0)
