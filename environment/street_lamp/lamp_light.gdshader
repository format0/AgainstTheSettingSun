shader_type canvas_item;
render_mode blend_add, unshaded;
// Light from one street lamp: a bright core, a soft halo, a cone of light falling through
// the rain and fog, and a pool of light on the wet ground. Drawn additively.

uniform vec2 rect_size = vec2(300.0, 200.0);
uniform vec4 bulbs[4];          // xy = bulb position inside the rect, z = intensity, w = 1 if used
uniform float ground_y = 170.0; // ground line inside the rect
uniform float fog = 1.0;
uniform float world_x = 0.0;
uniform vec3 light_color : source_color = vec3(1.0, 0.76, 0.45);

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }

void fragment() {
	vec2 L = UV * rect_size;
	float n = vnoise(vec2((L.x + world_x) * .018 - TIME * .55, L.y * .03 - TIME * .22)) * .65
	        + vnoise(vec2((L.x + world_x) * .05 + TIME * .3, L.y * .07)) * .35;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		if (bulbs[i].w < .5) continue;
		float I = bulbs[i].z;
		vec2 d = L - bulbs[i].xy;
		float r = length(d);
		acc += light_color * I * (exp(-r / 4.0) * .9 + exp(-r / 30.0) * .12);
		// the wide soft halo of a lamp seen through rain
		acc += light_color * I * exp(-r / 58.0) * (.06 + .08 * fog) * (1.0 - smoothstep(100.0, 125.0, r));
		if (d.y > -2.0) {
			float ang = abs(d.x) / (d.y + 7.0);
			float edge = 1.0 - smoothstep(.40, .64, ang);
			float fall = exp(-d.y / 170.0) * (1.0 - smoothstep(ground_y - 4.0, ground_y + 6.0, L.y));
			acc += light_color * vec3(1.0, .92, .85) * I * edge * fall * (.04 + .13 * n * fog + .03 * fog);
		}
		vec2 g = (L - vec2(bulbs[i].x, ground_y + 4.0)) / vec2(80.0, 7.0);
		acc += light_color * I * exp(-dot(g, g)) * step(ground_y - 1.0, L.y) * .2;
	}
	COLOR = vec4(acc, 1.0);
}
