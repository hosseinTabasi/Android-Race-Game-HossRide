class_name CityBuilder
extends RefCounted
## Builds the Tehran that sits around the road.
##
## Three layers, each moving at a different rate, which is what gives the city
## depth on a flat mobile screen:
##
##   1. Roadside blocks - recycled with the road chunks, close and detailed.
##   2. Milad Tower     - parked far off to one side, drifting slowly, always
##                        visible. It is the single landmark that makes the
##                        location unmistakable, so it never despawns.
##   3. Alborz range    - a static backdrop pinned to the camera. Tehran sits
##                        against snow-capped mountains to the north, and
##                        leaving them out makes any skyline read as generic.

const BUILDING_PALETTE := [
	Color(0.52, 0.48, 0.42),   # sand brick
	Color(0.60, 0.57, 0.52),   # pale stone
	Color(0.44, 0.42, 0.40),   # weathered concrete
	Color(0.56, 0.50, 0.44),   # ochre
	Color(0.38, 0.37, 0.36),   # dark concrete
	Color(0.64, 0.60, 0.55),   # travertine
]


# =======================================================================
#  Milad Tower
# =======================================================================

## Tehran's telecom tower: a tapered octagonal shaft, a bulging observation
## pod near the top, and a long antenna spire. Roughly 315 m to the tip; built
## here at true scale so it dominates the skyline the way the real one does.
static func build_milad_tower() -> Node3D:
	var root := Node3D.new()
	root.name = "MiladTower"

	const SHAFT_H := 250.0
	const POD_Y := 245.0
	const SIDES := 16

	var concrete := MaterialLibrary.concrete(1.15)

	# --- splayed base ---------------------------------------------------
	var base := MeshInstance3D.new()
	base.name = "Base"
	var bm := CylinderMesh.new()
	bm.top_radius = 9.0
	bm.bottom_radius = 26.0
	bm.height = 34.0
	bm.radial_segments = SIDES
	base.mesh = bm
	base.material_override = concrete
	base.position = Vector3(0, 17.0, 0)
	root.add_child(base)

	# --- shaft ------------------------------------------------------------
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var sm := CylinderMesh.new()
	sm.top_radius = 6.4
	sm.bottom_radius = 9.0
	sm.height = SHAFT_H - 34.0
	sm.radial_segments = SIDES
	shaft.mesh = sm
	shaft.material_override = concrete
	shaft.position = Vector3(0, 34.0 + (SHAFT_H - 34.0) * 0.5, 0)
	root.add_child(shaft)

	# Vertical rib detail - the real shaft is strongly fluted.
	for i in 8:
		var a := TAU * float(i) / 8.0
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(1.6, SHAFT_H - 36.0, 1.6)
		rib.mesh = rm
		rib.material_override = MaterialLibrary.concrete(1.0)
		rib.position = Vector3(cos(a) * 7.4, 34.0 + (SHAFT_H - 36.0) * 0.5, sin(a) * 7.4)
		rib.rotation.y = -a
		root.add_child(rib)

	# --- observation pod ---------------------------------------------------
	# The signature bulge: widest just below its midpoint, tapering both ways.
	var pod_profile := [
		[0.00, 7.5], [0.10, 13.0], [0.24, 18.5], [0.40, 20.5],
		[0.56, 19.6], [0.72, 16.4], [0.86, 12.0], [1.00, 8.0],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pod_h := 52.0
	var rings: Array[PackedVector3Array] = []
	for row in pod_profile:
		var ring := PackedVector3Array()
		var y: float = POD_Y - pod_h * 0.5 + float(row[0]) * pod_h
		var r: float = float(row[1])
		for i in SIDES:
			var a := TAU * float(i) / float(SIDES)
			ring.append(Vector3(cos(a) * r, y, sin(a) * r))
		rings.append(ring)

	for i in range(rings.size() - 1):
		_stitch_rings(st, rings[i], rings[i + 1])
	st.generate_normals()

	var pod := MeshInstance3D.new()
	pod.name = "Pod"
	pod.mesh = st.commit()
	pod.material_override = concrete
	root.add_child(pod)

	# The tower is lit every night in reality, and here it has to carry 800 m
	# of rainy night air, so the bands get their own bright unshaded material
	# rather than sharing the dimmer one used for ordinary building windows.
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.95, 0.80, 0.55)
	band_mat.emission_enabled = true
	band_mat.emission = Color(1.0, 0.84, 0.58)
	band_mat.emission_energy_multiplier = 11.0
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Vertical light strips running the height of the shaft. More than the
	# bands, these are what make it identifiable as a tower from far off.
	for i in 8:
		var a := TAU * float(i) / 8.0
		var strip := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(0.9, SHAFT_H - 44.0, 0.9)
		strip.mesh = stm
		strip.material_override = band_mat
		strip.position = Vector3(cos(a) * 8.1, 38.0 + (SHAFT_H - 44.0) * 0.5, sin(a) * 8.1)
		strip.rotation.y = -a
		root.add_child(strip)

	# Lit window bands around the pod - the tower is always illuminated.
	for band: float in [0.30, 0.48, 0.64]:
		var y: float = POD_Y - pod_h * 0.5 + band * pod_h
		var r := _pod_radius(pod_profile, band) + 0.25
		var ring_mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.5
		tm.outer_radius = r + 0.5
		tm.rings = SIDES
		tm.ring_segments = 6
		ring_mi.mesh = tm
		ring_mi.material_override = band_mat
		ring_mi.position = Vector3(0, y, 0)
		root.add_child(ring_mi)

	# --- antenna spire -------------------------------------------------------
	var spire := MeshInstance3D.new()
	spire.name = "Spire"
	var spm := CylinderMesh.new()
	spm.top_radius = 0.35
	spm.bottom_radius = 3.2
	spm.height = 64.0
	spm.radial_segments = 10
	spire.mesh = spm
	spire.material_override = MaterialLibrary.concrete(0.9)
	spire.position = Vector3(0, POD_Y + pod_h * 0.5 + 32.0, 0)
	root.add_child(spire)

	# Aircraft warning light at the tip.
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	var beam := SphereMesh.new()
	beam.radius = 1.6
	beam.height = 3.2
	beacon.mesh = beam
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(1.0, 0.1, 0.1)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.05, 0.05)
	beacon_mat.emission_energy_multiplier = 8.0
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = beacon_mat
	beacon.position = Vector3(0, POD_Y + pod_h * 0.5 + 64.0, 0)
	root.add_child(beacon)

	var beacon_light := OmniLight3D.new()
	beacon_light.name = "BeaconLight"
	beacon_light.position = beacon.position
	beacon_light.omni_range = 40.0
	beacon_light.light_energy = 4.0
	beacon_light.light_color = Color(1.0, 0.15, 0.12)
	root.add_child(beacon_light)

	return root


