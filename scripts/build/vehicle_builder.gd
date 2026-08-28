class_name VehicleBuilder
extends RefCounted
## Builds car meshes at runtime by lofting the section profiles in CarCatalog.
##
## Every ring of the loft is a rounded rectangle rather than a hard box, which
## is the single biggest reason the result reads as a car: real bodies have
## radiused shoulders and a crowned roof, and a boxed silhouette never looks
## right no matter how good the lighting is.
##
## The whole vehicle is assembled once per body type and then reused through
## MultiMesh-free instancing (duplicated node trees sharing meshes), so having
## forty cars on screen costs forty transforms, not forty mesh builds.

const RING_SEGMENTS := 20      # points around each cross-section
const LOFT_SAMPLES := 26       # rings along the body length
const CABIN_SAMPLES := 18
const WHEEL_SEGMENTS := 18

## Cache: body_id -> built Mesh resources, so we build each shape only once.
static var _mesh_cache: Dictionary = {}
static var _wheel_cache: Dictionary = {}


# =======================================================================
#  Public entry point
# =======================================================================

## Builds a complete vehicle node tree: body, glass, wheels, lights, plate.
## The returned Node3D has its origin at the centre of the wheelbase, on the
## road surface, which is what the traffic system wants to position.
static func build(body_id: String, paint: Color, livery: String = "") -> Node3D:
	var spec := CarCatalog.spec(body_id)

	var root := Node3D.new()
	root.name = "Vehicle_" + body_id

	var meshes := _get_meshes(body_id)

	# --- painted body -------------------------------------------------
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = meshes["body"]
	body_mi.material_override = MaterialLibrary.car_paint(paint)
	body_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(body_mi)

	# --- greenhouse ---------------------------------------------------
	if meshes.has("cabin") and meshes["cabin"] != null:
		var pillar_mi := MeshInstance3D.new()
		pillar_mi.name = "Pillars"
		pillar_mi.mesh = meshes["cabin"]
		# Pillars share the body paint; the glass sits just inside them.
		pillar_mi.material_override = MaterialLibrary.car_paint(paint)
		root.add_child(pillar_mi)

		var glass_mi := MeshInstance3D.new()
		glass_mi.name = "Glass"
		glass_mi.mesh = meshes["glass"]
		glass_mi.material_override = MaterialLibrary.glass()
		glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glass_mi)

	# --- wheels -------------------------------------------------------
	var wheels := Node3D.new()
	wheels.name = "Wheels"
	root.add_child(wheels)

	var wb: float = spec["wheelbase"]
	var track: float = spec["track"]
	var wr: float = spec["wheel_r"]
	var wheel_mesh: Mesh = _get_wheel(body_id)
	var is_multi_axle: bool = String(spec["class"]) in ["bus", "truck"]

	var axles: Array = [wb * 0.5, -wb * 0.5]
	if is_multi_axle and float(spec["length"]) > 8.0:
		# Long vehicles get a tandem rear axle - very visible on buses.
		axles = [wb * 0.5, -wb * 0.5, -wb * 0.5 - wr * 2.3]

	for i in axles.size():
		for side: float in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.name = "Wheel_%d_%s" % [i, "L" if side < 0 else "R"]
			w.mesh = wheel_mesh
			w.position = Vector3(side * track * 0.5, wr, axles[i])
			w.rotation.z = PI * 0.5   # cylinder axis runs across the car
			wheels.add_child(w)

	# --- lights -------------------------------------------------------
	_add_lights(root, spec)

	# --- livery / plate ------------------------------------------------
	if livery != "":
		_add_taxi_livery(root, spec, livery)
	_add_plates(root, spec)

	return root


## Meshes only, for callers that want to instance manually.
static func mesh_for(body_id: String) -> Mesh:
	return _get_meshes(body_id)["body"]


static func clear_cache() -> void:
	_mesh_cache.clear()
	_wheel_cache.clear()


# =======================================================================
#  Mesh construction
# =======================================================================

