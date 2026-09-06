class_name CarData
extends RefCounted

## Definition der vier Fahrzeuge.
##
## "body" beschreibt die Karosserie als Folge von Querschnitten:
##   [t, halbe_breite, y_unten, y_oben, exponent_oben, exponent_unten]
## t laeuft von 0 (Front) bis 1 (Heck) und wird spaeter auf die Fahrzeuglaenge
## abgebildet. Die Exponenten steuern die Form des Querschnitts: 2 ergibt eine
## Ellipse, grosse Werte einen fast rechteckigen Schnitt (flacher Unterboden).

## Anzeigename des rosa Wagens. Die Karosserie ist eine eigenstaendige Hommage,
## keine lizenzierte Vorlage - wer den Markennamen nicht moechte, aendert nur
## diese eine Zeile.
const PINK_CAR_NAME := "911 GT3 RS Rosa"


static func all() -> Array:
	return [hornet_gt(), vanta_s(), aurora_ev(), pink_gt3_rs(), prisma_rainbow()]


static func hornet_gt() -> Dictionary:
	return {
		"name": "Hornet GT",
		"subtitle": "Mittelmotor - ausgewogen",
		"paint": Color(0.95, 0.34, 0.04),
		"accent": Color(0.08, 0.08, 0.09),
		"rim_color": Color(0.16, 0.16, 0.18),
		"glass_tint": Color(0.04, 0.05, 0.06),
		"length": 4.42,
		"body": [
			[0.00, 0.30, 0.34, 0.48, 3.0, 4.0],
			[0.04, 0.66, 0.20, 0.58, 3.0, 5.0],
			[0.11, 0.86, 0.14, 0.66, 3.2, 6.5],
			[0.19, 0.94, 0.12, 0.74, 3.2, 8.0],
			[0.28, 0.92, 0.11, 0.84, 2.8, 8.0],
			[0.36, 0.90, 0.11, 1.02, 2.5, 8.0],
			[0.45, 0.88, 0.11, 1.16, 2.3, 8.0],
			[0.53, 0.88, 0.12, 1.18, 2.3, 8.0],
			[0.62, 0.91, 0.12, 1.12, 2.5, 8.0],
			[0.71, 0.95, 0.13, 1.00, 2.8, 8.0],
			[0.80, 0.98, 0.14, 0.92, 3.0, 7.0],
			[0.89, 0.96, 0.16, 0.88, 3.0, 6.0],
			[0.96, 0.88, 0.22, 0.84, 3.2, 5.0],
			[1.00, 0.56, 0.32, 0.76, 3.4, 4.0],
		],
		"cabin": [0.33, 0.70],
		"front_axle_z": -1.28,
		"rear_axle_z": 1.26,
		"track_half": 0.80,
		"wheel_radius_front": 0.335,
		"wheel_radius_rear": 0.345,
		"tire_width_front": 0.25,
		"tire_width_rear": 0.30,
		"rim_style": "double",
		"rim_spokes": 5,
		"wing": "ducktail",
		"headlight": "slim",
		"exhaust": "twin_center",
		"mass": 1290.0,
		"power": 2350.0,
		"top_speed": 88.0,
		"brake_force": 78.0,
		"steer_max": 0.44,
		"drive": "rwd",
		"downforce": 6.5,
		"gears": 7,
	}


static func vanta_s() -> Dictionary:
	return {
		"name": "Vanta S",
		"subtitle": "Frontmotor-GT - viel Drehmoment",
		"paint": Color(0.055, 0.058, 0.07),
		"accent": Color(0.72, 0.14, 0.12),
		"rim_color": Color(0.30, 0.31, 0.34),
		"glass_tint": Color(0.03, 0.03, 0.04),
		"length": 4.86,
		"body": [
			[0.00, 0.32, 0.36, 0.56, 3.0, 4.0],
			[0.04, 0.68, 0.24, 0.66, 3.0, 5.0],
			[0.11, 0.88, 0.18, 0.74, 3.2, 6.5],
			[0.20, 0.95, 0.15, 0.80, 3.4, 8.0],
			[0.30, 0.94, 0.14, 0.84, 3.2, 8.0],
			[0.40, 0.92, 0.14, 0.90, 3.0, 8.0],
			[0.48, 0.90, 0.14, 1.10, 2.6, 8.0],
			[0.57, 0.89, 0.14, 1.28, 2.4, 8.0],
			[0.66, 0.90, 0.15, 1.26, 2.4, 8.0],
			[0.75, 0.94, 0.15, 1.10, 2.7, 8.0],
			[0.84, 0.99, 0.16, 0.96, 3.0, 7.0],
			[0.92, 0.96, 0.19, 0.90, 3.0, 6.0],
			[0.97, 0.88, 0.25, 0.86, 3.2, 5.0],
			[1.00, 0.58, 0.34, 0.80, 3.4, 4.0],
		],
		"cabin": [0.45, 0.78],
		"front_axle_z": -1.44,
		"rear_axle_z": 1.42,
		"track_half": 0.82,
		"wheel_radius_front": 0.355,
		"wheel_radius_rear": 0.365,
		"tire_width_front": 0.27,
		"tire_width_rear": 0.33,
		"rim_style": "turbo",
		"rim_spokes": 10,
		"wing": "lip",
		"headlight": "slim",
		"exhaust": "quad",
		"mass": 1610.0,
		"power": 2750.0,
		"top_speed": 92.0,
		"brake_force": 82.0,
		"steer_max": 0.40,
		"drive": "rwd",
		"downforce": 5.0,
		"gears": 8,
	}


