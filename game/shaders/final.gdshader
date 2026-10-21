shader_type canvas_item;
// The last step: the level's picture plus bloom and light shafts, softened edges and a
// touch of diffusion, raindrops on the lens, colour fringing, grading, vignette, the night
// closing in, and film grain (with halation and a little flicker if wanted).

uniform sampler2D scene : filter_linear;
uniform sampler2D bloom_near : filter_linear;
uniform sampler2D bloom_far : filter_linear;
uniform sampler2D rays : filter_linear;
uniform vec2 scene_texel = vec2(0.0007, 0.0013);
uniform float weather_time = 0.0;
uniform float flash = 0.0;
uniform float aspect = 1.778;
uniform float bloom = 1.0;
uniform float bloom_wide = 1.0;
uniform float rays_amount = 1.0;
uniform float softness = 0.6;
uniform float diffusion = 0.18;
uniform float lens_rain = 0.8;
uniform float chroma = 1.0;
uniform float exposure = 1.0;
uniform float warmth = 0.2;
uniform float saturation = 1.1;
uniform float contrast = 1.0;
uniform float vignette = 0.5;
uniform float grain = 0.05;
uniform float grain_size = 1.6;     // size of a grain in pixels of a 768-line picture
uniform float grain_color = 0.35;   // 0 = grey grain, 1 = each colour layer grains on its own
uniform float film_flicker = 0.0;   // the exposure breathing a little from frame to frame
uniform float halation = 0.0;       // red glow bleeding around bright light, as on film
uniform float darkness = 0.0;
uniform float red_shift = 0.0;   // the light turning red as the sun goes down
uniform float night = 0.0;       // the blue hour: shadows turning cold
uniform float light = 1.0;
uniform float motes = 1.0;
uniform float wind = 0.5;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }

// Film grain: clumps of silver of uneven size, a fresh pattern on every film frame (24 a second).
float film_grain(vec2 p, float frame) {
	vec2 o = vec2(hash12(vec2(frame, 1.7)), hash12(vec2(frame, 9.2))) * 400.0;
	float g = vnoise(p + o) * 0.65 + vnoise(p * 2.13 - o) * 0.35;
	return (g - 0.5) * 2.4;
}

