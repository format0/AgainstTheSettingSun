shader_type canvas_item;
render_mode blend_add, unshaded;
// A warm point of light (fire, lantern): a hot core, a wide soft glow that breathes
// with the flame, drifting through the rain and haze.

uniform vec2 rect_size = vec2(300.0, 300.0);
uniform vec2 center = vec2(150.0, 150.0);
uniform float radius = 90.0;
uniform float intensity = 1.0;
uniform float weather_time = 0.0;
uniform vec3 color : source_color = vec3(1.0, 0.6, 0.25);

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), u.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), u.x), u.y); }

void fragment() {
	vec2 L = UV * rect_size;
	vec2 d = L - center;
	float r = length(d * vec2(1.0, 1.15));
	float haze = 0.75 + 0.25 * vnoise(vec2(L.x * 0.03 - weather_time * 0.4, L.y * 0.04 - weather_time * 0.2));
	float g = exp(-r / (radius * 0.45)) * 0.35 * haze + exp(-r / 7.0) * 0.8;
	g *= smoothstep(radius * 1.6, radius * 0.6, r);
	COLOR = vec4(color * g * intensity, 1.0);
}
