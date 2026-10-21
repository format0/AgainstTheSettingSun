shader_type canvas_item;
// Stateless rain: every drop is one instance of a quad. Its position is computed from its
// random seed and the time, so tens of thousands of drops cost almost nothing on the CPU.
// INSTANCE_CUSTOM = (x seed, y seed, depth seed, length seed). The node follows the camera,
// so VERTEX is in screen pixels.

uniform vec2 view_size = vec2(1366.0, 768.0);
uniform float weather_time = 0.0;
uniform float cam_x = 0.0;
uniform float wind_acc = 0.0;
uniform float wind_angle = 0.2;
uniform float depth_min = 0.0;
uniform float depth_max = 1.0;
uniform float flash = 0.0;
uniform float opacity = 1.0;
uniform float ground_y = 635.0;     // ground line in screen pixels
uniform vec3 lamps[6];             // screen x, screen y, brightness
uniform vec3 rain_color : source_color = vec3(0.80, 0.74, 0.70);
uniform vec3 lit_color : source_color = vec3(1.0, 0.80, 0.52);
uniform float light = 1.0;
uniform sampler2D occluders : filter_linear;   // the level's silhouettes (alpha), from the Game
uniform float shelter = 0.0;                    // 1 = no drops under roofs and beams
uniform float gusts = 1.0;                      // denser sheets of rain sweeping past in gusts
uniform float gust_strength = 0.5;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }

varying float v_along;
varying float v_across;
varying float v_y;
varying float v_ground;
varying float v_alpha;
varying vec3 v_col;

void vertex() {
	vec4 s = INSTANCE_CUSTOM;
	vec2 corner = VERTEX;
	float z = mix(depth_min, depth_max, s.z);
	float z2 = z * z;
	float speed = mix(430.0, 1500.0, z2);
	float len = mix(7.0, 74.0, z2) * (0.6 + 0.8 * s.w);
	float span_h = view_size.y + 260.0;
	float y = mod(s.y * span_h + weather_time * speed, span_h) - 130.0;
	float span_w = view_size.x + 520.0;
	float x = mod(s.x * span_w - cam_x * mix(0.35, 1.35, z) - wind_acc * speed, span_w) - 260.0;
	// gusts sweep through as bands: more slant and denser rain inside them
	float xw = x + cam_x;
	float band = vnoise(vec2(xw * 0.0035 + weather_time * (0.6 + gust_strength * 1.4), y * 0.002 + weather_time * 0.05));
	float sheet = smoothstep(0.5, 0.85, band) * gusts;
	vec2 dir = normalize(vec2(-tan(wind_angle * (1.0 + sheet * 0.5)), 1.0));
	vec2 head = vec2(x, y);
	vec2 perp = vec2(dir.y, -dir.x);
	float w = mix(0.55, 2.3, z2);
	VERTEX = head - dir * len * (1.0 - corner.y) + perp * w * (corner.x - 0.5);

	float lit = 0.0;
	for (int i = 0; i < 6; i++) {
		vec2 d = head - lamps[i].xy;
		float cone = (d.y > 0.0 && d.y < 150.0) ? (1.0 - smoothstep(0.36, 0.62, abs(d.x) / (d.y + 7.0))) * exp(-d.y / 140.0) : 0.0;
		lit += lamps[i].z * (cone + exp(-length(d) / 26.0));
	}
	lit = clamp(lit, 0.0, 1.5);
	v_col = mix(rain_color * (0.25 + 0.75 * light), lit_color, clamp(lit, 0.0, 1.0)) + vec3(0.2, 0.25, 0.4) * flash;
	v_alpha = mix(0.04, 0.16, z) * (0.5 + 0.5 * light + lit * 3.0 + flash * 1.6) * opacity;
	v_alpha *= 1.0 + sheet * 1.4 - gusts * 0.25;
	if (shelter > 0.5) {
		// look upwind along the fall line: anything solid above means this drop is sheltered
		float cover = 0.0;
		for (int k = 1; k <= 5; k++) {
			vec2 q = head - dir * (float(k * k) * 9.0 + 6.0);
			// only something at least ~8 px thick keeps the rain off (not a wire or a thin chord)
			float a = min(textureLod(occluders, q / view_size, 0.0).a, textureLod(occluders, (q - dir * 8.0) / view_size, 0.0).a);
			cover = max(cover, a);
		}
		v_alpha *= 1.0 - smoothstep(0.55, 0.85, cover);
	}
	v_along = corner.y;
	v_across = corner.x * 2.0 - 1.0;
	v_y = VERTEX.y;
	v_ground = ground_y + (z - 0.45) * 170.0;   // nearer drops land lower on screen
}

void fragment() {
	if (v_y > v_ground) discard;
	float a = v_alpha * pow(v_along, 1.6) * (1.0 - v_across * v_across);
	COLOR = vec4(v_col, a);
}
