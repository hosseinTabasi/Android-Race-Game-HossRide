extends Control
## Post-crash summary.
##
## Numbers count up rather than appearing, because the credit total is the
## reward loop and watching it climb is most of the payoff for a good run.

signal retry_pressed
signal garage_pressed
signal menu_pressed

var _distance_label: Label
var _credits_label: Label
var _near_miss_label: Label
var _top_speed_label: Label
var _best_badge: Label
var _total_label: Label
var _headline: Label
var _retry: Button


func _ready() -> void:
	_build()
	hide()


func show_summary(data: Dictionary) -> void:
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)

	# Arriving home and crashing are very different endings, so they read
	# differently: one is an arrival, the other is a stop.
	var completed := bool(data.get("completed", false))
	if completed:
		_headline.text = "YOU MADE IT HOME"
		_headline.modulate = Color(1.0, 0.86, 0.45)
		_retry.text = "RIDE AGAIN"
	else:
		_headline.text = "RUN OVER"
		_headline.modulate = Color(1, 1, 1)
		_retry.text = "TRY AGAIN"

	_best_badge.visible = bool(data.get("is_best", false)) and not completed
	_near_miss_label.text = "%d close passes" % int(data.get("near_misses", 0))
	_top_speed_label.text = "%d km/h top" % int(data.get("top_speed_kmh", 0.0))
	_total_label.text = "%d cr total" % Game.credits

	_count_up(_distance_label, 0.0, float(data.get("distance_m", 0.0)) / 1000.0, " km", 2)
	_count_up(_credits_label, 0.0, float(data.get("credits", 0)), " cr", 0)


## Tweens a label's number from `from` to `to`.
func _count_up(label: Label, from: float, to: float, suffix: String, decimals: int) -> void:
	# The format string is built up front: GDScript's % operator has no
	# star-precision form, so the decimal count has to be baked in.
	var fmt := "%d%s" if decimals <= 0 else "%%.%df%%s" % decimals
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void:
			var shown: Variant = int(v) if decimals <= 0 else v
			label.text = fmt % [shown, suffix],
		from, to, 0.9
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.78)
	add_child(shade)

	var centre := VBoxContainer.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 8)
	centre.position = Vector2(-190, -180)
	centre.custom_minimum_size = Vector2(380, 0)
	add_child(centre)

	_headline = Label.new()
	_headline.text = "RUN OVER"
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.add_theme_font_size_override("font_size", 38)
	centre.add_child(_headline)

	_best_badge = Label.new()
	_best_badge.text = "NEW BEST"
	_best_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_badge.add_theme_font_size_override("font_size", 20)
	_best_badge.modulate = Color(1.0, 0.78, 0.22)
	centre.add_child(_best_badge)

	centre.add_child(_spacer(14))

	_distance_label = Label.new()
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distance_label.add_theme_font_size_override("font_size", 46)
	centre.add_child(_distance_label)

	_credits_label = Label.new()
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_label.add_theme_font_size_override("font_size", 30)
	_credits_label.modulate = Color(1.0, 0.80, 0.30)
	centre.add_child(_credits_label)

	centre.add_child(_spacer(10))

	_near_miss_label = _small_label()
	centre.add_child(_near_miss_label)
	_top_speed_label = _small_label()
	centre.add_child(_top_speed_label)
	_total_label = _small_label()
	centre.add_child(_total_label)

	centre.add_child(_spacer(18))

	_retry = Button.new()
	_retry.text = "RIDE AGAIN"
	_retry.custom_minimum_size.y = 60
	_retry.add_theme_font_size_override("font_size", 26)
	_retry.pressed.connect(func() -> void:
		Sfx.play_ui("click")
		retry_pressed.emit()
	)
	centre.add_child(_retry)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	centre.add_child(row)

	var garage := Button.new()
	garage.text = "GARAGE"
	garage.custom_minimum_size.y = 46
	garage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage.pressed.connect(func() -> void:
		Sfx.play_ui("click")
		garage_pressed.emit()
	)
	row.add_child(garage)

	var menu := Button.new()
	menu.text = "MENU"
	menu.custom_minimum_size.y = 46
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func() -> void:
		Sfx.play_ui("click")
		menu_pressed.emit()
	)
	row.add_child(menu)


func _small_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
