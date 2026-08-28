class_name BikeBuilder
extends RefCounted
## Builds the player's motorcycle and rider from a BikeCatalog frame preset.
##
## The bike is assembled as a node tree rather than one mesh because the parts
## have to move independently: the front wheel steers, both wheels spin, the
## rider leans against the frame in corners, and his right hand leaves the bar
## when he lights a cigarette. Baking it into a single mesh would kill all of
## that.
##
## Node names matter - player.gd and cigarette.gd look parts up by name:
##   FrontAssembly / FrontWheel / RearWheel / Rider / Rider/TorsoPivot /
##   Rider/RightArm / Rider/Head / Exhaust / Headlight

const SEG := 16

## Registration shown on the tail.
##
## A real Iranian plate carries a Persian letter and a two-digit province code,
## but Godot's built-in font has no Persian glyphs and would render them as
## empty boxes, so this is digits only. Change the string to whatever you want;
## the plate resizes itself around it.
const PLATE_NUMBER := "4N5555/IRAN"


static func build(bike_id: String, paint: Color) -> Node3D:
	var f := BikeCatalog.frame(bike_id)

	var root := Node3D.new()
	root.name = "Bike_" + bike_id

	var wb: float = f["wheelbase"]
	var wr: float = f["wheel_r"]
	var tw: float = f["tyre_w"]
	var seat_h: float = f["seat_h"]
	var style: String = f["style"]

	var is_cruiser := style == "cruiser"

	# A bike built entirely from matte black parts vanishes against wet night
	# asphalt. Every component gets its own value and finish instead, so the
	# forks, frame, seat and pipes all read separately at a glance.
	var paint_mat := MaterialLibrary.car_paint(paint)
	var chrome := MaterialLibrary.chrome()
	var alloy := _mat(Color(0.70, 0.72, 0.76), 0.30)
	alloy.metallic = 0.88
	var frame_mat := _mat(Color(0.52, 0.55, 0.59), 0.34)
	frame_mat.metallic = 0.80
	var leather := _mat(Color(0.38, 0.23, 0.13), 0.58)    # tan saddle
	var grip_mat := _mat(Color(0.30, 0.21, 0.14), 0.68)   # matching grips

	# Bar height: cruisers run tall risers with the bars up and pulled back.
	var bar_y := 0.34 if is_cruiser else 0.10
	var bar_z := -0.13 if is_cruiser else -0.02

	# --- rear wheel (fixed to the frame) ------------------------------
	var rear := _wheel(wr, tw)
	rear.name = "RearWheel"
	rear.position = Vector3(0, wr, -wb * 0.5)
	root.add_child(rear)

	# --- front assembly (steers as a unit) ----------------------------
	var front_assembly := Node3D.new()
	front_assembly.name = "FrontAssembly"
	# Pivot sits at the steering head, above and behind the contact patch.
	front_assembly.position = Vector3(0, seat_h * 0.95, wb * 0.5 - 0.06)
	root.add_child(front_assembly)

	var front := _wheel(wr, tw * 0.85)
	front.name = "FrontWheel"
	front.position = Vector3(0, wr - seat_h * 0.95, 0.06)
	front_assembly.add_child(front)

	# Fork legs, raked back like a real steering head.
	var rake := deg_to_rad(25.0)
	for side: float in [-1.0, 1.0]:
		var leg := _cyl(0.021, seat_h * 0.95 - wr + 0.10, chrome)
		leg.name = "Fork_%s" % ("L" if side < 0 else "R")
		leg.position = Vector3(side * tw * 0.9, -(seat_h * 0.95 - wr) * 0.5 + 0.02, 0.03)
		leg.rotation.x = -rake * 0.5
		front_assembly.add_child(leg)

	# Handlebars
	var bar := _cyl(0.014, float(f["bar_w"]) * 2.0, chrome)
	bar.name = "Handlebar"
	bar.rotation.z = PI * 0.5
	bar.position = Vector3(0, bar_y, bar_z)
	front_assembly.add_child(bar)

	for side: float in [-1.0, 1.0]:
		var grip := _cyl(0.021, 0.13, grip_mat)
		grip.rotation.z = PI * 0.5
		grip.position = Vector3(side * (float(f["bar_w"]) - 0.06), bar_y, bar_z)
		front_assembly.add_child(grip)

		# Mirrors - small, but they catch headlights and read well at speed.
		var stalk := _cyl(0.008, 0.16, chrome)
		stalk.position = Vector3(side * float(f["bar_w"]) * 0.85, bar_y + 0.08, bar_z + 0.01)
		front_assembly.add_child(stalk)
		var mirror := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(0.10, 0.06, 0.012)
		mirror.mesh = mm
		mirror.material_override = chrome
		mirror.position = Vector3(side * float(f["bar_w"]) * 0.95, bar_y + 0.16, bar_z + 0.01)
		mirror.rotation.y = side * 0.35
		front_assembly.add_child(mirror)

	# Headlight, parented to the steering so the beam follows the bars.
	var hl := MeshInstance3D.new()
	hl.name = "HeadlightLens"
	var hl_mesh := SphereMesh.new()
	hl_mesh.radius = 0.085
	hl_mesh.height = 0.13
	hl.mesh = hl_mesh
	hl.material_override = MaterialLibrary.headlight()
	hl.position = Vector3(0, 0.03, 0.10)
	hl.scale = Vector3(1.0, 1.0, 0.55)
	front_assembly.add_child(hl)

	var beam := SpotLight3D.new()
	beam.name = "Headlight"
	beam.position = Vector3(0, 0.03, 0.12)
	beam.rotation.x = deg_to_rad(-6.0)
	beam.spot_range = 42.0
	beam.spot_angle = 32.0
	beam.spot_angle_attenuation = 1.4
	beam.light_energy = 3.2
	beam.light_color = Color(1.0, 0.95, 0.86)
	beam.shadow_enabled = false
	front_assembly.add_child(beam)

	# --- fairing / front cowl -----------------------------------------
	var fairing: float = f["fairing"]
	if fairing > 0.05:
		var cowl := MeshInstance3D.new()
		cowl.name = "Cowl"
		var cm := PrismMesh.new()
		cm.size = Vector3(0.30 * (0.6 + fairing), 0.34 * fairing + 0.12, 0.26)
		cowl.mesh = cm
		cowl.material_override = paint_mat
		cowl.rotation.x = deg_to_rad(-70.0)
		cowl.position = Vector3(0, 0.10, 0.06)
		front_assembly.add_child(cowl)

	# --- frame spine ---------------------------------------------------
	var spine := _cyl(0.032, wb * 0.72, frame_mat)
	spine.name = "Spine"
	spine.rotation.x = PI * 0.5
	spine.position = Vector3(0, seat_h * 0.72, 0.02)
	root.add_child(spine)

	# --- fuel tank ------------------------------------------------------
	# A cruiser's tank is the widest thing on the bike; a commuter's is narrow.
	var tank := MeshInstance3D.new()
	tank.name = "Tank"
	var tank_mesh := SphereMesh.new()
	tank_mesh.radius = 0.5
	tank_mesh.height = 1.0
	tank.mesh = tank_mesh
	tank.material_override = paint_mat
	tank.scale = Vector3(
		0.46 if is_cruiser else 0.30,
		float(f["tank_h"]) * 1.5,
		float(f["tank_len"])
	)
	tank.position = Vector3(0, seat_h * 0.92, wb * 0.12)
	root.add_child(tank)

	# --- fenders (cruisers only) -------------------------------------------
	# Deep valanced mudguards over both wheels. More than anything else, this
	# is what separates a cruiser silhouette from a naked commuter.
	if is_cruiser:
		var rear_fender := _fender(wr * 1.22, tw * 2.4, 128.0, paint_mat)
		rear_fender.name = "RearFender"
		rear_fender.position = Vector3(0, wr, -wb * 0.5)
		root.add_child(rear_fender)

		var front_fender := _fender(wr * 1.16, tw * 2.0, 104.0, paint_mat)
		front_fender.name = "FrontFender"
		front_fender.position = Vector3(0, wr - seat_h * 0.95, 0.06)
		front_assembly.add_child(front_fender)

		# Forward-set footboards, the giveaway of a feet-first riding position.
		for side: float in [-1.0, 1.0]:
			var board := MeshInstance3D.new()
			var bdm := BoxMesh.new()
			bdm.size = Vector3(0.11, 0.035, 0.30)
			board.mesh = bdm
			board.material_override = chrome
			board.position = Vector3(side * 0.20, wr - 0.10, wb * 0.30)
			root.add_child(board)

	# --- seat -----------------------------------------------------------
	var seat := MeshInstance3D.new()
	seat.name = "Seat"
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.26, 0.09, wb * 0.46)
	seat.mesh = seat_mesh
	seat.material_override = leather
	seat.position = Vector3(0, seat_h, -wb * 0.20)
	root.add_child(seat)

	# --- engine block ----------------------------------------------------
	var engine := MeshInstance3D.new()
	engine.name = "Engine"
	var em := BoxMesh.new()
	em.size = Vector3(0.26, 0.28, 0.30)
	engine.mesh = em
	engine.material_override = MaterialLibrary.rim()
	engine.position = Vector3(0, wr + 0.16, 0.02)
	root.add_child(engine)

	# --- exhaust ---------------------------------------------------------
	_add_exhaust(root, f, chrome, wb, wr)

	# --- swingarm --------------------------------------------------------
	for side: float in [-1.0, 1.0]:
		var arm := _cyl(0.021, wb * 0.42, alloy)
		arm.rotation.x = PI * 0.5
		arm.position = Vector3(side * 0.09, wr + 0.05, -wb * 0.28)
		root.add_child(arm)

	# --- tail / plate ------------------------------------------------------
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.16, 0.05, 0.22)
	tail.mesh = tm
	tail.material_override = paint_mat
	tail.position = Vector3(0, seat_h + 0.02, -wb * 0.50)
	root.add_child(tail)

	var brake_l := MeshInstance3D.new()
	brake_l.name = "BrakeLight"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.13, 0.045, 0.03)
	brake_l.mesh = bm
	brake_l.material_override = MaterialLibrary.taillight()
	brake_l.position = Vector3(0, seat_h + 0.02, -wb * 0.50 - 0.11)
	root.add_child(brake_l)

	# --- registration plate ------------------------------------------------
	# Hung below the tail light. The chase camera sits behind the bike, so the
	# rear plate is the one part of the bike permanently facing the player -
	# worth building properly rather than as a blank white card.
	# Hung well clear behind the rear wheel. At the old offset it sat 0.20 m
	# from the wheel's centre - inside both the tyre and the fender - so it was
	# rendering the whole time, just buried. It needs to clear the fender
	# radius, which on the cruiser is 0.49 m.
	var plate := _number_plate(PLATE_NUMBER)
	plate.position = Vector3(0, seat_h - 0.06, -wb * 0.50 - 0.50)
	plate.rotation.x = deg_to_rad(-10.0)   # tipped back, as plates are
	root.add_child(plate)

	# Bracket, so the plate is mounted to something rather than floating.
	var bracket := _cyl(0.011, 0.30, alloy)
	bracket.rotation.x = deg_to_rad(72.0)
	bracket.position = Vector3(0, seat_h + 0.02, -wb * 0.50 - 0.32)
	root.add_child(bracket)

	# --- rider -------------------------------------------------------------
	root.add_child(_build_rider(seat_h, wb, style))

	return root


