class_name BikeCatalog
extends RefCounted
## Static catalogue of rideable motorcycles.
##
## The line-up mirrors what actually moves through Tehran traffic: small
## commuter singles are the workhorses, with a couple of bigger machines as
## late-game purchases. Geometry values feed the procedural bike builder, so
## each machine genuinely looks different rather than being a recolour.

const MAX_UPGRADE_LEVEL := 5

## Every bike, keyed by id.
##   top_speed  m/s
##   accel      m/s^2
##   brake      m/s^2
##   lean_rate  radians/s of steering authority
##   mass       kg (affects how hard it is to flick between lanes)
##   frame      geometry preset consumed by bike_builder.gd
const BIKES := {
	# The bike you start on: a big, wide, low-slung V-twin cruiser. Long
	# wheelbase and fat tyres make it heavy to flick between lanes, which is
	# the trade for how planted and imposing it feels.
	"cruiser1200": {
		"name": "Cruiser 1200",
		"name_fa": "کروزر ۱۲۰۰",
		"price": 0,
		"top_speed": 39.0,
		"accel": 8.4,
		"brake": 10.8,
		"lean_rate": 2.05,
		"mass": 310.0,
		"frame": {
			"wheelbase": 1.74, "wheel_r": 0.40, "tyre_w": 0.22,
			"seat_h": 0.68, "tank_len": 0.64, "tank_h": 0.34,
			"fairing": 0.18, "bar_w": 0.48, "exhaust": "twin_low",
			"style": "cruiser",
		},
	},
	"honda125": {
		"name": "Honda 125",
		"name_fa": "هوندا ۱۲۵",
		"price": 1800,
		"top_speed": 33.0,
		"accel": 7.8,
		"brake": 10.0,
		"lean_rate": 2.6,
		"mass": 110.0,
		"frame": {
			"wheelbase": 1.28, "wheel_r": 0.30, "tyre_w": 0.09,
			"seat_h": 0.78, "tank_len": 0.46, "tank_h": 0.20,
			"fairing": 0.0, "bar_w": 0.36, "exhaust": "low_single",
			"style": "commuter",
		},
	},
	"cargo150": {
		"name": "Cargo 150",
		"name_fa": "کارگو ۱۵۰",
		"price": 3500,
		"top_speed": 36.5,
		"accel": 8.6,
		"brake": 10.6,
		"lean_rate": 2.4,
		"mass": 128.0,
		"frame": {
			"wheelbase": 1.34, "wheel_r": 0.31, "tyre_w": 0.10,
			"seat_h": 0.80, "tank_len": 0.50, "tank_h": 0.23,
			"fairing": 0.15, "bar_w": 0.38, "exhaust": "low_single",
			"style": "commuter",
		},
	},
	"apache180": {
		"name": "Apache 180",
		"name_fa": "آپاچی ۱۸۰",
		"price": 9000,
		"top_speed": 43.5,
		"accel": 10.2,
		"brake": 12.2,
		"lean_rate": 3.0,
		"mass": 140.0,
		"frame": {
			"wheelbase": 1.36, "wheel_r": 0.32, "tyre_w": 0.12,
			"seat_h": 0.79, "tank_len": 0.52, "tank_h": 0.26,
			"fairing": 0.45, "bar_w": 0.34, "exhaust": "upswept",
			"style": "naked_sport",
		},
	},
	"benelli250": {
		"name": "Benelli 250",
		"name_fa": "بنلی ۲۵۰",
		"price": 22000,
		"top_speed": 53.0,
		"accel": 12.1,
		"brake": 14.4,
		"lean_rate": 3.1,
		"mass": 165.0,
		"frame": {
			"wheelbase": 1.42, "wheel_r": 0.33, "tyre_w": 0.14,
			"seat_h": 0.81, "tank_len": 0.56, "tank_h": 0.30,
			"fairing": 0.70, "bar_w": 0.32, "exhaust": "underslung",
			"style": "sport",
		},
	},
	"street650": {
		"name": "Street 650",
		"name_fa": "استریت ۶۵۰",
		"price": 48000,
		"top_speed": 65.0,
		"accel": 14.8,
		"brake": 16.6,
		"lean_rate": 2.9,
		"mass": 198.0,
		"frame": {
			"wheelbase": 1.48, "wheel_r": 0.34, "tyre_w": 0.17,
			"seat_h": 0.83, "tank_len": 0.60, "tank_h": 0.33,
			"fairing": 0.35, "bar_w": 0.40, "exhaust": "twin_low",
			"style": "naked_sport",
		},
	},
}

