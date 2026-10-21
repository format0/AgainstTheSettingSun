shader_type canvas_item;
// The leaf clumps of an OldOak, recorded once (in the frame of their branch's tip) and set
// moving here exactly as the oak used to redraw them every frame: each clump bobs and turns
// a little about its centre and shifts in the gusts, the loose leaves on its sprigs turn
// more, and the twig carrying it stays fixed at the branch and follows it at the clump.
// Per vertex: UV = the point it turns about; COLOR.r = the clump's phase (0..1 of a turn),
// COLOR.g = how much it turns with the flutter, COLOR.b = how far it moves with the clump.

uniform float weather_time = 0.0;
uniform float wind = 0.5;
uniform vec2 gust_shift = vec2(0.0);

void vertex() {
	float ph = COLOR.r * 6.28318530718;
	float flutter = sin(weather_time * (5.0 + wind * 5.0) + ph * 3.0) * (0.4 + wind) * 0.8;
	float a = flutter * COLOR.g;
	vec2 d = VERTEX - UV;
	d = vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
	VERTEX = UV + d + (vec2(0.0, flutter) + gust_shift) * COLOR.b;
}

void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
}
