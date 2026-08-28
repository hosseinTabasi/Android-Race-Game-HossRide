extends Node3D
## Time of day and weather.
##
## A run starts at a random hour and then advances quickly - about one in-game
## hour per 40 seconds - so a long ride genuinely carries you from afternoon
## into dusk, night, and dawn. That single cycle does more for variety than any
## amount of extra track content, because every element of the scene keys off
## it: sun colour and angle, sky tint, fog, street lights, headlights, and the
## windows in the roadside blocks.
##
## Rain rolls in and out independently, and drives MaterialLibrary.set_wetness,
## which is what turns the asphalt into a mirror at night.

signal phase_changed(phase: String)
signal rain_changed(intensity: float)

## In-game hours per real second.
@export var time_scale: float = 0.025
@export var start_hour: float = -1.0    # <0 picks a random hour
@export var rain_chance: float = 0.34

## Pin the game to night. The clock stops advancing and the hour is held at
## `night_hour`, so every ride happens after dark.
@export var always_night: bool = true
@export var night_hour: float = 22.5
## Keep it raining permanently. Intensity still varies between showers and
## downpours so the weather isn't a flat constant, but it never dries out.
@export var always_rain: bool = true
@export var rain_floor: float = 0.55

## Lightning. Only strikes while it is actually raining.
@export var lightning_enabled: bool = true
@export var lightning_interval_min: float = 9.0
@export var lightning_interval_max: float = 26.0

@onready var sun: DirectionalLight3D = $Sun
@onready var env_node: WorldEnvironment = $WorldEnvironment

var hour: float = 15.0
var rain_intensity: float = 0.0
var wetness: float = 0.0
var phase: String = "day"

var _rain_particles: GPUParticles3D
var _flash: DirectionalLight3D
var _lightning_timer: float = 0.0
var _rain_target: float = 0.0
var _weather_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _env: Environment
var _follow: Node3D = null

# Key colours for the cycle. Tehran light is hard and slightly dusty.
const SUN_NIGHT := Color(0.16, 0.20, 0.34)
const SUN_DAWN := Color(1.0, 0.62, 0.38)
const SUN_DAY := Color(1.0, 0.96, 0.90)
const SUN_DUSK := Color(1.0, 0.52, 0.26)

const SKY_NIGHT := Color(0.035, 0.045, 0.075)
const SKY_DAWN := Color(0.55, 0.42, 0.42)
const SKY_DAY := Color(0.46, 0.60, 0.80)
const SKY_DUSK := Color(0.62, 0.38, 0.30)


func _ready() -> void:
	_rng.randomize()
	if always_night:
		hour = night_hour
	else:
		hour = _rng.randf_range(0.0, 24.0) if start_hour < 0.0 else start_hour
	_env = env_node.environment
	_build_rain()
	_build_flash()
	_weather_timer = _rng.randf_range(25.0, 80.0)
	_lightning_timer = _rng.randf_range(4.0, lightning_interval_max)

	if always_rain:
		# Start already wet, so the first frame looks right rather than fading
		# into the weather over the opening minute.
		_rain_target = _rng.randf_range(rain_floor, 1.0)
		rain_intensity = _rain_target
		wetness = 1.0
		MaterialLibrary.set_wetness(1.0)
		Sfx.set_rain(_rain_target)

	_apply(true)


## The rain volume follows the camera so it always surrounds the rider.
func set_follow_target(node: Node3D) -> void:
	_follow = node


func _process(delta: float) -> void:
	# time_scale is in-game hours per real second: 0.025 gives one hour per 40 s.
	# Pinned to night, the clock simply doesn't run.
	if always_night:
		hour = night_hour
	else:
		hour = fmod(hour + time_scale * delta, 24.0)

	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_roll_weather()

	rain_intensity = move_toward(rain_intensity, _rain_target, 0.14 * delta)

	# Roads stay wet for a while after the rain stops, then slowly dry.
	if rain_intensity > 0.02:
		wetness = move_toward(wetness, clampf(rain_intensity * 1.2, 0.0, 1.0), 0.08 * delta)
	else:
		wetness = move_toward(wetness, 0.0, 0.012 * delta)
	MaterialLibrary.set_wetness(wetness)

	_update_lightning(delta)

	if _rain_particles != null:
		_rain_particles.emitting = rain_intensity > 0.02
		_rain_particles.amount_ratio = clampf(rain_intensity, 0.0, 1.0)
		if _follow != null:
			_rain_particles.global_position = _follow.global_position + Vector3(0, 9.0, 12.0)

	_apply(false)


