extends Node3D
## Assembles and drives the world around the rider.
##
## Responsibilities:
##   * build and recycle the ring of road chunks and roadside blocks
##   * keep Milad Tower on the skyline, drifting at a fraction of road speed
##     so it reads as genuinely distant
##   * run the chase camera, including the speed effects that sell velocity
##
## Everything here is treadmill-relative: the rider never moves in z, so
## "recycling" is just moving a chunk from behind the camera to the far end.

const CHUNK_LENGTH := RoadBuilder.CHUNK_LENGTH
## Enough chunks to cover the draw distance plus one being recycled.
const CHUNK_COUNT := 8
const LANE_COUNT := 4

## How far out the destination is built. Well beyond draw distance, so the
## house and banner resolve out of the haze instead of popping into being.
const FINISH_SPAWN_LEAD := 600.0
## Where the rider starts easing off for the run-in.
const FINISH_SLOWDOWN := 95.0
## How long he sits there with the family before the summary appears.
const FINISH_CELEBRATION := 3.4

## Extra top speed granted by a boost pad, in m/s, on top of the current
## ceiling. It decays away rather than being a permanent gain.
const BOOST_AMOUNT := 15.0
## Fraction of recycled chunks that get a live pad. Not every stretch has one -
## a boost on every chunk stops being a reward and becomes the baseline.
const PAD_CHANCE := 0.55

@onready var player: Node3D = $Player
@onready var traffic: Node3D = $Traffic
@onready var weather: Node3D = $Weather
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var camera_rig: Node3D = $CameraRig

var _chunks: Array[Node3D] = []
var _blocks: Array[Node3D] = []
var _milad: Node3D
var _mountains: Node3D
var _rng := RandomNumberGenerator.new()
var _shake: float = 0.0
var _base_fov: float = 72.0
var _milad_z: float = 960.0
var _finish: Node3D = null
var _finish_slowing: bool = false
var _finish_done: bool = false
## One record per chunk: {node, chunk, armed}. Pads live as children of their
## chunk, so they ride the treadmill for free.
var _pads: Array[Dictionary] = []

# --- aircraft -----------------------------------------------------------
## Only ever one plane at a time; two would stop feeling like an event.
var _plane: Node3D = null
var _plane_dir: float = 1.0
var _plane_speed: float = 58.0
var _plane_timer: float = 20.0
var _strobe: Node3D = null
var _strobe_t: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_build_road()
	_build_landmarks()

	weather.set_follow_target(camera_rig)
	Sfx.attach_to(camera_rig)

	var cig := player.get_node_or_null("Cigarette")
	if cig != null and cig.has_method("set_traffic"):
		cig.set_traffic(traffic)

	player.crashed.connect(_on_player_crashed)
	traffic.near_miss.connect(_on_near_miss)


func _build_road() -> void:
	var road_root := Node3D.new()
	road_root.name = "Road"
	add_child(road_root)

	# One chunk mesh, instanced. Duplicating the node tree shares the meshes.
	var template := RoadBuilder.build_chunk(LANE_COUNT)
	var block_offset := LANE_COUNT * RoadBuilder.LANE_WIDTH * 0.5 + 8.0

	for i in CHUNK_COUNT:
		# duplicate() is statically typed as Node, so cast it back down.
		var chunk: Node3D = (template.duplicate() as Node3D) if i > 0 else template
		chunk.position.z = i * CHUNK_LENGTH - CHUNK_LENGTH
		road_root.add_child(chunk)
		_chunks.append(chunk)

		# Each chunk gets its own randomised roadside, so the repeat is hidden.
		var block := CityBuilder.build_block(_rng, CHUNK_LENGTH, block_offset)
		block.position.z = chunk.position.z
		road_root.add_child(block)
		_blocks.append(block)

		# Boost pad, parented to the chunk so it scrolls with the road.
		var pad := RoadBuilder.build_boost_pad()
		chunk.add_child(pad)
		_pads.append({"node": pad, "chunk": chunk, "armed": true})
		_place_pad(pad)
		pad.visible = _rng.randf() < PAD_CHANCE
		_pads[i]["armed"] = pad.visible