static func _get_meshes(body_id: String) -> Dictionary:
	if _mesh_cache.has(body_id):
		return _mesh_cache[body_id]

	var spec := CarCatalog.spec(body_id)
	var out := {}
	out["body"] = _loft_body(spec)

	var cabin: Array = spec.get("cabin", [])
	if cabin.size() >= 3:
		out["cabin"] = _loft_cabin(spec, 1.0)
		# Glass is the same shell shrunk slightly, so it sits inside the pillars.
		out["glass"] = _loft_cabin(spec, 0.955)
	else:
		out["cabin"] = null
		out["glass"] = null

	_mesh_cache[body_id] = out
	return out


## Lofts the lower body from its [z, half_w, y0, y1] profile.
static func _loft_body(spec: Dictionary) -> ArrayMesh:
	var profile: Array = spec["body"]
	var length: float = spec["length"]
	var half_width: float = float(spec["width"]) * 0.5
	var ride_h: float = spec["ride_h"]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array[PackedVector3Array] = []
	for i in LOFT_SAMPLES:
		var t := float(i) / float(LOFT_SAMPLES - 1)
		var s := _sample_body(profile, t)
		# z: front of car at +z/2, rear at -z/2 (Godot forward is -z, and
		# traffic drives away from the camera, so the nose points +z here and
		# the traffic node is rotated to face travel direction).
		var z := (0.5 - t) * length
		var hw: float = s.x * half_width
		var y0: float = s.y + ride_h
		var y1: float = s.z + ride_h
		# Corner radius scales with the smaller of the two dimensions.
		var radius: float = minf(hw, (y1 - y0) * 0.5) * 0.45
		rings.append(_rounded_ring(hw, y0, y1, radius, z))

	_stitch(st, rings, true)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Lofts the greenhouse. `inset` shrinks it for the glass pass.
static func _loft_cabin(spec: Dictionary, inset: float) -> ArrayMesh:
	var profile: Array = spec["cabin"]
	var length: float = spec["length"]
	var half_width: float = float(spec["width"]) * 0.5
	var ride_h: float = spec["ride_h"]

	var z_start: float = float(profile[0][0])
	var z_end: float = float(profile[profile.size() - 1][0])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array[PackedVector3Array] = []
	for i in CABIN_SAMPLES:
		var t := float(i) / float(CABIN_SAMPLES - 1)
		var z_norm: float = lerpf(z_start, z_end, t)
		var s := _sample_cabin(profile, z_norm)
		var z := (0.5 - z_norm) * length
		var hw: float = s.x * half_width * inset
		# Base of the greenhouse follows the body's beltline.
		var belt := _sample_body(spec["body"], z_norm).z + ride_h
		var roof: float = s.y * inset + ride_h
		if roof <= belt + 0.02:
			roof = belt + 0.02
		var radius: float = minf(hw * 0.55, (roof - belt) * 0.5)
		rings.append(_rounded_ring(hw, belt, roof, radius, z))

	_stitch(st, rings, true)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## One cross-section: a rounded rectangle in the XY plane at depth `z`.