# =======================================================================
#  Lighting
# =======================================================================

func _apply(immediate: bool) -> void:
	var new_phase := _phase_for(hour)
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)

	# Sun elevation: below the horizon between roughly 19:00 and 06:00.
	var day_t := (hour - 6.0) / 12.0          # 0 at sunrise, 1 at sunset
	var elevation := sin(clampf(day_t, -0.2, 1.2) * PI) * 78.0 - 4.0
	var azimuth := lerpf(-95.0, 95.0, clampf(day_t, 0.0, 1.0))

	sun.rotation_degrees.x = -clampf(elevation, -20.0, 88.0)
	sun.rotation_degrees.y = azimuth

	var sun_col := _sun_colour(hour)
	var sky_col := _sky_colour(hour)
	var night_amount := _night_amount(hour)

	# Rain flattens and desaturates everything.
	var rain_mix := clampf(rain_intensity, 0.0, 1.0)
	sun_col = sun_col.lerp(Color(0.55, 0.58, 0.62), rain_mix * 0.7)
	sky_col = sky_col.lerp(Color(0.26, 0.28, 0.31), rain_mix * 0.65)

	var energy := lerpf(1.45, 0.06, night_amount) * lerpf(1.0, 0.42, rain_mix)

	if immediate:
		sun.light_color = sun_col
		sun.light_energy = energy
	else:
		sun.light_color = sun.light_color.lerp(sun_col, 0.04)
		sun.light_energy = lerpf(sun.light_energy, energy, 0.04)

	sun.shadow_enabled = night_amount < 0.85 and rain_mix < 0.8

	if _env != null:
		var sky_mat := _env.sky.sky_material as ProceduralSkyMaterial
		if sky_mat != null:
			sky_mat.sky_top_color = sky_col.darkened(0.25)
			sky_mat.sky_horizon_color = sky_col.lightened(0.12)
			sky_mat.ground_horizon_color = sky_col.darkened(0.4)
			sky_mat.ground_bottom_color = sky_col.darkened(0.7)
			sky_mat.sun_angle_max = lerpf(12.0, 40.0, rain_mix)

		_env.ambient_light_energy = lerpf(0.9, 0.12, night_amount)
		_env.ambient_light_color = sky_col

		# Fog: Tehran haze by day, thicker and closer in rain and at night.
		_env.fog_enabled = true
		_env.fog_light_color = sky_col.lerp(Color(0.5, 0.52, 0.55), rain_mix * 0.6)
		# Kept deliberately thin. Heavier fog looks better up close, but at
		# permanent night and rain it erases Milad Tower at 800 m, and the
		# tower staying on the skyline matters more than the haze.
		_env.fog_density = lerpf(0.0006, 0.0010, maxf(rain_mix, night_amount * 0.45))

		# Glow makes headlights and lit windows bloom, which is most of what
		# sells a night scene.
		_env.glow_enabled = true
		_env.glow_intensity = lerpf(0.32, 1.15, night_amount)
		_env.glow_bloom = lerpf(0.05, 0.35, maxf(night_amount, rain_mix * 0.6))


func _phase_for(h: float) -> String:
	if h < 5.0 or h >= 20.0:
		return "night"
	if h < 7.5:
		return "dawn"
	if h < 17.5:
		return "day"
	return "dusk"


## 0 in full daylight, 1 in deep night.
func _night_amount(h: float) -> float:
	if h >= 7.0 and h <= 18.0:
		return 0.0
	if h > 18.0 and h < 20.5:
		return smoothstep(18.0, 20.5, h)
	if h > 4.5 and h < 7.0:
		return 1.0 - smoothstep(4.5, 7.0, h)
	return 1.0


func _sun_colour(h: float) -> Color:
	if h < 5.0 or h >= 20.5:
		return SUN_NIGHT
	if h < 7.5:
		return SUN_NIGHT.lerp(SUN_DAWN, smoothstep(5.0, 6.8, h)).lerp(SUN_DAY, smoothstep(6.8, 8.5, h))
	if h < 16.5:
		return SUN_DAY
	if h < 19.0:
		return SUN_DAY.lerp(SUN_DUSK, smoothstep(16.5, 18.8, h))
	return SUN_DUSK.lerp(SUN_NIGHT, smoothstep(19.0, 20.5, h))