## Connects two equal-sized rings with a band of quads.
static func _stitch_rings(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array) -> void:
	var n := a.size()
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(a[i]); st.add_vertex(b[i]); st.add_vertex(b[j])
		st.add_vertex(a[i]); st.add_vertex(b[j]); st.add_vertex(a[j])


static func _pod_radius(profile: Array, t: float) -> float:
	for i in range(profile.size() - 1):
		var a: Array = profile[i]
		var b: Array = profile[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var span := float(b[0]) - float(a[0])
			var f: float = 0.0 if span <= 0.0 else (t - float(a[0])) / span
			return lerpf(float(a[1]), float(b[1]), f)
	return float(profile[0][1])


# =======================================================================
#  Roadside blocks
# =======================================================================

## Builds one chunk's worth of roadside buildings. `offset_x` is the distance
## from the road centreline to the building line.
static func build_block(rng: RandomNumberGenerator, chunk_length: float, offset_x: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Block"

	for side: float in [-1.0, 1.0]:
		var z := -chunk_length * 0.5
		while z < chunk_length * 0.5:
			var w := rng.randf_range(8.0, 20.0)
			var depth := rng.randf_range(10.0, 24.0)
			# Heights are capped deliberately. Most of Tehran along an
			# expressway really is mid-rise, and just as importantly the
			# roadside roofline has to stay below Milad Tower's skyline angle
			# or the landmark disappears behind the nearest apartment block.
			var floors := rng.randi_range(3, 9)
			if rng.randf() < 0.05:
				floors = rng.randi_range(10, 15)
			var h := floors * 3.1

			var b := _building(rng, w, depth, h, floors)
			b.position = Vector3(
				side * (offset_x + depth * 0.5),
				0,
				z + w * 0.5
			)
			node.add_child(b)

			z += w + rng.randf_range(1.5, 6.0)

	return node


static func _building(rng: RandomNumberGenerator, w: float, depth: float, h: float, floors: int) -> Node3D:
	var node := Node3D.new()

	var shell := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(depth, h, w)
	shell.mesh = bm
	shell.material_override = MaterialLibrary.building(
		BUILDING_PALETTE[rng.randi() % BUILDING_PALETTE.size()]
	)
	shell.position = Vector3(0, h * 0.5, 0)
	node.add_child(shell)

	# Window bands facing the road. Cheap, but at speed it is all you read.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lit_any := false
	for f in range(1, floors):
		var y := f * 3.1 - 1.1
		var x := -depth * 0.5 - 0.06
		var cols := maxi(2, int(w / 2.6))
		for c in cols:
			# Randomly dark windows keep a night skyline from looking uniform.
			if rng.randf() < 0.38:
				continue
			lit_any = true
			var cz := -w * 0.5 + (c + 0.5) * (w / float(cols))
			var hw := 0.62
			var hh := 0.78
			st.add_vertex(Vector3(x, y - hh, cz - hw))
			st.add_vertex(Vector3(x, y + hh, cz - hw))
			st.add_vertex(Vector3(x, y + hh, cz + hw))
			st.add_vertex(Vector3(x, y - hh, cz - hw))
			st.add_vertex(Vector3(x, y + hh, cz + hw))
			st.add_vertex(Vector3(x, y - hh, cz + hw))

	if lit_any:
		st.generate_normals()
		var win := MeshInstance3D.new()
		win.name = "Windows"
		win.mesh = st.commit()
		win.material_override = MaterialLibrary.lit_window(rng.randf_range(0.7, 1.0))
		win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(win)

	# Rooftop clutter - water tanks and stair housings, very Tehran.
	if rng.randf() < 0.7:
		var tank := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.9
		cm.bottom_radius = 0.9
		cm.height = 1.6
		cm.radial_segments = 8
		tank.mesh = cm
		tank.material_override = MaterialLibrary.concrete(0.8)
		tank.position = Vector3(
			rng.randf_range(-depth * 0.3, depth * 0.3),
			h + 0.8,
			rng.randf_range(-w * 0.3, w * 0.3)
		)
		node.add_child(tank)

	return node


# =======================================================================
#  Aircraft
# =======================================================================

## An airliner crossing high overhead, built nose-first along +Z.
##
## Scaled generously - a real airliner at cruising height is a speck, and a
## speck is not worth building. What actually sells it at night is the light
## rig: steady red on the left wingtip, green on the right, and a white strobe
## that fires twice a second. Those three are what you genuinely see of a
## plane in a dark sky, so they are the part built with care.
static func build_airliner() -> Node3D:
	var plane := Node3D.new()
	plane.name = "Airliner"

	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.74, 0.78)
	skin.roughness = 0.42
	skin.metallic = 0.35

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.20, 0.22, 0.26)
	dark.roughness = 0.6

	# --- fuselage ------------------------------------------------------
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 1.5
	bm.height = 34.0
	bm.radial_segments = 12
	bm.rings = 4
	body.mesh = bm
	body.material_override = skin
	body.rotation.x = PI * 0.5      # capsule runs along Y; lay it along Z
	plane.add_child(body)

	# --- wings ----------------------------------------------------------
	for side: float in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(16.0, 0.55, 5.0)
		wing.mesh = wm
		wing.material_override = skin
		wing.position = Vector3(side * 8.6, -0.4, -1.0)
		# Swept back, and angled up a little - both read clearly in silhouette.
		wing.rotation.y = side * deg_to_rad(-22.0)
		wing.rotation.z = side * deg_to_rad(-4.0)
		plane.add_child(wing)

		# Engine nacelle slung under each wing.
		var nacelle := MeshInstance3D.new()
		var nm := CylinderMesh.new()
		nm.top_radius = 1.05
		nm.bottom_radius = 1.05
		nm.height = 4.6
		nm.radial_segments = 10
		nacelle.mesh = nm
		nacelle.material_override = dark
		nacelle.rotation.x = PI * 0.5
		nacelle.position = Vector3(side * 7.2, -1.5, 0.6)
		plane.add_child(nacelle)

		# Horizontal stabiliser.
		var stab := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(6.4, 0.4, 2.4)
		stab.mesh = stm
		stab.material_override = skin
		stab.position = Vector3(side * 3.4, 0.6, -15.0)
		stab.rotation.y = side * deg_to_rad(-18.0)
		plane.add_child(stab)

	# --- tail fin --------------------------------------------------------
	var fin := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.5, 6.0, 4.4)
	fin.mesh = fm
	fin.material_override = skin
	fin.position = Vector3(0, 3.4, -14.6)
	plane.add_child(fin)

	# --- navigation lights -------------------------------------------------
	plane.add_child(_nav_light("NavRed", Vector3(-16.0, -0.4, -3.0), Color(1.0, 0.10, 0.08), 5.0))
	plane.add_child(_nav_light("NavGreen", Vector3(16.0, -0.4, -3.0), Color(0.15, 1.0, 0.25), 5.0))
	plane.add_child(_nav_light("Strobe", Vector3(0, -1.6, -15.5), Color(1.0, 1.0, 1.0), 9.0))
	plane.add_child(_nav_light("Beacon", Vector3(0, 2.2, 2.0), Color(1.0, 0.25, 0.10), 4.0))

	return plane


