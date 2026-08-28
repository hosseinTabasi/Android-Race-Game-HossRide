class_name CarCatalog
extends RefCounted
## Catalogue of the vehicles that fill Tehran traffic.
##
## Each entry describes a body as two lofted profiles rather than a box, which
## is what makes a Paykan read as a Paykan and a 206 read as a hatchback:
##
##   body   - the lower body, sill to beltline.  Rows are
##            [z, half_width, y_bottom, y_top]
##   cabin  - the greenhouse above the beltline.  Rows are
##            [z, half_width, y_roof]
##
## z runs 0.0 at the front bumper to 1.0 at the rear bumper. Widths are a
## fraction of the vehicle's half width, heights are in metres. The builder
## lofts a closed hull through these rings, so a steeply raked rear (206) and
## an upright three-box tail (Paykan) come out structurally different.
##
## These are original approximations built to evoke the real Tehran street mix.
## They are stylised lookalikes, not licensed or dimensionally exact models.

## Realistic paint distribution. Iranian traffic skews overwhelmingly white,
## then silver and black; strong colours are comparatively rare.
const COMMON_PAINTS := [
	{"color": Color(0.88, 0.88, 0.86), "weight": 42.0},  # white
	{"color": Color(0.66, 0.68, 0.70), "weight": 18.0},  # silver
	{"color": Color(0.10, 0.10, 0.11), "weight": 12.0},  # black
	{"color": Color(0.36, 0.38, 0.42), "weight": 8.0},   # graphite
	{"color": Color(0.30, 0.10, 0.11), "weight": 5.0},   # dark red
	{"color": Color(0.13, 0.22, 0.38), "weight": 5.0},   # navy
	{"color": Color(0.55, 0.52, 0.44), "weight": 4.0},   # beige
	{"color": Color(0.18, 0.30, 0.24), "weight": 3.0},   # dark green
	{"color": Color(0.52, 0.14, 0.12), "weight": 3.0},   # red
]

const TAXI_YELLOW := Color(0.94, 0.72, 0.06)
const TAXI_GREEN := Color(0.10, 0.42, 0.26)