func _sky_colour(h: float) -> Color:
	if h < 5.0 or h >= 20.5:
		return SKY_NIGHT
	if h < 7.5:
		return SKY_NIGHT.lerp(SKY_DAWN, smoothstep(5.0, 6.5, h)).lerp(SKY_DAY, smoothstep(6.5, 8.5, h))
	if h < 16.5:
		return SKY_DAY
	if h < 19.0:
		return SKY_DAY.lerp(SKY_DUSK, smoothstep(16.5, 18.5, h))
	return SKY_DUSK.lerp(SKY_NIGHT, smoothstep(19.0, 20.5, h))


func is_night() -> bool:
	return _night_amount(hour) > 0.55


# =======================================================================
#  Rain
# =======================================================================

func _roll_weather() -> void:
	_weather_timer = _rng.randf_range(70.0, 180.0)

	if always_rain:
		# Never stops, but shifts between a steady shower and a downpour so the
		# weather still has some movement in it.
		_rain_target = _rng.randf_range(rain_floor, 1.0)
		rain_changed.emit(_rain_target)
		Sfx.set_rain(_rain_target)
		return

	if _rain_target > 0.05:
		# Rain always eventually stops.
		_rain_target = 0.0
		rain_changed.emit(0.0)
		Sfx.set_rain(0.0)
	elif _rng.randf() < rain_chance:
		_rain_target = _rng.randf_range(0.35, 1.0)
		rain_changed.emit(_rain_target)
		Sfx.set_rain(_rain_target)


func force_rain(intensity: float) -> void:
	_rain_target = clampf(intensity, 0.0, 1.0)
	rain_changed.emit(_rain_target)
	Sfx.set_rain(_rain_target)


# =======================================================================
#  Lightning
# =======================================================================

## A dedicated light for the flash, rather than driving the sun. The sun's
## energy is lerped toward its target every frame by _apply(), so anything
## written to it would be wiped out before it could be seen.
func _build_flash() -> void:
	_flash = DirectionalLight3D.new()
	_flash.name = "LightningFlash"
	_flash.rotation_degrees = Vector3(-58.0, 28.0, 0.0)
	_flash.light_color = Color(0.86, 0.91, 1.0)
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	add_child(_flash)


func _update_lightning(delta: float) -> void:
	if not lightning_enabled or _flash == null:
		return
	# No lightning out of a clear sky.
	if rain_intensity < 0.25:
		return

	_lightning_timer -= delta
	if _lightning_timer > 0.0:
		return
	_lightning_timer = _rng.randf_range(lightning_interval_min, lightning_interval_max)
	_strike()


## One strike: a stuttering double flash, then thunder delayed by distance.
func _strike() -> void:
	# Near strikes are rare; most of it is sheet lightning off in the distance.
	var distance := _rng.randf()
	var peak := lerpf(4.5, 1.1, distance)

	var tw := create_tween()
	# Real lightning flickers - a single fade in and out looks like a lamp.
	tw.tween_property(_flash, "light_energy", peak, 0.045)
	tw.tween_property(_flash, "light_energy", peak * 0.18, 0.055)
	tw.tween_property(_flash, "light_energy", peak * 0.82, 0.040)
	tw.tween_property(_flash, "light_energy", 0.0, 0.32)

	# Sound lags light: roughly 3 s per km, scaled to the distance band.
	var lag := lerpf(0.35, 6.5, distance)
	var boom := create_tween()
	boom.tween_interval(lag)
	boom.tween_callback(func() -> void: Sfx.play_thunder(distance))


func _build_rain() -> void:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = 2400
	p.lifetime = 1.1
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-30, -14, -40), Vector3(60, 28, 80))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(26.0, 1.0, 34.0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 3.0
	mat.initial_velocity_min = 17.0
	mat.initial_velocity_max = 23.0
	mat.gravity = Vector3(0, -12.0, 0)
	mat.scale_min = 0.7
	mat.scale_max = 1.3
	p.process_material = mat

	# Long thin quads read as streaks at speed, which is what rain looks like
	# from a moving bike.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.62)
	p.draw_pass_1 = quad

	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.72, 0.80, 0.92, 0.35)
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.billboard_keep_scale = true
	quad.material = draw_mat

	add_child(p)
	_rain_particles = p
