class_name SoundBank
extends RefCounted
## Every sound in the game is synthesized here at startup, so the project needs no audio files.
## Swap any function for a recorded sample later: e.g. `return preload("res://audio/frog.ogg")`.

const RATE := 22050

static var _cache := {}


static func rain_hiss() -> AudioStreamWAV:
	return _cached("rain_hiss", func(): return _make_rain_hiss(3.0))


static func rain_rumble() -> AudioStreamWAV:
	return _cached("rain_rumble", func(): return _make_brown(4.0, true))


static func wind_noise() -> AudioStreamWAV:
	return _cached("wind_noise", func(): return _make_white(3.0, true))


static func thunder(variant: int) -> AudioStreamWAV:
	return _cached("thunder%d" % variant, func(): return _make_thunder(5.0, variant))


static func thunder_crack() -> AudioStreamWAV:
	return _cached("crack", func(): return _make_crack(0.5))


static func croak() -> AudioStreamWAV:
	return _cached("croak", func(): return _make_croak())


static func caw() -> AudioStreamWAV:
	return _cached("caw", func(): return _make_caw())


static func lamp_buzz() -> AudioStreamWAV:
	return _cached("buzz", func(): return _make_buzz())


## A footstep on: grass, dirt, stone, wood, metal, water.
static func step(surface: String) -> AudioStreamWAV:
	return _cached("step_" + surface, func(): return _make_surface_step(surface))


static func creature_step() -> AudioStreamWAV:
	return _cached("creature_step", func(): return _make_thud(0.18, 0.04, 0.5, 90.0))


static func body_fall() -> AudioStreamWAV:
	return _cached("body_fall", func(): return _make_thud(0.45, 0.06, 0.9, 70.0))


static func stone_thud() -> AudioStreamWAV:
	return _cached("stone_thud", func(): return _make_thud(0.25, 0.15, 0.7, 140.0))


static func heavy_impact() -> AudioStreamWAV:
	return _cached("heavy_impact", func(): return _make_impact(1.4, false))


static func hammer_blow() -> AudioStreamWAV:
	return _cached("hammer_blow", func(): return _make_impact(1.3, true))


static func clank() -> AudioStreamWAV:
	return _cached("clank", func(): return _make_metal(0.45, [310.0, 847.0, 1530.0, 2410.0], 9.0, 0.5))


static func lever() -> AudioStreamWAV:
	return _cached("lever", func(): return _make_lever())


static func grind() -> AudioStreamWAV:
	return _cached("grind", func(): return _make_grind(1.6))


static func chain_rattle() -> AudioStreamWAV:
	return _cached("chain_rattle", func(): return _make_rattle(1.5, 26.0, true))


static func chain_snap() -> AudioStreamWAV:
	return _cached("chain_snap", func(): return _make_chain_snap())


static func scrape(metal: bool) -> AudioStreamWAV:
	return _cached("scrape_metal" if metal else "scrape_wood", func(): return _make_scrape(1.2, metal))


static func wood_creak() -> AudioStreamWAV:
	return _cached("wood_creak", func(): return _make_creak(1.1))


static func wood_snap() -> AudioStreamWAV:
	return _cached("wood_snap", func(): return _make_snap(0.35))


static func tree_crash() -> AudioStreamWAV:
	return _cached("tree_crash", func(): return _make_tree_crash())


static func splash() -> AudioStreamWAV:
	return _cached("splash", func(): return _make_splash())


## A raindrop striking a window pane (four variants).
static func glass_tap(variant: int) -> AudioStreamWAV:
	return _cached("tap%d" % variant, func(): return _make_glass_tap(variant))


## A single drop of water falling from an edge into a puddle (four variants).
static func drip(variant: int) -> AudioStreamWAV:
	return _cached("drip%d" % variant, func(): return _make_drip(variant))


static func sizzle() -> AudioStreamWAV:
	return _cached("sizzle", func(): return _make_sizzle(1.3))


static func bubbling() -> AudioStreamWAV:
	return _cached("bubbling", func(): return _make_bubbling(2.5))


static func fire_crackle() -> AudioStreamWAV:
	return _cached("fire_crackle", func(): return _make_fire(2.5))


static func shriek() -> AudioStreamWAV:
	return _cached("shriek", func(): return _make_shriek())


