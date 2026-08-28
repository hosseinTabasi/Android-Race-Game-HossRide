extends Node3D
## Spawns and drives the traffic the player weaves through.
##
## The world is treated as a treadmill: the rider stays at z = 0 and everything
## else slides past. That keeps float precision perfect over an infinite run and
## makes "relative speed" the only number that matters. A car's on-screen
## velocity is simply (its speed - the rider's speed), so overtaking, being
## overtaken, and closing on a slow bus all fall out of one line of maths.
##
## Vehicles are pooled per body type. Building a Samand mesh costs real time,
## so we build each body once, then recycle instances forever.

signal near_miss(closeness: float)
signal collided(vehicle_name: String, relative_speed: float)

const LANE_WIDTH := RoadBuilder.LANE_WIDTH
## How far ahead traffic is spawned. Must exceed the draw distance or cars
## visibly pop into existence.
const SPAWN_AHEAD := 260.0
const DESPAWN_BEHIND := -70.0
## Rider half-width for the overlap test - deliberately generous so that
## clipping a mirror counts as a hit.
const RIDER_HALF_W := 0.42
const RIDER_HALF_L := 1.05
## A pass closer than this counts as a near miss and feeds the multiplier.
const NEAR_MISS_DIST := 1.30

@export var lane_count: int = 4
@export var max_vehicles: int = 46
## Target gap between cars in a lane, in seconds of headway. Lower is denser.
@export var density: float = 1.0

var rng := RandomNumberGenerator.new()
var _pool: Dictionary = {}          # body_id -> Array[Node3D] of idle instances
var _active: Array = []             # Array[Dictionary] of live vehicle records
var _player_speed: float = 0.0
var _player_x: float = 0.0
var _enabled: bool = false
## Cars we have already scored a near miss against, so one pass scores once.
var _scored: Dictionary = {}


func _ready() -> void:
	rng.randomize()


var _spawning: bool = true
var _collisions: bool = true


func set_enabled(on: bool) -> void:
	_enabled = on
	_spawning = on
	_collisions = on
	if not on:
		_recycle_all()


## Disarms crashes without removing traffic. Used on the approach to Amirabad:
## the remaining cars keep driving so the road stays alive, but nothing can
## end the run metres from the front door.
func set_collisions(on: bool) -> void:
	_collisions = on


## Stops new traffic appearing while letting whatever is already on the road
## drive away naturally. Used for the run-in to Amirabad, so the last stretch
## clears itself instead of cars popping out of existence.
func stop_spawning() -> void:
	_spawning = false


func lane_x(lane: int) -> float:
	var half := lane_count * LANE_WIDTH * 0.5
	return -half + (lane + 0.5) * LANE_WIDTH


## Driven from the player each physics frame.
func update_traffic(delta: float, player_speed: float, player_x: float) -> void:
	if not _enabled:
		return
	_player_speed = player_speed
	_player_x = player_x

	_drive(delta)
	_spawn()
	_check_interactions()


# =======================================================================
#  Driving
# =======================================================================

