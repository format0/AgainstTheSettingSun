shader_type canvas_item;
// Wet ground: a faint sheen of the sky on the whole ground, and puddles that mirror the
// world above them with rain ripples.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 view_size = vec2(1366.0, 768.0);
uniform float horizon = 636.0;        // ground line in screen pixels
uniform float weather_time = 0.0;
uniform float cam_x = 0.0;
uniform float storm = 1.0;
uniform float sheen = 0.07;
uniform vec4 puddles[8];              // screen x, half width, y offset, seed (half width 0 = unused)

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }

void fragment() {
	vec2 L = UV * view_size;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	if (L.y > horizon + 0.5) {
		float depth = L.y - horizon;
		float k_sheen = sheen * exp(-depth / 12.0);
		float pud = 0.0;
		for (int i = 0; i < 8; i++) {
			vec4 P = puddles[i];
			if (P.y <= 0.0) continue;
			vec2 e = (L - vec2(P.x, horizon + 6.0 + P.z)) / vec2(P.y, 4.5 + P.y * .035);
			float wob = vnoise(vec2((L.x + cam_x) * .045, L.y * .4) + P.w) * .55;
			pud = max(pud, smoothstep(1.05, .72, dot(e, e) + wob));
		}
		float k = max(k_sheen, pud * .5);
		if (k > .003) {
			vec2 wp = vec2(L.x + cam_x, L.y);
			vec2 cs = vec2(15., 5.);
			vec2 id = floor(wp / cs);
			float h = hash12(id);
			vec2 ctr = (id + .25 + .5 * vec2(hash12(id + 2.3), hash12(id + 5.1))) * cs;
			float ph = fract(weather_time * (.7 + .6 * h) * (.4 + .6 * storm) + h * 7.);
			vec2 dv = (wp - ctr) * vec2(1., 3.);
			float ring = exp(-pow((length(dv) - ph * 7.) * 1.1, 2.)) * (1. - ph) * pud;
			vec2 disp = (length(dv) > .01 ? normalize(dv) : vec2(0.)) * ring * 1.6;
			disp.x += sin(wp.y * 1.7 + weather_time * 3.) * .5 * pud;
			vec2 R = vec2(L.x + disp.x, horizon - depth * 1.05 + disp.y * 2.);
			vec2 ruv = SCREEN_UV + (R - L) / view_size;
			vec3 r = texture(screen_tex, ruv).rgb * .6 + texture(screen_tex, ruv + vec2(0., -2.5) / view_size).rgb * .4;
			c += r * k * vec3(.86, .86, .92) + vec3(.9, .8, .7) * ring * .10;
		}
	}
	COLOR = vec4(c, 1.0);
}
