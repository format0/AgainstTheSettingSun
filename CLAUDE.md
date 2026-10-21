# Working on Against the Setting Sun

Godot 4.7, GL Compatibility renderer. Everything in a level is drawn in code (black
silhouettes in `_draw()`, shaders for light, water, sky and fog); there is no image art for
levels. `README.md` explains the game, the folders and the hooks elements use.

Levels are designed in the Godot editor with the **Level Tools** plugin
(`addons/level_tools`). So the editor must show a level as the game does, and every element
must be easy to select and shape there. **Every new element (and every change to an
element) has to keep working in the editor.** The rules below say how; the two checks at the
end prove it.

## The editor rules for a level element

A level element is a script with a `class_name` in `cover/`, `structures/`, `interactive/`,
`hazards/`, `environment/`, `creatures/`, `enemies/` or `gameplay/`.

1. **`@tool`, `@icon(...)`, `class_name`**, in its own folder of the matching category. The
   doc comment says where the node's position is ("The node's position is the foot of the
   trunk."); handles and boxes are measured from there.
2. **It looks in the editor as it does in the game, standing still.** Build everything you
   can see in `_ready()` *before* any `if Engine.is_editor_hint(): return`: shader-lit
   `ColorRect`s for glows, water and fire, generated polygons, child nodes. Only behaviour comes
   after the return: sounds, particles, moths, timers, groups the gameplay needs, `Game.no_occlude`.
   In `_draw()`, draw the resting pose in the editor (no flames or glows left out).
3. **Nothing runs while editing.** `_process()` and `_physics_process()` begin with
   `if Engine.is_editor_hint(): return`. No `queue_redraw()` every frame in the editor. No AI,
   no physics, no wind animation.
4. **Shape it from the Inspector.** Every size, length and look is an `@export` with a setter
   that rebuilds what depends on it (cached geometry, collision, the size of its glow) and calls
   `queue_redraw()`. Expensive generation happens in setters and `_ready()`, never in `_draw()`.
   Children made in code get no owner, so they are never saved into the scene; collision
   shapes made in code are hidden in the editor by the plugin (toolbar: Collision).
5. **Never change a saved property from editor code** (e.g. moving the node itself to follow
   the view): the scene would be marked changed and saved that way. Move a child instead.
6. **The editor API.** At the end of the script, under
   `# ------------------------------------------------------------------ editor (Level Tools)`:

   ```gdscript
   ## Required: its box in its own coordinates, for clicking it in the 2D view.
   func _editor_rect() -> Rect2:
   	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)

   ## Optional: a precise test. SHAPE (on the drawn shape, picked first), BOX, AREA (large
   ## invisible areas, picked last) or MISS. Without it the box counts as BOX.
   func _editor_hit(p: Vector2) -> DrawKit.EditorHit:
   	...

   ## Handles: one diamond per thing you would want to drag (a size corner, a height, the end
   ## of a chain, each pole). "props" lists what a drag changes (default [id]); it becomes one
   ## undo step. A handle must sit exactly where its value is: dragging it onto itself changes
   ## nothing (tools/check_elements.gd tests this).
   func _editor_handles() -> Array[Dictionary]:
   	return [{"id": "size", "pos": Vector2(size.x * 0.5, -size.y)}]

   func _editor_drag(_id: Variant, p: Vector2) -> void:   # p in local coordinates, snapped
   	size = Vector2(maxf(16.0, absf(p.x) * 2.0), maxf(10.0, -p.y))

   ## When its look depends on the time of day or the weather (a lamp that switches on, a
   ## glow that grows at night): show that look, still. Called when the toolbar's Time slider
   ## or the level's weather changes; also call it from _ready() and the setters in the editor.
   func _editor_preview() -> void:
   	intensity = 1.0 if Daylight.progress >= turns_on_at else 0.0
   	_update_light()
   ```

   A shape made of a line of points (like `Terrain.points`, `Roof.profile`,
   `RustyPipes.path`) gets point handles by adding the class to `KINDS` in
   `addons/level_tools/point_path_editor.gd`.
7. Elements that have no place of their own (flocks that follow the view) go into `SKIP` in
   `addons/level_tools/element_bounds.gd` and `NOT_PLACED` in `tools/check_elements.gd`.
8. Put the new element into `levels/gallery/gallery.tscn` and list it in `README.md`.

Effects that are part of the look of a level (like `effects/fog/fog_layer.gd`) follow the
same idea: `@tool`, still in the editor, redrawn only when the view or the preview changes.

## Checking it

Both must pass before committing a new or changed element:

```sh
# fast, no display: the rules above, for every element script
godot --headless -s tools/check_elements.gd

# the real editor (needs a display, e.g. Xvfb, and OpenGL): opens the levels and the gallery,
# drags every element's handles, previews three times of day, one real mouse drag with undo,
# and saves screenshots to look at (/tmp/editor_check_<scene>_<time>.png)
tools/editor_check.sh
```

Look at the screenshots: the new element should be there, lit and shaped as in the game.
Also run the levels (or a bot playtest) to see the game itself is unchanged.

Running the editor can rewrite `project.godot` (it drops settings equal to their defaults):
check `git diff project.godot` and keep only intended changes.
