extends Control
## Title screen, overlaid on the live world so the city is moving behind it.

signal play_pressed
signal garage_pressed

var _best_label: Label
var _credits_label: Label
var _track_label: Label


func _ready() -> void:
	_build()
	Radio.track_changed.connect(func(t: String, a: String) -> void:
		_track_label.text = ("%s - %s" % [a, t]) if a != "" else t
	)
	Radio.playlist_loaded.connect(func(count: int) -> void:
		if count == 0:
			_track_label.text = "Radio: no tracks found - add music in Settings"
	)


func show_menu() -> void:
	show()
	_refresh()


func _refresh() -> void:
	_best_label.text = "Best  %.2f km" % (Game.best_distance_m / 1000.0)
	_credits_label.text = "%d cr" % Game.credits


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# A soft vignette rather than a solid panel, so the world stays visible.
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var centre := VBoxContainer.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 10)
	centre.position = Vector2(-190, -160)
	centre.custom_minimum_size = Vector2(380, 0)
	add_child(centre)

	var title := Label.new()
	title.text = "HOSSRIDE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 62)
	centre.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "TEHRAN"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.modulate = Color(1.0, 0.72, 0.25)
	centre.add_child(subtitle)

	centre.add_child(_spacer(18))

	_best_label = Label.new()
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.add_theme_font_size_override("font_size", 18)
	_best_label.modulate = Color(1, 1, 1, 0.75)
	centre.add_child(_best_label)

	_credits_label = Label.new()
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_label.add_theme_font_size_override("font_size", 18)
	_credits_label.modulate = Color(1.0, 0.80, 0.30)
	centre.add_child(_credits_label)

	centre.add_child(_spacer(18))

	var play := Button.new()
	play.text = "RIDE"
	play.custom_minimum_size.y = 64
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(func() -> void:
		Sfx.play_ui("click")
		play_pressed.emit()
	)
	centre.add_child(play)

	var garage := Button.new()
	garage.text = "GARAGE"
	garage.custom_minimum_size.y = 48
	garage.add_theme_font_size_override("font_size", 20)
	garage.pressed.connect(func() -> void:
		Sfx.play_ui("click")
		garage_pressed.emit()
	)
	centre.add_child(garage)

	centre.add_child(_spacer(10))

	var hint := Label.new()
	hint.text = "Tilt or drag to steer  -  hold to brake"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.45)
	centre.add_child(hint)

	# Now-playing line pinned to the bottom.
	_track_label = Label.new()
	_track_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track_label.add_theme_font_size_override("font_size", 14)
	_track_label.modulate = Color(1, 1, 1, 0.5)
	_track_label.position.y = -34
	_track_label.text = "Radio"
	add_child(_track_label)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