static func _rounded_ring(half_w: float, y0: float, y1: float, r: float, z: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var h := (y1 - y0) * 0.5
	var cy := (y0 + y1) * 0.5
	r = clampf(r, 0.001, minf(half_w, h) * 0.99)

	var inner_w := half_w - r
	var inner_h := h - r

	for i in RING_SEGMENTS:
		var a := TAU * float(i) / float(RING_SEGMENTS)
		# Walk an ellipse, but clamp onto the flat panel first and then push
		# back out by the corner radius. That gives straight body sides with
		# radiused shoulders, instead of either a box or a pure ellipse.
		var x := clampf(cos(a) * half_w, -inner_w, inner_w)
		var y := clampf(sin(a) * h, -inner_h, inner_h)
		var d := Vector2(cos(a) * half_w - x, sin(a) * h - y)
		if d.length() > 0.0001:
			d = d.normalized() * r
		pts.append(Vector3(x + d.x, cy + y + d.y, z))
	return pts


## Builds triangles between consecutive rings, optionally capping the ends.
static func _stitch(st: SurfaceTool, rings: Array[PackedVector3Array], cap: bool) -> void:
	var n := rings.size()
	if n < 2:
		return
	var m := rings[0].size()

	for i in range(n - 1):
		var a := rings[i]
		var b := rings[i + 1]
		for j in m:
			var j2 := (j + 1) % m
			# Two triangles per quad, wound so the outside faces out.
			st.add_vertex(a[j])
			st.add_vertex(b[j])
			st.add_vertex(b[j2])

			st.add_vertex(a[j])
			st.add_vertex(b[j2])
			st.add_vertex(a[j2])

	if not cap:
		return

	# Fan-cap the front and rear openings.
	for pair: Array in [[rings[0], false], [rings[n - 1], true]]:
		var ring: PackedVector3Array = pair[0]
		var flip: bool = pair[1]
		var centre := Vector3.ZERO
		for p in ring:
			centre += p
		centre /= float(ring.size())
		for j in m:
			var j2 := (j + 1) % m
			if flip:
				st.add_vertex(centre)
				st.add_vertex(ring[j])
				st.add_vertex(ring[j2])
			else:
				st.add_vertex(centre)
				st.add_vertex(ring[j2])
				st.add_vertex(ring[j])


## Interpolates the body profile at normalised length t. Returns
## Vector3(half_width_fraction, y_bottom, y_top).
static func _sample_body(profile: Array, t: float) -> Vector3:
	if profile.is_empty():
		return Vector3(1.0, 0.2, 0.8)
	if t <= float(profile[0][0]):
		return Vector3(profile[0][1], profile[0][2], profile[0][3])
	var last: Array = profile[profile.size() - 1]
	if t >= float(last[0]):
		return Vector3(last[1], last[2], last[3])

	for i in range(profile.size() - 1):
		var a: Array = profile[i]
		var b: Array = profile[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			var f: float = 0.0 if span <= 0.0 else (t - float(a[0])) / span
			f = _smooth(f)
			return Vector3(
				lerpf(a[1], b[1], f),
				lerpf(a[2], b[2], f),
				lerpf(a[3], b[3], f)
			)
	return Vector3(profile[0][1], profile[0][2], profile[0][3])


## Interpolates the cabin profile. Returns Vector2(half_width_fraction, y_roof).
static func _sample_cabin(profile: Array, t: float) -> Vector2:
	if profile.is_empty():
		return Vector2(0.9, 1.3)
	if t <= float(profile[0][0]):
		return Vector2(profile[0][1], profile[0][2])
	var last: Array = profile[profile.size() - 1]
	if t >= float(last[0]):
		return Vector2(last[1], last[2])

	for i in range(profile.size() - 1):
		var a: Array = profile[i]
		var b: Array = profile[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			var f: float = 0.0 if span <= 0.0 else (t - float(a[0])) / span
			f = _smooth(f)
			return Vector2(lerpf(a[1], b[1], f), lerpf(a[2], b[2], f))
	return Vector2(profile[0][1], profile[0][2])


## Smoothstep, so lofted panels flow instead of creasing at every control row.
static func _smooth(f: float) -> float:
	f = clampf(f, 0.0, 1.0)
	return f * f * (3.0 - 2.0 * f)


# =======================================================================
#  Wheels
# =======================================================================

static func _get_wheel(body_id: String) -> Mesh:
	var spec := CarCatalog.spec(body_id)
	var key := "%.3f_%s" % [float(spec["wheel_r"]), String(spec["class"])]
	if _wheel_cache.has(key):
		return _wheel_cache[key]

	var r: float = spec["wheel_r"]
	var width: float = r * (0.72 if String(spec["class"]) in ["bus", "truck"] else 0.62)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tyre: a cylinder with slightly domed shoulders so it isn't a hard disc.
	var rings: Array[PackedVector3Array] = []
	var shoulder := [
		[-0.50, 0.86], [-0.44, 0.96], [-0.34, 1.00],
		[0.34, 1.00], [0.44, 0.96], [0.50, 0.86],
	]
	for row in shoulder:
		var ring := PackedVector3Array()
		var y := float(row[0]) * width
		var rr := float(row[1]) * r
		for i in WHEEL_SEGMENTS:
			var a := TAU * float(i) / float(WHEEL_SEGMENTS)
			ring.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		rings.append(ring)

	_stitch(st, rings, true)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	# Rim as a second surface with its own material.
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim_r := r * 0.60
	var rim_rings: Array[PackedVector3Array] = []
	for y_f: float in [-0.36, 0.36]:
		var ring2 := PackedVector3Array()
		for i in WHEEL_SEGMENTS:
			var a := TAU * float(i) / float(WHEEL_SEGMENTS)
			ring2.append(Vector3(cos(a) * rim_r, y_f * width, sin(a) * rim_r))
		rim_rings.append(ring2)
	_stitch(rim, rim_rings, true)
	rim.generate_normals()
	var rim_mesh: ArrayMesh = rim.commit()

	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		rim_mesh.surface_get_arrays(0)
	)
	mesh.surface_set_material(0, MaterialLibrary.tyre())
	mesh.surface_set_material(1, MaterialLibrary.rim())

	_wheel_cache[key] = mesh
	return mesh


# =======================================================================
#  Details
# =======================================================================

static func _add_lights(root: Node3D, spec: Dictionary) -> void:
	var length: float = spec["length"]
	var half_w: float = float(spec["width"]) * 0.5
	var ride_h: float = spec["ride_h"]

	# Headlight height tracks the front of the body profile.
	var front := _sample_body(spec["body"], 0.06)
	var rear := _sample_body(spec["body"], 0.94)
	var head_y: float = lerpf(front.y, front.z, 0.62) + ride_h
	var tail_y: float = lerpf(rear.y, rear.z, 0.62) + ride_h

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(half_w * 0.42, 0.13, 0.06)
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(half_w * 0.36, 0.14, 0.06)

	for side: float in [-1.0, 1.0]:
		var hl := MeshInstance3D.new()
		hl.name = "Headlight_%s" % ("L" if side < 0 else "R")
		hl.mesh = head_mesh
		hl.position = Vector3(side * half_w * 0.60, head_y, length * 0.5 - 0.03)
		hl.material_override = MaterialLibrary.headlight()
		hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hl)

		var tl := MeshInstance3D.new()
		tl.name = "Taillight_%s" % ("L" if side < 0 else "R")
		tl.mesh = tail_mesh
		tl.position = Vector3(side * half_w * 0.62, tail_y, -length * 0.5 + 0.03)
		tl.material_override = MaterialLibrary.taillight()
		tl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tl)


