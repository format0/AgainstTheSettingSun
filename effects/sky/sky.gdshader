shader_type canvas_item;
// Stormy sunset sky drawn live: colour gradient, sun with glow, two layers of
// domain-warped clouds drifting in the wind, and clouds lit from inside by lightning.

uniform vec2 view_size = vec2(1366.0, 768.0);
uniform float weather_time = 0.0;
uniform float cam_x = 0.0;
uniform vec2 sun_pos = vec2(560.0, 622.0);
uniform float flash = 0.0;
uniform float bolt_x = 0.0;
uniform float storm = 1.0;
uniform float cloud_cover = 0.40;
uniform vec3 zenith : source_color = vec3(0.045, 0.022, 0.035);
uniform vec3 high_sky : source_color = vec3(0.26, 0.06, 0.05);
uniform vec3 low_sky : source_color = vec3(0.78, 0.25, 0.07);
uniform vec3 horizon : source_color = vec3(0.92, 0.42, 0.13);

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }
float fbm(vec2 p){ float s = 0., a = .5; mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
  for (int i = 0; i < 5; i++){ s += a * vnoise(p); p = m * p; a *= .5; } return s; }

void fragment() {
	vec2 L = UV * view_size;
	float h = L.y / view_size.y;
	vec3 c = mix(zenith, high_sky, smoothstep(0., .45, h));
	c = mix(c, low_sky, smoothstep(.36, .72, h));
	c = mix(c, horizon, smoothstep(.70, .83, h));
	float d = length((L - sun_pos) * vec2(1., 1.2));
	c += vec3(1., .50, .16) * (exp(-d / 240.) * .30 + exp(-d / 60.) * .5) * smoothstep(.15, .8, h + .1);

	vec2 sp = vec2(L.x + cam_x * .06, L.y);
	float t = weather_time;
	vec2 q1 = vec2(sp.x * .0017 + t * .012, sp.y * .0048);
	float w1 = fbm(q1 * 1.7 + vec2(t * .015, 0.));
	float n1 = fbm(q1 + w1 * .85);
	float cover = cloud_cover - .10 * clamp(storm, 0., 1.5);
	float dens1 = smoothstep(cover, cover + .32, n1) * (1. - smoothstep(.50, .74, h));
	vec2 q2 = vec2(sp.x * .0032 + t * .05, sp.y * .010 + 3.);
	float n2 = fbm(q2 + fbm(q2 * 2.1 - t * .03) * .6);
	float dens2 = smoothstep(.48, .78, n2) * smoothstep(.30, .45, h) * (1. - smoothstep(.66, .78, h));

	float sun_near = exp(-d / 520.);
	float under = smoothstep(.15, .7, h);
	vec3 dark = vec3(.075, .03, .035);
	vec3 lit = vec3(.95, .40, .14);
	float rim1 = clamp(dens1 * (1. - dens1) * 3.2, 0., 1.);
	c = mix(c, mix(dark, lit, (.18 + .55 * sun_near) * under) + vec3(1., .62, .3) * rim1 * sun_near * 1.1, dens1 * .93);
	float rim2 = clamp(dens2 * (1. - dens2) * 3.2, 0., 1.);
	c = mix(c, mix(dark * .8, lit * 1.05, (.10 + .7 * sun_near) * under) + vec3(1., .6, .28) * rim2 * sun_near * 1.4, dens2 * .88);

	float disk = smoothstep(37., 34., d) * (1. - dens2 * .85);
	c = mix(c, vec3(1., .96, .82), disk);

	float near = exp(-abs(L.x - bolt_x) / 380.);
	c += vec3(.55, .62, .95) * flash * (.18 + (dens1 + dens2) * 1.1 * near);
	c *= mix(1., .78, clamp(storm - 1., 0., 1.));
	COLOR = vec4(c, 1.);
}
