extends Node

const SAMPLE_RATE: int = 44100

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _get_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return p

func _make_stream(duration: float) -> AudioStreamGenerator:
	var s := AudioStreamGenerator.new()
	s.mix_rate = SAMPLE_RATE
	s.buffer_length = max(duration, 0.1)
	return s

func _play_tones(freqs: Array, dur_each: float, vol: float = 0.4, wave: String = "square") -> void:
	var p := _get_player()
	var total: float = dur_each * freqs.size()
	var stream := _make_stream(total + 0.05)
	p.stream = stream
	p.play()
	var pb: AudioStreamGeneratorPlayback = p.get_stream_playback()
	if pb == null:
		return
	var samples_per_tone: int = int(SAMPLE_RATE * dur_each)
	for f in freqs:
		var freq: float = float(f)
		var phase: float = 0.0
		var inc: float = freq / float(SAMPLE_RATE)
		for i in range(samples_per_tone):
			phase = fmod(phase + inc, 1.0)
			var sample: float
			match wave:
				"sine":
					sample = sin(phase * TAU)
				"saw":
					sample = (phase * 2.0) - 1.0
				_:
					sample = 1.0 if phase < 0.5 else -1.0
			var t: float = float(i) / float(samples_per_tone)
			var env: float = 1.0
			if t < 0.05:
				env = t / 0.05
			elif t > 0.7:
				env = (1.0 - t) / 0.3
			sample *= env * vol
			pb.push_frame(Vector2(sample, sample))

func click() -> void:
	_play_tones([880], 0.05, 0.25, "square")

func correct() -> void:
	_play_tones([880, 1320], 0.06, 0.30, "square")

func wrong() -> void:
	_play_tones([220, 165], 0.08, 0.35, "saw")

func combo() -> void:
	_play_tones([523, 659, 784, 1047], 0.06, 0.32, "square")

func board_complete() -> void:
	_play_tones([523, 659, 784, 1047, 1319], 0.12, 0.38, "sine")

func purchase() -> void:
	_play_tones([1047, 1319, 1568], 0.07, 0.30, "sine")

func prestige() -> void:
	_play_tones([262, 392, 523, 784, 1047, 1568], 0.10, 0.40, "sine")

func achievement() -> void:
	_play_tones([784, 1047, 1568, 2093], 0.07, 0.35, "sine")
