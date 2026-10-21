shader_type canvas_item;
// Drifting fog. mode 0 = a bank in the distance behind the level, mode 1 = low ground fog
// in front of it. Lit warm near the sun and by street lamps, flashes with lightning.

uniform vec2 view_size = vec2(1366.0, 768.0);
uniform float mode = 0.0;
uniform float density = 0.3;
uniform float weather_time = 0.0;
uniform float wind_acc = 0.0;
uniform float cam_x = 0.0;
uniform float parallax = 1.0;
uniform float ground_y = 635.0;   // screen pixels
uniform float flash = 0.0;
uniform vec2 sun_pos = vec2(560.0, 622.0);
uniform vec3 lamps[6];

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }
float fbm(vec2 p, int oct){ float s = 0., a = .5; mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
  for (int i = 0; i < 5; i++){ if (i >= oct) break; s += a * vnoise(p); p = m * p; a *= .5; } return s; }

void fragment() {
	vec2 L = UV * view_size;
	float wx = L.x + cam_x * parallax;
	float g = ground_y;
	float prof = mode < 0.5
		? smoothstep(g - 215.0, g - 75.0, L.y) * (1.0 - smoothstep(g - 35.0, g + 10.0, L.y))
		: smoothstep(g - 75.0, g - 1.0, L.y) * exp(-max(L.y - g - 5.0, 0.0) / 16.0);
	if (prof < 0.001) {
		COLOR = vec4(0.0);
	} else {
		float n = fbm(vec2(wx * .0032 + wind_acc * .55, L.y * .010 - weather_time * .015), 5);
		float n2 = fbm(vec2(wx * .0090 + wind_acc * 1.1, L.y * .024 + weather_time * .05), 3);
		float dens = prof * smoothstep(.30, .85, n * .75 + n2 * .45) * density;
		vec3 col = mix(vec3(.20, .085, .065), vec3(.78, .38, .17), exp(-length(L - sun_pos) / 480.)) * (mode < 0.5 ? 1.0 : 0.55);
		vec3 lamp = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			vec2 d = L - lamps[i].xy;
			lamp += vec3(lamps[i].z * exp(-length(d * vec2(1., .8)) / 85.));
		}
		col += vec3(1., .72, .42) * lamp * 1.25 + vec3(.5, .55, .75) * flash * .7;
		COLOR = vec4(col, dens);
	}
}
