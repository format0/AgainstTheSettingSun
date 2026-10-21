shader_type canvas_item;
// Light shafts, step 1: the glow of the sun, blocked wherever a silhouette stands in front
// of it. The silhouettes come from a second view of the level that draws only solid things.

uniform sampler2D occluders : filter_linear;
uniform vec2 sun = vec2(683.0, 600.0);
uniform vec2 view = vec2(1366.0, 768.0);
uniform float strength = 1.0;

void fragment() {
	vec2 L = UV * view;
	float cover = texture(occluders, UV).a;
	float d = length(L - sun);
	float s = (exp(-d / 45.0) * 0.9 + exp(-d / 180.0) * 0.18) * strength;
	COLOR = vec4(vec3(s * (1.0 - cover)), 1.0);
}
