class_name EmberParticles
extends RefCounted
## Glowing sparks rising from fire and molten steel, carried off by the wind.


static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null:
		var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
		for y in 6:
			for x in 6:
				var d := Vector2(x - 2.5, y - 2.5).length() / 3.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		_texture = ImageTexture.create_from_image(img)
	return _texture


static func make(extents: Vector2, amount: int) -> GPUParticles2D:
	var fx := GPUParticles2D.new()
	fx.texture = texture()
	fx.amount = maxi(amount, 4)
	fx.lifetime = 2.6
	fx.local_coords = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	fx.z_as_relative = false
	fx.z_index = Layers.HAZARD_GLOW
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extents.x, extents.y, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 70.0
	pm.gravity = Vector3(-30, -15, 0)
	pm.scale_min = 0.25
	pm.scale_max = 0.7
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 3.0
	pm.turbulence_noise_scale = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	ramp.add_point(0.4, Color(1.0, 0.5, 0.1, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.1, 0.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	fx.process_material = pm
	fx.visibility_rect = Rect2(-600, -500, 1200, 700)
	return fx
