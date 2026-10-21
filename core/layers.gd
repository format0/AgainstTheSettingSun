class_name Layers
extends RefCounted
## Draw order of everything in the world (z_index), back to front.
## Screen-space effects use CanvasLayers instead; their numbers are listed at the bottom.

const DISTANT_FAR := -60      ## hills, turbines, factory
const DISTANT_MID := -55      ## pylons, poplars
const RAIN_FAR := -50         ## rain falling behind the level
const FOG_BANK := -45
const BACKDROP := -40         ## painted level art
const ELEMENTS_BACK := -30    ## trees, power lines, windmill
const ELEMENTS := -20         ## lamps, beams, flag, solid blocks
const CREATURES := -10
const PLAYER := 0
const GRASS := 5
const LAMP_LIGHT := 10
const GROUND_FOG := 15
const SPLASHES := 20
const FOREGROUND := 30        ## reeds in front of the player
const RAIN_NEAR := 40

# CanvasLayer numbers for screen-space effects
const CANVAS_SKY := -100
const CANVAS_LIGHTNING := -99
const CANVAS_WET_GROUND := 10
const CANVAS_LIGHT_SHAFTS := 11
const CANVAS_LENS := 12
const CANVAS_UI := 50