static func growl() -> AudioStreamWAV:
	return _cached("growl", func(): return _make_growl())


static func chitter() -> AudioStreamWAV:
	return _cached("chitter", func(): return _make_rattle(0.5, 40.0, false))


static func creature_breath() -> AudioStreamWAV:
	return _cached("breath", func(): return _make_breath())


static func heartbeat() -> AudioStreamWAV:
	return _cached("heartbeat", func(): return _make_heartbeat())


static func crickets() -> AudioStreamWAV:
	return _cached("crickets", func(): return _make_crickets(4.0))


## A slow, quiet pad of four chords, ~32 s long, or null until build_music_pad() has run.
static func music_pad() -> AudioStreamWAV:
	return _cache.get("music_pad")


## Slow (a few seconds): call it from a thread, then hand the result to store_music_pad().
static func build_music_pad() -> AudioStreamWAV:
	return _make_pad()


static func store_music_pad(stream: AudioStreamWAV) -> void:
	_cache["music_pad"] = stream


# ------------------------------------------------------------------ helpers

static func _cached(key: String, maker: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


static func _to_stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


static func _make_white(seconds: float, loop: bool) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = randf_range(-0.5, 0.5)
	return _to_stream(a, loop)


static func _make_brown(seconds: float, loop: bool) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var last := 0.0
	for i in n:
		last = (last + 0.02 * randf_range(-1.0, 1.0)) / 1.02
		a[i] = last * 3.0
	# fade the loop seam
	var f := 2000
	for i in f:
		var k := float(i) / f
		a[i] = a[i] * k + a[n - f + i] * (1.0 - k)
	return _to_stream(a.slice(0, n - f), loop)


static func _make_rain_hiss(seconds: float) -> AudioStreamWAV:
	# high-passed noise plus a dense field of tiny droplet ticks
	var n := int(seconds * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var prev_in := 0.0
	var prev_out := 0.0
	for i in n:
		var x := randf_range(-1.0, 1.0)
		prev_out = 0.85 * (prev_out + x - prev_in)
		prev_in = x
		a[i] = prev_out * 0.22
	for d in int(seconds * 260):
		var at := randi() % (n - 400)
		var amp := randf_range(0.05, 0.35)
		var freq := randf_range(1500.0, 5000.0)
		for k in 300:
			a[at + k] += sin(TAU * freq * k / RATE) * amp * exp(-k / 40.0)
	return _to_stream(a, true)


static func _make_thunder(seconds: float, variant: int) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var brown := 0.0
	var lp := 0.0
	var seed_phase := float(variant) * 1.7
	for i in n:
		var t := float(i) / RATE
		brown = (brown + 0.02 * randf_range(-1.0, 1.0)) / 1.02
		var cutoff := lerpf(0.25, 0.02, clampf(t / 3.5, 0.0, 1.0))
		lp += (brown * 3.5 - lp) * cutoff
		var env := (t / 0.06 if t < 0.06 else exp(-(t - 0.06) * 0.9)) * (0.65 + 0.35 * sin(t * 6.0 + seed_phase) * sin(t * 2.3 + seed_phase * 2.0))
		a[i] = lp * env * 2.2
	return _to_stream(a, false)


static func _make_crack(seconds: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 9.0) * 0.8
	return _to_stream(a, false)


static func _make_croak() -> AudioStreamWAV:
	var n := int(0.32 * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(330.0, 250.0, t / 0.32) / RATE
		var sq := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var am := 1.0 if fmod(t * 42.0, 1.0) < 0.5 else 0.3
		var env := 0.0
		for p0: float in [0.0, 0.16]:
			var k: float = t - p0
			if k >= 0.0 and k < 0.1:
				env = maxf(env, minf(k / 0.015, 1.0) * (1.0 - k / 0.1))
		lp += (sq * am * env - lp) * 0.35
		a[i] = lp * 0.5
	return _to_stream(a, false)


static func _make_caw() -> AudioStreamWAV:
	var n := int(0.75 * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := fmod(t, 0.38)
		var env := minf(k / 0.03, 1.0) * exp(-k * 9.0) if k < 0.34 else 0.0
		phase += lerpf(560.0, 360.0, k / 0.34) / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		lp += (saw + randf_range(-0.3, 0.3) - lp) * 0.3
		a[i] = lp * env * 0.45
	return _to_stream(a, false)


static func _make_buzz() -> AudioStreamWAV:
	var n := RATE / 10     # exactly ten cycles of 100 Hz
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var p := fmod(float(i) * 100.0 / RATE, 1.0)
		a[i] = ((p * 2.0 - 1.0) * 0.5 + sin(TAU * 2.0 * p) * 0.3) * 0.25
	return _to_stream(a, true)


static func _make_step(wet: bool) -> AudioStreamWAV:
	var n := int((0.16 if wet else 0.08) * RATE)
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf_range(-1.0, 1.0)
		lp += (x - lp) * (0.6 if wet else 0.12)
		a[i] = lp * exp(-t * (28.0 if wet else 55.0)) * (0.5 if wet else 0.9)
	return _to_stream(a, false)


# ------------------------------------------------------------------ helpers for the new sounds

static func _new(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


## Fades the end of a loop into its start so it repeats without a click.
static func _seam(a: PackedFloat32Array, fade := 1500) -> PackedFloat32Array:
	var n := a.size()
	for i in fade:
		var k := float(i) / fade
		a[i] = a[i] * k + a[n - fade + i] * (1.0 - k)
	return a.slice(0, n - fade)


static func _make_surface_step(surface: String) -> AudioStreamWAV:
	match surface:
		"water":
			return _make_step(true)
		"metal":
			var a := _new(0.22)
			var tones := [420.0, 1180.0, 2350.0]
			for i in a.size():
				var t := float(i) / RATE
				var v := randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.5
				for f in tones:
					v += sin(TAU * f * t) * exp(-t * (18.0 + f * 0.01)) * 0.12
				a[i] = v * 0.7
			return _to_stream(a, false)
		"wood":
			var a := _new(0.18)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				lp += (randf_range(-1.0, 1.0) - lp) * 0.25
				a[i] = (sin(TAU * 190.0 * t) * 0.6 + sin(TAU * 410.0 * t) * 0.25) * exp(-t * 32.0) * 0.6 + lp * exp(-t * 60.0) * 0.5
			return _to_stream(a, false)
		"stone":
			var a := _new(0.12)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				lp += (randf_range(-1.0, 1.0) - lp) * 0.4
				a[i] = lp * exp(-t * 70.0) * 0.8 + sin(TAU * 110.0 * t) * exp(-t * 40.0) * 0.4
			return _to_stream(a, false)
		"grass":
			var a := _new(0.16)
			var lp := 0.0
			for i in a.size():
				var t := float(i) / RATE
				lp += (randf_range(-1.0, 1.0) - lp) * 0.18
				var rustle := randf_range(-1.0, 1.0) * (0.25 if randf() < 0.08 else 0.04)
				a[i] = (lp * 0.7 + rustle) * exp(-t * 30.0) * minf(t / 0.008, 1.0)
			return _to_stream(a, false)
	return _make_step(false)


static func _make_thud(seconds: float, brightness: float, amp: float, pitch: float) -> AudioStreamWAV:
	var a := _new(seconds)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * (0.05 + brightness)
		a[i] = (lp * 0.8 + sin(TAU * pitch * t * (1.0 - t)) * 0.7) * exp(-t * 14.0 / seconds) * amp
	return _to_stream(a, false)


static func _make_impact(seconds: float, metal: bool) -> AudioStreamWAV:
	var a := _new(seconds)
	var lp := 0.0
	var brown := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.08
		brown = (brown + 0.03 * randf_range(-1.0, 1.0)) / 1.02
		var v := sin(TAU * 52.0 * t * (1.0 - t * 0.3)) * exp(-t * 4.0) * 0.9 + lp * exp(-t * 10.0) * 0.9 + brown * 4.0 * exp(-t * 2.0)
		if metal:
			v += (sin(TAU * 233.0 * t) * 0.3 + sin(TAU * 611.0 * t) * 0.2 + sin(TAU * 1450.0 * t) * 0.1) * exp(-t * 3.0)
		a[i] = v * 0.7
	return _to_stream(a, false)


static func _make_metal(seconds: float, tones: Array, decay: float, amp: float) -> AudioStreamWAV:
	var a := _new(seconds)
	for i in a.size():
		var t := float(i) / RATE
		var v := randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.6
		for k in tones.size():
			v += sin(TAU * tones[k] * t) * exp(-t * decay * (1.0 + k * 0.5)) * 0.35
		a[i] = v * amp
	return _to_stream(a, false)


static func _make_lever() -> AudioStreamWAV:
	var a := _new(0.6)
	# ratchet clicks, then the clunk at the end of the throw
	for c in 5:
		var at := int((0.03 + c * 0.05) * RATE)
		for k in 500:
			if at + k < a.size():
				a[at + k] += randf_range(-1.0, 1.0) * exp(-k / 60.0) * 0.4 + sin(TAU * 2100.0 * k / RATE) * exp(-k / 90.0) * 0.15
	var at := int(0.3 * RATE)
	var lp := 0.0
	for k in a.size() - at:
		var t := float(k) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.15
		a[at + k] += (lp * 0.8 + sin(TAU * 140.0 * t) * 0.6 + sin(TAU * 690.0 * t) * 0.2) * exp(-t * 18.0)
	return _to_stream(a, false)


static func _make_grind(seconds: float) -> AudioStreamWAV:
	var a := _new(seconds)
	var lp := 0.0
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.12
		phase += (95.0 + 20.0 * sin(t * 7.0)) / RATE
		var rough := 0.6 + 0.4 * sin(t * 31.0) * sin(t * 13.0)
		a[i] = (lp * 0.6 + (fmod(phase, 1.0) - 0.5) * 0.25) * rough * 0.6
	return _to_stream(_seam(a), true)


static func _make_rattle(seconds: float, rate: float, loop: bool) -> AudioStreamWAV:
	var a := _new(seconds)
	var n := a.size()
	for c in int(seconds * rate):
		var at := randi() % maxi(n - 900, 1)
		var f := randf_range(1800.0, 4200.0)
		var amp := randf_range(0.1, 0.35)
		for k in 800:
			a[at + k] += (sin(TAU * f * k / RATE) * 0.6 + randf_range(-0.4, 0.4)) * amp * exp(-k / 120.0)
	if loop:
		return _to_stream(_seam(a, 800), true)
	return _to_stream(a, false)


static func _make_chain_snap() -> AudioStreamWAV:
	var a := _new(0.7)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = (sin(TAU * 1720.0 * t) * 0.4 + sin(TAU * 2930.0 * t) * 0.25) * exp(-t * 14.0) + randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.5
	for c in 14:
		var at := int(randf_range(0.05, 0.6) * RATE)
		for k in 600:
			if at + k < a.size():
				a[at + k] += randf_range(-0.3, 0.3) * exp(-k / 80.0)
	return _to_stream(a, false)


static func _make_scrape(seconds: float, metal: bool) -> AudioStreamWAV:
	var a := _new(seconds)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * (0.3 if metal else 0.1)
		var judder := 0.5 + 0.5 * absf(sin(t * (41.0 if metal else 23.0)))
		a[i] = lp * judder * 0.5
	return _to_stream(_seam(a), true)


static func _make_creak(seconds: float) -> AudioStreamWAV:
	var a := _new(seconds)
	var phase := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 160.0 + 90.0 * sin(t * 2.3) + 40.0 * sin(t * 9.0)
		phase += f / RATE
		# stick-slip friction: a pulse train with jitter
		var pulse := 1.0 if fmod(phase, 1.0) < 0.12 else 0.0
		lp += (pulse + randf_range(-0.2, 0.2) - lp) * 0.3
		var env := minf(t / 0.1, 1.0) * minf((seconds - t) / 0.3, 1.0)
		a[i] = (lp - 0.12) * env * 0.7
	return _to_stream(a, false)


static func _make_snap(seconds: float) -> AudioStreamWAV:
	var a := _new(seconds)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = randf_range(-1.0, 1.0) * exp(-t * 35.0) * 0.9 + sin(TAU * 240.0 * t) * exp(-t * 25.0) * 0.4
	for c in 6:
		var at := int(randf_range(0.02, 0.25) * RATE)
		for k in 300:
			if at + k < a.size():
				a[at + k] += randf_range(-0.5, 0.5) * exp(-k / 40.0)
	return _to_stream(a, false)


static func _make_tree_crash() -> AudioStreamWAV:
	var a := _new(3.0)
	var brown := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		brown = (brown + 0.03 * randf_range(-1.0, 1.0)) / 1.02
		lp += (randf_range(-1.0, 1.0) - lp) * 0.2
		var swish := lp * 0.25 * exp(-absf(t - 0.25) * 6.0)
		var thump := sin(TAU * 48.0 * t) * exp(-maxf(t - 0.02, 0.0) * 3.5) * 0.9
		a[i] = thump + brown * 5.0 * exp(-t * 1.2) + swish
	# branches cracking as it lands
	for c in 40:
		var at := int(randf_range(0.0, 1.4) * RATE)
		var amp := randf_range(0.1, 0.5) * exp(-float(at) / RATE)
		for k in 400:
			if at + k < a.size():
				a[at + k] += randf_range(-1.0, 1.0) * amp * exp(-k / 50.0)
	return _to_stream(a, false)


static func _make_splash() -> AudioStreamWAV:
	var a := _new(0.9)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.35
		a[i] = lp * exp(-t * 6.0) * 0.8
	for b in 12:
		var at := int(randf_range(0.05, 0.7) * RATE)
		var f := randf_range(500.0, 1100.0)
		for k in 1200:
			if at + k < a.size():
				var tt := float(k) / RATE
				a[at + k] += sin(TAU * f * tt * (1.0 + tt * 6.0)) * exp(-tt * 40.0) * 0.18
	return _to_stream(a, false)


static func _make_glass_tap(variant: int) -> AudioStreamWAV:
	var a := _new(0.06)
	# a hard little tick with the faint ring of the pane behind it
	var f := 2400.0 + variant * 700.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.6
		a[i] = lp * exp(-t * 900.0) * 0.6 + sin(TAU * f * t) * exp(-t * 120.0) * 0.12
	return _to_stream(a, false)


static func _make_drip(variant: int) -> AudioStreamWAV:
	var a := _new(0.16)
	# the "plink": a tone that bends upward as the bubble closes, and a tiny tick of impact
	var f := 900.0 + variant * 330.0
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * f * (1.0 + t * 9.0) / RATE
		a[i] = sin(ph) * exp(-t * 38.0) * 0.5
		if i < 90:
			a[i] += randf_range(-1.0, 1.0) * (1.0 - i / 90.0) * 0.25
	return _to_stream(a, false)


static func _make_sizzle(seconds: float) -> AudioStreamWAV:
	var a := _new(seconds)
	var prev := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var x := randf_range(-1.0, 1.0)
		var hp := x - prev
		prev = x
		var crackle := randf_range(-1.0, 1.0) * (0.8 if randf() < 0.01 else 0.0)
		a[i] = (hp * 0.35 + crackle) * minf(t / 0.02, 1.0) * exp(-t * 2.2)
	return _to_stream(a, false)


static func _make_bubbling(seconds: float) -> AudioStreamWAV:
	var a := _new(seconds)
	var brown := 0.0
	for i in a.size():
		brown = (brown + 0.02 * randf_range(-1.0, 1.0)) / 1.02
		a[i] = brown * 2.0
	for b in int(seconds * 7.0):
		var at := randi() % maxi(a.size() - 3000, 1)
		var f := randf_range(70.0, 160.0)
		for k in 2500:
			var tt := float(k) / RATE
			a[at + k] += sin(TAU * f * tt * (1.0 + tt * 8.0)) * exp(-tt * 18.0) * 0.35
	return _to_stream(_seam(a), true)


static func _make_fire(seconds: float) -> AudioStreamWAV:
	var a := _new(seconds)
	var lp := 0.0
	for i in a.size():
		lp += (randf_range(-1.0, 1.0) - lp) * 0.05
		a[i] = lp * 0.5
	for c in int(seconds * 30.0):
		var at := randi() % maxi(a.size() - 400, 1)
		var amp := randf_range(0.05, 0.5) if randf() < 0.85 else randf_range(0.5, 0.9)
		for k in 300:
			a[at + k] += randf_range(-1.0, 1.0) * amp * exp(-k / 25.0)
	return _to_stream(_seam(a), true)


static func _make_shriek() -> AudioStreamWAV:
	var a := _new(1.1)
	var p1 := 0.0
	var p2 := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 520.0 + 380.0 * sin(t * 3.0) - t * 260.0 + sin(t * 70.0) * 25.0
		p1 += f / RATE
		p2 += f * 1.49 / RATE
		var rasp := randf_range(-1.0, 1.0) * 0.5
		var v := sin(TAU * p1 + sin(TAU * p2) * 2.5) * 0.6 + rasp * (0.4 + 0.3 * sin(t * 40.0))
		lp += (v - lp) * 0.35
		var env := minf(t / 0.05, 1.0) * exp(-maxf(t - 0.2, 0.0) * 2.6)
		a[i] = lp * env * 0.55
	return _to_stream(a, false)


static func _make_growl() -> AudioStreamWAV:
	var a := _new(0.9)
	var phase := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		phase += (68.0 + 10.0 * sin(t * 11.0)) / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var am := 0.6 + 0.4 * sin(t * 47.0)
		lp += (saw * am + randf_range(-0.3, 0.3) - lp) * 0.12
		a[i] = lp * minf(t / 0.08, 1.0) * minf((0.9 - t) / 0.3, 1.0) * 0.9
	return _to_stream(a, false)


static func _make_breath() -> AudioStreamWAV:
	var a := _new(2.2)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.3
		var env := maxf(0.0, sin(t / 2.2 * PI * 2.0)) * 0.8 + maxf(0.0, -sin(t / 2.2 * PI * 2.0)) * 0.4
		var rattle := 0.7 + 0.3 * sin(t * 90.0)
		a[i] = (lp - lp2) * env * rattle * 1.6
	return _to_stream(a, false)


static func _make_heartbeat() -> AudioStreamWAV:
	var a := _new(1.0)
	for beat: float in [0.0, 0.22]:
		var at := int(beat * RATE)
		for k in int(0.18 * RATE):
			var t := float(k) / RATE
			a[at + k] += sin(TAU * 52.0 * t) * exp(-t * 22.0) * (0.9 if beat == 0.0 else 0.6)
	return _to_stream(a, true)


static func _make_crickets(seconds: float) -> AudioStreamWAV:
	var a := _new(seconds)
	for c in 3:
		var f := randf_range(3800.0, 4800.0)
		var rate := randf_range(2.5, 4.0)
		var off := randf()
		var amp := randf_range(0.05, 0.12)
		for i in a.size():
			var t := float(i) / RATE
			var chirp := fmod(t * rate + off, 1.0)
			if chirp < 0.25:
				var pulse := 0.5 + 0.5 * sin(TAU * 45.0 * t)
				a[i] += sin(TAU * f * t) * pulse * amp * sin(chirp / 0.25 * PI)
	return _to_stream(_seam(a, 600), true)


static func _make_pad() -> AudioStreamWAV:
	# A minor, F major, C major, E minor: slow, low, a little detuned
	var rate := 11025
	var chords := [[110.0, 164.81, 220.0, 261.63], [87.31, 174.61, 220.0, 261.63], [65.41, 130.81, 196.0, 329.63], [82.41, 164.81, 196.0, 246.94]]
	var chord_len := 8.0
	var n := int(chord_len * chords.size() * rate)
	var a := PackedFloat32Array()
	a.resize(n)
	var phases := PackedFloat32Array()
	phases.resize(8)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var ci := int(t / chord_len) % chords.size()
		var local := fmod(t, chord_len)
		var v := 0.0
		for k in 4:
			var f: float = chords[ci][k]
			for d in 2:
				var idx := k * 2 + d
				phases[idx] = fmod(phases[idx] + f * (1.0 + (d * 2 - 1) * 0.0025) / rate, 1.0)
				var tri := 1.0 - 4.0 * absf(phases[idx] - 0.5)
				v += (sin(TAU * phases[idx]) * 0.7 + tri * 0.3) * (0.3 if k == 0 else 0.18)
		# swell into each chord and fade before the next, so the change is soft
		var swell := smoothstep(0.0, 3.0, local) * (1.0 - smoothstep(chord_len - 2.0, chord_len, local)) * 0.85 + 0.15
		lp += (v * swell - lp) * 0.18
		a[i] = lp * 0.35 * (0.85 + 0.15 * sin(t * 0.7))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(a[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n
	return s
