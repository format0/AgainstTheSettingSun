# Against the Setting Sun (Godot 4.7)

Open `project.godot` in Godot 4.7 or newer and press **F5**.

A nameless runner tries to get through three places before the sun is gone. No story, no
shooting: sneaking, running, hiding in the shadows and solving old machinery.
Everything in the world is drawn by code as a black silhouette; there are no image files
for the levels. The only picture in the project is the runner's animation sheet.

**Controls:** ← → run, ↑ jump, **Space** is the one action button (pull a lever, push a dead
tree over, hold it to grab a crate and pull).

Developer keys: **R** restart the level, **L** lightning, **F1** the look panel (see below).

The project uses the *Compatibility* renderer, so it runs on built-in laptop graphics and can be exported to the web.

### The look, and the F1 panel
The game starts `game/game.tscn`, which loads each level into its own viewport and builds the
final picture from it the way the first WebGL version did: the bright parts of the picture
are blurred twice (a near glow and a wide haze glow) and laid back over it, the sun shines
through the gaps between the silhouettes as light shafts, edges are softened, and a colour
grade, lens drops, grain and a vignette finish it. A level scene run on its own (F6) starts
inside the game by itself.

**F1** opens a panel (use the mouse; the arrow keys still run) with a slider or switch for
everything that shapes the look: bloom, threshold and wide glow, light shafts, lamp and sun
glow, edge softening, diffusion, haze and fog, exposure, warmth, saturation, contrast,
vignette, grain, colour fringing, lens rain, the amount of rain, rain stopping under roofs,
gust sheets, drips, splashes, leaves, bats, starlings, fireflies, dust in the light, steam,
chimney smoke and sparks, and the sundown: how red the light turns as the sun goes, the
cold blue hour after it, the afterglow on the clouds, the sun flattening on the horizon,
silent lightning far away and the mist rising at dusk. It also has the time of day (with "Stop the sun"), the storm strength,
"Nothing can kill me", a lightning button, and a switch for each effect node in the level.
Settings are saved when the panel closes (`user://vfx.cfg`); **Copy** puts them all on the
clipboard, and **Reset** goes back to the defaults in `core/vfx.gd`.

---

## How the game works

| | |
|---|---|
| **Goal** | Reach the `LevelExit` at the end of each level. |
| **The sun sets** | Each level has a clock (`Level.sunset_seconds`). The sky drains from orange to night, lamps switch on, the picture closes in. When the light is gone the level starts over from the beginning. |
| **Dying** | Creatures, molten steel, deep water, falls, crushing machinery and falling trees kill. You come back at the last `Checkpoint`, and whatever you changed before it stays changed (levers, fallen trees, broken bridges, moved crates). The sun keeps setting, so every death costs time. |
| **Shadows** | The runner is black like everything else. In front of a black shape (a `Cover`: a wall, a hay stack, a big trunk, a container...) he disappears: creatures that hunt by sight can't see him and walk right past him. While he moves there, a faint warm rim shows the player where he is; standing still he vanishes completely (`Player.rim_when_still`). Light (street lamps, lanterns, fire, molten steel) takes the shadow away. |
| **Creatures** | *Hunters* (Stalker, Hound) see you in a cone in front of them, freeze, shriek and chase you. Break their line of sight or hide and they search for a while, then go back. *Blind ones* (Crawler) just walk their round and find you by touch. None of them can jump. Loud landings, crashes and grinding gates make hunters come to look. Three others behave differently: the *Dangler* hangs from a beam or a branch and drops on you when you pass beneath it in the open (bait it, step back, go while it climbs); the *Burrower* lives under soft ground and bursts up where it hears a step or feels you standing (jump its patch or keep running); the *Watcher* sits high up and sweeps a beam of light. It can't hurt you, but its beam takes your shadow away, and when it finds you it screams and the hunters come. |
| **Storm** | Each level has its own weather (`WeatherController.storm`): rain, wind, lightning. Wind moves trees, grass, cloth, chains, swinging beams, tarps and drifting rafts, never the runner. |

### The levels
| | Setting | Weather | What happens |
|---|---|---|---|
| I · The Fields | meadows, a creek, a farm | light rain, breeze | push a dead tree over the creek, jump a crawler, cross a burrower's field, sneak past a stalker using hay, a ruin and an oak, run over a collapsing rope bridge, outrun a falling tree, ride a log across a pond, open the barn gate (the grinding draws the stalker over) |
| II · The Works | an abandoned steelworks | heavy rain, lightning | swinging beams over molten steel, steam hammers (time them, or climb up and cut two of them), drag a crate onto a plate to open a gate, a stalker in the warehouse (lure it onto a trap door over a molten pit), drop a concrete block into a rebar pit as a stepping stone, bait the dangler under the crane, ride a lift past a crawler under a watcher's beam, slip past a creature dozing by a fire |
| III · The Quarry | cliffs, a flooded pit, a pine forest | wild storm | cross a burrower on the rim, come down quietly into a hound's basin, ride a ropeway pallet over flooded water, a rotten rope bridge, close the hatch over a flooded shaft (and hide when the hound comes to look), cross the yard between the sweeps of a watcher's beam, a stone that drops a tree across a gully, a dangler in the pines, another tree that falls on you, a ropeway car over the abyss, the climb to the last light |