static func aurora_ev() -> Dictionary:
	return {
		"name": "Aurora EV",
		"subtitle": "Allrad-Elektro - sofortiger Schub",
		"paint": Color(0.05, 0.32, 0.85),
		"accent": Color(0.55, 0.85, 1.0),
		"rim_color": Color(0.78, 0.80, 0.84),
		"glass_tint": Color(0.03, 0.05, 0.08),
		"length": 4.68,
		"body": [
			[0.00, 0.32, 0.30, 0.46, 3.0, 4.0],
			[0.04, 0.68, 0.18, 0.54, 3.0, 5.0],
			[0.11, 0.88, 0.13, 0.62, 3.2, 7.0],
			[0.19, 0.96, 0.11, 0.70, 3.4, 8.0],
			[0.28, 0.95, 0.10, 0.82, 2.8, 8.0],
			[0.37, 0.93, 0.10, 1.00, 2.4, 8.0],
			[0.46, 0.91, 0.10, 1.14, 2.2, 8.0],
			[0.55, 0.91, 0.11, 1.16, 2.2, 8.0],
			[0.64, 0.93, 0.11, 1.10, 2.4, 8.0],
			[0.73, 0.96, 0.12, 0.98, 2.7, 8.0],
			[0.82, 0.99, 0.13, 0.88, 3.0, 7.0],
			[0.90, 0.97, 0.16, 0.84, 3.0, 6.0],
			[0.96, 0.89, 0.22, 0.80, 3.2, 5.0],
			[1.00, 0.58, 0.30, 0.72, 3.4, 4.0],
		],
		"cabin": [0.32, 0.72],
		"front_axle_z": -1.42,
		"rear_axle_z": 1.40,
		"track_half": 0.82,
		"wheel_radius_front": 0.355,
		"wheel_radius_rear": 0.355,
		"tire_width_front": 0.27,
		"tire_width_rear": 0.30,
		"rim_style": "aero",
		"rim_spokes": 12,
		"wing": "active",
		"headlight": "slim",
		"exhaust": "none",
		"mass": 1720.0,
		"power": 3400.0,
		"top_speed": 86.0,
		"brake_force": 88.0,
		"steer_max": 0.42,
		"drive": "awd",
		"downforce": 6.0,
		"gears": 2,
	}


