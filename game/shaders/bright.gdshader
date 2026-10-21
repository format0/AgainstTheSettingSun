shader_type canvas_item;
// Bloom, step 1 (half size): keep only the bright parts of the picture. Very bright light
// (sun, lamps, molten steel) passes fully; the glowing sky near the sun passes a little,
// which later spreads as a warm haze over the silhouettes.

uniform sampler2D src : filter_linear;
uniform vec2 texel = vec2(0.001, 0.001);
uniform float threshold = 0.72;
uniform float wide = 1.0;

void fragment() {
	vec3 c = (texture(src, UV + texel * vec2(-0.5, -0.5)).rgb + texture(src, UV + texel * vec2(0.5, -0.5)).rgb
		+ texture(src, UV + texel * vec2(-0.5, 0.5)).rgb + texture(src, UV + texel * vec2(0.5, 0.5)).rgb) * 0.25;
	float l = max(c.r, max(c.g, c.b));
	float k = max(smoothstep(threshold, 1.0, l), wide * 0.22 * smoothstep(threshold * 0.5, threshold + 0.15, l));
	COLOR = vec4(c * k, 1.0);
}
