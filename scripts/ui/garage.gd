extends Control
## The garage: pick a bike, paint it, and spend distance-earned credits on it.
##
## Built entirely in code rather than as a scene tree, because the contents are
## driven by BikeCatalog - adding a bike to the catalogue should make it appear
## here with no editor work.
##
## The bike on display is a live 3D preview on a turntable, lit the same way as
## the game world, so what you buy is what you ride.

signal closed

const PREVIEW_LAYER := 2

var _selected: String = ""
var _preview_root: Node3D
var _preview_bike: Node3D
var _viewport: SubViewport

var _credits_label: Label
var _bike_list: VBoxContainer
var _paint_row: HBoxContainer
var _upgrade_rows: VBoxContainer
var _stat_bars: Dictionary = {}
var _buy_button: Button
var _name_label: Label
var _name_fa_label: Label


func _ready() -> void:
	_build_ui()
	Game.credits_changed.connect(func(_c: int) -> void: _refresh())
	hide()


func open() -> void:
	_selected = Game.selected_bike
	show()
	_refresh()
	_rebuild_preview()


func close() -> void:
	# Selecting an owned bike is what actually equips it.
	if Game.owns(_selected):
		Game.selected_bike = _selected
		Game.save_game()
	hide()
	closed.emit()


func _process(delta: float) -> void:
	if visible and _preview_root != null:
		_preview_root.rotate_y(delta * 0.45)


# =======================================================================
#  UI construction
# =======================================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.045, 0.06, 0.96)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	margin.add_child(cols)

	# --- left: bike list -------------------------------------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)

	var header := HBoxContainer.new()
	left.add_child(header)

	var title := Label.new()
	title.text = "GARAGE"
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 24)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	header.add_child(_credits_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)

	_bike_list = VBoxContainer.new()
	_bike_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bike_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_bike_list)

	for id in BikeCatalog.ids():
		_bike_list.add_child(_make_bike_button(String(id)))

	# --- centre: 3D preview -----------------------------------------------
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.add_theme_constant_override("separation", 6)
	cols.add_child(centre)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 32)
	centre.add_child(_name_label)

	_name_fa_label = Label.new()
	_name_fa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_fa_label.add_theme_font_size_override("font_size", 22)
	_name_fa_label.modulate = Color(1, 1, 1, 0.6)
	centre.add_child(_name_fa_label)

	var preview_holder := SubViewportContainer.new()
	preview_holder.stretch = true
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.add_child(preview_holder)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_holder.add_child(_viewport)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.95, 3.0)
	cam.rotation_degrees.x = -11.0
	cam.fov = 42.0
	_viewport.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 42, 0)
	key.light_energy = 1.6
	_viewport.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.2, 1.6, 1.4)
	fill.omni_range = 9.0
	fill.light_energy = 1.2
	fill.light_color = Color(0.7, 0.8, 1.0)
	_viewport.add_child(fill)

	_preview_root = Node3D.new()
	_viewport.add_child(_preview_root)

	# Paint swatches
	_paint_row = HBoxContainer.new()
	_paint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_paint_row.add_theme_constant_override("separation", 8)
	centre.add_child(_paint_row)

	for paint in BikeCatalog.PAINTS:
		_paint_row.add_child(_make_swatch(paint))

	_buy_button = Button.new()
	_buy_button.custom_minimum_size.y = 52
	_buy_button.add_theme_font_size_override("font_size", 22)
	_buy_button.pressed.connect(_on_buy_pressed)
	centre.add_child(_buy_button)

	# --- right: stats and upgrades -----------------------------------------
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 320
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)

	var stats_title := Label.new()
	stats_title.text = "SPECS"
	stats_title.add_theme_font_size_override("font_size", 20)
	right.add_child(stats_title)

	for stat: String in ["top_speed", "accel", "brake", "lean_rate"]:
		right.add_child(_make_stat_bar(stat))

	var up_title := Label.new()
	up_title.text = "UPGRADES"
	up_title.add_theme_font_size_override("font_size", 20)
	right.add_child(up_title)

	_upgrade_rows = VBoxContainer.new()
	_upgrade_rows.add_theme_constant_override("separation", 6)
	right.add_child(_upgrade_rows)

	for part in BikeCatalog.UPGRADE_PARTS:
		_upgrade_rows.add_child(_make_upgrade_row(String(part)))

	var close_btn := Button.new()
	close_btn.text = "RIDE"
	close_btn.custom_minimum_size.y = 56
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(close)
	right.add_child(close_btn)


func _make_bike_button(id: String) -> Button:
	var b := Button.new()
	b.name = "Bike_" + id
	b.custom_minimum_size.y = 54
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		_selected = id
		Sfx.play_ui("click")
		_refresh()
		_rebuild_preview()
	)
	return b


func _make_swatch(paint: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(38, 38)
	b.tooltip_text = "%s  /  %s" % [paint["name"], paint["name_fa"]]

	var sb := StyleBoxFlat.new()
	sb.bg_color = paint["color"]
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(1, 1, 1, 0.25)
	b.add_theme_stylebox_override("normal", sb)

	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)

	b.pressed.connect(func() -> void:
		if not Game.owns(_selected):
			return
		Game.set_bike_color(_selected, paint["color"])
		Sfx.play_ui("click")
		_rebuild_preview()
	)
	return b


