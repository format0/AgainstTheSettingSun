// The clear sky without clouds: the colour gradient that drains from orange to wine red to
// night, and the glow around the sun. Shared by the sky itself and by the haze that the
// distant scenery is seen through, so the far hills fade into exactly the sky behind them.

uniform vec2 view_size = vec2(1366.0, 768.0);
uniform vec2 sun_pos = vec2(560.0, 622.0);
uniform float storm = 1.0;
uniform float dusk = 0.0;
uniform float sun_glow = 1.0;
uniform float sun_squash = 1.0;
uniform vec3 zenith : source_color = vec3(0.045, 0.022, 0.035);
uniform vec3 high_sky : source_color = vec3(0.26, 0.06, 0.05);
uniform vec3 low_sky : source_color = vec3(0.78, 0.25, 0.07);
uniform vec3 horizon : source_color = vec3(0.92, 0.42, 0.13);

// How low the sun is (it gets squashed and reddened near the horizon).
float sky_sun_low() {
	return smoothstep(.62, .84, sun_pos.y / view_size.y) * sun_squash;
}

float sky_sun_dist(vec2 L) {
	return length((L - sun_pos) * vec2(1., 1.2 + .55 * sky_sun_low()));
}

vec3 sky_gradient(vec2 L) {
	float h = L.y / view_size.y;
	float d1 = smoothstep(0.3, 0.78, dusk);
	float d2 = smoothstep(0.66, 1.0, dusk);
	vec3 zen = mix(mix(zenith, vec3(0.03, 0.02, 0.045), d1), vec3(0.006, 0.007, 0.016), d2);
	vec3 hi = mix(mix(high_sky, vec3(0.16, 0.04, 0.07), d1), vec3(0.02, 0.018, 0.04), d2);
	vec3 lo = mix(mix(low_sky, vec3(0.55, 0.12, 0.08), d1), vec3(0.06, 0.03, 0.06), d2);
	vec3 hor = mix(mix(horizon, vec3(0.80, 0.26, 0.10), d1), vec3(0.16, 0.05, 0.06), d2);
	vec3 c = mix(zen, hi, smoothstep(0., .45, h));
	c = mix(c, lo, smoothstep(.36, .72, h));
	c = mix(c, hor, smoothstep(.70, .83, h));
	float d = sky_sun_dist(L);
	c += vec3(1., .50, .16) * (exp(-d / 240.) * .30 + exp(-d / 60.) * .5) * smoothstep(.15, .8, h + .1) * sun_glow;
	return c;
}