func _build_landmarks() -> void:
	_milad = CityBuilder.build_milad_tower()
	# Dead centre, at the far end of the road.
	#
	# Straight down the carriageway is the only bearing that is guaranteed
	# clear: the roadside blocks line both sides from 15 m outward, so anything
	# placed off to a side is behind that wall however far away it is. On axis
	# there is nothing between the camera and the tower but fog.
	#
	# 960 m is chosen so the whole thing fits: the tip lands about 30 degrees
	# up, inside the 36 degree half-FOV, with room to spare as the FOV widens
	# with speed.
	_milad.position = Vector3(0.0, 0.0, _milad_z)
	add_child(_milad)

	_mountains = CityBuilder.build_mountains(_rng)
	# Parented to the rig so the ridge never slides past - a horizon shouldn't.
	camera_rig.add_child(_mountains)


# =======================================================================
#  Frame update
# =======================================================================

func _physics_process(delta: float) -> void:
	var speed: float = player.speed
	if not Game.run_active:
		speed = 0.0

	_scroll(delta, speed)
	_update_plane(delta)
	_update_pads()
	_update_finish(delta, speed)
	_update_camera(delta, speed)

	Sfx.update_engine(speed, player._top_speed, 0.0 if player.braking else 1.0)


func _scroll(delta: float, speed: float) -> void:
	var d := speed * delta
	var recycle_at := -CHUNK_LENGTH * 1.5

	for i in _chunks.size():
		var chunk := _chunks[i]
		chunk.position.z -= d
		var block := _blocks[i]
		block.position.z -= d

		if chunk.position.z < recycle_at:
			# Jump it to the back of the queue.
			chunk.position.z += CHUNK_COUNT * CHUNK_LENGTH
			block.position.z = chunk.position.z
			_reseed_block(block)
			_rearm_pad(i)

	# Milad Tower deliberately does NOT scroll. It is the landmark that says
	# where you are, so it holds its place on the skyline for the whole ride
	# instead of sliding past and vanishing. At 800 m out and 315 m tall it
	# reads as genuinely distant anyway - a real tower that far away barely
	# shifts over a few kilometres of road.


## Shuffles a recycled block's buildings so the same skyline never repeats
## twice in a row.
func _reseed_block(block: Node3D) -> void:
	for child in block.get_children():
		var n := child as Node3D
		if n == null:
			continue
		# Cheap reshuffle: nudge scale and spacing rather than rebuilding
		# geometry, which would stutter mid-run.
		n.scale.y = _rng.randf_range(0.72, 1.45)
		n.rotation.y = _rng.randf_range(-0.05, 0.05)


func _update_camera(delta: float, speed: float) -> void:
	# Chase cam sits behind and above, easing laterally so the bike can move
	# within the frame instead of being pinned to the centre.
	var target_x: float = player.position.x * 0.72
	camera_rig.position.x = lerpf(camera_rig.position.x, target_x, 6.0 * delta)
	camera_rig.position.y = lerpf(camera_rig.position.y, 1.88, 4.0 * delta)

	# Roll the camera slightly with the bike's lean.
	camera_rig.rotation.z = lerpf(camera_rig.rotation.z, -player.lean * 0.22, 5.0 * delta)

	# FOV opens up with speed. This is the single strongest speed cue there is.
	var norm := clampf(speed / 55.0, 0.0, 1.0)
	var target_fov := _base_fov + norm * 22.0
	if player.braking:
		target_fov -= 6.0
	camera.fov = lerpf(camera.fov, target_fov, 3.0 * delta)

	# Road buzz: a touch of shake that grows with speed, plus impact shake.
	_shake = maxf(0.0, _shake - delta * 2.2)
	var buzz := norm * 0.012 + _shake * 0.09
	camera.h_offset = _rng.randf_range(-buzz, buzz)
	camera.v_offset = _rng.randf_range(-buzz, buzz)


# =======================================================================
#  Aircraft
# =======================================================================

## Sends an airliner across the sky every so often.
##
## Deliberately infrequent. The value of a plane overhead is that it is an
## event you happen to catch, so one every 40-90 seconds is plenty; any more
## and Tehran starts looking like a flight path.
func _update_plane(delta: float) -> void:
	if _plane == null:
		_plane_timer -= delta
		if _plane_timer <= 0.0:
			_spawn_plane()
		return

	_plane.position.x += _plane_dir * _plane_speed * delta

	# Anti-collision strobe: a short double blink roughly every 1.4 s. Timing
	# it properly matters more than the geometry - it is what the eye catches.
	_strobe_t += delta
	if _strobe != null:
		var cycle := fmod(_strobe_t, 1.4)
		_strobe.visible = cycle < 0.06 or (cycle > 0.16 and cycle < 0.22)

	# Gone past the far side of the sky.
	if absf(_plane.position.x) > 520.0:
		_plane.queue_free()
		_plane = null
		_strobe = null
		_plane_timer = _rng.randf_range(40.0, 90.0)


