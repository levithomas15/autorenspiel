class_name EngineAudio
extends AudioStreamPlayer3D

## Prozeduraler Motorsound. Es gibt keine Audiodateien im Projekt, deshalb
## werden die Samples aus Grundton und Harmonischen selbst berechnet.

const SAMPLE_RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback = null
var _phase: float = 0.0
var _rev: float = 0.0
var _load: float = 0.0
var _base_hz: float = 42.0
var _harmonics: Array[float] = [1.0, 0.55, 0.32, 0.18, 0.10]
var _rasp: float = 0.35


func configure(spec: Dictionary) -> void:
	match spec["drive"]:
		"awd":
			# Elektroantrieb: hoher, sauberer Ton ohne Zuendrhythmus
			_base_hz = 90.0
			_harmonics = [1.0, 0.22, 0.10, 0.05, 0.0]
			_rasp = 0.05
		_:
			_base_hz = 38.0 if spec["mass"] > 1500.0 else 44.0
			_rasp = 0.45 if spec["wing"] == "gt" else 0.32
	volume_db = -6.0
	unit_size = 14.0
	max_distance = 140.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.12
	stream = generator
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func update(rev_fraction: float, load_fraction: float) -> void:
	_rev = clampf(rev_fraction, 0.0, 1.2)
	_load = clampf(load_fraction, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var freq: float = _base_hz * (0.45 + 2.6 * _rev)
	var amp: float = 0.10 + 0.30 * _load + 0.22 * _rev
	for i in frames:
		_phase = fmod(_phase + freq / SAMPLE_RATE, 1.0)
		var sample := 0.0
		for h in _harmonics.size():
			sample += _harmonics[h] * sin(TAU * _phase * float(h + 1))
		# Leichtes Rauschen gibt dem Ton den kernigen Charakter.
		sample += _rasp * (randf() - 0.5) * (0.25 + _load)
		sample = clampf(sample * amp * 0.42, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))
