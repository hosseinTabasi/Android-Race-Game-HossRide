class_name RoadBuilder
extends RefCounted
## Builds one reusable chunk of Tehran expressway.
##
## The road is a ring of chunks that get recycled: when a chunk falls behind
## the rider it is teleported to the far end of the ring. Nothing is ever
## created or freed during a run, which is what keeps the frame time flat on
## a phone. Because chunks repeat, all the visual variety has to come from
## what sits *beside* the road, so the roadside props are randomised per
## chunk while the tarmac geometry stays identical.

const LANE_WIDTH := 3.5
const CHUNK_LENGTH := 60.0
const SHOULDER := 1.4
const BARRIER_H := 0.85


## Builds the static tarmac, markings, shoulders and barriers for one chunk.
## Everything is merged into as few MeshInstances as possible.
static func build_chunk(lane_count: int) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "RoadChunk"

	var road_w := lane_count * LANE_WIDTH
	var half := road_w * 0.5

	# --- tarmac -------------------------------------------------------
	var tarmac := MeshInstance3D.new()
	tarmac.name = "Tarmac"
	var tm := PlaneMesh.new()
	tm.size = Vector2(road_w + SHOULDER * 2.0, CHUNK_LENGTH)
	tm.subdivide_width = 2
	tm.subdivide_depth = 8
	tarmac.mesh = tm
	tarmac.material_override = MaterialLibrary.asphalt()
	chunk.add_child(tarmac)

	# --- lane markings -------------------------------------------------
	chunk.add_child(_build_markings(lane_count, half))

	# --- shoulders and barriers ----------------------------------------
	chunk.add_child(_build_barriers(half))

	# --- street lighting ------------------------------------------------
	chunk.add_child(_build_street_lights(half))

	return chunk