func _spawn_plane() -> void:
	_plane = CityBuilder.build_airliner()
	_plane_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_plane_speed = _rng.randf_range(48.0, 72.0)
	_strobe_t = 0.0

	_plane.position = Vector3(
		-_plane_dir * 500.0,
		_rng.randf_range(210.0, 340.0),
		_rng.randf_range(420.0, 820.0)
	)
	# The model is built nose-first along +Z, so yaw it onto its flight path.
	_plane.rotation.y = deg_to_rad(90.0 * _plane_dir)
	# A touch of bank, as though mid-turn on approach.
	_plane.rotation.z = deg_to_rad(-6.0 * _plane_dir)

	add_child(_plane)
	_strobe = _plane.get_node_or_null("Strobe")


# =======================================================================
#  Boost pads
# =======================================================================

## Drops a pad into a random lane at a random point along its chunk.
func _place_pad(pad: Node3D) -> void:
	var lane := _rng.randi_range(0, LANE_COUNT - 1)
	var half := LANE_COUNT * RoadBuilder.LANE_WIDTH * 0.5
	pad.position.x = -half + (lane + 0.5) * RoadBuilder.LANE_WIDTH
	pad.position.z = _rng.randf_range(-CHUNK_LENGTH * 0.38, CHUNK_LENGTH * 0.38)


## Re-rolls a pad when its chunk is recycled, so the same lane never repeats.
func _rearm_pad(index: int) -> void:
	if index >= _pads.size():
		return
	var rec: Dictionary = _pads[index]
	var node: Node3D = rec["node"]
	_place_pad(node)
	node.visible = _rng.randf() < PAD_CHANCE
	rec["armed"] = node.visible


func _update_pads() -> void:
	if not Game.run_active:
		return
	for rec in _pads:
		if not bool(rec["armed"]):
			continue
		var node: Node3D = rec["node"]
		var chunk: Node3D = rec["chunk"]
		# The pad's own z is chunk-local, so add the chunk's position back on.
		var world_z: float = chunk.position.z + node.position.z
		if absf(world_z) > 4.0:
			continue
		if absf(player.position.x - node.position.x) > 1.55:
			continue
		# Disarm so one pass grants one boost, however long the overlap lasts.
		rec["armed"] = false
		player.apply_boost(BOOST_AMOUNT)
		Sfx.play_boost()
		_shake = maxf(_shake, 0.45)


# =======================================================================
#  Arriving home
# =======================================================================

## Builds the destination once it is within range, slides it in with the rest
## of the world, and hands off to the ending when the rider reaches it.
func _update_finish(delta: float, speed: float) -> void:
	if _finish == null:
		if Game.run_active and not _finish_done:
			var remaining: float = Game.FINISH_DISTANCE_M - Game.run_distance_m
			if remaining <= FINISH_SPAWN_LEAD:
				_spawn_finish(remaining)
		return

	# The destination rides the same treadmill as everything else.
	_finish.position.z -= speed * delta

	if _finish_done:
		return

	if not _finish_slowing and _finish.position.z <= FINISH_SLOWDOWN:
		_finish_slowing = true
		player.begin_finish()
		# No crashing on the doorstep.
		traffic.set_collisions(false)

	if _finish.position.z <= 4.0:
		_finish_done = true
		player.halt()
		_arrive()


func _spawn_finish(remaining: float) -> void:
	_finish = FinishLine.new()
	_finish.name = "Amirabad"
	_finish.position = Vector3(0, 0, maxf(remaining, 30.0))
	add_child(_finish)
	# Let the road ahead clear itself out naturally over the last stretch.
	traffic.stop_spawning()


func _arrive() -> void:
	# Let him roll to a stop and the family cheer before the panel appears.
	await get_tree().create_timer(FINISH_CELEBRATION).timeout
	Game.finish_run()


func _on_near_miss(closeness: float) -> void:
	_shake = maxf(_shake, closeness * 0.55)


func _on_player_crashed(_vehicle_name: String) -> void:
	_shake = 1.6
	Game.end_run()


# =======================================================================
#  Run control
# =======================================================================

func begin_run() -> void:
	if _finish != null:
		_finish.queue_free()
		_finish = null
	_finish_slowing = false
	_finish_done = false
	player.start()
	traffic.set_enabled(true)
	Game.start_run()
	Radio.play()


func abort_run() -> void:
	player.stop()
	traffic.set_enabled(false)
	Sfx.stop_engine()
