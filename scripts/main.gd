extends Node
## Top-level flow: menu -> run -> summary -> garage.
##
## The world stays loaded the whole time. Menus are overlays on a live scene
## with the bike idling on the road, which is both cheaper than reloading and
## a much better first impression than a static title card.

enum State { MENU, RIDING, SUMMARY, GARAGE }

@onready var world: Node3D = $World
@onready var hud: CanvasLayer = $HUD
@onready var menu: Control = $UI/Menu
@onready var summary: Control = $UI/Summary
@onready var garage: Control = $UI/Garage

var state: State = State.MENU


func _ready() -> void:
	# Lock handhelds to landscape. The web display server has no orientation
	# control and logs an error every launch if asked, so this is gated to
	# platforms that actually implement it.
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

	Game.run_ended.connect(_on_run_ended)
	world.player.speed_changed.connect(hud.set_speed)
	world.traffic.near_miss.connect(hud.flash_near_miss)
	hud.horn_pressed.connect(sound_horn)

	# Explicitly typed: `world` is a plain Node3D here, so anything reached
	# through world.player is untyped and `:=` has nothing to infer from.
	var cig: Node = world.player.get_node_or_null("Cigarette")
	if cig != null:
		cig.lit.connect(func() -> void: hud.set_smoking(true))
		cig.finished.connect(func() -> void: hud.set_smoking(false))

	menu.play_pressed.connect(_start_run)
	menu.garage_pressed.connect(_open_garage)
	summary.retry_pressed.connect(_start_run)
	summary.garage_pressed.connect(_open_garage)
	summary.menu_pressed.connect(_open_menu)
	garage.closed.connect(_on_garage_closed)

	Radio.play()
	_open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.RIDING:
		if event.is_action_pressed("horn"):
			sound_horn()
		elif event.is_action_pressed("radio_next"):
			Radio.next_track()
		elif event.is_action_pressed("smoke"):
			var cig: Node = world.player.get_node_or_null("Cigarette")
			if cig != null and cig.has_method("toggle"):
				cig.toggle()

	if event.is_action_pressed("ui_cancel"):
		if state == State.GARAGE:
			garage.close()
		elif state == State.RIDING:
			# Treat back as a bail-out, not a pause, so a run always resolves.
			world.abort_run()
			Game.end_run()


# =======================================================================
#  Transitions
# =======================================================================

## Sounds the bike's horn. Bound to H on desktop and the on-screen button on
## a phone, and it isn't purely cosmetic: cars directly ahead notice.
func sound_horn() -> void:
	if state != State.RIDING:
		return
	Sfx.play_player_horn()
	world.traffic.react_to_horn(world.player.position.x)


func _open_menu() -> void:
	state = State.MENU
	menu.show_menu()
	summary.hide()
	garage.hide()
	hud.visible = false


func _start_run() -> void:
	state = State.RIDING
	menu.hide()
	summary.hide()
	garage.hide()
	hud.visible = true
	world.player.refresh_bike()
	world.begin_run()


func _on_run_ended(run_summary: Dictionary) -> void:
	if state != State.RIDING:
		return
	state = State.SUMMARY
	hud.visible = false
	# Small beat before the panel so the crash animation reads.
	await get_tree().create_timer(1.35).timeout
	summary.show_summary(run_summary)


func _open_garage() -> void:
	state = State.GARAGE
	menu.hide()
	summary.hide()
	hud.visible = false
	garage.open()


func _on_garage_closed() -> void:
	world.player.refresh_bike()
	_open_menu()
