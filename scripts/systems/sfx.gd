extends Node
## All non-music audio.
##
## Three layers, mixed independently of the radio:
##
##   engine  - a continuous loop whose pitch tracks road speed, plus a second
##             voice an octave up that fades in under load. Two layers is the
##             cheapest way to stop a single pitched loop sounding like a
##             mosquito at high revs.
##   world   - one-shots: horns, tyre scrub, crashes, the lighter, rain.
##   voice   - Persian shouts triggered on close passes. These are positional
##             so they sweep past the rider properly.
##
## Clips live in assets/sfx/ and are looked up by name at load. Anything
## missing is skipped silently rather than crashing, so the game runs with a
## partial sound set - which matters because the shipped clips are synthesised
## placeholders meant to be replaced.

const SFX_DIR := "res://assets/sfx"
## Simultaneous positional voices. More than this on a phone is wasted.
const VOICE_POOL := 6
const ONESHOT_POOL := 10

## Everything non-musical sits well under the radio. The engine is a constant
## drone and the rain is a constant hiss, so at equal levels they bury the
## music completely - the mix has to be deliberately lopsided in the music's
## favour for the station to be the thing you actually hear.
var master_volume: float = 0.48
var enabled: bool = true

var _engine_low: AudioStreamPlayer
var _engine_high: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _oneshots: Array[AudioStreamPlayer] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _next_oneshot: int = 0
var _next_voice: int = 0
var _clips: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _rain_level: float = 0.0
## Cooldown so a dense stretch of traffic doesn't turn into a shouting match.
var _voice_cooldown: float = 0.0
var _horn_cooldown: float = 0.0

## Clips that make up the Persian voice bank. The synth tool writes these
## names; swap in real recordings using the same filenames and nothing else
## needs to change.
const VOICE_CLIPS := [
	"voice/shout_01", "voice/shout_02", "voice/shout_03",
	"voice/shout_04", "voice/shout_05", "voice/shout_06",
]


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_clips()
	_build_players()


func _process(delta: float) -> void:
	_voice_cooldown = maxf(0.0, _voice_cooldown - delta)
	_horn_cooldown = maxf(0.0, _horn_cooldown - delta)


# =======================================================================
#  Setup
# =======================================================================

func _load_clips() -> void:
	_scan(SFX_DIR, "")


