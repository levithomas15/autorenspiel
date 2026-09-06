class_name Cheats
extends RefCounted

## Schalter aus dem Admin-Panel.
##
## Alles hier ist statisch und wird an genau einer Stelle gelesen: entweder in
## `main.gd` (Ablauf, Untergrund, Schwerkraft) oder in `car.gd` (Antrieb). So
## bleibt der normale Spielcode frei von Sonderfaellen.

enum Kind { AUTOPILOT, TURBO, MOON, SLOWMO, RAINBOW_ALL, NO_OFFTRACK }

const NAMES := {
	Kind.AUTOPILOT: "Autopilot",
	Kind.TURBO: "Dreifache Leistung",
	Kind.MOON: "Mondschwerkraft",
	Kind.SLOWMO: "Zeitlupe",
	Kind.RAINBOW_ALL: "Alles im Regenbogenlack",
	Kind.NO_OFFTRACK: "Voller Grip ueberall",
}

const HINTS := {
	Kind.AUTOPILOT: "Faehrt von allein die Ideallinie, so schnell es geht",
	Kind.TURBO: "Antriebskraft mal drei - auch fuer den Autopiloten",
	Kind.MOON: "Schwerkraft auf ein Sechstel, Spruenge werden weit",
	Kind.SLOWMO: "Alles laeuft auf 35 Prozent Tempo",
	Kind.RAINBOW_ALL: "Jedes Fahrzeug bekommt den Verlaufslack",
	Kind.NO_OFFTRACK: "Neben der Strecke haftet es wie auf Asphalt",
}

const ORDER := [Kind.AUTOPILOT, Kind.TURBO, Kind.MOON, Kind.SLOWMO,
	Kind.RAINBOW_ALL, Kind.NO_OFFTRACK]

const NORMAL_GRAVITY := 12.0
const MOON_GRAVITY := 2.0
const SLOWMO_SCALE := 0.35

static var _active: Dictionary = {}


static func is_on(kind: int) -> bool:
	return bool(_active.get(kind, false))


static func toggle(kind: int) -> void:
	_active[kind] = not is_on(kind)


static func any_on() -> bool:
	for kind: int in ORDER:
		if is_on(kind):
			return true
	return false


static func reset() -> void:
	_active.clear()


## Antriebskraft mal drei, wenn Turbo laeuft.
static func power_factor() -> float:
	return 3.0 if is_on(Kind.TURBO) else 1.0


## Schwerkraft und Zeitskala wirken global und muessen bei jeder Aenderung
## neu gesetzt werden - sie ueberleben sonst das Abschalten.
static func apply_world(tree: SceneTree) -> void:
	Engine.time_scale = SLOWMO_SCALE if is_on(Kind.SLOWMO) else 1.0
	var space := tree.root.get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY,
		MOON_GRAVITY if is_on(Kind.MOON) else NORMAL_GRAVITY)
