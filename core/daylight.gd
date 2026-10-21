class_name Daylight
extends RefCounted
## How far the sun has set. The Level advances it; sky, fog, rain, light shafts, lamps
## and the lens all read it. When it reaches 1 the light is gone and the level is lost.

## 0 = low golden sun, 1 = dark.
static var progress := 0.0


## Remaining daylight, 1..0. Stays high for a long time and falls off at the end.
static func light() -> float:
	return 1.0 - smoothstep(0.35, 1.0, progress) * 0.94


## 0..1: how close the end is (used for the closing vignette and the heartbeat).
static func urgency() -> float:
	return smoothstep(0.8, 1.0, progress)


## Enemies see less far in the dark.
static func sight_factor() -> float:
	return lerpf(1.0, 0.6, smoothstep(0.4, 1.0, progress))