const VEHICLES := {

	# --- Saipa Pride 131 -------------------------------------------------
	# The default car of Iran. Tiny, boxy, upright, short overhangs.
	"pride": {
		"name": "Pride",
		"name_fa": "پراید",
		"class": "car",
		"length": 3.80, "width": 1.60, "wheelbase": 2.32,
		"wheel_r": 0.28, "track": 1.36, "ride_h": 0.16,
		"weight": 22.0,
		"speed_range": [11.0, 19.0],
		"body": [
			[0.00, 0.72, 0.30, 0.62],
			[0.05, 0.92, 0.22, 0.70],
			[0.16, 1.00, 0.18, 0.74],
			[0.30, 1.00, 0.18, 0.76],
			[0.52, 1.00, 0.18, 0.76],
			[0.74, 1.00, 0.18, 0.76],
			[0.88, 0.98, 0.20, 0.74],
			[0.96, 0.88, 0.24, 0.70],
			[1.00, 0.70, 0.30, 0.62],
		],
		"cabin": [
			[0.26, 0.86, 0.78],
			[0.34, 0.93, 1.06],
			[0.44, 0.95, 1.30],
			[0.62, 0.95, 1.32],
			[0.78, 0.92, 1.28],
			[0.86, 0.84, 1.02],
			[0.90, 0.76, 0.80],
		],
	},

	# --- Iran Khodro Paykan ----------------------------------------------
	# 1960s Hillman Hunter lineage: flat hood, upright glass, razor edges.
	"peykan": {
		"name": "Paykan",
		"name_fa": "پیکان",
		"class": "car",
		"length": 4.26, "width": 1.63, "wheelbase": 2.50,
		"wheel_r": 0.30, "track": 1.32, "ride_h": 0.19,
		"weight": 30.0,
		"speed_range": [9.0, 17.0],
		"body": [
			[0.00, 0.78, 0.32, 0.66],
			[0.04, 0.96, 0.24, 0.72],
			[0.14, 1.00, 0.20, 0.74],
			[0.28, 1.00, 0.20, 0.75],
			[0.50, 1.00, 0.20, 0.75],
			[0.72, 1.00, 0.20, 0.75],
			[0.90, 1.00, 0.20, 0.74],
			[0.97, 0.94, 0.26, 0.70],
			[1.00, 0.78, 0.32, 0.66],
		],
		"cabin": [
			[0.30, 0.88, 0.77],
			[0.36, 0.94, 1.06],
			[0.42, 0.96, 1.32],
			[0.66, 0.96, 1.34],
			[0.80, 0.94, 1.30],
			[0.86, 0.88, 1.00],
			[0.90, 0.80, 0.78],
		],
	},

	# --- Iran Khodro Samand ----------------------------------------------
	# Bigger, softer, notably tall and rounded greenhouse.
	"samand": {
		"name": "Samand",
		"name_fa": "سمند",
		"class": "car",
		"length": 4.50, "width": 1.73, "wheelbase": 2.67,
		"wheel_r": 0.31, "track": 1.47, "ride_h": 0.17,
		"weight": 32.0,
		"speed_range": [11.0, 21.0],
		"body": [
			[0.00, 0.74, 0.28, 0.60],
			[0.05, 0.94, 0.20, 0.70],
			[0.15, 1.00, 0.16, 0.76],
			[0.30, 1.00, 0.16, 0.78],
			[0.52, 1.00, 0.16, 0.78],
			[0.74, 1.00, 0.16, 0.78],
			[0.89, 0.99, 0.18, 0.76],
			[0.96, 0.90, 0.22, 0.70],
			[1.00, 0.72, 0.28, 0.60],
		],
		"cabin": [
			[0.24, 0.86, 0.80],
			[0.33, 0.93, 1.10],
			[0.44, 0.96, 1.38],
			[0.63, 0.96, 1.42],
			[0.79, 0.93, 1.34],
			[0.88, 0.85, 1.02],
			[0.93, 0.76, 0.80],
		],
	},

	# --- Samand Soren ----------------------------------------------------
	# Facelifted Samand: same shell, cleaner nose, lower stance, alloys.
	"soren": {
		"name": "Soren",
		"name_fa": "سورن",
		"class": "car",
		"length": 4.52, "width": 1.75, "wheelbase": 2.67,
		"wheel_r": 0.32, "track": 1.49, "ride_h": 0.15,
		"weight": 12.0,
		"speed_range": [12.0, 23.0],
		"body": [
			[0.00, 0.76, 0.26, 0.58],
			[0.05, 0.95, 0.18, 0.68],
			[0.15, 1.00, 0.15, 0.75],
			[0.30, 1.00, 0.15, 0.77],
			[0.52, 1.00, 0.15, 0.77],
			[0.74, 1.00, 0.15, 0.77],
			[0.89, 0.99, 0.17, 0.75],
			[0.96, 0.90, 0.21, 0.68],
			[1.00, 0.73, 0.26, 0.58],
		],
		"cabin": [
			[0.24, 0.87, 0.79],
			[0.33, 0.94, 1.08],
			[0.45, 0.96, 1.36],
			[0.64, 0.96, 1.39],
			[0.80, 0.93, 1.30],
			[0.89, 0.84, 1.00],
			[0.94, 0.75, 0.78],
		],
	},

	# --- Iran Khodro Runna -----------------------------------------------
	"runna": {
		"name": "Runna",
		"name_fa": "رانا",
		"class": "car",
		"length": 4.32, "width": 1.72, "wheelbase": 2.61,
		"wheel_r": 0.30, "track": 1.46, "ride_h": 0.16,
		"weight": 8.0,
		"speed_range": [12.0, 22.0],
		"body": [
			[0.00, 0.75, 0.27, 0.58],
			[0.05, 0.94, 0.19, 0.68],
			[0.16, 1.00, 0.16, 0.74],
			[0.32, 1.00, 0.16, 0.76],
			[0.54, 1.00, 0.16, 0.76],
			[0.76, 1.00, 0.16, 0.76],
			[0.90, 0.98, 0.18, 0.74],
			[0.96, 0.89, 0.22, 0.68],
			[1.00, 0.72, 0.27, 0.58],
		],
		"cabin": [
			[0.25, 0.86, 0.78],
			[0.34, 0.93, 1.06],
			[0.46, 0.96, 1.32],
			[0.64, 0.96, 1.34],
			[0.80, 0.92, 1.26],
			[0.88, 0.84, 0.98],
			[0.93, 0.75, 0.78],
		],
	},

	# --- Peugeot 405 -----------------------------------------------------
	# Still everywhere in Tehran. Long, low, wedge nose, flat tail.
	"peugeot405": {
		"name": "Peugeot 405",
		"name_fa": "پژو ۴۰۵",
		"class": "car",
		"length": 4.41, "width": 1.71, "wheelbase": 2.67,
		"wheel_r": 0.30, "track": 1.44, "ride_h": 0.16,
		"weight": 16.0,
		"speed_range": [11.0, 21.0],
		"body": [
			[0.00, 0.74, 0.24, 0.55],
			[0.05, 0.93, 0.18, 0.64],
			[0.16, 1.00, 0.16, 0.72],
			[0.32, 1.00, 0.16, 0.75],
			[0.54, 1.00, 0.16, 0.76],
			[0.76, 1.00, 0.16, 0.76],
			[0.90, 0.99, 0.18, 0.75],
			[0.97, 0.90, 0.22, 0.68],
			[1.00, 0.74, 0.26, 0.58],
		],
		"cabin": [
			[0.26, 0.86, 0.76],
			[0.35, 0.93, 1.02],
			[0.47, 0.96, 1.28],
			[0.66, 0.96, 1.30],
			[0.82, 0.93, 1.24],
			[0.90, 0.85, 0.96],
			[0.94, 0.76, 0.78],
		],
	},

	# --- Peugeot 206 hatchback -------------------------------------------
	# Short, round, dropped nose and a fast, steeply cut rear hatch.
	"peugeot206": {
		"name": "Peugeot 206",
		"name_fa": "پژو ۲۰۶",
		"class": "car",
		"length": 3.84, "width": 1.65, "wheelbase": 2.44,
		"wheel_r": 0.29, "track": 1.42, "ride_h": 0.15,
		"weight": 20.0,
		"speed_range": [12.0, 23.0],
		"body": [
			[0.00, 0.70, 0.22, 0.52],
			[0.05, 0.92, 0.16, 0.62],
			[0.17, 1.00, 0.14, 0.71],
			[0.34, 1.00, 0.14, 0.75],
			[0.56, 1.00, 0.14, 0.76],
			[0.78, 1.00, 0.15, 0.76],
			[0.92, 0.97, 0.17, 0.75],
			[0.98, 0.86, 0.22, 0.70],
			[1.00, 0.70, 0.26, 0.62],
		],
		# Hatch: roof carries far back then drops almost vertically.
		"cabin": [
			[0.24, 0.85, 0.74],
			[0.33, 0.92, 1.02],
			[0.46, 0.95, 1.30],
			[0.66, 0.95, 1.36],
			[0.83, 0.92, 1.32],
			[0.93, 0.86, 1.14],
			[0.98, 0.78, 0.80],
		],
	},

	# --- Peugeot Pars ----------------------------------------------------
	"pars": {
		"name": "Peugeot Pars",
		"name_fa": "پژو پارس",
		"class": "car",
		"length": 4.48, "width": 1.72, "wheelbase": 2.67,
		"wheel_r": 0.30, "track": 1.45, "ride_h": 0.16,
		"weight": 12.0,
		"speed_range": [11.0, 22.0],
		"body": [
			[0.00, 0.75, 0.25, 0.56],
			[0.05, 0.94, 0.18, 0.66],
			[0.16, 1.00, 0.16, 0.73],
			[0.32, 1.00, 0.16, 0.76],
			[0.54, 1.00, 0.16, 0.77],
			[0.76, 1.00, 0.16, 0.77],
			[0.90, 0.99, 0.18, 0.75],
			[0.97, 0.90, 0.22, 0.69],
			[1.00, 0.74, 0.26, 0.58],
		],
		"cabin": [
			[0.25, 0.86, 0.77],
			[0.34, 0.93, 1.04],
			[0.46, 0.96, 1.31],
			[0.65, 0.96, 1.34],
			[0.81, 0.93, 1.26],
			[0.89, 0.85, 0.98],
			[0.94, 0.76, 0.78],
		],
	},

	# --- Saipa Tiba ------------------------------------------------------
	"tiba": {
		"name": "Tiba",
		"name_fa": "تیبا",
		"class": "car",
		"length": 4.04, "width": 1.65, "wheelbase": 2.40,
		"wheel_r": 0.29, "track": 1.40, "ride_h": 0.18,
		"weight": 9.0,
		"speed_range": [10.0, 19.0],
		"body": [
			[0.00, 0.72, 0.28, 0.60],
			[0.05, 0.93, 0.20, 0.68],
			[0.16, 1.00, 0.17, 0.74],
			[0.32, 1.00, 0.17, 0.76],
			[0.54, 1.00, 0.17, 0.76],
			[0.76, 1.00, 0.17, 0.76],
			[0.90, 0.98, 0.19, 0.74],
			[0.97, 0.88, 0.23, 0.68],
			[1.00, 0.71, 0.28, 0.60],
		],
		"cabin": [
			[0.26, 0.86, 0.78],
			[0.35, 0.93, 1.08],
			[0.46, 0.95, 1.34],
			[0.64, 0.95, 1.36],
			[0.80, 0.92, 1.30],
			[0.88, 0.84, 1.02],
			[0.93, 0.76, 0.80],
		],
	},

	# --- Paykan Vanet (pickup) -------------------------------------------
	# Load bed, no rear greenhouse. Common on the right-hand lanes.
	"vanet": {
		"name": "Paykan Vanet",
		"name_fa": "وانت پیکان",
		"class": "utility",
		"length": 4.44, "width": 1.65, "wheelbase": 2.65,
		"wheel_r": 0.31, "track": 1.34, "ride_h": 0.24,
		"weight": 8.0,
		"speed_range": [9.0, 16.0],
		"body": [
			[0.00, 0.78, 0.34, 0.68],
			[0.04, 0.96, 0.26, 0.74],
			[0.14, 1.00, 0.22, 0.78],
			[0.30, 1.00, 0.22, 0.80],
			[0.48, 1.00, 0.22, 0.86],
			[0.72, 1.00, 0.22, 0.94],
			[0.94, 1.00, 0.22, 0.94],
			[1.00, 0.96, 0.26, 0.90],
		],
		# Cab only - stops at the bulkhead, leaving an open bed behind.
		"cabin": [
			[0.28, 0.88, 0.81],
			[0.34, 0.94, 1.10],
			[0.40, 0.96, 1.36],
			[0.52, 0.96, 1.38],
			[0.58, 0.94, 1.36],
		],
	},

	# --- City bus (BRT style) --------------------------------------------
	"bus": {
		"name": "City Bus",
		"name_fa": "اتوبوس",
		"class": "bus",
		"length": 11.50, "width": 2.50, "wheelbase": 5.80,
		"wheel_r": 0.50, "track": 2.10, "ride_h": 0.30,
		"weight": 3.5,
		"speed_range": [8.0, 14.0],
		"body": [
			[0.00, 0.92, 0.32, 2.90],
			[0.02, 0.99, 0.30, 3.00],
			[0.08, 1.00, 0.28, 3.05],
			[0.50, 1.00, 0.28, 3.05],
			[0.92, 1.00, 0.28, 3.05],
			[0.98, 0.99, 0.30, 3.00],
			[1.00, 0.92, 0.32, 2.90],
		],
		"cabin": [],
	},

	# --- Light truck ------------------------------------------------------
	"truck": {
		"name": "Light Truck",
		"name_fa": "کامیونت",
		"class": "truck",
		"length": 6.80, "width": 2.20, "wheelbase": 3.80,
		"wheel_r": 0.44, "track": 1.90, "ride_h": 0.32,
		"weight": 4.5,
		"speed_range": [8.0, 15.0],
		"body": [
			[0.00, 0.90, 0.36, 1.10],
			[0.04, 0.99, 0.34, 1.20],
			[0.10, 1.00, 0.32, 2.35],
			[0.28, 1.00, 0.32, 2.40],
			[0.34, 1.00, 0.34, 1.05],
			[0.40, 1.00, 0.90, 2.55],
			[0.94, 1.00, 0.90, 2.55],
			[1.00, 0.98, 0.90, 2.50],
		],
		"cabin": [],
	},

	# --- Minibus ----------------------------------------------------------
	"minibus": {
		"name": "Minibus",
		"name_fa": "مینی‌بوس",
		"class": "bus",
		"length": 6.60, "width": 2.10, "wheelbase": 3.40,
		"wheel_r": 0.40, "track": 1.80, "ride_h": 0.30,
		"weight": 4.0,
		"speed_range": [9.0, 15.0],
		"body": [
			[0.00, 0.90, 0.34, 2.20],
			[0.03, 0.99, 0.32, 2.30],
			[0.10, 1.00, 0.30, 2.35],
			[0.50, 1.00, 0.30, 2.35],
			[0.90, 1.00, 0.30, 2.35],
			[0.98, 0.98, 0.32, 2.28],
			[1.00, 0.90, 0.34, 2.20],
		],
		"cabin": [],
	},
}

