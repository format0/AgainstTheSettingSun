shader_type canvas_item;
// Leaves of a WindTree, recorded once and set fluttering here: each leaf turns about its own
// centre and bobs up and down, exactly as the tree used to redraw them every frame.
// Per vertex: UV = the centre of its leaf, COLOR.r = the leaf's phase (0..1 of a full turn).

uniform float weather_time = 0.0;
uniform float wind = 0.5;

void vertex() {
	float ph = COLOR.r * 6.28318530718;
	float a = sin(weather_time * 9.0 + ph) * 0.5 * wind;
	vec2 d = VERTEX - UV;
	d = vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
	VERTEX = UV + d + vec2(0.0, sin(weather_time * 11.0 + ph) * 0.8);
}

void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
}
