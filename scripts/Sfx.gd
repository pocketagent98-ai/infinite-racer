class_name Sfx
extends RefCounted
## Procedurally generated sound effects. The audio is synthesised into
## AudioStreamWAV objects in code, so the game ships with sound and still has
## zero third-party asset licensing obligations.

const RATE := 22050

static func _wav(data: PackedByteArray, loop: bool, n_samples: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n_samples
	return w

## Low rumbling engine loop; pitch is driven by speed at runtime.
static func engine_loop() -> AudioStreamWAV:
	var n := 8192
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var f := 62.0
	for i in range(n):
		phase = fmod(phase + f / float(RATE), 1.0)
		var saw: float = phase * 2.0 - 1.0
		var sub: float = sin(TAU * phase * 0.5)
		var v: float = saw * 0.45 + sub * 0.35
		v *= 0.72 + 0.28 * sin(TAU * float(i) * 24.0 / float(RATE))   # combustion pulse
		v = clampf(v, -1.0, 1.0) * 0.55
		data.encode_s16(i * 2, int(v * 32767.0))
	return _wav(data, true, n)

## Rubbery tyre squeal (low-passed noise).
static func screech_loop() -> AudioStreamWAV:
	var n := 4096
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp := 0.0
	for i in range(n):
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.35)
		data.encode_s16(i * 2, int(clampf(lp, -1.0, 1.0) * 0.5 * 32767.0))
	return _wav(data, true, n)

## Short whoosh when nitro fires.
static func nitro_burst() -> AudioStreamWAV:
	var n := 6615
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(n):
		var t := float(i) / float(RATE)
		var env: float = exp(-t * 6.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var tone: float = sin(TAU * (180.0 + 900.0 * t) * t)
		var v: float = clampf(noise * 0.5 + tone * 0.5, -1.0, 1.0) * env * 0.6
		data.encode_s16(i * 2, int(v * 32767.0))
	return _wav(data, false, n)

## UI click.
static func click() -> AudioStreamWAV:
	var n := 900
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(RATE)
		var env: float = exp(-t * 60.0)
		data.encode_s16(i * 2, int(sin(TAU * 1400.0 * t) * env * 0.5 * 32767.0))
	return _wav(data, false, n)
