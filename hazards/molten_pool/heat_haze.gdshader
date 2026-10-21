shader_type canvas_item;
// Shimmering air above something hot: the image behind wobbles a little.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float weather_time = 0.0;
uniform float strength = 1.0;

void fragment() {
	float fade = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.75, UV.y) * smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	vec2 o = vec2(sin(UV.y * 40.0 - weather_time * 6.0) + sin(UV.x * 23.0 + weather_time * 3.1), cos(UV.y * 31.0 - weather_time * 5.0)) * 0.0012 * strength * fade;
	COLOR = vec4(texture(screen_tex, SCREEN_UV + o).rgb, fade * strength);
}
