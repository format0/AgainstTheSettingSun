// The whole sky as a function of a point on the screen L (in pixels of a view_size picture):
// the gradient and the sun from sky_base, two layers of domain-warped clouds drifting in the
// wind, clouds lit from inside by lightning, the afterglow, stars, silent far lightning.
// Used by the sky itself and by the editor's preview of a level.
#include "res://effects/sky/sky_base.gdshaderinc"

uniform float weather_time = 0.0;
uniform float cam_x = 0.0;
uniform float flash = 0.0;
uniform float bolt_x = 0.0;
uniform float cloud_cover = 0.40;
uniform float afterglow = 1.0;
uniform float far_flash = 0.0;   // silent lightning far away, inside the clouds on the horizon
uniform float far_x = 600.0;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }
float fbm(vec2 p){ float s = 0., a = .5; mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
  for (int i = 0; i < 5; i++){ s += a * vnoise(p); p = m * p; a *= .5; } return s; }

vec3 sky_color(vec2 L) {
	float h = L.y / view_size.y;
	// the palette drains from orange to wine red to a deep blue-violet night
	float d1 = smoothstep(0.3, 0.78, dusk);
	float d2 = smoothstep(0.66, 1.0, dusk);
	vec3 c = sky_gradient(L);
	// near the horizon the sun is squashed flat and reddened by the thick air
	float low = sky_sun_low();
	float d = sky_sun_dist(L);
	// after it has gone down the clouds still catch its light from below
	float ag = smoothstep(.22, .45, dusk) * (1. - smoothstep(.78, .97, dusk)) * afterglow;

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
	vec3 dark = mix(vec3(.075, .03, .035), vec3(.012, .01, .02), d2);
	vec3 lit = mix(mix(vec3(.95, .40, .14), vec3(.7, .18, .1), d1), vec3(.10, .04, .06), d2);
	lit = mix(lit, vec3(.95, .26, .24), ag * .55);
	sun_near = max(sun_near, ag * .45 * smoothstep(.35, .7, h));
	float rim1 = clamp(dens1 * (1. - dens1) * 3.2, 0., 1.);
	c = mix(c, mix(dark, lit, (.18 + .55 * sun_near) * under) + vec3(1., .62, .3) * rim1 * sun_near * 1.1, dens1 * .93);
	float rim2 = clamp(dens2 * (1. - dens2) * 3.2, 0., 1.);
	c = mix(c, mix(dark * .8, lit * 1.05, (.10 + .7 * sun_near) * under) + vec3(1., .6, .28) * rim2 * sun_near * 1.4, dens2 * .88);

	float disk = smoothstep(37., 34., d) * (1. - dens2 * .85);
	// thin slivers of cloud drawn across the low sun
	disk *= 1. - low * .85 * smoothstep(.55, .62, vnoise(vec2(L.x * .012 + t * .02, L.y * .2)));
	c = mix(c, mix(mix(vec3(1., .96, .82), vec3(1., .55, .3), d1), vec3(1., .38, .2), low * .6), disk * (1. - d2));
	// the pink band of the afterglow above the horizon, away from where the sun went down
	float band = smoothstep(.5, .66, h) * (1. - smoothstep(.72, .82, h));
	c += vec3(.38, .12, .2) * band * ag * .55 * smoothstep(200., 900., abs(L.x - sun_pos.x));
	// first stars where the clouds are thin
	float star = step(.9975, hash12(floor(L / 2.0) + 17.0)) * smoothstep(.65, .95, dusk) * (1. - smoothstep(.0, .5, h)) * (1. - dens1) * (1. - dens2);
	c += vec3(.8, .82, 1.) * star * (.5 + .5 * sin(weather_time * 3. + L.x));

	float fl = exp(-abs(L.x - far_x) / 230.) * smoothstep(.42, .8, h) * (1. - smoothstep(.8, .86, h));
	c += vec3(1., .72, .55) * far_flash * fl * (.06 + (dens1 + dens2 * .7) * .5);
	float near = exp(-abs(L.x - bolt_x) / 380.);
	c += vec3(.55, .62, .95) * flash * (.18 + (dens1 + dens2) * 1.1 * near);
	c *= mix(1., .78, clamp(storm - 1., 0., 1.));
	return c;
}
