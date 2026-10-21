class_name PostEffect
extends CanvasLayer
## Base for full-screen effects that read what has been drawn so far and change it
## (wet ground, light shafts, the camera lens). Each sits on its own CanvasLayer with a
## BackBufferCopy, so they stack in layer order.

var material: ShaderMaterial


func _setup(shader: Shader, canvas_layer: int) -> void:
	layer = canvas_layer
	add_to_group("effects")
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	add_child(rect)
