shader_type canvas_item;
#include "res://effects/sky/sky_base.gdshaderinc"
// One layer of distant scenery, seen through the air. The layer is drawn opaque (so nearer
// layers hide farther ones, as they should) and then mixed with the sky that would be
// behind it, the further away the more. Lit windows and lamps shine through the haze.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
// How much of the sky colour the air between lays over the layer (0 = none, 1 = all).
uniform float haze = 0.45;
uniform float flash = 0.0;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec3 sky = sky_gradient(SCREEN_UV * view_size) * mix(1., .78, clamp(storm - 1., 0., 1.));
	sky += vec3(.55, .62, .95) * flash * .18;
	float glow = smoothstep(.12, .35, dot(c.rgb, vec3(.3, .59, .11)));
	COLOR = vec4(mix(mix(c.rgb, sky, haze), c.rgb, glow), c.a);
}