static func _add_taxi_livery(root: Node3D, spec: Dictionary, livery: String) -> void:
	# Roof sign - the giveaway that makes a taxi read instantly at distance.
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(float(spec["width"]) * 0.34, 0.14, 0.18)

	var cabin: Array = spec.get("cabin", [])
	if cabin.is_empty():
		return
	var roof_y := 0.0
	var roof_z := 0.5
	for row in cabin:
		if float(row[2]) > roof_y:
			roof_y = float(row[2])
			roof_z = float(row[0])

	var sign := MeshInstance3D.new()
	sign.name = "TaxiSign"
	sign.mesh = sign_mesh
	sign.position = Vector3(0, roof_y + float(spec["ride_h"]) + 0.07,
		(0.5 - roof_z) * float(spec["length"]))
	sign.material_override = MaterialLibrary.taxi_sign(
		CarCatalog.TAXI_GREEN if livery == "green" else CarCatalog.TAXI_YELLOW
	)
	root.add_child(sign)


static func _add_plates(root: Node3D, spec: Dictionary) -> void:
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.44, 0.10, 0.02)
	var length: float = spec["length"]
	var ride_h: float = spec["ride_h"]

	for pair: Array in [[length * 0.5 + 0.01, 0.06], [-length * 0.5 - 0.01, 0.94]]:
		var z: float = pair[0]
		var s := _sample_body(spec["body"], float(pair[1]))
		var plate := MeshInstance3D.new()
		plate.mesh = plate_mesh
		plate.position = Vector3(0, lerpf(s.y, s.z, 0.22) + ride_h, z)
		plate.material_override = MaterialLibrary.plate()
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plate)
