shader_type canvas_item;
// A window pane in the rain, seen from inside. Drops cling to the glass, swell, and run
// down in wandering trails that leave beads behind; each drop is a small lens showing the
// world sharp and upside down, while beyond the glass everything is soft and out of focus.
// A faint mist of condensation lies on the glass except where the drops have run.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec2 rect_size = vec2(1000.0, 550.0);
uniform float time = 0.0;
uniform float rain = 0.8;          // how wet the glass is
uniform float blur = 2.6;          // how far out of focus the world beyond is (mip level)
uniform float focus = 0.0;         // 0 = focused on the glass, 1 = on the landscape
uniform float refraction = 1.0;
uniform float mist = 0.3;          // condensation
uniform float drop_scale = 1.1;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
vec3 hash3(float p) {
	vec3 p3 = fract(vec3(p) * vec3(.1031, .11369, .13787));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}
float saw(float b, float t) { return smoothstep(0., b, t) * smoothstep(1., b, t); }

// One layer of running drops: x = the drops, y = the wet trails they leave.
vec2 running(vec2 uv, float t) {
	vec2 uv0 = uv;
	uv.y += t * .75;
	vec2 cells = vec2(12., 2.);
	vec2 id = floor(uv * cells);
	uv.y += hash1(id.x * 1.37);
	id = floor(uv * cells);
	vec3 n = hash3(id.x * 35.2 + id.y * 2376.1);
	vec2 st = fract(uv * cells) - vec2(.5, 0.);
	float x = n.x - .5;
	float w = uv0.y * 20.;
	x += sin(w + sin(w)) * (.5 - abs(x)) * (n.z - .5);   // the drop wanders as it runs
	x *= .7;
	float y = (saw(.85, fract(t + n.z)) - .5) * .9 + .5;  // slow, then a sudden slide
	float d = length((st - vec2(x, y)) * vec2(1., 6.));
	float drop = smoothstep(.4, 0., d);
	float r = sqrt(smoothstep(1., y, st.y));
	float cd = abs(st.x - x);
	float front = smoothstep(-.02, .02, st.y - y);
	float trail = smoothstep(.23 * r, .15 * r * r, cd) * front * r * r;
	// beads left behind in the trail
	float by = fract(uv0.y * 10.) + (st.y - .5);
	float beads = smoothstep(.3, 0., length(st - vec2(x, by)));
	return vec2(drop + beads * r * front, trail);
}

// Small drops that land, sit, and dry.
float sitting(vec2 uv, float t) {
	uv *= 40.;
	vec2 id = floor(uv);
	uv = fract(uv) - .5;
	vec3 n = hash3(id.x * 107.45 + id.y * 3543.654);
	vec2 p = (n.xy - .5) * .7;
	float fade = saw(.025, fract(t + n.z));
	return smoothstep(.3, 0., length(uv - p)) * fract(n.z * 10.) * fade;
}

vec2 drops(vec2 uv, float t, float l0, float l1, float l2) {
	float s = sitting(uv, t) * l0;
	vec2 m1 = running(uv, t) * l1;
	vec2 m2 = running(uv * 1.85, t) * l2;
	float c = smoothstep(.3, 1., s + m1.x + m2.x);
	return vec2(c, max(m1.y * l0, m2.y * l1));
}

void fragment() {
	vec2 q = vec2(UV.x * rect_size.x / rect_size.y, 1. - UV.y) * drop_scale;
	float t = time * .2;
	float l0 = smoothstep(-.5, 1., rain) * .8;
	float l1 = smoothstep(.25, .75, rain);
	float l2 = smoothstep(0., .5, rain);
	vec2 c = drops(q, t, l0, l1, l2);
	vec2 e = vec2(.001, 0.);
	float cx = drops(q + e, t, l0, l1, l2).x;
	float cy = drops(q + e.yx, t, l0, l1, l2).x;
	vec2 n = vec2(cx - c.x, cy - c.x) * refraction;
	float in_drop = smoothstep(.1, .2, c.x);
	// beyond the glass: out of focus, a little clearer where the drops have wiped it
	float lod = mix(blur * (1. - c.y * .35), 0., in_drop) * (1. - focus);
	vec2 suv = SCREEN_UV + vec2(n.x, -n.y);
	vec2 px = 1. / vec2(textureSize(screen_texture, 0));
	float spread = exp2(lod) * .6;
	vec3 col = textureLod(screen_texture, suv, lod).rgb * .4;
	col += textureLod(screen_texture, suv + px * vec2(spread, spread * .4), lod).rgb * .15;
	col += textureLod(screen_texture, suv + px * vec2(-spread, -spread * .4), lod).rgb * .15;
	col += textureLod(screen_texture, suv + px * vec2(-spread * .4, spread), lod).rgb * .15;
	col += textureLod(screen_texture, suv + px * vec2(spread * .4, -spread), lod).rgb * .15;
	// condensation: a pale veil over the cold glass, wiped where the water ran
	float veil = mist * (1. - c.y) * (1. - in_drop) * (1. - focus * .7);
	float lum = dot(col, vec3(.3, .59, .11));
	col = mix(col, vec3(lum) * vec3(1.15, .92, .8) + .015, veil * .4);
	// the drops catch the light: a bright rim on their lower edge
	col += col * smoothstep(.02, .08, -n.y) * in_drop * .6;
	COLOR = vec4(col, 1.);
}