---

## How the project is organised

The folders tell what a thing does to the player. Their icons in **Add Node** have the same colours:

```
core/          shared code: weather, daylight, layers, sounds, camera, drawing helpers
player/        the runner
levels/        one folder per level, plus the Level base script
gameplay/      ■ cyan    Checkpoint, LevelExit (invisible markers)
interactive/   ■ orange  things the player uses or that react to him: levers, gates, crates...
hazards/       ■ red     things that kill: water, molten steel, hammers, falling loads, spikes
enemies/       ■ purple  creatures that kill on touch
cover/         ■ green   black shapes behind the player that hide him
structures/    ■ white   solid things to stand on and bump into
environment/   ■ grey    scenery only: trees, grass, lamps, fences, chains...
creatures/     ■ grey    harmless animals: frogs, crows, bats, fireflies, a cat, rats, fish
effects/       weather and look: sky, rain, fog, lightning, post effects, sound
game/          the frame around the levels and the picture pipeline (bloom, light shafts, grade)
ui/            the fade and title overlay, the F1 look panel
```

In the editor every gameplay element also marks itself: orange dashed lines from switches to
what they drive, green outlines where the player can hide, red boxes where things kill,
purple patrol ranges and sight cones for creatures.

### core/
| File | What it does |
|---|---|
| `weather.gd` | Shared weather state (`Weather.wind`, `Weather.storm`, `Weather.flash`...). Everything reads it. |
| `daylight.gd` | How far the sun has set (`Daylight.progress` 0..1). Sky, fog, rain, lamps and lens read it. |
| `vfx.gd` | Every setting of the look (`VFX.v("bloom")`, `VFX.on("bats")`), with defaults, ranges and the panel's labels. Add a line here and it shows up in the F1 panel. |
| `game_camera.gd` | Follows the player, stays inside the level, shakes on lightning and heavy impacts. |
| `layers.gd` | Draw order (z_index) of everything, and the physics layers. |
| `draw_kit.gd` | Drawing helpers for silhouettes: chains, ropes, trusses, limbs, rocks, rough edges, vines, editor markers. |
| `light_source.gd` | `LightSource.lit_at(pos)`: is any light on this spot? |
| `sound_bank.gd` | Every sound, synthesized at startup (rain, wind, thunder, footsteps on grass/stone/wood/metal/water, machinery, creatures, a quiet music pad). Replace any function with `return preload("res://audio/x.ogg")` to use a recording. |

### gameplay/ and levels/
| Node | Use it for |
|---|---|
| `Level` (root script) | Title, next level, size, spawn point, footstep surface, sunset length and start. Creates the burst effects; the game around it shows the title and the fades. |
| `Checkpoint` | Where the player comes back after dying. |
| `LevelExit` | The end of the level. |

### interactive/
| Node | What it does |
|---|---|
| `Lever` | Action button throws it; switches its `targets`. Can be one-way (rusted). |
| `PressurePlate` | Switches its `targets` while the player, a creature or a crate stands on it; can latch. |
| `SlidingGate` | Door, portcullis or (lying flat) a sliding cover over a hole. Crushes when it shuts; its grinding draws hunters. |
| `TrapDoor` | Hinged hatch that drops whoever stands on it. |
| `MovingPlatform` | Girder on chains, lift cage, ropeway pallet or slab; moves on a switch or in a loop. |
| `SwingingBeam` | Beams on chains swinging in the wind; carries the player. |
| `PushCrate` | Crate, oil drum or log: push it, grab and pull it, it falls off edges, floats and drifts. |
| `FallingTree` | Falls when pushed, when the player comes near (trap) or on a switch; crushes, then lies as a bridge. |
| `CollapsingBridge` | Rope bridge whose planks give way (all of them, or only the rotten ones). |

Switches talk to machines with `set_active(on, instant)`; anything with that method can be a target (see `interactive/mechanism.gd`).

### hazards/
`DeepWater` (drowning, reflections, floating things), `MoltenPool` (glow, embers, heat haze, light),
`SteamHammer` (timed crusher, a switch can stop it), `DropLoad` (hanging load that falls and
then stays as a platform), `RebarSpikes`, `KillZone` (bottom of an abyss).

