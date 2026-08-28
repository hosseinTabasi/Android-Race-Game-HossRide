extends CanvasLayer
## In-run HUD.
##
## Deliberately sparse. The road is the thing worth looking at, so the HUD
## holds the four numbers that change a decision - speed, distance, credits,
## multiplier - and one strip for the radio. Everything else is transient
## feedback that fades on its own.

@onready var speed_label: Label = $Root/TopLeft/Speed
@onready var speed_unit: Label = $Root/TopLeft/SpeedUnit
@onready var distance_label: Label = $Root/TopRight/Distance
@onready var credits_label: Label = $Root/TopRight/Credits
@onready var mult_label: Label = $Root/Multiplier
@onready var track_strip: PanelContainer = $Root/TrackStrip
@onready var track_title: Label = $Root/TrackStrip/Margin/Rows/Title
@onready var track_artist: Label = $Root/TrackStrip/Margin/Rows/Artist
@onready var smoke_icon: Label = $Root/SmokeIcon
@onready var near_miss_flash: Label = $Root/NearMissFlash

signal horn_pressed

var _mult_shown: float = 1.0
var _track_timer: float = 0.0


## The horn needs a thumb target on a phone, where there is no H key. Built in
## code rather than in the scene so it stays next to the signal it fires.
func _build_touch_controls() -> void:
	var horn := Button.new()
	horn.name = "HornButton"
	horn.text = "HORN"
	horn.add_theme_font_size_override("font_size", 18)
	horn.modulate = Color(1, 1, 1, 0.72)
	# Bottom-left, clear of the speed readout and the smoking indicator.
	horn.anchor_left = 0.0
	horn.anchor_top = 1.0
	horn.anchor_right = 0.0
	horn.anchor_bottom = 1.0
	horn.offset_left = 28.0
	horn.offset_top = -196.0
	horn.offset_right = 150.0
	horn.offset_bottom = -86.0
	horn.pressed.connect(func() -> void: horn_pressed.emit())
	$Root.add_child(horn)


func _ready() -> void:
	_build_touch_controls()
	Game.distance_changed.connect(_on_distance)
	Game.multiplier_changed.connect(_on_multiplier)
	Radio.track_changed.connect(_on_track_changed)

	near_miss_flash.modulate.a = 0.0
	smoke_icon.modulate.a = 0.0
	track_strip.modulate.a = 0.0
	mult_label.modulate.a = 0.0


func _process(delta: float) -> void:
	# Ease the displayed multiplier so it never snaps.
	_mult_shown = lerpf(_mult_shown, Game.multiplier, 8.0 * delta)
	mult_label.text = "x%.1f" % _mult_shown
	mult_label.modulate.a = lerpf(mult_label.modulate.a, 1.0 if _mult_shown > 1.05 else 0.0, 6.0 * delta)
	# Multiplier warms from white to orange as it climbs.
	mult_label.modulate = Color(1.0, lerpf(1.0, 0.55, (_mult_shown - 1.0) / 4.0),
		lerpf(1.0, 0.15, (_mult_shown - 1.0) / 4.0), mult_label.modulate.a)

	credits_label.text = "%d" % int(Game.run_credits)

	if _track_timer > 0.0:
		_track_timer -= delta
		if _track_timer <= 0.0:
			var tw := create_tween()
			tw.tween_property(track_strip, "modulate:a", 0.0, 0.6)


func set_speed(mps: float) -> void:
	speed_label.text = "%d" % int(round(mps * 3.6))


func _on_distance(metres: float) -> void:
	if metres < 1000.0:
		distance_label.text = "%d m" % int(metres)
	else:
		distance_label.text = "%.2f km" % (metres / 1000.0)


func _on_multiplier(_m: float) -> void:
	pass   # smoothed in _process


func _on_track_changed(title: String, artist: String) -> void:
	track_title.text = title
	track_artist.text = artist if artist != "" else "Radio"
	track_strip.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(track_strip, "modulate:a", 1.0, 0.4)
	_track_timer = 5.5


func flash_near_miss(closeness: float) -> void:
	near_miss_flash.text = "NICE!" if closeness < 0.75 else "CLOSE!"
	near_miss_flash.modulate.a = 1.0
	near_miss_flash.scale = Vector2.ONE * (1.0 + closeness * 0.35)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(near_miss_flash, "modulate:a", 0.0, 0.75)
	tw.tween_property(near_miss_flash, "scale", Vector2.ONE * 0.85, 0.75)


func set_smoking(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(smoke_icon, "modulate:a", 1.0 if on else 0.0, 0.4)
