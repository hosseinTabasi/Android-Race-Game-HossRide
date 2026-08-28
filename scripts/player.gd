extends Node3D
## Hossein. Stays at z = 0 while the world slides past him.
##
## Steering is lean-based rather than lane-snapped. Subway Surfers-style lane
## hopping would be wrong here: the whole point of the fantasy is threading a
## motorcycle through gaps that are not lane-shaped, so lateral position is
## continuous and the bike leans into it. Lane geometry still matters, but it
## belongs to the traffic, not the rider.
##
## Input works three ways, all live at once: device tilt, touch-drag, and
## keyboard for desktop testing.

signal crashed(vehicle_name: String)
signal speed_changed(speed_mps: float)
signal smoking_changed(active: bool)

@export var traffic_path: NodePath
@export var lane_count: int = 4

## How much of the road the rider may use, as a fraction of half-width.
const EDGE_MARGIN := 0.55
## Auto-throttle: the bike wants to be at full speed unless braking.
const THROTTLE_RATE := 1.0
## Base difficulty ramp: how much the speed ceiling grows per km travelled.
const SPEED_RAMP_PER_KM := 1.6
const MAX_RAMP := 20.0

# Tilt steering
const TILT_DEADZONE := 0.06
const TILT_RANGE := 0.42
@export var tilt_enabled: bool = true
@export var tilt_sensitivity: float = 2.4
@export var touch_sensitivity: float = 0.024

var speed: float = 0.0
var lateral: float = 0.0          # x position on the road
var lean: float = 0.0             # visual roll, radians
var alive: bool = true
var braking: bool = false
## Set when the banner comes into view: throttle off for the run-in home.
var _finishing: bool = false
## Set on arrival: come to a full stop beside the family.
var _halting: bool = false
## Extra ceiling granted by a boost pad, bleeding away over a few seconds.
var _boost: float = 0.0
## How fast boost bleeds off, in m/s per second.
const BOOST_DECAY := 3.4

var _stats: Dictionary = {}
var _top_speed: float = 27.0
var _accel: float = 6.5
var _brake: float = 9.0
var _lean_rate: float = 2.6
var _steer_input: float = 0.0
var _touch_steer: float = 0.0
var _touch_active: bool = false
var _bike_node: Node3D
var _front_assembly: Node3D
var _front_wheel: Node3D
var _rear_wheel: Node3D
var _rider: Node3D
var _traffic: Node = null
var _road_half_width: float = 7.0
var _cigarette: Node = null


func _ready() -> void:
	_road_half_width = lane_count * RoadBuilder.LANE_WIDTH * 0.5
	if traffic_path != NodePath():
		_traffic = get_node_or_null(traffic_path)
	_build_bike()
	_apply_stats()

	if _traffic != null:
		_traffic.near_miss.connect(_on_near_miss)
		_traffic.collided.connect(_on_collided)


func _build_bike() -> void:
	if _bike_node != null:
		_bike_node.queue_free()

	var bike_id := Game.selected_bike
	var cfg := Game.get_config(bike_id)
	_bike_node = BikeBuilder.build(bike_id, cfg["color"])
	add_child(_bike_node)

	_front_assembly = _bike_node.get_node_or_null("FrontAssembly")
	_front_wheel = _bike_node.get_node_or_null("FrontAssembly/FrontWheel")
	_rear_wheel = _bike_node.get_node_or_null("RearWheel")
	_rider = _bike_node.get_node_or_null("Rider")

	# The cigarette routine drives the rider's right arm and head, so it needs
	# the freshly built rig.
	_cigarette = get_node_or_null("Cigarette")
	if _cigarette != null and _cigarette.has_method("bind"):
		_cigarette.bind(_rider)


func _apply_stats() -> void:
	_stats = Game.active_stats()
	_top_speed = _stats["top_speed"]
	_accel = _stats["accel"]
	_brake = _stats["brake"]
	_lean_rate = _stats["lean_rate"]


## Rebuilds the bike after a garage change.
func refresh_bike() -> void:
	_build_bike()
	_apply_stats()


func start() -> void:
	alive = true
	_finishing = false
	_halting = false
	speed = 14.0
	lateral = 0.0
	lean = 0.0
	position.x = 0.0
	rotation = Vector3.ZERO
	_apply_stats()
	if _traffic != null:
		_traffic.set_enabled(true)


func stop() -> void:
	alive = false
	if _traffic != null:
		_traffic.set_enabled(false)


## The banner is in sight - ease off the throttle for the run-in.
func begin_finish() -> void:
	_finishing = true


## He's home. Come to a stop.
func halt() -> void:
	_halting = true


## Hit a boost pad. Raises the ceiling and gives an immediate shove, so the
## boost is felt now rather than only being available a second later.
func apply_boost(amount: float) -> void:
	if not alive or _finishing:
		return
	_boost = maxf(_boost, amount)
	speed = minf(speed + amount * 0.45, _top_speed + MAX_RAMP + amount)


# =======================================================================
#  Input
# =======================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_steer = clampf(_touch_steer + drag.relative.x * touch_sensitivity, -1.0, 1.0)
		_touch_active = true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			_touch_active = false


