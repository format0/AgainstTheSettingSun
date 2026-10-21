shader_type canvas_item;
// The level's sky behind the editor view: the same sky as in the game (sky_full), seen as if
// the game camera stood where the editor is looking. `game_cam` is that camera's top-left
// corner in the world.
#include "res://effects/sky/sky_full.gdshaderinc"

uniform vec2 game_cam = vec2(0.0);
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR = vec4(sky_color(world - game_cam), 1.);
}