# =======================================================================
#  Rider
# =======================================================================

## Builds the rider: a man in casual clothes, sat astride the bike.
##
## Limbs are segmented at the joints - shoulder/elbow/wrist, hip/knee/ankle -
## rather than being one capsule each, because the elbow and knee bends are
## what make a figure read as a person instead of a mannequin. The torso is
## two stacked sections at different widths so it tapers from shoulders to
## waist the way a jacket actually hangs on someone.
##
## Node names are load-bearing: player.gd leans "Hips/TorsoPivot" and
## cigarette.gd drives "Hips/TorsoPivot/RightArm".
static func _build_rider(seat_h: float, wb: float, style: String) -> Node3D:
	var rider := Node3D.new()
	rider.name = "Rider"

	# Sport bikes tip the torso forward; commuters sit bolt upright. This does
	# more for a bike's character than any amount of bodywork.
	var lean := 0.0
	match style:
		"sport": lean = deg_to_rad(32.0)
		"naked_sport": lean = deg_to_rad(17.0)
		"cruiser": lean = deg_to_rad(-17.0)  # sat right back, arms up and out
		_: lean = deg_to_rad(7.0)

	var cruiser := style == "cruiser"

	# --- casual wardrobe -------------------------------------------------
	var jacket := _mat(Color(0.21, 0.23, 0.20), 0.78)   # olive canvas jacket
	var shirt := _mat(Color(0.80, 0.79, 0.75), 0.86)    # plain tee at the collar
	var jeans := _mat(Color(0.19, 0.25, 0.35), 0.88)
	var skin := _mat(Color(0.64, 0.46, 0.35), 0.72)
	var hair := _mat(Color(0.05, 0.045, 0.05), 0.68)
	var shoe := _mat(Color(0.87, 0.86, 0.83), 0.72)     # white trainers
	var sole := _mat(Color(0.14, 0.14, 0.15), 0.85)

	var hips := Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0, seat_h + 0.07, -wb * 0.15)
	rider.add_child(hips)

	var torso_pivot := Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.rotation.x = lean
	hips.add_child(torso_pivot)

	# --- torso: waist then chest, so the silhouette tapers ----------------
	var waist := _capsule(0.133, 0.24, jacket)
	waist.position = Vector3(0, 0.12, 0.01)
	torso_pivot.add_child(waist)

	var chest := _capsule(0.160, 0.30, jacket)
	chest.position = Vector3(0, 0.34, 0.035)
	# Broader across the shoulders, flatter front to back - people aren't round.
	chest.scale = Vector3(1.18, 1.0, 0.86)
	torso_pivot.add_child(chest)

	# The tee showing at the open collar.
	var collar := _capsule(0.076, 0.10, shirt)
	collar.position = Vector3(0, 0.495, 0.045)
	torso_pivot.add_child(collar)

	var neck := _capsule(0.050, 0.10, skin)
	neck.position = Vector3(0, 0.545, 0.05)
	torso_pivot.add_child(neck)

	# --- head --------------------------------------------------------------
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.635, 0.06)
	torso_pivot.add_child(head)

	var skull := MeshInstance3D.new()
	var skm := SphereMesh.new()
	skm.radius = 0.092
	skm.height = 0.184
	skm.radial_segments = 14
	skm.rings = 8
	skull.mesh = skm
	skull.material_override = skin
	skull.scale = Vector3(0.94, 1.12, 1.0)
	head.add_child(skull)

	# Hair as a slightly larger shell, lifted and pushed back off the face.
	var hair_mi := MeshInstance3D.new()
	var hrm := SphereMesh.new()
	hrm.radius = 0.097
	hrm.height = 0.194
	hrm.radial_segments = 14
	hrm.rings = 8
	hair_mi.mesh = hrm
	hair_mi.material_override = hair
	hair_mi.scale = Vector3(0.95, 0.97, 1.0)
	hair_mi.position = Vector3(0, 0.021, -0.016)
	head.add_child(hair_mi)

	# Short beard along the jaw - very Tehran, and it breaks up the chin.
	var beard := MeshInstance3D.new()
	var bdm := SphereMesh.new()
	bdm.radius = 0.078
	bdm.height = 0.156
	beard.mesh = bdm
	beard.material_override = hair
	beard.scale = Vector3(0.94, 0.70, 0.92)
	beard.position = Vector3(0, -0.040, 0.014)
	head.add_child(beard)

	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var erm := SphereMesh.new()
		erm.radius = 0.020
		erm.height = 0.040
		ear.mesh = erm
		ear.material_override = skin
		ear.scale = Vector3(0.5, 1.25, 1.0)
		ear.position = Vector3(side * 0.085, 0.0, -0.008)
		head.add_child(ear)

	# --- arms: shoulder -> elbow -> hand, reaching to the bars --------------
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.name = "RightArm" if side > 0 else "LeftArm"
		shoulder.position = Vector3(side * 0.183, 0.44, 0.04)
		torso_pivot.add_child(shoulder)

		# On a cruiser the hands are up near shoulder height on tall risers,
		# so the whole arm rotates up and the elbow drops far less.
		shoulder.rotation.x = deg_to_rad(-34.0) if cruiser else 0.0

		var upper := _capsule(0.051, 0.26, jacket)
		upper.position = Vector3(0, -0.10, 0.055)
		upper.rotation.x = deg_to_rad(-20.0 if cruiser else -48.0)
		shoulder.add_child(upper)

		var elbow := Node3D.new()
		elbow.name = "Elbow"
		elbow.position = Vector3(0, -0.085 if cruiser else -0.175, 0.215 if cruiser else 0.155)
		shoulder.add_child(elbow)

		var forearm := _capsule(0.043, 0.24, jacket)
		forearm.position = Vector3(0, -0.035, 0.105)
		forearm.rotation.x = deg_to_rad(-50.0 if cruiser else -74.0)
		elbow.add_child(forearm)

		var hand := _capsule(0.040, 0.095, skin)
		hand.name = "Hand"
		hand.position = Vector3(0, -0.055, 0.215)
		hand.rotation.x = deg_to_rad(-84.0)
		elbow.add_child(hand)

	# --- legs: hip -> knee -> foot, tucked back onto the pegs ----------------
	for side: float in [-1.0, 1.0]:
		# A cruiser puts the feet out front on boards; everything else tucks
		# them back under the hips onto pegs.
		var thigh := _capsule(0.081, 0.32, jeans)
		thigh.position = Vector3(side * 0.113, seat_h + 0.045, wb * (0.10 if cruiser else 0.02))
		thigh.rotation.x = deg_to_rad(86.0 if cruiser else 72.0)
		rider.add_child(thigh)

		var knee := Node3D.new()
		knee.position = Vector3(
			side * 0.145,
			seat_h - (0.03 if cruiser else 0.075),
			wb * (0.26 if cruiser else 0.155)
		)
		rider.add_child(knee)

		var shin := _capsule(0.061, 0.32, jeans)
		shin.position = Vector3(0, -0.14, 0.045 if cruiser else -0.075)
		shin.rotation.x = deg_to_rad(24.0 if cruiser else -18.0)
		knee.add_child(shin)

		# Trainer: a light upper over a dark sole. The two-tone split is what
		# makes it read as a shoe rather than a block on the end of the leg.
		var foot := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.086, 0.068, 0.210)
		foot.mesh = fm
		foot.material_override = shoe
		foot.position = Vector3(0, -0.302, 0.075 if cruiser else -0.055)
		knee.add_child(foot)

		var sole_mi := MeshInstance3D.new()
		var solem := BoxMesh.new()
		solem.size = Vector3(0.092, 0.026, 0.220)
		sole_mi.mesh = solem
		sole_mi.material_override = sole
		sole_mi.position = Vector3(0, -0.340, 0.075 if cruiser else -0.055)
		knee.add_child(sole_mi)

	return rider


