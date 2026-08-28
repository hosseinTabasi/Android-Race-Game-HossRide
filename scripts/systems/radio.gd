extends Node
## The in-game radio station.
##
## Behaves like a radio rather than a playlist: it keeps playing across menus,
## runs, crashes and the garage, never restarting a track just because you
## died. That continuity is the whole point - the ride should feel like it has
## a soundtrack running underneath it, not a music cue that resets.
##
## Two sources are scanned, in this order:
##
##   1. user://music/     - the user's own files, added on the device. On
##                          Android this resolves inside the app's private
##                          storage, which is why import_from() exists.
##   2. res://assets/music/ - anything bundled with the build.
##
## Supported formats: .ogg and .mp3. Godot can load both at runtime; .ogg is
## preferred because loading is cheaper and seeking is exact.
##
## NOTE ON CONTENT: this project ships with no music. Add tracks you have the
## right to use. See assets/music/README.md.

signal track_changed(title: String, artist: String)
signal station_changed(name: String)
signal playlist_loaded(count: int)

const USER_MUSIC_DIR := "user://music"
const BUNDLED_MUSIC_DIR := "res://assets/music"
const SUPPORTED := ["ogg", "mp3"]
## Crossfade length between tracks, in seconds.
const FADE := 1.6

var playlist: Array[Dictionary] = []
var current_index: int = -1
var shuffle: bool = true
var enabled: bool = true

var _player: AudioStreamPlayer
var _order: Array[int] = []
var _order_pos: int = -1
var _rng := RandomNumberGenerator.new()
## Ducking: SFX like a crash briefly pull the music down.
var _duck: float = 0.0
## The station sits at full level; everything else is mixed down under it.
var _base_volume_db: float = 0.0


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "RadioPlayer"
	_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_player.volume_db = _base_volume_db
	_player.finished.connect(_on_track_finished)
	add_child(_player)

	_ensure_user_dir()
	rescan()


func _process(delta: float) -> void:
	# Recover from ducking.
	if _duck > 0.0:
		_duck = maxf(0.0, _duck - delta * 1.4)
		_player.volume_db = _base_volume_db - _duck * 16.0


# =======================================================================
#  Playlist
# =======================================================================

func _ensure_user_dir() -> void:
	if not DirAccess.dir_exists_absolute(USER_MUSIC_DIR):
		DirAccess.make_dir_recursive_absolute(USER_MUSIC_DIR)


## Rebuilds the playlist from both source directories.
func rescan() -> void:
	playlist.clear()
	_scan_dir(USER_MUSIC_DIR)
	_scan_dir(BUNDLED_MUSIC_DIR)
	_rebuild_order()
	playlist_loaded.emit(playlist.size())

	if playlist.is_empty():
		push_warning("Radio: no tracks found. Add .ogg or .mp3 files to %s" % USER_MUSIC_DIR)


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with("."):
				_scan_dir(path.path_join(name))
		else:
			# Exported projects rename imported audio, so accept .import too.
			var clean := name.trim_suffix(".import")
			var ext := clean.get_extension().to_lower()
			if ext in SUPPORTED:
				var full := path.path_join(clean)
				if not _already_listed(full):
					playlist.append(_describe(full))
		name = dir.get_next()
	dir.list_dir_end()


func _already_listed(path: String) -> bool:
	for t in playlist:
		if String(t["path"]) == path:
			return true
	return false


## Derives a title and artist from the filename, since we cannot rely on tags.
## Recognises the common "Artist - Title.mp3" convention and falls back to the
## bare filename.
func _describe(path: String) -> Dictionary:
	var base := path.get_file().get_basename()
	# Strip leading track numbers like "03 - " or "03. ".
	var stripped := base
	var re := RegEx.new()
	re.compile("^\\s*\\d{1,3}\\s*[-.\\)]\\s*")
	stripped = re.sub(stripped, "", false)

	var artist := ""
	var title := stripped
	var sep := stripped.find(" - ")
	if sep > 0:
		artist = stripped.substr(0, sep).strip_edges()
		title = stripped.substr(sep + 3).strip_edges()

	return {
		"path": path,
		"title": title.replace("_", " ").strip_edges(),
		"artist": artist,
	}


func _rebuild_order() -> void:
	_order.clear()
	for i in playlist.size():
		_order.append(i)
	if shuffle:
		# Fisher-Yates, so every ordering is equally likely.
		for i in range(_order.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp := _order[i]
			_order[i] = _order[j]
			_order[j] = tmp
	_order_pos = -1


# =======================================================================
#  Transport
# =======================================================================

func play() -> void:
	if playlist.is_empty():
		return
	if _player.playing:
		return
	if current_index < 0:
		next_track()
	else:
		_player.play()


func pause() -> void:
	_player.stream_paused = true


func resume() -> void:
	_player.stream_paused = false


func stop() -> void:
	_player.stop()


func next_track() -> void:
	if playlist.is_empty():
		rescan()
		if playlist.is_empty():
			return

	_order_pos += 1
	if _order_pos >= _order.size():
		_rebuild_order()
		_order_pos = 0

	_load_and_play(_order[_order_pos])


func previous_track() -> void:
	if playlist.is_empty():
		return
	_order_pos -= 1
	if _order_pos < 0:
		_order_pos = _order.size() - 1
	_load_and_play(_order[_order_pos])


func _load_and_play(index: int) -> void:
	if index < 0 or index >= playlist.size():
		return
	var track: Dictionary = playlist[index]
	var stream := _load_stream(String(track["path"]))
	if stream == null:
		# Skip a bad file rather than stalling the station.
		push_warning("Radio: could not load %s" % track["path"])
		playlist.remove_at(index)
		_rebuild_order()
		next_track()
		return

	current_index = index
	_player.stream = stream
	_player.play()
	track_changed.emit(String(track["title"]), String(track["artist"]))


## Loads audio from res:// via the resource loader, and from user:// by
## reading the bytes directly - user files are never imported by Godot.
func _load_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		# load() is untyped, so annotate rather than infer.
		var res: Resource = load(path)
		return res as AudioStream

	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	f.close()

	match path.get_extension().to_lower():
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			return mp3
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
	return null


func _on_track_finished() -> void:
	if enabled:
		next_track()


# =======================================================================
#  Mixing
# =======================================================================

## Briefly pulls the music down. `amount` is 0..1.
func duck(amount: float) -> void:
	_duck = maxf(_duck, clampf(amount, 0.0, 1.0))


func set_volume(linear: float) -> void:
	_base_volume_db = linear_to_db(clampf(linear, 0.0001, 1.0))
	_player.volume_db = _base_volume_db


func get_volume() -> float:
	return db_to_linear(_base_volume_db)


func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		play()
	else:
		stop()


# =======================================================================
#  Importing user files
# =======================================================================

## Copies a file the user picked into the radio's own folder and refreshes the
## playlist. Returns the destination path, or "" on failure.
func import_from(source_path: String) -> String:
	if not FileAccess.file_exists(source_path):
		return ""
	var ext := source_path.get_extension().to_lower()
	if ext not in SUPPORTED:
		return ""

	_ensure_user_dir()
	var dest := USER_MUSIC_DIR.path_join(source_path.get_file())

	var src := FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		return ""
	var data := src.get_buffer(src.get_length())
	src.close()

	var out := FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(data)
	out.close()

	rescan()
	return dest


func current_track() -> Dictionary:
	if current_index < 0 or current_index >= playlist.size():
		return {}
	return playlist[current_index]


func track_count() -> int:
	return playlist.size()