## Which bodies can appear as taxis, and in which livery.
const TAXI_BODIES := ["peykan", "samand", "pars", "peugeot405", "soren"]

## Spawn weighting by lane discipline. Heavy vehicles hug the right-hand lanes,
## quick hatchbacks live in the fast lanes - this is what makes the traffic
## read as a real road rather than random noise.
const LANE_BIAS := {
	"car": [1.0, 1.0, 1.0, 1.0],
	"utility": [1.6, 1.2, 0.6, 0.2],
	"bus": [2.2, 1.0, 0.3, 0.05],
	"truck": [2.0, 1.1, 0.4, 0.1],
}


static func ids() -> Array:
	return VEHICLES.keys()


static func spec(id: String) -> Dictionary:
	return VEHICLES.get(id, VEHICLES["pride"])


static func has(id: String) -> bool:
	return VEHICLES.has(id)


## Weighted random body id, respecting how common each car is on the street.
static func random_id(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in VEHICLES:
		total += float(VEHICLES[id]["weight"])
	var pick := rng.randf() * total
	for id in VEHICLES:
		pick -= float(VEHICLES[id]["weight"])
		if pick <= 0.0:
			return id
	return "pride"


static func random_paint(rng: RandomNumberGenerator) -> Color:
	var total := 0.0
	for p in COMMON_PAINTS:
		total += float(p["weight"])
	var pick := rng.randf() * total
	for p in COMMON_PAINTS:
		pick -= float(p["weight"])
		if pick <= 0.0:
			var c: Color = p["color"]
			# Slight per-car variance so identical models aren't clones.
			return c.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.04)
	return Color.WHITE


static func lane_weight(vehicle_class: String, lane: int, lane_count: int) -> float:
	var bias: Array = LANE_BIAS.get(vehicle_class, LANE_BIAS["car"])
	if lane_count <= 1:
		return 1.0
	# Map the lane onto the 4-entry bias curve regardless of lane count.
	var t := float(lane) / float(lane_count - 1)
	var idx := clampi(int(round(t * (bias.size() - 1))), 0, bias.size() - 1)
	return float(bias[idx])
