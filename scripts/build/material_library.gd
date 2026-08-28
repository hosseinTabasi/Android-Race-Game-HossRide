class_name MaterialLibrary
extends RefCounted
## Shared materials for every procedurally built object.
##
## Materials are cached and shared aggressively. On mobile, a fresh
## StandardMaterial3D per car means a fresh shader variant and a stall on
## first sight of that car; sharing one material per paint colour keeps the
## whole traffic system down to a handful of pipeline states.
##
## Wetness is driven globally: weather.gd calls set_wetness() when it starts
## raining, and every cached surface darkens and sharpens its reflections at
## once, which is what sells a wet Tehran expressway at night.

static var _paints: Dictionary = {}
static var _cache: Dictionary = {}
static var _wetness: float = 0.0


# =======================================================================
#  Vehicle surfaces
# =======================================================================

static func car_paint(color: Color) -> StandardMaterial3D:
	var key := "%d" % color.to_rgba32()
	if _paints.has(key):
		return _paints[key]

	var m := StandardMaterial3D.new()
	m.albedo_color = color
	# Automotive clearcoat: fairly smooth, slightly metallic flake.
	m.metallic = 0.35
	m.metallic_specular = 0.65
	m.roughness = lerpf(0.28, 0.12, _wetness)
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.4
	_paints[key] = m
	return m


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	# Tinted, as almost every car in Tehran is.
	m.albedo_color = Color(0.05, 0.07, 0.09, 0.62)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.0
	m.metallic_specular = 1.0
	m.roughness = 0.04
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass"] = m
	return m


static func tyre() -> StandardMaterial3D:
	if _cache.has("tyre"):
		return _cache["tyre"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.045, 0.045, 0.05)
	m.metallic = 0.0
	m.roughness = lerpf(0.92, 0.55, _wetness)
	_cache["tyre"] = m
	return m


static func rim() -> StandardMaterial3D:
	if _cache.has("rim"):
		return _cache["rim"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.60, 0.62, 0.65)
	m.metallic = 0.85
	m.roughness = 0.30
	_cache["rim"] = m
	return m


static func chrome() -> StandardMaterial3D:
	if _cache.has("chrome"):
		return _cache["chrome"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.79, 0.81)
	m.metallic = 1.0
	m.roughness = 0.08
	_cache["chrome"] = m
	return m


static func matte_black() -> StandardMaterial3D:
	if _cache.has("matte_black"):
		return _cache["matte_black"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.055)
	m.metallic = 0.1
	m.roughness = 0.75
	_cache["matte_black"] = m
	return m


static func headlight() -> StandardMaterial3D:
	if _cache.has("headlight"):
		return _cache["headlight"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.94, 0.88)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.96, 0.85)
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.1
	_cache["headlight"] = m
	return m


static func taillight() -> StandardMaterial3D:
	if _cache.has("taillight"):
		return _cache["taillight"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.05, 0.05)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.10, 0.06)
	m.emission_energy_multiplier = 1.6
	m.roughness = 0.2
	_cache["taillight"] = m
	return m


static func brake_light() -> StandardMaterial3D:
	if _cache.has("brake_light"):
		return _cache["brake_light"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.05, 0.05)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.08, 0.04)
	m.emission_energy_multiplier = 5.0
	_cache["brake_light"] = m
	return m


static func taxi_sign(color: Color) -> StandardMaterial3D:
	var key := "taxisign_%d" % color.to_rgba32()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.7
	m.roughness = 0.4
	_cache[key] = m
	return m


static func plate() -> StandardMaterial3D:
	if _cache.has("plate"):
		return _cache["plate"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.88, 0.88, 0.84)
	m.metallic = 0.2
	m.roughness = 0.45
	_cache["plate"] = m
	return m


# =======================================================================
#  Road and world surfaces
# =======================================================================

static func asphalt() -> StandardMaterial3D:
	if _cache.has("asphalt"):
		return _cache["asphalt"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.085, 0.085, 0.092)
	m.metallic = 0.0
	m.metallic_specular = 0.5
	m.roughness = 0.88
	_cache["asphalt"] = m
	return m


static func lane_paint() -> StandardMaterial3D:
	if _cache.has("lane_paint"):
		return _cache["lane_paint"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.82, 0.80)
	m.roughness = 0.7
	_cache["lane_paint"] = m
	return m


static func concrete(shade: float = 1.0) -> StandardMaterial3D:
	var key := "concrete_%.2f" % shade
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.41, 0.39) * shade
	m.roughness = 0.85
	_cache[key] = m
	return m


static func building(color: Color) -> StandardMaterial3D:
	var key := "bld_%d" % color.to_rgba32()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.80
	m.metallic = 0.05
	_cache[key] = m
	return m


## Lit windows for night-time buildings and the Milad Tower shaft.
static func lit_window(warmth: float = 1.0) -> StandardMaterial3D:
	var key := "win_%.2f" % warmth
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.10, 0.10, 0.12)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.82, 0.55).lerp(Color(0.7, 0.85, 1.0), 1.0 - warmth)
	m.emission_energy_multiplier = 1.0
	m.roughness = 0.25
	_cache[key] = m
	return m


static func street_light_glow() -> StandardMaterial3D:
	if _cache.has("slglow"):
		return _cache["slglow"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.80, 0.50)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache["slglow"] = m
	return m


# =======================================================================
#  Global wetness
# =======================================================================

## Called by the weather system. 0 = bone dry, 1 = standing water.
static func set_wetness(w: float) -> void:
	_wetness = clampf(w, 0.0, 1.0)

	for key in _paints:
		var m: StandardMaterial3D = _paints[key]
		m.roughness = lerpf(0.28, 0.12, _wetness)

	if _cache.has("asphalt"):
		var a: StandardMaterial3D = _cache["asphalt"]
		# Wet asphalt goes darker AND much glossier - both matter.
		a.albedo_color = Color(0.085, 0.085, 0.092).lerp(Color(0.030, 0.031, 0.036), _wetness)
		a.roughness = lerpf(0.88, 0.14, _wetness)
		a.metallic = lerpf(0.0, 0.30, _wetness)

	if _cache.has("lane_paint"):
		var lp: StandardMaterial3D = _cache["lane_paint"]
		lp.roughness = lerpf(0.70, 0.22, _wetness)

	if _cache.has("tyre"):
		var t: StandardMaterial3D = _cache["tyre"]
		t.roughness = lerpf(0.92, 0.55, _wetness)


static func get_wetness() -> float:
	return _wetness


static func clear_cache() -> void:
	_paints.clear()
	_cache.clear()