### enemies/
`Enemy` is the base (patrol, sight, chase, search, hearing, death). `Stalker` (tall hunter),
`Hound` (fast hunter), `Crawler` (blind patroller). Not built on `Enemy`: `Dangler` (drops from
a thread), `Burrower` (strikes from under the ground at sounds), `Watcher` (a sweeping beam
that raises the alarm).

### creatures/
Harmless life: `Frog`, `Crow` (sit on power lines, fly up when you come), `Bats` (come out at
dusk and follow the view), `Fireflies` (in an area, blinking as the light goes), `StrayCat`
(walks a ledge or a beam, washes, keeps away from you), `Rat`, `JumpingFish`, `PlasticBag`,
`Starlings` (a murmuration flying home over the horizon while the sun goes down).

### cover/
`Cover` is the base. `RuinedWall` (from a broken wall to a house's end wall with a `gable`, with
window bars, missing bricks, beams and ivy), `OldOak`, `HayBales`, `RockFace`, `ShippingContainer`,
`Boiler`, `WaterTower`, `HangingTarp` (the wind can blow it aside).

### structures/
`SolidBlock` (plain, broken concrete, planks, riveted steel, earth or invisible), `Terrain`
(natural ground along a line of points, with grass, stones and roots), `Girder`, `Catwalk`
(one-way), `CrateStack`, `Boulder`, `TreeStump`, `CarWreck`, `Roof` (tiles, shingles or corrugated
iron along a line of points, with missing tiles, holes showing the rafters, gutters, a chimney
and a weathervane that turns with the wind).

### environment/
`GrassField`, `WindTree`, `PineTree`, `Bush`, `Cattails`, `WoodenFence`, `PowerLine`,
`Windmill`, `ClothFlag`, `StreetLamp` (can switch on at dusk), `Lantern`, `FireBarrel`,
`HangingChains`, `RustyPipes`, `Puddle`, `Chasm` (depth and mist in a ravine).
Molten steel throws sparks and steam, the steam hammers and boilers hiss, and rain drips from
the edges of roofs and girders.

### effects/
`WeatherController`, `SkyEffect`, `LightningEffect`, `DistantScenery` (fields, works or quarry
on the horizon, in two hazy layers with smoking chimneys), `RainLayer` (gust sheets; near rain
stops under roofs), `RainSplashes` (splashes and drips), `FogLayer`, `LeafStorm`, `WetGround`,
`LightShafts` and `CameraLens` (inside the game they only set how strong the shafts and lens
drops are), `Ambience`. Bursts of dust, embers and leaves are made by the
Level: `get_tree().call_group("dust_emitters", "burst", position, count, width)`.

---

## Making a new level

`levels/gallery/gallery.tscn` puts the trees, buildings, roofs, rocks, machinery and props side
by side on a flat strip, to look at them against the sunset (run it with F6, F1 to scrub the time).

1. Duplicate a level scene into a new folder, or start a new scene with a `Node2D` root and attach `levels/level.gd`.
2. On the root, set the title, the next level, width, spawn point and the sunset.
3. Under **Effects**, keep what the level needs and set the storm and the distant scenery.
4. Under **World**, lay the ground (`Terrain` for nature, `SolidBlock` for concrete), then add structures, cover, interactive elements, hazards and creatures.
5. Put a `Checkpoint` before every hard part and a `LevelExit` at the end.
6. Keep hazards and things the player must see out of the way of cover shapes: black in front of black is invisible (creatures get a faint rim there, but machinery doesn't).

## Adding a new element

1. Make a folder in the matching category and a script with `@tool`, `@icon(...)` and `class_name`.
2. Draw it in `_draw()` in black (helpers in `DrawKit`), and read `Weather` and `Daylight` to make it move and react to the dusk.
3. Hooks the rest of the game uses:
   - extend `Cover` and return shapes from `_cover_shapes()` → the player hides in front of it;
   - join `interactables` with `can_interact()`, `get_interact_position()`, `interact()` → the action button uses it;
   - give it `set_active(on, instant)` → switches can drive it;
   - call `Level.remember(self, state)` and read `Level.recall(self)` in `_ready()` → it survives a checkpoint respawn;
   - join `light_sources` with `illuminates(pos)` → it takes the player's shadow away; join `lamps` with `get_light_points()` → rain and fog glow around it;
   - glows, fog and other see-through effects call `Game.no_occlude(node)` → they don't block the sun's shafts or the rain;
   - join `rain_surfaces` with `get_rain_edges()` → rain splashes on it; join `lightning_listeners` with `on_lightning()`;
   - call `player.make_noise(pos, radius)` → hunters come to look.