## Dashed white lane dividers plus solid edge lines.
static func _build_markings(lane_count: int, half: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Markings"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Dashed interior dividers: 3 m painted, 6 m gap - standard highway rhythm.
	const DASH := 3.0
	const GAP := 6.0
	var stride := DASH + GAP

	for lane in range(1, lane_count):
		var x := -half + lane * LANE_WIDTH
		var z := -CHUNK_LENGTH * 0.5
		while z < CHUNK_LENGTH * 0.5:
			var z_end := minf(z + DASH, CHUNK_LENGTH * 0.5)
			_quad(st, x - 0.06, x + 0.06, z, z_end, 0.012)
			z += stride

	# Solid edge lines.
	_quad(st, -half - 0.10, -half + 0.06, -CHUNK_LENGTH * 0.5, CHUNK_LENGTH * 0.5, 0.012)
	_quad(st, half - 0.06, half + 0.10, -CHUNK_LENGTH * 0.5, CHUNK_LENGTH * 0.5, 0.012)

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Paint"
	mi.mesh = st.commit()
	mi.material_override = MaterialLibrary.lane_paint()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	return node


## Concrete jersey barriers down both sides.
static func _build_barriers(half: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Barriers"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for side: float in [-1.0, 1.0]:
		var x := side * (half + SHOULDER)
		# Jersey profile: wide splayed foot, narrow top.
		var rings: Array[PackedVector3Array] = []
		for z: float in [-CHUNK_LENGTH * 0.5, CHUNK_LENGTH * 0.5]:
			var ring := PackedVector3Array()
			ring.append(Vector3(x - 0.24, 0.0, z))
			ring.append(Vector3(x + 0.24, 0.0, z))
			ring.append(Vector3(x + 0.16, 0.26, z))
			ring.append(Vector3(x + 0.09, BARRIER_H, z))
			ring.append(Vector3(x - 0.09, BARRIER_H, z))
			ring.append(Vector3(x - 0.16, 0.26, z))
			rings.append(ring)
		_extrude_ring(st, rings[0], rings[1])

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = MaterialLibrary.concrete(1.0)
	node.add_child(mi)

	# Collision walls so the player physically cannot leave the road.
	for side: float in [-1.0, 1.0]:
		var body := StaticBody3D.new()
		body.collision_layer = 4   # "world"
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.48, BARRIER_H, CHUNK_LENGTH)
		shape.shape = box
		shape.position = Vector3(side * (half + SHOULDER), BARRIER_H * 0.5, 0)
		body.add_child(shape)
		node.add_child(body)

	return node


## Sodium street lights on alternating sides, the colour Tehran actually is
## at night.
static func _build_street_lights(half: float) -> Node3D:
	var node := Node3D.new()
	node.name = "StreetLights"

	var spacing := 30.0
	var count := int(CHUNK_LENGTH / spacing)

	for i in count:
		var z := -CHUNK_LENGTH * 0.5 + (i + 0.5) * spacing
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var base_x := side * (half + SHOULDER + 0.6)

		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.07
		pm.bottom_radius = 0.11
		pm.height = 9.0
		pm.radial_segments = 8
		pole.mesh = pm
		pole.material_override = MaterialLibrary.concrete(0.75)
		pole.position = Vector3(base_x, 4.5, z)
		node.add_child(pole)

		# Curved arm reaching over the carriageway.
		var arm := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.055
		am.bottom_radius = 0.055
		am.height = 2.4
		am.radial_segments = 6
		arm.mesh = am
		arm.material_override = MaterialLibrary.concrete(0.75)
		arm.rotation.z = PI * 0.5
		arm.position = Vector3(base_x - side * 1.2, 8.9, z)
		node.add_child(arm)

		var lamp := MeshInstance3D.new()
		lamp.name = "Lamp"
		var lm := BoxMesh.new()
		lm.size = Vector3(0.52, 0.14, 0.28)
		lamp.mesh = lm
		lamp.material_override = MaterialLibrary.street_light_glow()
		lamp.position = Vector3(base_x - side * 2.3, 8.78, z)
		node.add_child(lamp)

		var light := OmniLight3D.new()
		light.name = "Glow"
		light.position = Vector3(base_x - side * 2.3, 8.5, z)
		light.omni_range = 22.0
		light.light_energy = 2.4
		light.light_color = Color(1.0, 0.76, 0.45)
		light.shadow_enabled = false
		node.add_child(light)

	return node


# =======================================================================
#  Boost pads
# =======================================================================

## A glowing chevron strip painted on the tarmac. Ride over it for speed.
##
## Drawn unshaded and emissive so it reads identically at noon and at
## midnight - a boost you can't see in the dark would be a trap rather than a
## reward. The chevrons point down the road so the direction is unambiguous
## even glimpsed at 180 km/h.
static func build_boost_pad() -> Node3D:
	var pad := Node3D.new()
	pad.name = "BoostPad"

	const PAD_W := 2.5
	const PAD_L := 7.5

	# Dark backing so the glow has something to sit against on pale tarmac.
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(PAD_W, 0.02, PAD_L)
	base.mesh = bm
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.03, 0.04, 0.05)
	base_mat.roughness = 0.5
	base.mesh = bm
	base.material_override = base_mat
	base.position = Vector3(0, 0.011, 0)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.add_child(base)

	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.62, 0.12)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.52, 0.06)
	glow.emission_energy_multiplier = 4.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Four chevrons, each a pair of angled bars forming a ">" down the road.
	for i in 4:
		var z := -PAD_L * 0.5 + 1.05 + i * 1.8
		for side: float in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			var barm := BoxMesh.new()
			barm.size = Vector3(1.5, 0.03, 0.38)
			bar.mesh = barm
			bar.material_override = glow
			bar.position = Vector3(side * 0.52, 0.022, z)
			bar.rotation.y = side * deg_to_rad(38.0)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pad.add_child(bar)

	# A soft light so the pad throws colour onto the road around it at night.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.1, 0)
	lamp.omni_range = 7.5
	lamp.light_energy = 1.8
	lamp.light_color = Color(1.0, 0.55, 0.15)
	lamp.shadow_enabled = false
	pad.add_child(lamp)

	return pad


# =======================================================================
#  Geometry helpers
# =======================================================================

## Flat horizontal quad at height y, spanning x0..x1 and z0..z1.
static func _quad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var a := Vector3(x0, y, z0)
	var b := Vector3(x1, y, z0)
	var c := Vector3(x1, y, z1)
	var d := Vector3(x0, y, z1)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	st.add_vertex(a); st.add_vertex(d); st.add_vertex(c)


## Connects two matching rings into a closed tube, capping both ends.
static func _extrude_ring(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array) -> void:
	var n := a.size()
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(a[i]); st.add_vertex(b[i]); st.add_vertex(b[j])
		st.add_vertex(a[i]); st.add_vertex(b[j]); st.add_vertex(a[j])

	for pair: Array in [[a, false], [b, true]]:
		var ring: PackedVector3Array = pair[0]
		var flip: bool = pair[1]
		var centre := Vector3.ZERO
		for p in ring:
			centre += p
		centre /= float(ring.size())
		for i in n:
			var j := (i + 1) % n
			if flip:
				st.add_vertex(centre); st.add_vertex(ring[i]); st.add_vertex(ring[j])
			else:
				st.add_vertex(centre); st.add_vertex(ring[j]); st.add_vertex(ring[i])
