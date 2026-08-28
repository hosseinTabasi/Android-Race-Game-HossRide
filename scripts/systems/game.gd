extends Node
## Global game state: run progress, credits, garage inventory, persistence.
##
## Credits are earned purely by distance travelled - there are no pickups.
## The rate scales with how dangerously you ride: weaving close to traffic
## builds a multiplier, so a careful rider still earns, but a fast one earns
## much more.

signal credits_changed(total: int)
signal distance_changed(metres: float)
signal multiplier_changed(mult: float)
signal run_started
signal run_ended(summary: Dictionary)

const SAVE_PATH := "user://hossein_rides.save"
## Bumped to 2 when the starter bike changed from the 125 to the cruiser.
## Older saves are reset rather than migrated - there is no progress worth
## preserving this early, and a save pointing at a bike you no longer own by
## default would leave the garage in an inconsistent state.
const SAVE_VERSION := 3
const STARTER_BIKE := "cruiser1200"

# --- Run length ---------------------------------------------------------
## Distance to Amirabad. The ride is meant to last about five minutes, and at
## the speeds the bikes actually settle at (roughly 33 m/s early, rising past
## 50 m/s once the ramp kicks in) this works out close to that. Shorten it
## here if you want a quicker trip home.
const FINISH_DISTANCE_M := 11000.0

# --- Economy tuning -----------------------------------------------------
## Base credits awarded per kilometre at 1.0x multiplier.
const CREDITS_PER_KM := 100.0
## Multiplier ceiling. Reached by sustained close passes at high speed.
const MULT_MAX := 5.0
## How fast the multiplier decays back toward 1.0 (per second).
const MULT_DECAY := 0.55
## Multiplier added per near-miss, scaled by how close the pass was.
const MULT_PER_NEAR_MISS := 0.35

# --- Persistent state ---------------------------------------------------
var credits: int = 0
var best_distance_m: float = 0.0
var total_distance_m: float = 0.0
var total_runs: int = 0
var owned_bikes: Array[String] = [STARTER_BIKE]
var selected_bike: String = STARTER_BIKE
## bike_id -> { "color": Color, "upgrades": { "engine": 0, "brakes": 0, ... } }
var bike_config: Dictionary = {}

# --- Live run state -----------------------------------------------------
var run_active: bool = false
var run_distance_m: float = 0.0
var run_credits: float = 0.0
var run_near_misses: int = 0
var run_top_speed: float = 0.0
var multiplier: float = 1.0
## True when the run ended by arriving home rather than by crashing.
var run_completed: bool = false

var _accum_credit: float = 0.0


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	if not run_active:
		return
	if multiplier > 1.0:
		multiplier = maxf(1.0, multiplier - MULT_DECAY * delta)
		multiplier_changed.emit(multiplier)


# --- Run lifecycle ------------------------------------------------------

func start_run() -> void:
	run_active = true
	run_distance_m = 0.0
	run_credits = 0.0
	run_near_misses = 0
	run_top_speed = 0.0
	multiplier = 1.0
	run_completed = false
	_accum_credit = 0.0
	run_started.emit()
	distance_changed.emit(0.0)
	multiplier_changed.emit(1.0)


func end_run() -> void:
	if not run_active:
		return
	run_active = false
	total_runs += 1
	total_distance_m += run_distance_m
	best_distance_m = maxf(best_distance_m, run_distance_m)
	credits += int(run_credits)
	credits_changed.emit(credits)

	var summary := {
		"distance_m": run_distance_m,
		"credits": int(run_credits),
		"near_misses": run_near_misses,
		"top_speed_kmh": run_top_speed * 3.6,
		"is_best": is_equal_approx(run_distance_m, best_distance_m),
		"completed": run_completed,
	}
	save_game()
	run_ended.emit(summary)


## Ends the run as a success: he made it to Amirabad.
func finish_run() -> void:
	if not run_active:
		return
	run_completed = true
	end_run()


## Called every physics frame by the player with distance covered this frame.
func add_distance(metres: float, speed_mps: float) -> void:
	if not run_active:
		return
	run_distance_m += metres
	run_top_speed = maxf(run_top_speed, speed_mps)

	_accum_credit += (metres / 1000.0) * CREDITS_PER_KM * multiplier
	if _accum_credit >= 1.0:
		var whole := floorf(_accum_credit)
		run_credits += whole
		_accum_credit -= whole

	distance_changed.emit(run_distance_m)


## Registered when the player threads the gap between vehicles.
## `closeness` is 0..1, where 1 is a paint-scraping pass.
func register_near_miss(closeness: float) -> void:
	if not run_active:
		return
	run_near_misses += 1
	multiplier = minf(MULT_MAX, multiplier + MULT_PER_NEAR_MISS * closeness)
	multiplier_changed.emit(multiplier)


