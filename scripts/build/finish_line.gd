class_name FinishLine
extends Node3D
## The end of the ride: home, in Amirabad.
##
## Built as one self-contained node that the world slides toward the rider like
## any other piece of scenery, so arriving needs no special-case movement code
## - the treadmill just delivers it.
##
## Staging matters here. The banner crosses the road so you ride *under* it and
## know you've arrived; the house sits ahead and to the right with its name on
## the roof; and the family stands on the shoulder between the two, close
## enough to the racing line that they're the last thing you see. They cheer on
## a loop from the moment they spawn, so they're already celebrating as you
## come into view rather than triggering awkwardly on arrival.

const ROAD_HALF := 7.0        # 4 lanes x 3.5 m, halved
const SHOULDER := 1.4

var _cheerers: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	_build_banner()
	_build_house()
	_build_family()
	_build_lights()


func _process(delta: float) -> void:
	_time += delta
	_animate_family()


# =======================================================================
#  Banner across the road
# =======================================================================

func _build_banner() -> void:
	var span := (ROAD_HALF + SHOULDER) * 2.0 + 1.2
	var post_h := 7.2

	var concrete := MaterialLibrary.concrete(0.9)

	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.20
		pm.bottom_radius = 0.28
		pm.height = post_h
		pm.radial_segments = 10
		post.mesh = pm
		post.material_override = concrete
		post.position = Vector3(side * span * 0.5, post_h * 0.5, 0)
		add_child(post)

	# Cross beam.
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(span, 1.5, 0.35)
	beam.mesh = bm
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.10, 0.34, 0.24)   # municipal sign green
	beam_mat.roughness = 0.55
	beam.mesh = bm
	beam.material_override = beam_mat
	beam.position = Vector3(0, post_h - 0.4, 0)
	add_child(beam)

	add_child(_make_sign("AMIRABAD", Vector3(0, post_h - 0.4, -0.2), 150, Color(1, 1, 1)))


# =======================================================================
#  The house
# =======================================================================

func _build_house() -> void:
	var house := Node3D.new()
	house.name = "House"
	# Ahead and to the right, set back off the shoulder.
	house.position = Vector3(14.5, 0, 26.0)
	house.rotation.y = deg_to_rad(-24.0)   # angled toward the road
	add_child(house)

	var w := 12.0
	var d := 9.0
	var storey := 3.2
	var h := storey * 2.0

	# --- shell: Tehran beige brick ------------------------------------
	var brick := StandardMaterial3D.new()
	brick.albedo_color = Color(0.62, 0.54, 0.44)
	brick.roughness = 0.88

	var shell := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(w, h, d)
	shell.mesh = sm
	shell.material_override = brick
	shell.position = Vector3(0, h * 0.5, 0)
	house.add_child(shell)

	# --- parapet around the flat roof ----------------------------------
	var parapet := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(w + 0.4, 0.7, d + 0.4)
	parapet.mesh = pm
	parapet.material_override = MaterialLibrary.concrete(0.95)
	parapet.position = Vector3(0, h + 0.35, 0)
	house.add_child(parapet)

	# --- lit windows facing the road ------------------------------------
	var glow := MaterialLibrary.lit_window(0.9)
	for floor_i in 2:
		for col in 3:
			var win := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(1.5, 1.7, 0.12)
			win.mesh = wm
			win.material_override = glow
			win.position = Vector3(
				-w * 0.5 + 2.4 + col * 3.7,
				storey * floor_i + 1.9,
				-d * 0.5 - 0.05
			)
			house.add_child(win)

	# --- door, warmly lit --------------------------------------------------
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.4, 2.3, 0.14)
	door.mesh = dm
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.30, 0.18, 0.10)
	door_mat.roughness = 0.7
	door.mesh = dm
	door.material_override = door_mat
	door.position = Vector3(w * 0.5 - 2.2, 1.15, -d * 0.5 - 0.06)
	house.add_child(door)

	var porch := OmniLight3D.new()
	porch.position = Vector3(w * 0.5 - 2.2, 2.9, -d * 0.5 - 0.7)
	porch.omni_range = 9.0
	porch.light_energy = 2.6
	porch.light_color = Color(1.0, 0.83, 0.58)
	house.add_child(porch)

	# --- balcony -----------------------------------------------------------
	var balcony := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.2, 0.22, 1.6)
	balcony.mesh = bm
	balcony.material_override = MaterialLibrary.concrete(1.0)
	balcony.position = Vector3(-w * 0.25, storey + 0.9, -d * 0.5 - 0.8)
	house.add_child(balcony)

	for i in 9:
		var rail := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.035
		rm.bottom_radius = 0.035
		rm.height = 0.95
		rm.radial_segments = 6
		rail.mesh = rm
		rail.material_override = MaterialLibrary.matte_black()
		rail.position = Vector3(-w * 0.25 - 2.4 + i * 0.6, storey + 1.48, -d * 0.5 - 1.5)
		house.add_child(rail)

	# --- rooftop sign: the name of the place ---------------------------------
	var board := MeshInstance3D.new()
	var boardm := BoxMesh.new()
	boardm.size = Vector3(9.0, 1.9, 0.25)
	board.mesh = boardm
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.08, 0.10, 0.13)
	board_mat.roughness = 0.5
	board.mesh = boardm
	board.material_override = board_mat
	board.position = Vector3(0, h + 1.9, -d * 0.5 - 0.1)
	house.add_child(board)

	house.add_child(_make_sign("AMIRABAD", Vector3(0, h + 1.9, -d * 0.5 - 0.25), 165,
		Color(1.0, 0.85, 0.42)))

	# Rooftop water tank, because every Tehran roof has one.
	var tank := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.85
	tm.bottom_radius = 0.85
	tm.height = 1.5
	tm.radial_segments = 10
	tank.mesh = tm
	tank.material_override = MaterialLibrary.concrete(0.8)
	tank.position = Vector3(w * 0.3, h + 1.4, d * 0.25)
	house.add_child(tank)

	# --- garden wall out front -------------------------------------------------
	var wall := MeshInstance3D.new()
	var wm2 := BoxMesh.new()
	wm2.size = Vector3(w + 3.0, 1.7, 0.3)
	wall.mesh = wm2
	wall.material_override = MaterialLibrary.concrete(1.05)
	wall.position = Vector3(0, 0.85, -d * 0.5 - 4.5)
	house.add_child(wall)