## Shorthand for a plain, non-metallic material.
static func _mat(colour: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	return m


# =======================================================================
#  Parts
# =======================================================================

static func _add_exhaust(root: Node3D, f: Dictionary, chrome: Material, wb: float, wr: float) -> void:
	var kind: String = f["exhaust"]
	match kind:
		"upswept":
			var p := _cyl(0.045, 0.52, chrome)
			p.name = "Exhaust"
			p.position = Vector3(0.14, wr + 0.30, -wb * 0.36)
			p.rotation.x = deg_to_rad(78.0)
			root.add_child(p)
		"underslung":
			var p2 := _cyl(0.060, 0.34, chrome)
			p2.name = "Exhaust"
			p2.position = Vector3(0, wr - 0.04, -wb * 0.18)
			p2.rotation.x = PI * 0.5
			root.add_child(p2)
		"twin_low":
			for side: float in [-1.0, 1.0]:
				var p3 := _cyl(0.042, 0.46, chrome)
				p3.name = "Exhaust" if side > 0 else "Exhaust2"
				p3.position = Vector3(side * 0.16, wr - 0.02, -wb * 0.34)
				p3.rotation.x = deg_to_rad(84.0)
				root.add_child(p3)
		_:
			var p4 := _cyl(0.045, 0.56, chrome)
			p4.name = "Exhaust"
			p4.position = Vector3(0.13, wr - 0.05, -wb * 0.30)
			p4.rotation.x = deg_to_rad(86.0)
			root.add_child(p4)


## A rear registration plate: white card, blue province strip, black digits.
##
## The whole thing faces -Z, because that is the direction the chase camera
## looks from. Label3D renders toward +Z by default, hence the yaw.
static func _number_plate(number: String) -> Node3D:
	var plate := Node3D.new()
	plate.name = "NumberPlate"

	# Larger than scale strictly allows. A correctly sized plate is unreadable
	# from the chase camera at night, and an unreadable plate may as well not
	# be there.
	const PLATE_W := 0.310
	const PLATE_H := 0.108
	const STRIP_W := 0.044

	# Real plates are retroreflective, so a faint emission is both honest and
	# exactly what makes it stay legible on an unlit road at night.
	var white := _mat(Color(1.0, 1.0, 0.98), 0.34)
	white.metallic = 0.05
	white.emission_enabled = true
	white.emission = Color(1.0, 1.0, 0.96)
	white.emission_energy_multiplier = 0.55

	var card := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(PLATE_W, PLATE_H, 0.010)
	card.mesh = cm
	card.material_override = white
	plate.add_child(card)

	# Blue strip down one edge. +X is screen-left from the chase camera, which
	# is where the strip sits on a real plate as you look at it.
	var strip := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(STRIP_W, PLATE_H, 0.012)
	strip.mesh = sm
	var blue := _mat(Color(0.06, 0.16, 0.48), 0.40)
	blue.metallic = 0.1
	strip.material_override = blue
	strip.position = Vector3((PLATE_W - STRIP_W) * 0.5, 0, 0.001)
	plate.add_child(strip)

	var label := Label3D.new()
	label.name = "Digits"
	label.text = number
	label.font_size = 64
	# 11 characters across ~0.24 m of usable card, once the blue strip and the
	# margins are taken out.
	label.pixel_size = 0.00055
	label.modulate = Color(0.06, 0.06, 0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	label.no_depth_test = false
	# Nudged toward the non-strip side so the digits sit centred in the space
	# actually left for them.
	label.position = Vector3(-STRIP_W * 0.5, 0, -0.007)
	label.rotation.y = PI
	plate.add_child(label)

	return plate


## A mudguard: a band of quads swept over the top of a wheel.
##
## Built as an arc rather than a torus because a torus would wrap all the way
## round and read as a second tyre. `arc_deg` is the total sweep, centred on
## top dead centre; the axle runs along X, matching the wheels.
static func _fender(radius: float, width: float, arc_deg: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var steps := 14
	var half_arc := deg_to_rad(arc_deg) * 0.5
	var hw := width * 0.5

	for i in steps:
		var a0 := lerpf(-half_arc, half_arc, float(i) / float(steps))
		var a1 := lerpf(-half_arc, half_arc, float(i + 1) / float(steps))

		# Angles measured from straight up, sweeping fore and aft.
		var p0 := Vector3(0, cos(a0) * radius, sin(a0) * radius)
		var p1 := Vector3(0, cos(a1) * radius, sin(a1) * radius)

		var l0 := p0 + Vector3(-hw, 0, 0)
		var r0 := p0 + Vector3(hw, 0, 0)
		var l1 := p1 + Vector3(-hw, 0, 0)
		var r1 := p1 + Vector3(hw, 0, 0)

		# Double-sided, so the underside of the guard is not see-through.
		st.add_vertex(l0); st.add_vertex(r0); st.add_vertex(r1)
		st.add_vertex(l0); st.add_vertex(r1); st.add_vertex(l1)
		st.add_vertex(l0); st.add_vertex(r1); st.add_vertex(r0)
		st.add_vertex(l0); st.add_vertex(l1); st.add_vertex(r1)

	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


static func _wheel(radius: float, width: float) -> Node3D:
	var node := Node3D.new()

	# White sport wheels. These materials are local rather than shared from
	# MaterialLibrary so the bike gets white rubber without turning every car
	# in Tehran traffic white too.
	var tyre_mat := _mat(Color(0.91, 0.91, 0.89), 0.52)
	tyre_mat.metallic = 0.05
	var rim_mat := _mat(Color(0.97, 0.97, 0.95), 0.20)
	rim_mat.metallic = 0.80
	var disc_mat := _mat(Color(0.28, 0.29, 0.32), 0.26)
	disc_mat.metallic = 0.90

	var tyre := MeshInstance3D.new()
	tyre.name = "Tyre"
	var tm := TorusMesh.new()
	tm.inner_radius = radius - width * 0.5
	tm.outer_radius = radius
	tm.rings = SEG
	tm.ring_segments = 10
	tyre.mesh = tm
	tyre.material_override = tyre_mat
	# TorusMesh's hole axis is Y, so it must be tipped about Z to stand the
	# wheel up with its axle running across the bike.
	tyre.rotation.z = PI * 0.5
	node.add_child(tyre)

	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var rm := CylinderMesh.new()
	rm.top_radius = radius * 0.60
	rm.bottom_radius = radius * 0.60
	rm.height = width * 0.60
	rm.radial_segments = SEG
	rim.mesh = rm
	rim.material_override = rim_mat
	rim.rotation.z = PI * 0.5
	node.add_child(rim)

	# Sport alloy: five twin-spoke pairs running hub to rim. Each spoke gets
	# its own pivot so it is a true radial arm rather than a bar spanning the
	# whole diameter, which is what makes it read as a cast alloy rather than
	# a wire wheel.
	for i in 5:
		var a := TAU * float(i) / 5.0
		for arm: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.rotation.x = a + arm * 0.17
			node.add_child(pivot)

			var spoke := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(width * 0.32, radius * 0.92, 0.022)
			spoke.mesh = sm
			spoke.material_override = rim_mat
			spoke.position = Vector3(0, radius * 0.50, 0)
			pivot.add_child(spoke)

	# Brake disc on one side - a dark accent that keeps the wheel from reading
	# as a flat white circle.
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var dm := CylinderMesh.new()
	dm.top_radius = radius * 0.54
	dm.bottom_radius = radius * 0.54
	dm.height = 0.014
	dm.radial_segments = 20
	disc.mesh = dm
	disc.material_override = disc_mat
	disc.rotation.z = PI * 0.5
	disc.position = Vector3(width * 0.66, 0, 0)
	node.add_child(disc)

	return node


static func _cyl(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	return mi


static func _capsule(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.05)
	m.radial_segments = 10
	m.rings = 4
	mi.mesh = m
	mi.material_override = mat
	return mi
