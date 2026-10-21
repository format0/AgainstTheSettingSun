shader_type canvas_item;
// Molten steel: a slow, glowing surface with dark crust drifting on it, bubbles that swell
// and pop, white-hot seams, and a body that gets darker and redder with depth.

uniform vec2 rect_size = vec2(200.0, 60.0);
uniform float weather_time = 0.0;
uniform float world_x = 0.0;
uniform float heat = 1.0;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }
float fbm(vec2 p){ float s = 0., a = .5; for (int i = 0; i < 4; i++){ s += a * vnoise(p); p *= 2.03; a *= .5; } return s; }

void fragment() {
	vec2 L = UV * rect_size;
	float wx = L.x + world_x;
	float t = weather_time;
	float surf = 4.0 + sin(wx * 0.05 + t * 0.9) * 1.2 + sin(wx * 0.13 - t * 1.3) * 0.6;
	// bubbles rising out of the surface
	float cell = floor(wx / 26.0);
	float bh = hash12(vec2(cell, 3.7));
	float life = fract(t * (0.25 + bh * 0.3) + bh * 5.0);
	float bx = (cell + 0.3 + bh * 0.4) * 26.0;
	float br = 5.0 * smoothstep(0.0, 0.8, life) * step(life, 0.9);
	float dome = sqrt(max(br * br - (wx - bx) * (wx - bx), 0.0));
	surf -= dome;
	if (L.y < surf) {
		COLOR = vec4(0.0);
	} else {
		float depth = L.y - surf;
		float n = fbm(vec2(wx * 0.03 + t * 0.05, depth * 0.06 - t * 0.02));
		float crust = smoothstep(0.52, 0.66, fbm(vec2(wx * 0.022 - t * 0.04, t * 0.03)) ) * smoothstep(9.0, 2.0, depth);
		vec3 hot = vec3(1.0, 0.86, 0.5);
		vec3 warm = vec3(1.0, 0.42, 0.08);
		vec3 deep = vec3(0.35, 0.04, 0.0);
		vec3 col = mix(hot, warm, smoothstep(0.0, 10.0, depth + n * 8.0));
		col = mix(col, deep, smoothstep(6.0, 22.0, depth));
		col = mix(col, vec3(0.04, 0.008, 0.0), smoothstep(18.0, 44.0, depth));
		float seam = smoothstep(0.03, 0.0, abs(n - 0.5)) * smoothstep(14.0, 0.0, depth);
		col += hot * seam * 0.6;
		col = mix(col, vec3(0.08, 0.02, 0.0), crust * 0.85);
		col *= heat * (0.9 + 0.1 * sin(t * 2.0 + wx * 0.02));
		COLOR = vec4(col, 1.0);
	}
}