## An emissive Label3D, turned to face the arriving rider.
func _make_sign(text: String, pos: Vector3, font_size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.008
	label.modulate = colour
	label.outline_size = 18
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = true
	label.shaded = false
	label.position = pos
	# Label3D faces +Z; the rider approaches from -Z, so turn it around.
	label.rotation.y = PI
	return label


# =======================================================================
#  The family
# =======================================================================

func _build_family() -> void:
	# Standing in the middle of the road, waiting for him.
	#
	# They used to be on the shoulder, ten metres off the centreline, which put
	# them at the very edge of frame behind the barrier - effectively invisible.
	# Dead ahead is the only placement that guarantees you see them.
	#
	# They sit 12-15 m past the banner, so the bike rolls to a stop just short
	# of them: close enough to read faces, far enough to see all three.
	_cheerers.append(_make_person(
		Vector3(-1.9, 0, 13.6), 1.78,
		Color(0.16, 0.20, 0.30),      # man, dark jacket
		Color(0.20, 0.20, 0.22),
		false, 0.0))

	_cheerers.append(_make_person(
		Vector3(1.7, 0, 14.6), 1.63,
		Color(0.44, 0.14, 0.22),      # woman, deep red coat
		Color(0.30, 0.30, 0.34),
		true, 1.1))

	_cheerers.append(_make_person(
		Vector3(-0.2, 0, 12.1), 1.14,
		Color(0.20, 0.42, 0.52),      # kid, blue
		Color(0.25, 0.25, 0.28),
		false, 2.2))


## Builds one cheering figure. Returns a record the animator can drive.
func _make_person(pos: Vector3, height: float, clothing: Color, lower: Color,
		headscarf: bool, phase: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	# Face back down the road toward the arriving rider.
	root.rotation.y = PI
	add_child(root)

	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = clothing
	cloth.roughness = 0.82

	var trousers := StandardMaterial3D.new()
	trousers.albedo_color = lower
	trousers.roughness = 0.86

	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.66, 0.48, 0.36)
	skin.roughness = 0.74

	# Proportions scale off total height.
	var leg_h := height * 0.46
	var torso_h := height * 0.34
	var head_r := height * 0.072

	# A body node so the whole figure can bob without moving its feet far.
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	for side: float in [-1.0, 1.0]:
		var leg := _capsule(height * 0.055, leg_h, trousers)
		leg.position = Vector3(side * height * 0.055, leg_h * 0.5, 0)
		body.add_child(leg)

	var torso := _capsule(height * 0.10, torso_h, cloth)
	torso.position = Vector3(0, leg_h + torso_h * 0.45, 0)
	body.add_child(torso)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = head_r
	hm.height = head_r * 2.1
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0, leg_h + torso_h + head_r * 0.85, 0)
	body.add_child(head)

	if headscarf:
		var scarf := MeshInstance3D.new()
		var scm := SphereMesh.new()
		scm.radius = head_r * 1.16
		scm.height = head_r * 2.3
		scarf.mesh = scm
		var scarf_mat := StandardMaterial3D.new()
		scarf_mat.albedo_color = clothing.lightened(0.18)
		scarf_mat.roughness = 0.9
		scarf.mesh = scm
		scarf.material_override = scarf_mat
		scarf.position = Vector3(0, leg_h + torso_h + head_r * 0.95, -head_r * 0.12)
		scarf.scale = Vector3(1.0, 1.05, 1.12)
		body.add_child(scarf)

	# Arms, raised and waving. Pivot at the shoulder.
	var arms: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * height * 0.115, leg_h + torso_h * 0.88, 0)
		body.add_child(shoulder)

		var upper := _capsule(height * 0.038, height * 0.30, cloth)
		upper.position = Vector3(0, height * 0.15, 0)
		shoulder.add_child(upper)

		var hand := MeshInstance3D.new()
		var handm := SphereMesh.new()
		handm.radius = height * 0.042
		handm.height = height * 0.084
		hand.mesh = handm
		hand.material_override = skin
		hand.position = Vector3(0, height * 0.31, 0)
		shoulder.add_child(hand)

		# Splay the arms outward so they read as raised, not standing to attention.
		shoulder.rotation.z = side * deg_to_rad(28.0)
		arms.append(shoulder)

	return {
		"root": root,
		"body": body,
		"arms": arms,
		"phase": phase,
		"height": height,
		"base_y": 0.0,
	}


