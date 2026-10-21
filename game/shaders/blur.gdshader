shader_type canvas_item;
// Bloom, steps 2..: a separable Gaussian blur, one direction per pass.

uniform sampler2D src : filter_linear;
uniform vec2 dir = vec2(0.001, 0.0);

void fragment() {
	vec3 c = texture(src, UV).rgb * 0.227;
	c += (texture(src, UV + dir * 1.385).rgb + texture(src, UV - dir * 1.385).rgb) * 0.316;
	c += (texture(src, UV + dir * 3.231).rgb + texture(src, UV - dir * 3.231).rgb) * 0.070;
	COLOR = vec4(c, 1.0);
}