func _drive(delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var v: Dictionary = _active[i]
		var node: Node3D = v["node"]

		# Relative motion: this is the whole treadmill trick.
		var rel: float = float(v["speed"]) - _player_speed
		node.position.z += rel * delta

		# --- following behaviour -------------------------------------
		# Cars slow for whatever is directly ahead of them in their lane.
		var ahead := _vehicle_ahead(v)
		var braking := false
		if not ahead.is_empty():
			var gap: float = ahead["node"].position.z - node.position.z
			var safe: float = v["length"] * 0.5 + float(ahead["length"]) * 0.5 + 4.0 + v["speed"] * 0.55
			if gap < safe:
				v["speed"] = maxf(v["speed"] - 7.0 * delta, float(ahead["speed"]) * 0.92)
				braking = true
			elif gap > safe * 1.9:
				v["speed"] = minf(v["speed"] + 2.2 * delta, float(v["cruise"]))
		else:
			v["speed"] = move_toward(v["speed"], float(v["cruise"]), 2.2 * delta)

		_set_brake_lights(v, braking)

		# --- lane changes ----------------------------------------------
		v["lane_timer"] -= delta
		if v["lane_timer"] <= 0.0:
			v["lane_timer"] = rng.randf_range(4.0, 14.0)
			_maybe_change_lane(v)

		# Ease toward the target lane centre rather than snapping.
		var target_x: float = lane_x(v["lane"]) + float(v["lane_offset"])
		node.position.x = move_toward(node.position.x, target_x, 2.6 * delta)
		# Body leans very slightly into the lane change - reads as real steering.
		var drift := target_x - node.position.x
		node.rotation.z = lerpf(node.rotation.z, clampf(-drift * 0.06, -0.05, 0.05), 6.0 * delta)

		# --- wheels -----------------------------------------------------
		_spin_wheels(v, delta)

		# --- recycle ------------------------------------------------------
		if node.position.z < DESPAWN_BEHIND or node.position.z > SPAWN_AHEAD + 120.0:
			_recycle(i)


## Returns the vehicle record directly ahead in the same lane, or an empty
## Dictionary if the lane is clear. Returning Dictionary rather than Variant
## keeps the caller's `:=` inferable.
func _vehicle_ahead(v: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := INF
	var z: float = v["node"].position.z
	var self_id: int = v["id"]
	for other in _active:
		# Compare by instance id, not by `==` - Dictionary equality in GDScript
		# compares contents, so two identically-configured cars would match.
		if int(other["id"]) == self_id:
			continue
		if int(other["lane"]) != int(v["lane"]):
			continue
		var gap: float = float(other["node"].position.z) - z
		if gap > 0.0 and gap < best_gap:
			best_gap = gap
			best = other
	return best


func _maybe_change_lane(v: Dictionary) -> void:
	# Buses and trucks stay put; they are the immovable obstacles that make
	# the lane geometry interesting.
	if String(v["class"]) in ["bus", "truck"]:
		return
	if rng.randf() > 0.35:
		return

	var dir := 1 if rng.randf() < 0.5 else -1
	var target: int = int(v["lane"]) + dir
	if target < 0 or target >= lane_count:
		target = int(v["lane"]) - dir
	if target < 0 or target >= lane_count:
		return

	# Only move if there is a real gap in the target lane.
	var z: float = v["node"].position.z
	for other in _active:
		if int(other["lane"]) != target:
			continue
		var gap: float = absf(float(other["node"].position.z) - z)
		if gap < float(v["length"]) + float(other["length"]) + 8.0:
			return

	v["lane"] = target


func _spin_wheels(v: Dictionary, delta: float) -> void:
	var wheels: Node3D = v.get("wheels")
	if wheels == null:
		return
	var radius: float = v["wheel_r"]
	if radius <= 0.0:
		return
	# Spin by ground speed, not relative speed - the tyre meets real tarmac.
	var spin: float = (float(v["speed"]) / radius) * delta
	for w in wheels.get_children():
		# The wheel node is yawed 90 degrees, so its local UP is the axle and
		# it points to the car's left. Negating makes the top of the wheel
		# travel forward, which is the direction a rolling wheel actually goes.
		(w as Node3D).rotate_object_local(Vector3.UP, -spin)


func _set_brake_lights(v: Dictionary, on: bool) -> void:
	if bool(v["braking"]) == on:
		return
	v["braking"] = on
	var node: Node3D = v["node"]
	var mat: Material = MaterialLibrary.brake_light() if on else MaterialLibrary.taillight()
	for child in node.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Taillight"):
			(child as MeshInstance3D).material_override = mat


# =======================================================================
#  Spawning
# =======================================================================

func _spawn() -> void:
	if not _spawning:
		return
	if _active.size() >= max_vehicles:
		return

	for lane in lane_count:
		# Lanes fill independently, which is what produces natural clumps and
		# gaps instead of a uniform grid of cars.
		var occupied := false
		for v in _active:
			if int(v["lane"]) == lane and float(v["node"].position.z) > SPAWN_AHEAD - 40.0:
				occupied = true
				break
		if occupied:
			continue

		# Headway-based gate: denser traffic at higher density values.
		if rng.randf() > 0.02 * density:
			continue

		_spawn_one(lane)
		if _active.size() >= max_vehicles:
			return


func _spawn_one(lane: int) -> void:
	# Pick a body, weighted both by how common it is and by lane discipline.
	var body_id := ""
	for _attempt in 6:
		var candidate := CarCatalog.random_id(rng)
		var cls := String(CarCatalog.spec(candidate)["class"])
		var w := CarCatalog.lane_weight(cls, lane, lane_count)
		if rng.randf() < clampf(w, 0.0, 1.0) or w >= 1.0:
			body_id = candidate
			break
	if body_id == "":
		body_id = "pride"

	var spec := CarCatalog.spec(body_id)
	var node := _take_from_pool(body_id)

	var speeds: Array = spec["speed_range"]
	# Lane 0 is the slow lane; the outside lane runs fastest.
	var lane_bias := float(lane) / maxf(1.0, float(lane_count - 1))
	var cruise := lerpf(float(speeds[0]), float(speeds[1]), clampf(lane_bias + rng.randf_range(-0.25, 0.25), 0.0, 1.0))

	var record := {
		"node": node,
		"body_id": body_id,
		"class": String(spec["class"]),
		"lane": lane,
		"lane_offset": rng.randf_range(-0.35, 0.35),
		"speed": cruise,
		"cruise": cruise,
		"length": float(spec["length"]),
		"width": float(spec["width"]),
		"wheel_r": float(spec["wheel_r"]),
		"wheels": node.get_node_or_null("Wheels"),
		"braking": false,
		"lane_timer": rng.randf_range(2.0, 10.0),
		"id": node.get_instance_id(),
	}

	node.position = Vector3(lane_x(lane) + float(record["lane_offset"]), 0.0, SPAWN_AHEAD + rng.randf_range(0.0, 60.0))
	node.rotation = Vector3.ZERO
	node.visible = true

	_active.append(record)


func _take_from_pool(body_id: String) -> Node3D:
	if not _pool.has(body_id):
		_pool[body_id] = []
	var bucket: Array = _pool[body_id]
	if not bucket.is_empty():
		return bucket.pop_back()

	# Build a fresh one. Taxis get a livery; everything else gets street paint.
	var livery := ""
	var paint := CarCatalog.random_paint(rng)
	if body_id in CarCatalog.TAXI_BODIES and rng.randf() < 0.22:
		if rng.randf() < 0.6:
			livery = "yellow"
			paint = CarCatalog.TAXI_YELLOW
		else:
			livery = "green"
			paint = CarCatalog.TAXI_GREEN

	var node := VehicleBuilder.build(body_id, paint, livery)
	add_child(node)
	return node


func _recycle(index: int) -> void:
	var v: Dictionary = _active[index]
	var node: Node3D = v["node"]
	node.visible = false
	node.position = Vector3(0, -500, 0)
	_scored.erase(v["id"])
	if not _pool.has(v["body_id"]):
		_pool[v["body_id"]] = []
	_pool[v["body_id"]].append(node)
	_active.remove_at(index)


func _recycle_all() -> void:
	for i in range(_active.size() - 1, -1, -1):
		_recycle(i)
	_scored.clear()


# =======================================================================
#  Player interaction
# =======================================================================

func _check_interactions() -> void:
	for v in _active:
		var node: Node3D = v["node"]
		var dz: float = absf(node.position.z)
		var half_l: float = float(v["length"]) * 0.5

		# Only care about vehicles overlapping the rider's z band.
		if dz > half_l + RIDER_HALF_L + NEAR_MISS_DIST:
			continue

		var dx: float = absf(node.position.x - _player_x)
		var half_w: float = float(v["width"]) * 0.5
		var gap_x: float = dx - (half_w + RIDER_HALF_W)
		var overlapping_z: bool = dz < half_l + RIDER_HALF_L

		if overlapping_z and gap_x <= 0.0:
			if not _collisions:
				continue
			collided.emit(String(CarCatalog.spec(v["body_id"])["name"]),
				absf(_player_speed - float(v["speed"])))
			return

		# Near miss: threaded the gap without touching.
		if overlapping_z and gap_x < NEAR_MISS_DIST and not _scored.has(v["id"]):
			_scored[v["id"]] = true
			var closeness := 1.0 - (gap_x / NEAR_MISS_DIST)
			near_miss.emit(clampf(closeness, 0.0, 1.0))


## Cars just ahead notice the horn. Some pull into another lane, some only
## edge over within their own, and - Tehran being Tehran - plenty ignore it
## completely. Buses and trucks never move for a motorbike.
func react_to_horn(player_x: float) -> void:
	for v in _active:
		var node: Node3D = v["node"]
		var z: float = node.position.z
		if z < 0.0 or z > 45.0:
			continue
		if absf(node.position.x - player_x) > LANE_WIDTH * 0.9:
			continue
		if String(v["class"]) in ["bus", "truck"]:
			continue

		var roll := rng.randf()
		if roll < 0.40:
			_maybe_change_lane(v)
		elif roll < 0.70:
			# Shuffles aside without committing to a full lane change.
			var away := signf(node.position.x - player_x)
			if is_zero_approx(away):
				away = 1.0
			v["lane_offset"] = clampf(float(v["lane_offset"]) + away * 0.55, -1.3, 1.3)


## Nearest vehicle ahead of the rider, used by the HUD warning and the
## Persian shout triggers.
func nearest_ahead() -> Dictionary:
	var best := {}
	var best_z := INF
	for v in _active:
		var z: float = v["node"].position.z
		if z > 0.0 and z < best_z:
			best_z = z
			best = v
	return best


func active_count() -> int:
	return _active.size()
