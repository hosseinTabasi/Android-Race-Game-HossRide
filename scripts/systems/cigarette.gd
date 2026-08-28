extends Node3D
## Hossein smokes the whole way home.
##
## This started life as an occasional event gated on clear road. It isn't any
## more: he lights up when the run starts and keeps smoking until he arrives,
## because that constant presence is the character. The left hand stays off the
## bar holding the cigarette, riding one-handed the entire time, and lifts to
## his mouth for a drag every few seconds.
##
## Three separate smoke sources, because one particle system cannot do all
## three jobs:
##   * the ember wisp   - a thin continuous trail off the tip
##   * the exhale       - a burst from his mouth a beat after each drag
##   * the ember flare  - the tip glowing brighter on the inhale
##
## Steering is never affected. He rides one-handed and it costs the player
## nothing, which is the point.

signal lit
signal finished
signal drag_taken

## Seconds between drags.
@export var drag_interval_min: float = 2.6
@export var drag_interval_max: float = 4.4
## How long the hand stays at his mouth.
@export var inhale_hold: float = 0.55

# --- arm pose ----------------------------------------------------------
## These are offsets applied on top of the arm's resting rotation, in radians.
##
## The sign convention matters: NEGATIVE lift raises the hand, positive lowers
## it. On a cruiser the arm already rests raised, reaching high bars, so the
## hold pose has to push it back DOWN - which is why hold_lift is positive.
##
## All six are exported so they can be dialled in live from the inspector on
## the Cigarette node while the game runs.
@export var hold_lift: float = 0.30      # hand down off the bar, holding it
@export var drag_lift: float = -0.34     # raised toward his mouth
@export var hold_fold: float = 0.20      # elbow almost straight
@export var drag_fold: float = 1.05      # elbow folded up to his face
@export var hold_inward: float = 0.08
@export var drag_inward: float = 0.46

var active: bool = false
var _rider: Node3D = null
var _arm: Node3D = null            # the left shoulder pivot
var _elbow: Node3D = null
var _arm_rest: Vector3 = Vector3.ZERO
var _elbow_rest: Vector3 = Vector3.ZERO
var _head: Node3D = null
var _mouth: Node3D = null

var _cig: Node3D = null
var _ember: MeshInstance3D = null
var _tip_smoke: GPUParticles3D = null
var _exhale: GPUParticles3D = null

var _rng := RandomNumberGenerator.new()
## 0 = hand down holding the cigarette, 1 = at his mouth.
var _hand_up: float = 0.0
var _puff_timer: float = 0.0
var _traffic: Node = null


func _ready() -> void:
	_rng.randomize()


## Kept for compatibility with world.gd. Smoking no longer depends on traffic,
## but the reference is harmless and may be useful for future reactions.
func set_traffic(traffic: Node) -> void:
	_traffic = traffic


## Called by player.gd whenever the bike rig is rebuilt.
func bind(rider: Node3D) -> void:
	_rider = rider
	_arm = null
	_elbow = null
	_head = null
	if _rider == null:
		return

	# The LEFT hand holds the cigarette, so the right stays on the throttle -
	# which is also the correct hand to keep on a motorcycle.
	_arm = _rider.get_node_or_null("Hips/TorsoPivot/LeftArm")
	if _arm != null:
		_arm_rest = _arm.rotation
		_elbow = _arm.get_node_or_null("Elbow")
		if _elbow != null:
			_elbow_rest = _elbow.rotation

	_head = _rider.get_node_or_null("Hips/TorsoPivot/Head")
	_build_cigarette()
	_build_exhale()

	# Light up immediately if a run is already under way (bike swapped mid-run).
	if Game.run_active and not active:
		start_smoking()


# =======================================================================
#  Construction
# =======================================================================

func _build_cigarette() -> void:
	if _cig != null:
		_cig.queue_free()
		_cig = null
	if _elbow == null:
		return

	_cig = Node3D.new()
	_cig.name = "Cig"
	# In the fingers: elbow -> hand is (0, -0.055, 0.215), so sit just past it.
	_cig.position = Vector3(0.012, -0.062, 0.245)
	_cig.rotation.x = deg_to_rad(-70.0)
	_elbow.add_child(_cig)

	# Deliberately oversized. A real cigarette is a few millimetres across and
	# simply vanishes at this camera distance, so it is scaled up until it
	# actually reads on screen.
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0085
	cm.bottom_radius = 0.0085
	cm.height = 0.110
	cm.radial_segments = 8
	stick.mesh = cm
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.94, 0.92, 0.87)
	paper.roughness = 0.9
	stick.material_override = paper
	stick.rotation.x = PI * 0.5
	_cig.add_child(stick)

	_ember = MeshInstance3D.new()
	_ember.name = "Ember"
	var em := SphereMesh.new()
	em.radius = 0.013
	em.height = 0.026
	_ember.mesh = em
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(1.0, 0.35, 0.05)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.30, 0.03)
	ember_mat.emission_energy_multiplier = 9.0
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ember.material_override = ember_mat
	_ember.position = Vector3(0, 0, 0.058)
	_cig.add_child(_ember)

	var glow := OmniLight3D.new()
	glow.name = "EmberGlow"
	glow.omni_range = 1.4
	glow.light_energy = 2.2
	glow.light_color = Color(1.0, 0.42, 0.12)
	glow.shadow_enabled = false
	_ember.add_child(glow)

	# amount, lifetime, quad size, direction, velocity range, alpha, continuous
	_tip_smoke = _make_smoke(26, 1.9, 0.090, Vector3(0, 0.5, -1), Vector2(1.4, 3.0), 0.46, true)
	_tip_smoke.position = Vector3(0, 0, 0.064)
	_cig.add_child(_tip_smoke)

	_cig.visible = false


