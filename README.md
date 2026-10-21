# Against the Setting Sun (Godot 4.7)

Open `project.godot` in Godot 4.7 or newer and press **F5**.

**Controls:** arrows or A/D to run, Up/W/Space to jump, **L** for lightning, **R** to restart, **F1** for the debug panel.
With the panel open, the keys 1–9, 0, - and = switch single effects off and on, so you can see what each one adds and costs.

The project uses the *Compatibility* renderer, so it runs on built-in laptop graphics and can be exported to the web.

---

## How the project is organised

```
core/        shared code every other part uses
player/      the runner
levels/      one folder per level, plus the Level base script
elements/    things you place in a level (platforms, lamps, beams, trees...)
creatures/   animals and other things that move on their own
effects/     weather and look: sky, rain, fog, lightning, post effects, sound
ui/          the debug panel
assets/      images, one folder per level
```

### core/
| File | What it does |
|---|---|
| `weather.gd` | The shared weather state (`Weather.wind`, `Weather.storm`, `Weather.flash`, ...). Everything reads it. |
| `game_camera.gd` | Follows the player, stays inside the level, shakes on close lightning. `GameCamera.view_rect` tells effects what is on screen. |
| `layers.gd` | The drawing order (z_index) of everything, in one place. |
| `sound_bank.gd` | Every sound, synthesized at startup. Replace any function with `return preload("res://audio/x.ogg")` to use a recording. |

### player/
| File | What it does |
|---|---|
| `player.gd` | Running and jumping. The numbers come from the 2014 C version (converted to pixels per second); all of them are in the Inspector. Also has jump buffering, coyote time and an optional headwind push. |
| `runner_animator.gd` | Plays `runner_sheet.png`. The run cycle follows the distance covered, so the feet never slide. |

### elements/ (add them with **Add Node** – they have their own icons)
| Node | Use it for |
|---|---|
| `SolidBlock` | Anything you stand on or bump into. Turn off *Visible Fill* when the shape is painted in the backdrop. |
| `SwingingBeam` | Beams hanging from a cable, swinging in the wind; carries the player. Draws itself, or uses a painted texture. |
| `StreetLamp` | Light cone, light on the ground, moths, hum. *Steady*, *Flickering* or *Failing*. |
| `PowerLine` | Poles and swaying wires; crows perch on them. |
| `WindTree` | A tree grown from a seed. Change *Tree Seed* until you like the shape. Sheds leaves. |
| `Windmill`, `ClothFlag` | Spin and flap with the wind. |
| `GrassField` | Thousands of grass blades on the GPU; they part around the player. Also used for the foreground reeds. |
| `Puddle` | Marks a puddle on the ground: reflections, ripples and wet footsteps. |

### creatures/
`Frog` (croaks, flees), `Crow` (needs a PowerLine; startles and comes back), `PlasticBag` (tumbles in the wind).

### effects/ (pick the ones each level needs)
| Node | What it adds |
|---|---|
| `WeatherController` | Storm strength and gusting wind. Without it the level is calm. |
| `SkyEffect` | The sunset with drifting clouds. Also sets where the sun is. |
| `LightningEffect` | Bolts, flashes, thunder and camera shake. |
| `DistantScenery` | Hazy hills, turbines, factory, pylons and poplars on two parallax layers. |
| `RainLayer` | Rain drawn entirely on the GPU. Use one far (behind the level) and one near (in front). |
| `RainSplashes` | Droplets where rain hits the ground, platforms and the player. |
| `FogLayer` | A fog bank behind the level and/or ground fog in front of it. |
| `WetGround` | Sky sheen on the ground and reflections in every Puddle. |
| `LightShafts` | Sun rays between the silhouettes. |
| `CameraLens` | Glow, lens raindrops, colour fringing, grading, vignette, grain. |
| `Ambience` | Rain and wind sound, thunder. |

Effects only talk to each other through `Weather` and a few groups, so you can add or leave out any of them.

---

## Making a new level

1. Duplicate `levels/level_01/level_01.tscn` (right-click → Duplicate) into a new folder, or start a new scene with a `Node2D` root and attach `levels/level.gd`.
2. On the root, set the level width, height, ground line and spawn point.
3. Under **Effects**, delete what this level doesn't need (a calm level could have only the Sky and WeatherController with storm 0).
4. Under **World**, place elements. A `SolidBlock` under the whole level width is the ground.
5. Keep the **Player** and **Camera** nodes (the camera's *Target* is the player).

## Adding a new element or creature

1. Make a folder in `elements/` or `creatures/`.
2. Write a script that starts with `@tool`, `class_name YourThing` and `extends Node2D` (or `StaticBody2D` / `AnimatableBody2D` if the player should collide with it).
3. Draw it in `_draw()` in black, and read `Weather.wind`, `Weather.gust_at(x)` and `Weather.time` to make it move.
4. Optional hooks other parts of the game already use:
   - add it to the `rain_surfaces` group and give it `get_rain_edges()` → rain splashes on it;
   - add it to `lightning_listeners` and give it `on_lightning(screen_x, strength)` → it reacts to lightning;
   - call `get_tree().call_group("splash_emitters", "burst", position, count, power)` to make splashes.
5. It now appears in **Add Node** and can be placed in any level.

## Adding a new effect

Screen-space effects that change the finished image extend `PostEffect` (see `effects/post/`); other effects are plain nodes. Add the node to the `effects` group so the F1 panel lists it.