func _read_steering(delta: float) -> float:
	var raw := 0.0

	# Keyboard, for desktop testing.
	raw += Input.get_axis("steer_left", "steer_right")

	# Touch drag decays back to centre when the finger lifts.
	if _touch_active:
		raw += _touch_steer
	else:
		_touch_steer = move_toward(_touch_steer, 0.0, 3.2 * delta)
		raw += _touch_steer

	# Device tilt. Gravity on x is the natural steering axis in landscape.
	if tilt_enabled:
		var g := Input.get_gravity()
		if g.length_squared() > 0.01:
			var t := clampf(g.x / 9.8, -1.0, 1.0)
			if absf(t) > TILT_DEADZONE:
				var scaled := (absf(t) - TILT_DEADZONE) / (TILT_RANGE - TILT_DEADZONE)
				raw += signf(t) * clampf(scaled, 0.0, 1.0) * tilt_sensitivity * 0.5

	return clampf(raw, -1.0, 1.0)


# =======================================================================
#  Simulation
# =======================================================================

func _physics_process(delta: float) -> void:
	if not alive:
		return

	braking = Input.is_action_pressed("brake")
	_steer_input = _read_steering(delta)

	# --- longitudinal ------------------------------------------------
	# The speed ceiling climbs with distance, so the ride gets genuinely
	# harder rather than just spawning more cars.
	_boost = maxf(0.0, _boost - BOOST_DECAY * delta)
	var ramp := minf(Game.run_distance_m / 1000.0 * SPEED_RAMP_PER_KM, MAX_RAMP)
	var ceiling := _top_speed + ramp + _boost

	if _halting:
		speed = move_toward(speed, 0.0, _brake * 1.1 * delta)
	elif _finishing:
		# Roll off for the last stretch, but keep enough momentum to actually
		# reach the banner - stalling short of home would be a bad ending.
		speed = move_toward(speed, 7.0, _brake * 0.5 * delta)
	elif braking:
		speed = maxf(speed - _brake * delta, 6.0)
	else:
		speed = move_toward(speed, ceiling, _accel * THROTTLE_RATE * delta)

	speed_changed.emit(speed)

	# --- lateral -------------------------------------------------------
	# Steering authority falls off with speed, exactly like a real bike: at
	# 30 km/h you can flick it anywhere, at 150 it takes commitment.
	var authority := _lean_rate * lerpf(1.0, 0.55, clampf(speed / 50.0, 0.0, 1.0))
	var target_lean := _steer_input * 0.62
	lean = move_toward(lean, target_lean, authority * 1.8 * delta)

	# Lateral velocity comes from lean angle, not directly from input, which
	# is what gives the bike weight.
	var lateral_v := lean * 9.0 * lerpf(0.55, 1.0, clampf(speed / 30.0, 0.0, 1.0))
	lateral += lateral_v * delta

	# He may use the shoulder, but not climb the barrier.
	var limit := _road_half_width + RoadBuilder.SHOULDER * EDGE_MARGIN - 0.6
	if absf(lateral) > limit:
		lateral = clampf(lateral, -limit, limit)
		# Scrubbing the barrier bleeds speed and kicks the bike upright.
		speed = maxf(speed * 0.965, 6.0)
		lean *= 0.4

	position.x = lateral

	# --- visuals --------------------------------------------------------
	rotation.z = -lean
	# The bike also yaws slightly into the turn.
	rotation.y = lerpf(rotation.y, -lean * 0.18, 8.0 * delta)

	if _front_assembly != null:
		_front_assembly.rotation.y = lerpf(_front_assembly.rotation.y, -_steer_input * 0.16, 10.0 * delta)

	_spin_wheels(delta)
	_lean_rider(delta)

	# --- world ------------------------------------------------------------
	Game.add_distance(speed * delta, speed)
	if _traffic != null:
		_traffic.update_traffic(delta, speed, lateral)


func _spin_wheels(delta: float) -> void:
	var frame := BikeCatalog.frame(Game.selected_bike)
	var r: float = frame["wheel_r"]
	if r <= 0.0:
		return
	var spin := (speed / r) * delta
	if _front_wheel != null:
		_front_wheel.rotate_x(spin)
	if _rear_wheel != null:
		_rear_wheel.rotate_x(spin)


func _lean_rider(delta: float) -> void:
	if _rider == null:
		return
	# The rider counter-leans slightly less than the bike, so the pair reads
	# as a body on a machine rather than one rigid object.
	var pivot := _rider.get_node_or_null("Hips/TorsoPivot")
	if pivot != null:
		(pivot as Node3D).rotation.z = lerpf((pivot as Node3D).rotation.z, lean * 0.35, 7.0 * delta)


# =======================================================================
#  Events
# =======================================================================

func _on_near_miss(closeness: float) -> void:
	Game.register_near_miss(closeness)
	Sfx.play_near_miss(closeness)


func _on_collided(vehicle_name: String, relative_speed: float) -> void:
	if not alive:
		return
	alive = false
	Sfx.play_crash(relative_speed)
	if _traffic != null:
		_traffic.set_enabled(false)

	# Bike goes down and slides.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation:z", signf(lean if lean != 0.0 else 1.0) * 1.5, 0.55)
	tw.tween_property(self, "position:y", 0.15, 0.4)
	tw.tween_property(self, "speed", 0.0, 0.9)

	crashed.emit(vehicle_name)