## Rosa-Metallic, Heckmotor, grosser Heckfluegel.
static func pink_gt3_rs() -> Dictionary:
	return {
		"name": PINK_CAR_NAME,
		"subtitle": "Heckmotor - Saugmotor bis 9000 U/min",
		"paint": Color(0.98, 0.42, 0.68),
		"accent": Color(0.06, 0.06, 0.07),
		"rim_color": Color(0.92, 0.55, 0.74),
		"glass_tint": Color(0.03, 0.035, 0.045),
		"length": 4.57,
		"body": [
			[0.00, 0.30, 0.40, 0.54, 3.0, 4.0],
			[0.03, 0.62, 0.27, 0.65, 3.0, 5.0],
			[0.09, 0.82, 0.20, 0.72, 3.2, 6.5],
			[0.17, 0.90, 0.16, 0.79, 3.2, 7.5],
			[0.26, 0.885, 0.15, 0.81, 3.0, 8.0],
			[0.34, 0.87, 0.14, 0.89, 2.9, 8.0],
			[0.42, 0.855, 0.14, 1.10, 2.6, 8.0],
			[0.50, 0.845, 0.14, 1.27, 2.4, 8.0],
			[0.58, 0.855, 0.14, 1.28, 2.4, 8.0],
			[0.66, 0.885, 0.15, 1.20, 2.6, 8.0],
			[0.74, 0.925, 0.16, 1.06, 2.8, 8.0],
			[0.82, 0.95, 0.17, 0.96, 3.0, 7.0],
			[0.90, 0.935, 0.20, 0.91, 3.0, 6.0],
			[0.96, 0.86, 0.26, 0.87, 3.2, 5.0],
			[1.00, 0.55, 0.36, 0.79, 3.4, 4.0],
		],
		"cabin": [0.34, 0.72],
		"front_axle_z": -1.30,
		"rear_axle_z": 1.27,
		"track_half": 0.79,
		"wheel_radius_front": 0.345,
		"wheel_radius_rear": 0.365,
		"tire_width_front": 0.27,
		"tire_width_rear": 0.34,
		"rim_style": "double",
		"rim_spokes": 5,
		"wing": "gt",
		"headlight": "round",
		"exhaust": "twin_center",
		"mass": 1450.0,
		"power": 2600.0,
		"top_speed": 90.0,
		"brake_force": 90.0,
		"steer_max": 0.45,
		"drive": "rwd",
		"downforce": 9.5,
		"gears": 7,
	}


## Regenbogen-Prototyp. Hoechstgeschwindigkeit 500 km/h, und er beschleunigt
## dreimal so kraeftig wie der bis dahin schnellste Wagen (Aurora EV).
##
## Der Vergleich laeuft ueber Leistung je Masse, denn genau die bestimmt die
## Beschleunigung: Aurora kommt auf 3400 / 1720 = 1.98, dieser hier auf
## 7000 / 1180 = 5.93 - also exakt das Dreifache. Damit die Kraft nicht nur
## die Raeder durchdrehen laesst, braucht er deutlich mehr Griff und Allrad.
static func prisma_rainbow() -> Dictionary:
	return {
		"name": "Prisma R",
		"subtitle": "Regenbogen - dreifache Beschleunigung, 500 km/h",
		"paint": Color(0.9, 0.9, 0.9),
		"paint_style": "rainbow",
		"accent": Color(0.05, 0.05, 0.06),
		"rim_color": Color(0.86, 0.86, 0.92),
		"glass_tint": Color(0.03, 0.03, 0.05),
		"length": 4.72,
		# Flacher und breiter als alles andere im Feld.
		"body": [
			[0.00, 0.34, 0.20, 0.34, 3.4, 4.0],
			[0.03, 0.70, 0.13, 0.44, 3.2, 5.0],
			[0.09, 0.92, 0.10, 0.52, 3.4, 7.0],
			[0.17, 1.02, 0.09, 0.60, 3.4, 8.0],
			[0.26, 1.03, 0.09, 0.66, 3.0, 8.0],
			[0.34, 1.02, 0.09, 0.80, 2.8, 8.0],
			[0.42, 1.00, 0.09, 0.97, 2.5, 8.0],
			[0.50, 0.99, 0.10, 1.06, 2.4, 8.0],
			[0.58, 1.00, 0.10, 1.07, 2.4, 8.0],
			[0.66, 1.02, 0.11, 1.00, 2.6, 8.0],
			[0.74, 1.05, 0.11, 0.90, 2.8, 8.0],
			[0.82, 1.06, 0.12, 0.82, 3.0, 7.0],
			[0.90, 1.03, 0.14, 0.78, 3.0, 6.0],
			[0.96, 0.93, 0.19, 0.74, 3.2, 5.0],
			[1.00, 0.58, 0.27, 0.66, 3.4, 4.0],
		],
		"cabin": [0.33, 0.71],
		"front_axle_z": -1.42,
		"rear_axle_z": 1.40,
		"track_half": 0.90,
		"wheel_radius_front": 0.350,
		"wheel_radius_rear": 0.375,
		"tire_width_front": 0.30,
		"tire_width_rear": 0.38,
		"rim_style": "double",
		"rim_spokes": 7,
		"wing": "active",
		"headlight": "slim",
		"exhaust": "none",
		"mass": 1180.0,
		"power": 8100.0,
		"grip": 6.6,
		"top_speed": 138.9,
		"brake_force": 125.0,
		"steer_max": 0.40,
		"drive": "awd",
		"downforce": 10.0,
		"gears": 2,
	}