func _build_exhale() -> void:
	if _exhale != null:
		_exhale.queue_free()
		_exhale = null
	if _head == null:
		return

	# A mouth marker on the front-lower face, so the smoke starts from his lips
	# rather than from the middle of his skull.
	_mouth = Node3D.new()
	_mouth.name = "Mouth"
	_mouth.position = Vector3(0, -0.030, 0.082)
	_head.add_child(_mouth)

	# The exhale is a one-shot burst. At road speed the plume is torn backwards
	# almost immediately, which is why the velocity points hard down -Z.
	_exhale = _make_smoke(46, 2.3, 0.30, Vector3(0, 0.22, -1), Vector2(6.5, 12.0), 0.62, false)
	_mouth.add_child(_exhale)


## Builds a smoke emitter. `continuous` chooses a steady trail versus a burst.
func _make_smoke(amount: int, lifetime: float, size: float, direction: Vector3,
		velocity: Vector2, alpha: float, continuous: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false      # smoke is left behind, it doesn't ride along
	p.emitting = false
	p.one_shot = not continuous
	p.explosiveness = 0.0 if continuous else 0.85
	# Generous bounds; smoke travels a long way back at speed.
	p.visibility_aabb = AABB(Vector3(-6, -3, -30), Vector3(12, 8, 34))

	var mat := ParticleProcessMaterial.new()
	mat.direction = direction
	mat.spread = 14.0 if continuous else 21.0
	mat.initial_velocity_min = velocity.x
	mat.initial_velocity_max = velocity.y
	mat.gravity = Vector3(0, 0.5, -1.6)
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	mat.damping_min = 0.5
	mat.damping_max = 1.6

	# Grow as it disperses - smoke expands, it doesn't hold its shape.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.88, 0.88, 0.86, alpha))
	ramp.set_color(1, Color(0.72, 0.72, 0.70, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex

	p.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	p.draw_pass_1 = quad

	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.billboard_keep_scale = true
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.albedo_color = Color(1, 1, 1, 1)
	draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = draw_mat

	return p


# =======================================================================
#  Update
# =======================================================================

func _process(delta: float) -> void:
	# He smokes for exactly as long as the run lasts.
	if Game.run_active and not active:
		start_smoking()
	elif not Game.run_active and active:
		_stop()

	if active:
		_puff_timer -= delta
		if _puff_timer <= 0.0:
			_puff_timer = _rng.randf_range(drag_interval_min, drag_interval_max)
			_take_drag()

	_animate_arm(delta)


func _take_drag() -> void:
	# Hand up, hold, hand down.
	var tw := create_tween()
	tw.tween_property(self, "_hand_up", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(inhale_hold)
	tw.tween_property(self, "_hand_up", 0.0, 0.55).set_trans(Tween.TRANS_SINE)

	# Ember flares while the hand is at his mouth.
	if _ember != null:
		var mat := _ember.material_override as StandardMaterial3D
		if mat != null:
			var flare := create_tween()
			flare.tween_interval(0.45)
			flare.tween_method(
				func(v: float) -> void: mat.emission_energy_multiplier = v,
				6.0, 15.0, inhale_hold * 0.8
			)
			flare.tween_method(
				func(v: float) -> void: mat.emission_energy_multiplier = v,
				15.0, 6.0, 0.9
			)

	Sfx.play_drag()
	drag_taken.emit()

	# The exhale comes a beat after the hand drops - you hold it in first.
	_queue_exhale()


func _queue_exhale() -> void:
	if _exhale == null:
		return
	var wait := 0.45 + inhale_hold + 0.35
	var tw := create_tween()
	tw.tween_interval(wait)
	tw.tween_callback(func() -> void:
		if active and _exhale != null:
			# restart() re-fires the one-shot burst.
			_exhale.restart()
			_exhale.emitting = true
	)


func _animate_arm(delta: float) -> void:
	if _arm == null:
		return

	var t := clampf(_hand_up, 0.0, 1.0)
	var ease_t := t * t * (3.0 - 2.0 * t)

	# Offsets on top of the resting pose. See the exported values above for the
	# sign convention - the arm already rests raised on a cruiser, so holding
	# the cigarette means pushing it back down, not lifting it further.
	var lift := lerpf(hold_lift, drag_lift, ease_t)
	var inward := lerpf(hold_inward, drag_inward, ease_t)
	var fold := lerpf(hold_fold, drag_fold, ease_t)

	var target := _arm_rest + Vector3(lift, inward, 0.0)
	var w := clampf(8.0 * delta, 0.0, 1.0)
	_arm.rotation = _arm.rotation.lerp(target, w)

	if _elbow != null:
		_elbow.rotation.x = lerpf(_elbow.rotation.x, _elbow_rest.x - fold, w)


# =======================================================================
#  Control
# =======================================================================

func start_smoking() -> void:
	if active or _cig == null:
		return
	active = true
	_hand_up = 0.0
	# First drag comes quickly, so you see it happen rather than wondering.
	_puff_timer = 1.4
	_cig.visible = true
	if _tip_smoke != null:
		_tip_smoke.emitting = true
	Sfx.play_lighter()
	lit.emit()


func _stop() -> void:
	if not active:
		return
	active = false
	_hand_up = 0.0
	if _tip_smoke != null:
		_tip_smoke.emitting = false
	if _exhale != null:
		_exhale.emitting = false
	if _cig != null:
		_cig.visible = false
	finished.emit()


## Bound to the C key: put it out, or light another.
func toggle() -> void:
	if active:
		_stop()
	elif Game.run_active:
		start_smoking()