static func _nav_light(name: String, pos: Vector3, colour: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var sm := SphereMesh.new()
	sm.radius = 0.85
	sm.height = 1.7
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm

	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# =======================================================================
#  Alborz backdrop
# =======================================================================

## A ridge of snow-capped peaks far to the north. Built as a single fan of
## triangles at huge scale and parented to the camera rig, so it never moves
## relative to the rider - exactly how a real horizon behaves.
static func build_mountains(rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "Alborz"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	const DIST := 1400.0
	const PEAKS := 26
	const SPAN := 4200.0

	# +Z is "ahead" in this project, so the ridge sits at +DIST, out past the
	# far end of the road, not behind the rider.
	var prev := Vector3(-SPAN * 0.5, 0, DIST)
	for i in range(1, PEAKS + 1):
		var t := float(i) / float(PEAKS)
		var x := -SPAN * 0.5 + t * SPAN
		var h := rng.randf_range(150.0, 420.0)
		# Damavand-scale spike now and then.
		if rng.randf() < 0.12:
			h *= 1.6
		var apex := Vector3(x - SPAN / PEAKS * 0.5, h, DIST)
		var base := Vector3(x, 0, DIST)

		st.add_vertex(prev)
		st.add_vertex(apex)
		st.add_vertex(base)
		prev = base

	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "Ridge"
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	# Hazy blue-grey; distance does most of the work here.
	m.albedo_color = Color(0.38, 0.42, 0.52)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)

	return node