func _make_stat_bar(stat: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = stat.capitalize()
	label.custom_minimum_size.x = 96
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 1.0
	row.add_child(bar)

	_stat_bars[stat] = bar
	return row


func _make_upgrade_row(part: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Upgrade_" + part
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.name = "Label"
	label.custom_minimum_size.x = 84
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)

	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.add_theme_constant_override("separation", 3)
	for i in BikeCatalog.MAX_UPGRADE_LEVEL:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 14)
		pips.add_child(pip)
	row.add_child(pips)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var btn := Button.new()
	btn.name = "Buy"
	btn.custom_minimum_size = Vector2(96, 34)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(func() -> void:
		if Game.try_upgrade(_selected, part):
			Sfx.play_ui("purchase")
		else:
			Sfx.play_ui("deny")
		_refresh()
	)
	row.add_child(btn)

	return row


# =======================================================================
#  Refresh
# =======================================================================

func _refresh() -> void:
	if _selected == "" or not BikeCatalog.has(_selected):
		_selected = Game.selected_bike

	_credits_label.text = "%d cr" % Game.credits
	_name_label.text = BikeCatalog.display_name(_selected)
	_name_fa_label.text = BikeCatalog.display_name_fa(_selected)

	# Bike list
	for child in _bike_list.get_children():
		var b := child as Button
		var id := String(b.name).trim_prefix("Bike_")
		var owned := Game.owns(id)
		var equipped := id == Game.selected_bike
		var mark := "  <" if equipped else ""
		b.text = "%s%s" % [BikeCatalog.display_name(id), mark] if owned \
			else "%s   %d cr" % [BikeCatalog.display_name(id), BikeCatalog.price(id)]
		b.modulate = Color(1, 1, 1, 1.0 if owned else 0.55)
		b.button_pressed = id == _selected

	# Buy / equip button
	if Game.owns(_selected):
		_buy_button.text = "EQUIPPED" if _selected == Game.selected_bike else "SELECT"
		_buy_button.disabled = _selected == Game.selected_bike
	else:
		var price := BikeCatalog.price(_selected)
		_buy_button.text = "BUY  -  %d cr" % price
		_buy_button.disabled = Game.credits < price

	# Stats, shown relative to the fastest bike in the catalogue so the bars
	# mean something across the whole line-up.
	var stats := _stats_for(_selected)
	var maxima := _catalogue_maxima()
	for stat in _stat_bars:
		var bar: ProgressBar = _stat_bars[stat]
		bar.value = clampf(float(stats[stat]) / maxf(float(maxima[stat]), 0.001), 0.0, 1.0)

	# Upgrades
	var cfg := Game.get_config(_selected)
	var owned_now := Game.owns(_selected)
	for row in _upgrade_rows.get_children():
		var part := String(row.name).trim_prefix("Upgrade_")
		var level: int = cfg["upgrades"].get(part, 0)

		var label: Label = row.get_node("Label")
		label.text = BikeCatalog.UPGRADE_LABELS[part]["en"]

		var pips: HBoxContainer = row.get_node("Pips")
		for i in pips.get_child_count():
			var pip: ColorRect = pips.get_child(i)
			pip.color = Color(1.0, 0.72, 0.22) if i < level else Color(1, 1, 1, 0.14)

		var btn: Button = row.get_node("Buy")
		if level >= BikeCatalog.MAX_UPGRADE_LEVEL:
			btn.text = "MAX"
			btn.disabled = true
		else:
			var price := BikeCatalog.upgrade_price(_selected, part, level)
			btn.text = "%d cr" % price
			btn.disabled = not owned_now or Game.credits < price

	# Paint swatches only make sense on a bike you own.
	for swatch in _paint_row.get_children():
		(swatch as Button).disabled = not owned_now


## Stats for any bike, including upgrades if it is owned.
func _stats_for(id: String) -> Dictionary:
	var base := BikeCatalog.stats(id)
	if not Game.owns(id):
		return base
	var up: Dictionary = Game.get_config(id)["upgrades"]
	var step := 1.0 / float(BikeCatalog.MAX_UPGRADE_LEVEL)
	return {
		"top_speed": base["top_speed"] * (1.0 + 0.45 * up.get("engine", 0) * step),
		"accel": base["accel"] * (1.0 + 0.55 * up.get("engine", 0) * step),
		"brake": base["brake"] * (1.0 + 0.60 * up.get("brakes", 0) * step),
		"lean_rate": base["lean_rate"] * (1.0 + 0.50 * up.get("handling", 0) * step),
		"mass": base["mass"],
	}


func _catalogue_maxima() -> Dictionary:
	var out := {"top_speed": 0.0, "accel": 0.0, "brake": 0.0, "lean_rate": 0.0}
	for id in BikeCatalog.ids():
		var s := BikeCatalog.stats(String(id))
		for k in out:
			out[k] = maxf(float(out[k]), float(s[k]))
	# Headroom for fully upgraded bikes.
	for k in out:
		out[k] = float(out[k]) * 1.5
	return out


func _rebuild_preview() -> void:
	if _preview_bike != null:
		_preview_bike.queue_free()
	var cfg := Game.get_config(_selected)
	_preview_bike = BikeBuilder.build(_selected, cfg["color"])
	_preview_bike.position.y = -0.55
	_preview_root.add_child(_preview_bike)


func _on_buy_pressed() -> void:
	if Game.owns(_selected):
		Game.selected_bike = _selected
		Game.save_game()
		Sfx.play_ui("click")
	elif Game.try_buy_bike(_selected):
		Game.selected_bike = _selected
		Game.save_game()
		Sfx.play_ui("purchase")
	else:
		Sfx.play_ui("deny")
	_refresh()
