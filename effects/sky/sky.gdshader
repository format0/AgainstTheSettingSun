shader_type canvas_item;
#include "res://effects/sky/sky_full.gdshaderinc"
// Stormy sunset sky drawn live: colour gradient, sun with glow, two layers of
// domain-warped clouds drifting in the wind, and clouds lit from inside by lightning.
// `dusk` (0..1) lets the sun sink and the colours drain away into night, with a few stars.

void fragment() {
	COLOR = vec4(sky_color(UV * view_size), 1.);
}
