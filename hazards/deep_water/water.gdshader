shader_type canvas_item;
// Dark water: a wavy surface line that catches the last light, a mirror image of the sky and
// the silhouettes above it that fades with depth, and rings where the rain hits.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(300.0, 120.0);
uniform vec2 view_size = vec2(1366.0, 768.0);
uniform float weather_time = 0.0;
uniform float world_x = 0.0;
uniform float wind = 0.5;
uniform float storm = 1.0;
uniform float light = 1.0;
uniform float reflect = 0.55;
uniform vec3 glint : source_color = vec3(1.0, 0.70, 0.45);

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

float wave(float x) {
	return sin(x * 0.045 + weather_time * 1.8) * (0.6 + wind * 1.2) + sin(x * 0.12 - weather_time * 2.9) * (0.3 + wind * 0.6);
}

void fragment() {
	vec2 L = UV * rect_size;
	float wx = L.x + world_x;
	float surf = wave(wx) + 3.0;
	if (L.y < surf) {
		COLOR = vec4(0.0);
	} else {
		float depth = L.y - surf;
		// rain rings
		vec2 cs = vec2(18.0, 6.0);
		vec2 wp = vec2(wx, depth * 3.0);
		vec2 id = floor(wp / cs);
		float h = hash12(id);
		vec2 ctr = (id + 0.25 + 0.5 * vec2(hash12(id + 2.3), hash12(id + 5.1))) * cs;
		float ph = fract(weather_time * (0.8 + 0.6 * h) * (0.4 + 0.6 * storm) + h * 7.0);
		vec2 dv = (wp - ctr) * vec2(1.0, 2.0);
		float ring = exp(-pow((length(dv) - ph * 8.0) * 1.0, 2.0)) * (1.0 - ph) * step(depth, 18.0) * min(storm, 1.0);
		// reflection of whatever is above the surface
		float ripple = sin(wx * 0.3 + depth * 0.8 - weather_time * 4.0) * (0.8 + wind) + ring * 2.0;
		vec2 ruv = SCREEN_UV + vec2(ripple, -2.0 * depth - 2.0 * surf) / view_size;
		vec3 refl = textureLod(screen_tex, ruv, 1.0).rgb;
		float fade = exp(-depth / 34.0);
		vec3 col = refl * reflect * fade;
		col += glint * smoothstep(2.2, 0.0, depth) * 0.45 * light;
		col += glint * ring * 0.18 * light;
		COLOR = vec4(col, 1.0);
	}
}