func _animate_family() -> void:
	for c in _cheerers:
		var phase: float = c["phase"]
		var body: Node3D = c["body"]
		var height: float = c["height"]

		# Bounce. Kids bounce faster and higher relative to their size.
		var rate := 4.2 + (1.0 - height) * 2.0
		var bounce: float = absf(sin(_time * rate + phase)) * height * 0.055
		body.position.y = bounce
		# A little squash on landing sells the weight.
		body.scale.y = 1.0 - bounce * 0.12

		# Arms wave out of phase with each other.
		var arms: Array = c["arms"]
		for i in arms.size():
			var side := -1.0 if i == 0 else 1.0
			var arm: Node3D = arms[i]
			arm.rotation.z = side * (deg_to_rad(28.0) + sin(_time * (rate * 1.4) + phase + i * 1.6) * 0.42)


# =======================================================================
#  Dressing
# =======================================================================

func _build_lights() -> void:
	# Directly over the family. The game is permanently at night now, so this
	# light is the only reason they are visible at all - it has to sit above
	# where they actually stand.
	var key := OmniLight3D.new()
	key.position = Vector3(0.0, 7.0, 13.5)
	key.omni_range = 30.0
	key.light_energy = 4.2
	key.light_color = Color(1.0, 0.86, 0.62)
	add_child(key)

	# A second, lower fill from in front so faces and raised arms catch light
	# rather than being lit only from straight above.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 2.4, 8.0)
	fill.omni_range = 18.0
	fill.light_energy = 2.2
	fill.light_color = Color(1.0, 0.80, 0.58)
	add_child(fill)

	var banner_light := OmniLight3D.new()
	banner_light.position = Vector3(0, 5.4, -2.0)
	banner_light.omni_range = 18.0
	banner_light.light_energy = 2.0
	banner_light.light_color = Color(1.0, 0.92, 0.78)
	add_child(banner_light)


func _capsule(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.05)
	m.radial_segments = 8
	m.rings = 3
	mi.mesh = m
	mi.material_override = mat
	return mi
