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


static func step(wet: bool) -> AudioStreamWAV:
	return _cached("step_wet" if wet else "step_dry", func(): return _make_step(wet))


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
		for p0 in [0.0, 0.16]:
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