vec3 lens_drops(vec2 uv) {
	vec2 p = uv * vec2(aspect, 1.0);
	vec3 r = vec3(0.0);
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
	float cols = 11.0;
	float cw = aspect / cols;
	float cid = floor(p.x / cw);
	float hc = hash12(vec2(cid, 4.2));
	if (hc > 0.35) {
		float T = weather_time * (0.05 + hc * 0.07) + hc * 9.0;
		float cy = -0.15 + fract(T) * 1.35;
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

vec3 sample_scene(vec2 uv) {
	vec2 cc = uv - 0.5;
	float ca = 0.0022 * dot(cc, cc) * 4.0 * chroma;
	return vec3(texture(scene, uv + cc * ca).r, texture(scene, uv).g, texture(scene, uv - cc * ca).b);
}

void fragment() {
	vec2 uv0 = UV;
	vec3 dr = lens_rain > 0.0 ? lens_drops(uv0) * lens_rain : vec3(0.0);
	vec2 uv = uv0 - dr.xy;
	vec3 col = sample_scene(uv);

	// soften hard polygon edges where the contrast jumps, and diffuse the picture a little
	vec2 t = scene_texel;
	vec3 n0 = texture(scene, uv + t * vec2(0.8, 0.35)).rgb;
	vec3 n1 = texture(scene, uv + t * vec2(-0.35, 0.8)).rgb;
	vec3 n2 = texture(scene, uv + t * vec2(-0.8, -0.35)).rgb;
	vec3 n3 = texture(scene, uv + t * vec2(0.35, -0.8)).rgb;
	vec3 avg = (n0 + n1 + n2 + n3) * 0.25;
	float l0 = dot(col, vec3(0.3, 0.59, 0.11));
	float lmin = min(min(dot(n0, vec3(0.3, 0.59, 0.11)), dot(n1, vec3(0.3, 0.59, 0.11))), min(dot(n2, vec3(0.3, 0.59, 0.11)), dot(n3, vec3(0.3, 0.59, 0.11))));
	float lmax = max(max(dot(n0, vec3(0.3, 0.59, 0.11)), dot(n1, vec3(0.3, 0.59, 0.11))), max(dot(n2, vec3(0.3, 0.59, 0.11)), dot(n3, vec3(0.3, 0.59, 0.11))));
	float edge = smoothstep(0.03, 0.25, max(lmax, l0) - min(lmin, l0));
	col = mix(col, (col + avg * 2.0) / 3.0, edge * softness);
	vec3 wide = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785 + 0.39;
		wide += texture(scene, uv + vec2(cos(a), sin(a)) * t * 2.6).rgb;
	}
	col = mix(col, wide / 8.0, diffusion * 0.6);
	col += texture(bloom_far, uv).rgb * diffusion * 0.6 * bloom;

	col += (texture(bloom_near, uv).rgb * 0.4 + texture(bloom_far, uv).rgb * 0.55 * bloom_wide) * bloom;
	// halation: light scattered back through the film base glows red around bright things
	vec3 hal = texture(bloom_near, uv).rgb * 0.6 + texture(bloom_far, uv).rgb * 0.4;
	col += vec3(1.0, 0.22, 0.08) * dot(hal, vec3(0.33)) * halation * 0.9;
	vec3 shaft = texture(rays, uv).rgb;
	col += shaft * vec3(1.0, 0.58, 0.28) * 0.38 * rays_amount;
	if (motes > 0.0) {
		// dust and fine spray drifting in the air, catching the light inside the shafts
		vec2 p = uv * vec2(aspect, 1.0) * 70.0 + vec2(weather_time * (2.0 + wind * 9.0), -weather_time * 0.6);
		vec2 id = floor(p);
		vec2 f = fract(p) - 0.5;
		float h = hash12(id);
		vec2 o = (vec2(hash12(id + 1.3), hash12(id + 4.1)) - 0.5) * 0.7 + 0.12 * vec2(sin(weather_time * 1.3 + h * 20.0), cos(weather_time * 1.1 + h * 13.0));
		float speck = smoothstep(0.09, 0.0, length(f - o)) * step(0.55, h) * (0.5 + 0.5 * sin(weather_time * 3.0 + h * 40.0));
		col += vec3(1.0, 0.8, 0.55) * speck * smoothstep(0.02, 0.25, dot(shaft, vec3(0.33))) * 0.9 * motes * rays_amount;
	}
	col += vec3(0.5, 0.55, 0.75) * flash * 0.06;
	col += dr.z * 0.025 * col;

	// grade: exposure, golden warmth, saturation, contrast, the film curve of the original
	col *= exposure;
	col *= vec3(1.0 + 0.12 * warmth, 1.0 + 0.03 * warmth, 1.0 - 0.16 * warmth);
	// sundown: the gold drains out of the light and leaves red, then the darks go blue
	col *= vec3(1.0 + 0.10 * red_shift, 1.0 - 0.16 * red_shift, 1.0 - 0.20 * red_shift);
	float l_n = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l_n) * vec3(0.62, 0.72, 1.25), night * 0.45 * (1.0 - smoothstep(0.05, 0.4, l_n)));
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col = pow(max(col, 0.0), vec3(1.12));
	col = col / (1.0 + max(col - 0.92, 0.0) * 0.5);

	vec2 v = uv0 - 0.5;
	col *= 1.0 - vignette * pow(length(v * vec2(1.0, 0.82)) * 1.25, 2.4);
	float closing = 1.0 - smoothstep(0.25 - darkness * 0.2, 0.75 - darkness * 0.45, length(v * vec2(aspect, 1.0) * 0.6));
	col *= mix(1.0, closing, darkness);
	if (grain > 0.0) {
		// strongest in the midtones, still there in the shadows, as on film
		float frame = floor(weather_time * 24.0);
		vec2 gp = uv0 * vec2(aspect * 768.0, 768.0) / grain_size;
		float mono = film_grain(gp, frame);
		vec3 rgb = vec3(film_grain(gp + 31.7, frame), film_grain(gp + 67.1, frame), film_grain(gp + 13.9, frame));
		float l = clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
		col += mix(vec3(mono), rgb, grain_color) * grain * (0.35 + 2.6 * l * (1.0 - l));
	}
	col *= 1.0 + (hash12(vec2(floor(weather_time * 24.0), 3.3)) - 0.5) * 0.04 * film_flicker;
	COLOR = vec4(max(col, 0.0), 1.0);
}
