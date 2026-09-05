class_name Hud
extends CanvasLayer

## Anzeige waehrend des Rennens: Tacho, Drehzahlbogen, Gang, Rundenzeiten.

const ACCENT := Color(1.0, 0.42, 0.68)
const DIM := Color(0.72, 0.76, 0.84)


## Drehzahlbogen. Wird als eigener Control gezeichnet, damit der Verlauf
## weich ist und die Begrenzerzone farblich abgesetzt werden kann.
class RevGauge extends Control:
	var rev: float = 0.0
	var redline: float = 0.86

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.62)
		var radius: float = minf(size.x, size.y) * 0.42
		var from := PI * 0.78
		var to := PI * 2.22
		draw_arc(center, radius, from, to, 96, Color(1, 1, 1, 0.10), 14.0, true)
		var red_from: float = lerpf(from, to, redline)
		draw_arc(center, radius, red_from, to, 32, Color(0.9, 0.15, 0.2, 0.35), 14.0, true)
		if rev > 0.005:
			var end: float = lerpf(from, to, clampf(rev, 0.0, 1.0))
			var col := Color(0.35, 0.85, 1.0) if rev < redline else Color(1.0, 0.25, 0.28)
			draw_arc(center, radius, from, end, 96, col, 14.0, true)
			var needle := center + Vector2(cos(end), sin(end)) * radius
			draw_line(center + Vector2(cos(end), sin(end)) * radius * 0.55, needle,
				Color(1, 1, 1, 0.9), 3.0, true)


var _speed_label: Label
var _gear_label: Label
var _car_label: Label
var _lap_label: Label
var _time_label: Label
var _best_label: Label
var _last_label: Label
var _message: Label
var _hint: Label
var _gauge: RevGauge
var _message_timer: float = 0.0
var _hint_timer: float = 9.0


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Tacho unten rechts -------------------------------------------------
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-330, -250)
	panel.size = Vector2(300, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	_gauge = RevGauge.new()
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_gauge)

	_speed_label = _make_label(panel, Vector2(0, 96), Vector2(300, 70), 62,
		Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var unit := _make_label(panel, Vector2(0, 158), Vector2(300, 26), 16, DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	unit.text = "km/h"
	_gear_label = _make_label(panel, Vector2(0, 44), Vector2(300, 46), 34, ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)

	# --- Zeiten oben links --------------------------------------------------
	var info := Control.new()
	info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info.position = Vector2(32, 26)
	info.size = Vector2(420, 190)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)

	_car_label = _make_label(info, Vector2(0, 0), Vector2(420, 34), 24, ACCENT)
	_lap_label = _make_label(info, Vector2(0, 38), Vector2(420, 30), 20, DIM)
	_time_label = _make_label(info, Vector2(0, 70), Vector2(420, 46), 38, Color.WHITE)
	_last_label = _make_label(info, Vector2(0, 120), Vector2(420, 26), 17, DIM)
	_best_label = _make_label(info, Vector2(0, 146), Vector2(420, 26), 17,
		Color(1.0, 0.85, 0.35))

	# --- Meldungen und Hilfe ------------------------------------------------
	_message = _make_label(root, Vector2(0, 0), Vector2(0, 0), 44, ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.position = Vector2(-400, 120)
	_message.size = Vector2(800, 60)
	_message.modulate.a = 0.0

	_hint = _make_label(root, Vector2(32, -60), Vector2(900, 30), 16, DIM)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(32, -56)
	_hint.text = "W/S Gas und Bremse   A/D Lenken   Leertaste Handbremse   " \
		+ "C Kamera   L Licht   R Zuruecksetzen   Esc Garage"


func _make_label(parent: Node, pos: Vector2, dimensions: Vector2, font_size: int,
		color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func set_car_name(car_name: String) -> void:
	_car_label.text = car_name


func show_message(text: String, seconds := 2.4) -> void:
	_message.text = text
	_message_timer = seconds


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.---"
	var minutes := int(seconds / 60.0)
	var rest := seconds - float(minutes) * 60.0
	return "%d:%06.3f" % [minutes, rest]


func update_readouts(car: Car, lap: int, laps_total: int, lap_time: float,
		last_time: float, best_time: float, off_track: bool) -> void:
	_speed_label.text = "%d" % int(round(absf(car.speed_kmh)))
	var gear_text := "%d" % car.gear
	if car.forward_speed < -0.8:
		gear_text = "R"
	elif absf(car.forward_speed) < 0.4 and car.throttle_input < 0.05:
		gear_text = "N"
	_gear_label.text = gear_text
	_gauge.rev = clampf(car.rpm / car.max_rpm, 0.0, 1.0)
	_gauge.queue_redraw()

	_lap_label.text = "Runde %d / %d" % [lap, laps_total]
	_time_label.text = format_time(lap_time)
	_last_label.text = "Letzte   " + format_time(last_time)
	_best_label.text = "Beste    " + format_time(best_time)
	_car_label.modulate = Color(1, 0.5, 0.35) if off_track else Color.WHITE


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		_message.modulate.a = clampf(_message_timer, 0.0, 1.0)
	elif _message.modulate.a > 0.0:
		_message.modulate.a = 0.0
	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 3.0, 0.0, 1.0)
