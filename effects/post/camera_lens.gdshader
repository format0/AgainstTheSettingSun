shader_type canvas_item;
// The last step before the image reaches the screen: glow around bright lights (bloom),
// raindrops on the lens, a touch of colour fringing, colour grading, vignette and film grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float weather_time = 0.0;
uniform float flash = 0.0;
uniform float bloom = 1.0;
uniform float bloom_threshold = 0.78;
uniform float lens_rain = 0.8;
uniform float fringe = 1.0;
uniform float vignette = 0.55;
uniform float grain = 0.05;
uniform float aspect = 1.778;
uniform float darkness = 0.0;   // the night closing in at the end of the level

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

vec3 lens_drops(vec2 uv) {
	vec2 p = uv * vec2(aspect, 1.0);
	vec3 r = vec3(0.0);
	// beads that form and evaporate
	vec2 g = p * 13.0;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash12(id);
	vec2 c = (vec2(hash12(id + 3.1), hash12(id + 7.7)) - 0.5) * 0.55;
	float rad = mix(0.07, 0.2, hash12(id + 1.7));
	float life = fract(weather_time * 0.05 + h * 3.0);
	float vis = smoothstep(0.0, 0.06, life) * smoothstep(1.0, 0.55, life) * step(0.72, h);
	vec2 d = f - c;
	float m = smoothstep(rad, rad * 0.65, length(d)) * vis;
	r.xy += d / rad * m * 0.007;
	r.z = max(r.z, m);
	// drops sliding down, leaving a trail of tiny beads
	float cols = 11.0;
	float cw = aspect / cols;
	float cid = floor(p.x / cw);
	float hc = hash12(vec2(cid, 4.2));
	if (hc > 0.35) {
		float T = weather_time * (0.05 + hc * 0.07) + hc * 9.0;
		float cy = -0.15 + fract(T) * 1.35;                       // top to bottom in screen space
		float cx = (cid + 0.5) * cw + 0.28 * cw * sin(T * 6.2 + hc * 6.0);
		float rr = 0.010 + 0.009 * hc;
		vec2 dd = p - vec2(cx, cy);
		float md = smoothstep(rr, rr * 0.55, length(dd * vec2(1.0, 0.85)));
		float trail = step(dd.y, 0.0) * (1.0 - smoothstep(0.0, 0.28, -dd.y)) * smoothstep(rr * 0.6, 0.0, abs(dd.x));
		float beads = smoothstep(0.32, 0.0, length(vec2(dd.x / rr * 1.4, fract(dd.y * 38.0) - 0.5))) * trail;
		r.xy += dd / rr * md * 0.022 - vec2(0.0, 1.0) * beads * 0.004;
		r.z = max(r.z, max(md, beads * 0.6));
	}
	return r;
}

void fragment() {
	vec2 uv0 = SCREEN_UV;
	vec3 dr = lens_rain > 0.0 ? lens_drops(uv0) * lens_rain : vec3(0.0);
	vec2 uv = uv0 - dr.xy;
	vec2 cc = uv - 0.5;
	float ca = 0.0022 * dot(cc, cc) * 4.0 * fringe;
	vec3 col;
	col.r = textureLod(screen_tex, uv + cc * ca, 0.0).r;
	col.g = textureLod(screen_tex, uv, 0.0).g;
	col.b = textureLod(screen_tex, uv - cc * ca, 0.0).b;
	if (bloom > 0.0) {
		vec3 b = vec3(0.0);
		b += max(textureLod(screen_tex, uv, 2.0).rgb - bloom_threshold, 0.0) * 0.6;
		b += max(textureLod(screen_tex, uv, 3.5).rgb - bloom_threshold * 0.9, 0.0) * 0.9;
		b += max(textureLod(screen_tex, uv, 5.0).rgb - bloom_threshold * 0.8, 0.0) * 1.2;
		col += b * bloom * 1.6;
	}
	col += vec3(0.5, 0.55, 0.75) * flash * 0.06;
	col += dr.z * 0.025 * col;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 1.07);
	col = pow(max(col, 0.0), vec3(1.12));
	col = col / (1.0 + max(col - 0.92, 0.0) * 0.5);
	vec2 v = uv0 - 0.5;
	col *= 1.0 - vignette * pow(length(v * vec2(1.0, 0.82)) * 1.25, 2.4);
	float closing = 1.0 - smoothstep(0.25 - darkness * 0.2, 0.75 - darkness * 0.45, length(v * vec2(aspect, 1.0) * 0.6));
	col *= mix(1.0, closing, darkness);
	col += (hash12(FRAGCOORD.xy + fract(weather_time * 7.3) * 731.0) - 0.5) * grain * sqrt(max(lum, 0.0));
	COLOR = vec4(col, 1.0);
}
