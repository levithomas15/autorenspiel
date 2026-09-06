class_name AdminPanel
extends CanvasLayer

## Verstecktes Admin-Panel. Geoeffnet wird es durch dreimaliges Tippen in die
## obere rechte Ecke; das erkennt `main.gd`, weil dort ohnehin alle Zustaende
## zusammenlaufen.
##
## Sechs Schalter, gezeichnet wie der Rest des Spiels ohne Bilddateien.
## Bedienbar per Finger, Maus und Tastatur.

signal closed

const ACCENT := Color(1.0, 0.42, 0.68)
const ON := Color(0.35, 0.90, 0.55)
const DIM := Color(0.70, 0.74, 0.82)

var _canvas: Control
var _cursor: int = 0
var _hover: int = -1


func _ready() -> void:
	layer = 40
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_panel)
	add_child(_canvas)


func _size() -> Vector2:
	return _canvas.size


func _unit() -> float:
	return minf(_size().x, _size().y)


func _sheet() -> Rect2:
	var s := _size()
	var w: float = minf(s.x * 0.86, _unit() * 1.45)
	var h: float = minf(s.y * 0.94, _unit() * 1.04)
	return Rect2(Vector2(s.x * 0.5 - w * 0.5, s.y * 0.5 - h * 0.5), Vector2(w, h))


func _row_rect(i: int) -> Rect2:
	var sheet := _sheet()
	var top: float = sheet.position.y + sheet.size.y * 0.205
	var h: float = sheet.size.y * 0.098
	var gap: float = sheet.size.y * 0.016
	return Rect2(Vector2(sheet.position.x + sheet.size.x * 0.05, top + float(i) * (h + gap)),
		Vector2(sheet.size.x * 0.90, h))


func _close_rect() -> Rect2:
	var sheet := _sheet()
	var w: float = sheet.size.x * 0.30
	return Rect2(Vector2(sheet.position.x + sheet.size.x * 0.5 - w * 0.5,
		sheet.position.y + sheet.size.y * 0.905), Vector2(w, sheet.size.y * 0.072))


# --- Eingabe -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
	elif event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		return
	if pos == Vector2.INF:
		return

	if _close_rect().has_point(pos):
		closed.emit()
		return
	for i in Cheats.ORDER.size():
		if _row_rect(i).has_point(pos):
			Cheats.toggle(Cheats.ORDER[i])
			Cheats.apply_world(get_tree())
			_canvas.queue_redraw()
			return
	# Ausserhalb des Blatts schliesst ebenfalls.
	if not _sheet().has_point(pos):
		closed.emit()


func _update_hover(pos: Vector2) -> void:
	var found := -1
	for i in Cheats.ORDER.size():
		if _row_rect(i).has_point(pos):
			found = i
	if found != _hover:
		_hover = found
		_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("back"):
		closed.emit()
	elif Input.is_action_just_pressed("select_right"):
		_cursor = posmod(_cursor + 1, Cheats.ORDER.size())
		_canvas.queue_redraw()
	elif Input.is_action_just_pressed("select_left"):
		_cursor = posmod(_cursor - 1, Cheats.ORDER.size())
		_canvas.queue_redraw()
	elif Input.is_action_just_pressed("accept"):
		Cheats.toggle(Cheats.ORDER[_cursor])
		Cheats.apply_world(get_tree())
		_canvas.queue_redraw()


# --- Darstellung -------------------------------------------------------------

func _draw_panel() -> void:
	var s := _size()
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.02, 0.03, 0.82), true)

	var sheet := _sheet()
	_canvas.draw_rect(sheet, Color(0.065, 0.070, 0.085, 0.98), true)
	_canvas.draw_rect(sheet, ACCENT, false, maxf(1.5, _unit() * 0.003))

	_text(Vector2(sheet.position.x + sheet.size.x * 0.5,
		sheet.position.y + sheet.size.y * 0.055), "ADMIN", ACCENT, 0.028, true)
	_text(Vector2(sheet.position.x + sheet.size.x * 0.5,
		sheet.position.y + sheet.size.y * 0.105), "Werkstatt", Color.WHITE, 0.046, true)

	for i in Cheats.ORDER.size():
		_draw_row(i)

	var close := _close_rect()
	_canvas.draw_rect(close, Color(0.11, 0.11, 0.14), true)
	_canvas.draw_rect(close, Color(0.45, 0.48, 0.55), false, maxf(1.0, _unit() * 0.002))
	_text(Vector2(close.position.x + close.size.x * 0.5,
		close.position.y + close.size.y * 0.30), "SCHLIESSEN", Color.WHITE, 0.028, true)


func _draw_row(i: int) -> void:
	var kind: int = Cheats.ORDER[i]
	var rect := _row_rect(i)
	var on: bool = Cheats.is_on(kind)
	var focused: bool = i == _cursor or i == _hover

	_canvas.draw_rect(rect, Color(0.10, 0.105, 0.13) if not focused
		else Color(0.145, 0.135, 0.165), true)
	_canvas.draw_rect(rect, ACCENT if focused else Color(0.22, 0.24, 0.29), false,
		maxf(1.0, _unit() * (0.0028 if focused else 0.0015)))

	_text(Vector2(rect.position.x + rect.size.x * 0.035,
		rect.position.y + rect.size.y * 0.13),
		Cheats.NAMES[kind], Color.WHITE if on else DIM, 0.031, false)
	_text(Vector2(rect.position.x + rect.size.x * 0.035,
		rect.position.y + rect.size.y * 0.58),
		Cheats.HINTS[kind], Color(0.56, 0.60, 0.68), 0.022, false)

	# Kippschalter rechts.
	var sw_h: float = rect.size.y * 0.40
	var sw_w: float = sw_h * 2.0
	var sw := Rect2(Vector2(rect.position.x + rect.size.x - sw_w - rect.size.y * 0.30,
		rect.position.y + rect.size.y * 0.5 - sw_h * 0.5), Vector2(sw_w, sw_h))
	var track_col: Color = ON if on else Color(0.24, 0.25, 0.30)
	_canvas.draw_rect(sw, track_col, true)
	var knob_r: float = sw_h * 0.38
	var knob_x: float = sw.position.x + (sw_w - knob_r - sw_h * 0.12 if on
		else knob_r + sw_h * 0.12)
	_canvas.draw_circle(Vector2(knob_x, sw.position.y + sw_h * 0.5), knob_r,
		Color(0.97, 0.98, 1.0))


func _text(anchor: Vector2, text: String, color: Color, scale: float,
		centered: bool) -> void:
	var font := ThemeDB.fallback_font
	var size := int(_unit() * scale)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(anchor.x - (width * 0.5 if centered else 0.0),
		anchor.y + float(size) * 0.85)
	_canvas.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, Color(0, 0, 0, 0.7))
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
