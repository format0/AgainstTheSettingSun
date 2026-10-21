shader_type canvas_item;
// Grass blades bending in the wind, all on the GPU. Each blade is one instance of a
// unit blade mesh; INSTANCE_CUSTOM = (world x, phase, height/width, flexibility).

uniform float weather_time = 0.0;
uniform float wind = 0.5;
uniform float wind_response = 1.0;
uniform float player_x = -99999.0;
uniform float push_radius = 26.0;
uniform float flutter = 0.05;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float t = -VERTEX.y;                       // 0 at the base, 1 at the tip
	float x = c.r;
	float gust = 0.55 + 0.30 * sin(x * 0.0085 + weather_time * 1.9) + 0.15 * sin(x * 0.023 + weather_time * 3.7);
	float lean = (fract(c.g * 7.13) - 0.5) * 0.4;
	float a = lean - wind * c.a * (0.35 + 0.75 * gust) * wind_response
	        + sin(weather_time * 8.0 + c.g) * flutter * c.a * wind;
	float dh = x - player_x;
	if (abs(dh) < push_radius) {
		a += sign(dh) * (1.0 - abs(dh) / push_radius) * 0.9;
	}
	VERTEX.x += sin(a) * pow(t, 1.6) * c.b;
	VERTEX.y = -t * mix(1.0, cos(a), t);
}

void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
}
