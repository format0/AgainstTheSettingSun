shader_type canvas_item;
// Light shafts, step 2: smear the unblocked sunlight away from the sun, so it streams
// through gaps, windows, lattices and between branches.

uniform sampler2D src : filter_linear;
uniform vec2 sun_uv = vec2(0.5, 0.8);
uniform float length_k = 0.96;

void fragment() {
	vec2 delta = (UV - sun_uv) / 64.0 * length_k;
	vec2 p = UV;
	float decay = 1.0;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 64; i++) {
		p -= delta;
		acc += texture(src, p).rgb * decay;
		decay *= 0.962;
	}
	COLOR = vec4(acc / 14.0, 1.0);
}
