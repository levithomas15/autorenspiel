class_name Device
extends RefCounted

## Welches Geraet spielt gerade? Davon haengen zwei Dinge ab: wie aufwendig
## gerendert wird, und ob es Bedienelemente auf dem Bildschirm braucht.
##
## Die Auswahl trifft der Nutzer beim Start selbst. Automatische Erkennung
## waere unzuverlaessig - ein iPad meldet sich je nach Einstellung als Mac,
## und die Bildschirmgroesse allein sagt nichts ueber die Grafikleistung.
## `guess()` liefert nur die Vorauswahl.

enum Kind { PHONE, TABLET, DESKTOP }

const NAMES := {
	Kind.PHONE: "Handy",
	Kind.TABLET: "iPad",
	Kind.DESKTOP: "MacBook",
}

const HINTS := {
	Kind.PHONE: "Bedienung ueber den Bildschirm, sparsame Grafik",
	Kind.TABLET: "Bedienung ueber den Bildschirm, mittlere Grafik",
	Kind.DESKTOP: "Bedienung ueber die Tastatur, volle Grafik",
}

const _CONFIG_PATH := "user://einstellungen.cfg"

static var kind: int = Kind.DESKTOP


static func uses_touch() -> bool:
	return kind != Kind.DESKTOP


## Anteil der vollen Aufloesung, in der die 3D-Szene gerechnet wird. Das HUD
## bleibt davon unberuehrt und immer scharf.
static func render_scale() -> float:
	match kind:
		Kind.PHONE:
			return 0.6
		Kind.TABLET:
			return 0.75
		_:
			return 1.0


static func shadows_enabled() -> bool:
	return kind != Kind.PHONE


## Sichtweite der Sonnenschatten in Metern. Der mit Abstand teuerste Posten.
static func shadow_distance() -> float:
	match kind:
		Kind.TABLET:
			return 80.0
		Kind.DESKTOP:
			return 160.0
		_:
			return 0.0


static func shadow_atlas_size() -> int:
	match kind:
		Kind.TABLET:
			return 1024
		Kind.DESKTOP:
			return 2048
		_:
			return 512


## Baeume und Randbepflanzung sind reine Kulisse - auf dem Handy weniger davon.
static func scenery_density() -> float:
	match kind:
		Kind.PHONE:
			return 0.35
		Kind.TABLET:
			return 0.7
		_:
			return 1.0


static func apply_to(viewport: Viewport) -> void:
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale()
	viewport.msaa_3d = Viewport.MSAA_2X if kind == Kind.DESKTOP else Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size(), true)


## Vorauswahl auf dem Auswahlbildschirm. Bewusst nur ein Vorschlag.
static func guess() -> int:
	if OS.has_feature("web"):
		var size := DisplayServer.window_get_size()
		var shorter: int = mini(size.x, size.y)
		var longer: int = maxi(size.x, size.y)
		if longer < 900 or shorter < 500:
			return Kind.PHONE
		if longer < 1400:
			return Kind.TABLET
	return Kind.DESKTOP


static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("geraet", "art", kind)
	config.save(_CONFIG_PATH)


## Gibt zurueck, ob eine gespeicherte Auswahl gefunden wurde.
static func load_saved() -> bool:
	var config := ConfigFile.new()
	if config.load(_CONFIG_PATH) != OK:
		return false
	var stored: int = int(config.get_value("geraet", "art", Kind.DESKTOP))
	if stored < 0 or stored > Kind.DESKTOP:
		return false
	kind = stored
	return true