## Paints offered in the garage. Persian names because the garage UI is bilingual.
const PAINTS := [
	{"name": "Black", "name_fa": "مشکی", "color": Color(0.06, 0.06, 0.07)},
	{"name": "Pearl White", "name_fa": "سفید صدفی", "color": Color(0.90, 0.90, 0.88)},
	{"name": "Tehran Red", "name_fa": "قرمز", "color": Color(0.62, 0.07, 0.08)},
	{"name": "Petrol Blue", "name_fa": "آبی نفتی", "color": Color(0.08, 0.20, 0.36)},
	{"name": "Pistachio", "name_fa": "پسته‌ای", "color": Color(0.45, 0.55, 0.30)},
	{"name": "Saffron", "name_fa": "زعفرانی", "color": Color(0.85, 0.52, 0.06)},
	{"name": "Gunmetal", "name_fa": "نوک‌مدادی", "color": Color(0.22, 0.23, 0.25)},
	{"name": "Turquoise", "name_fa": "فیروزه‌ای", "color": Color(0.10, 0.55, 0.55)},
]

const UPGRADE_PARTS := ["engine", "brakes", "handling", "nitro"]

const UPGRADE_LABELS := {
	"engine": {"en": "Engine", "fa": "موتور"},
	"brakes": {"en": "Brakes", "fa": "ترمز"},
	"handling": {"en": "Handling", "fa": "فرمان"},
	"nitro": {"en": "Nitro", "fa": "نیترو"},
}


static func ids() -> Array:
	return BIKES.keys()


static func has(bike_id: String) -> bool:
	return BIKES.has(bike_id)


static func spec(bike_id: String) -> Dictionary:
	return BIKES.get(bike_id, BIKES["cruiser1200"])


static func stats(bike_id: String) -> Dictionary:
	var s := spec(bike_id)
	return {
		"top_speed": s["top_speed"],
		"accel": s["accel"],
		"brake": s["brake"],
		"lean_rate": s["lean_rate"],
		"mass": s["mass"],
	}


static func frame(bike_id: String) -> Dictionary:
	return spec(bike_id)["frame"]


static func price(bike_id: String) -> int:
	return int(spec(bike_id)["price"])


static func display_name(bike_id: String) -> String:
	return String(spec(bike_id)["name"])


static func display_name_fa(bike_id: String) -> String:
	return String(spec(bike_id)["name_fa"])


## Factory colour per bike.
##
## Explicit rather than hashed from the id. The old hash could - and for the
## cruiser did - land on Black, which puts a black tank and black fenders on a
## black road at night. Every factory colour here is deliberately strong.
const DEFAULT_PAINTS := {
	"cruiser1200": Color(0.62, 0.07, 0.08),   # Tehran red
	"honda125": Color(0.08, 0.20, 0.36),      # petrol blue
	"cargo150": Color(0.45, 0.55, 0.30),      # pistachio
	"apache180": Color(0.85, 0.52, 0.06),     # saffron
	"benelli250": Color(0.10, 0.55, 0.55),    # turquoise
	"street650": Color(0.90, 0.90, 0.88),     # pearl white
}


static func default_color(bike_id: String) -> Color:
	if DEFAULT_PAINTS.has(bike_id):
		return DEFAULT_PAINTS[bike_id]
	# Fallback for any bike added without a factory colour: pick from the
	# paint list but skip index 0, which is Black.
	var idx := 1 + absi(bike_id.hash()) % (PAINTS.size() - 1)
	return PAINTS[idx]["color"]


## Upgrades get progressively more expensive, and scale with the bike's value.
static func upgrade_price(bike_id: String, _part: String, current_level: int) -> int:
	var base := maxi(600, price(bike_id) / 8)
	return int(base * pow(1.7, current_level))
