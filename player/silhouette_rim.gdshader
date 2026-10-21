shader_type canvas_item;
// The runner is black like everything else. When he hides in front of a black shape he
// would vanish completely, so a faint warm rim shows the player where he is.

uniform float rim = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.72, 0.45, 0.55);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (rim > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE * 3.0;
		float m = 0.0;
		m = max(m, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		m = max(m, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		m = max(m, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		m = max(m, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		m = max(m, texture(TEXTURE, UV + px * 0.7).a);
		m = max(m, texture(TEXTURE, UV - px * 0.7).a);
		float edge = clamp(m - c.a, 0.0, 1.0) * rim;
		COLOR = vec4(mix(c.rgb, rim_color.rgb, edge), max(c.a, edge * rim_color.a));
	} else {
		COLOR = c;
	}
}
