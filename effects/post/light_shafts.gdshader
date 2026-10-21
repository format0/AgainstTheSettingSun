shader_type canvas_item;
render_mode blend_add;
// God rays: march from each pixel toward the sun through the image and gather the bright
// sky in between. Black silhouettes block it, so cranes and trees cast shafts of light.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 sun_uv = vec2(0.41, 0.81);
uniform float aspect = 1.778;
uniform float strength = 0.38;
uniform float threshold = 0.55;
uniform vec3 tint : source_color = vec3(1.0, 0.58, 0.28);
uniform int samples = 48;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 delta = (uv - sun_uv) / float(samples) * 0.96;
	vec2 p = uv;
	float decay = 1.0;
	float acc = 0.0;
	for (int i = 0; i < 64; i++) {
		if (i >= samples) break;
		p -= delta;
		vec3 s = texture(screen_tex, p).rgb;
		float l = max(max(s.r, s.g), s.b);
		float near_sun = exp(-length((p - sun_uv) * vec2(aspect, 1.0)) * 5.0);
		acc += max(l - threshold, 0.0) * near_sun * decay;
		decay *= 0.962;
	}
	COLOR = vec4(tint * acc / float(samples) * 6.0 * strength, 1.0);
}