func _scan(path: String, prefix: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with("."):
				_scan(path.path_join(name), prefix + name + "/")
		else:
			var clean := name.trim_suffix(".import")
			var ext := clean.get_extension().to_lower()
			if ext in ["wav", "ogg", "mp3"]:
				var key := prefix + clean.get_basename()
				var res: Resource = load(path.path_join(clean))
				if res is AudioStream:
					_clips[key] = res
		name = dir.get_next()
	dir.list_dir_end()


func _build_players() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"

	_engine_low = AudioStreamPlayer.new()
	_engine_low.bus = bus
	_engine_low.volume_db = -80.0
	_engine_low.stream = _clip("bike/engine_loop")
	_loopify(_engine_low.stream)
	add_child(_engine_low)

	_engine_high = AudioStreamPlayer.new()
	_engine_high.bus = bus
	_engine_high.volume_db = -80.0
	_engine_high.stream = _clip("bike/engine_high")
	_loopify(_engine_high.stream)
	add_child(_engine_high)

	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = bus
	_rain_player.volume_db = -80.0
	_rain_player.stream = _clip("traffic/rain_loop")
	_loopify(_rain_player.stream)
	add_child(_rain_player)

	for i in ONESHOT_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_oneshots.append(p)

	for i in VOICE_POOL:
		var v := AudioStreamPlayer3D.new()
		v.bus = bus
		# Fairly tight rolloff so a shout is clearly "that car, over there".
		v.unit_size = 6.0
		v.max_distance = 60.0
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		v.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		add_child(v)
		_voices.append(v)


func _clip(key: String) -> AudioStream:
	return _clips.get(key, null)


## Marks a stream as looping. WAV and OGG expose this differently.
func _loopify(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2   # 16-bit mono
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


# =======================================================================
#  Engine
# =======================================================================

## Called every frame with the bike's speed and how much throttle is applied.
func update_engine(speed_mps: float, top_speed: float, throttle: float) -> void:
	if not enabled or _engine_low.stream == null:
		if _engine_low.playing:
			_engine_low.stop()
			_engine_high.stop()
		return

	if not _engine_low.playing:
		_engine_low.play()
	if not _engine_high.playing and _engine_high.stream != null:
		_engine_high.play()

	# Gearbox illusion: revs climb, snap back, and climb again rather than
	# rising monotonically. Without this the engine sounds like a hairdryer.
	var norm := clampf(speed_mps / maxf(top_speed, 1.0), 0.0, 1.4)
	var gear := floorf(norm * 5.0)
	var in_gear := norm * 5.0 - gear
	var rev := 0.62 + in_gear * 0.75

	_engine_low.pitch_scale = clampf(rev, 0.5, 2.4)
	_engine_high.pitch_scale = clampf(rev * 1.5, 0.5, 3.0)

	var load_mix := clampf(throttle, 0.0, 1.0)
	# Held down hard: it should sit under the music as texture, not compete.
	_engine_low.volume_db = linear_to_db(clampf(0.30 * master_volume, 0.001, 1.0))
	_engine_high.volume_db = linear_to_db(
		clampf(0.17 * master_volume * (0.25 + 0.75 * load_mix) * clampf(norm, 0.0, 1.0), 0.001, 1.0)
	)


func stop_engine() -> void:
	_engine_low.stop()
	_engine_high.stop()


# =======================================================================
#  One-shots
# =======================================================================

func _play_oneshot(key: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not enabled:
		return
	var stream := _clip(key)
	if stream == null:
		return
	var p := _oneshots[_next_oneshot]
	_next_oneshot = (_next_oneshot + 1) % _oneshots.size()
	p.stream = stream
	p.volume_db = linear_to_db(clampf(volume * master_volume, 0.001, 1.0))
	p.pitch_scale = pitch
	p.play()


func play_horn(position: Vector3 = Vector3.ZERO) -> void:
	if _horn_cooldown > 0.0:
		return
	_horn_cooldown = _rng.randf_range(0.6, 2.4)
	var key := "traffic/horn_%02d" % (_rng.randi_range(1, 4))
	_play_positional(key, position, 0.8, _rng.randf_range(0.9, 1.15))


func play_crash(relative_speed: float) -> void:
	var force := clampf(relative_speed / 25.0, 0.2, 1.0)
	_play_oneshot("traffic/crash", force, _rng.randf_range(0.9, 1.05))
	Radio.duck(0.85)
	stop_engine()


func play_near_miss(closeness: float) -> void:
	# A whoosh whose brightness scales with how close the pass was.
	_play_oneshot("traffic/whoosh", 0.35 + closeness * 0.5, 0.85 + closeness * 0.5)

	# A close pass sometimes earns a shout out of a car window.
	if closeness > 0.55 and _voice_cooldown <= 0.0 and _rng.randf() < 0.45:
		_voice_cooldown = _rng.randf_range(2.5, 6.0)
		play_voice(Vector3(_rng.randf_range(-4.0, 4.0), 1.2, _rng.randf_range(-2.0, 3.0)))

	if closeness > 0.7 and _rng.randf() < 0.5:
		play_horn(Vector3(_rng.randf_range(-4.0, 4.0), 1.0, _rng.randf_range(-3.0, 4.0)))


## The rider's own horn. Non-positional - it's coming from under him.
func play_player_horn() -> void:
	_play_oneshot("bike/horn", 0.75, _rng.randf_range(0.97, 1.05))


func play_boost() -> void:
	_play_oneshot("bike/boost", 0.8, _rng.randf_range(0.96, 1.06))


## Thunder. `distance` 0..1 picks a closer crack or a further rumble, and sets
## how loud it lands.
func play_thunder(distance: float) -> void:
	var idx := 1
	if distance > 0.66:
		idx = 2
	elif distance > 0.33:
		idx = 3
	_play_oneshot("weather/thunder_%02d" % idx,
		lerpf(0.9, 0.35, clampf(distance, 0.0, 1.0)),
		_rng.randf_range(0.92, 1.06))


func play_lighter() -> void:
	_play_oneshot("bike/lighter", 0.55, _rng.randf_range(0.95, 1.08))


func play_drag() -> void:
	_play_oneshot("bike/inhale", 0.4, _rng.randf_range(0.95, 1.05))


func play_ui(kind: String) -> void:
	_play_oneshot("ui/%s" % kind, 0.6)


# =======================================================================
#  Positional voice
# =======================================================================

func play_voice(local_position: Vector3) -> void:
	var key: String = VOICE_CLIPS[_rng.randi() % VOICE_CLIPS.size()]
	_play_positional(key, local_position, 0.9, _rng.randf_range(0.92, 1.10))


func _play_positional(key: String, local_position: Vector3, volume: float, pitch: float) -> void:
	if not enabled:
		return
	var stream := _clip(key)
	if stream == null:
		return
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	v.stream = stream
	v.position = local_position
	v.volume_db = linear_to_db(clampf(volume * master_volume, 0.001, 1.0))
	v.pitch_scale = pitch
	v.play()


## Reparents the positional voice pool under the camera rig so distances are
## measured from the rider's ears.
func attach_to(node: Node3D) -> void:
	for v in _voices:
		if v.get_parent() != null:
			v.get_parent().remove_child(v)
		node.add_child(v)


# =======================================================================
#  Rain bed
# =======================================================================

func set_rain(intensity: float) -> void:
	_rain_level = clampf(intensity, 0.0, 1.0)
	if _rain_player.stream == null:
		return
	if _rain_level <= 0.02:
		_rain_player.stop()
		return
	if not _rain_player.playing:
		_rain_player.play()
	_rain_player.volume_db = linear_to_db(clampf(_rain_level * 0.26 * master_volume, 0.001, 1.0))


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		stop_engine()
		_rain_player.stop()