# --- Garage -------------------------------------------------------------

func get_config(bike_id: String) -> Dictionary:
	if not bike_config.has(bike_id):
		bike_config[bike_id] = {
			"color": BikeCatalog.default_color(bike_id),
			"upgrades": {"engine": 0, "brakes": 0, "handling": 0, "nitro": 0},
		}
	return bike_config[bike_id]


func owns(bike_id: String) -> bool:
	return owned_bikes.has(bike_id)


func try_buy_bike(bike_id: String) -> bool:
	if owns(bike_id):
		return false
	var price: int = BikeCatalog.price(bike_id)
	if credits < price:
		return false
	credits -= price
	owned_bikes.append(bike_id)
	credits_changed.emit(credits)
	save_game()
	return true


func try_upgrade(bike_id: String, part: String) -> bool:
	var cfg := get_config(bike_id)
	var level: int = cfg["upgrades"].get(part, 0)
	if level >= BikeCatalog.MAX_UPGRADE_LEVEL:
		return false
	var price: int = BikeCatalog.upgrade_price(bike_id, part, level)
	if credits < price:
		return false
	credits -= price
	cfg["upgrades"][part] = level + 1
	credits_changed.emit(credits)
	save_game()
	return true


func set_bike_color(bike_id: String, color: Color) -> void:
	get_config(bike_id)["color"] = color
	save_game()


## Final stats for the selected bike, base spec modified by upgrade levels.
func active_stats() -> Dictionary:
	var base := BikeCatalog.stats(selected_bike)
	var up: Dictionary = get_config(selected_bike)["upgrades"]
	var step := 1.0 / float(BikeCatalog.MAX_UPGRADE_LEVEL)
	return {
		"top_speed": base["top_speed"] * (1.0 + 0.45 * up.get("engine", 0) * step),
		"accel": base["accel"] * (1.0 + 0.55 * up.get("engine", 0) * step),
		"brake": base["brake"] * (1.0 + 0.60 * up.get("brakes", 0) * step),
		"lean_rate": base["lean_rate"] * (1.0 + 0.50 * up.get("handling", 0) * step),
		"nitro": float(up.get("nitro", 0)) * step,
		"mass": base["mass"],
	}


# --- Persistence --------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"credits": credits,
		"best_distance_m": best_distance_m,
		"total_distance_m": total_distance_m,
		"total_runs": total_runs,
		"owned_bikes": owned_bikes,
		"selected_bike": selected_bike,
		"bike_config": _serialise_config(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file corrupt, starting fresh.")
		return

	var data: Dictionary = parsed

	# A save from before the starter bike changed refers to a line-up that no
	# longer holds; start clean rather than half-migrate it.
	if int(data.get("version", 1)) < SAVE_VERSION:
		push_warning("Save is from an older version - starting fresh.")
		reset_progress()
		return

	credits = int(data.get("credits", 0))
	best_distance_m = float(data.get("best_distance_m", 0.0))
	total_distance_m = float(data.get("total_distance_m", 0.0))
	total_runs = int(data.get("total_runs", 0))
	selected_bike = String(data.get("selected_bike", STARTER_BIKE))

	owned_bikes.clear()
	for id in data.get("owned_bikes", [STARTER_BIKE]):
		owned_bikes.append(String(id))
	if owned_bikes.is_empty():
		owned_bikes.append(STARTER_BIKE)
	# Guard against a selection that isn't owned or no longer exists.
	if not BikeCatalog.has(selected_bike) or not owned_bikes.has(selected_bike):
		selected_bike = owned_bikes[0]

	bike_config.clear()
	for id in data.get("bike_config", {}):
		var entry: Dictionary = data["bike_config"][id]
		var c: Array = entry.get("color", [1, 1, 1])
		bike_config[id] = {
			"color": Color(c[0], c[1], c[2]),
			"upgrades": entry.get("upgrades", {}),
		}


func _serialise_config() -> Dictionary:
	var out := {}
	for id in bike_config:
		var col: Color = bike_config[id]["color"]
		out[id] = {
			"color": [col.r, col.g, col.b],
			"upgrades": bike_config[id]["upgrades"],
		}
	return out


func reset_progress() -> void:
	credits = 0
	best_distance_m = 0.0
	total_distance_m = 0.0
	total_runs = 0
	owned_bikes = [STARTER_BIKE]
	selected_bike = STARTER_BIKE
	bike_config.clear()
	save_game()
	credits_changed.emit(credits)
