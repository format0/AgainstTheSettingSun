shader_type canvas_item;
render_mode blend_add, unshaded;
// Orange light thrown up by molten metal onto the rain and the steam above it.

uniform vec2 rect_size = vec2(300.0, 200.0);
uniform float surface_y = 160.0;
uniform float intensity = 1.0;
uniform float weather_time = 0.0;
uniform vec3 color : source_color = vec3(1.0, 0.45, 0.12);

void fragment() {
	vec2 L = UV * rect_size;
	float above = surface_y - L.y;
	float edge = smoothstep(0.0, 70.0, L.x) * smoothstep(rect_size.x, rect_size.x - 70.0, L.x);
	float g = exp(-max(above, 0.0) / 70.0) * step(0.0, above + 2.0) * edge;
	float flicker = 0.85 + 0.15 * sin(weather_time * 7.0 + L.x * 0.02) * sin(weather_time * 3.3);
	COLOR = vec4(color * g * 0.32 * intensity * flicker, 1.0);
}
