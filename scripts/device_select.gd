class_name DeviceSelect
extends CanvasLayer

## Erster Bildschirm: Womit wird gespielt?
##
## Die Wahl bestimmt zweierlei - wie aufwendig gerendert wird und ob es
## Lenkrad und Pedale auf dem Bildschirm gibt. Sie laesst sich spaeter in der
## Garage jederzeit aendern.

signal chosen(kind: int)

const ACCENT := Color(1.0, 0.42, 0.68)
const DIM := Color(0.72, 0.76, 0.84)

var _selected: int = Device.Kind.DESKTOP
var _canvas: Control
var _hover: int = -1


func _ready() -> void:
	layer = 30
	_selected = Device.guess()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)


func _size() -> Vector2:
	return _canvas.size


func _unit() -> float:
	return minf(_size().x, _size().y)


## Die drei Karten liegen nebeneinander, auf schmalen Bildschirmen untereinander.
func _card_rect(kind: int) -> Rect2:
	var s := _size()
	var stacked: bool = s.x < s.y * 1.25
	if stacked:
		var w: float = minf(s.x * 0.82, _unit() * 1.15)
		var h: float = _unit() * 0.16
		var gap: float = _unit() * 0.045
		var total: float = h * 3.0 + gap * 2.0
		var top: float = s.y * 0.52 - total * 0.5
		return Rect2(Vector2(s.x * 0.5 - w * 0.5, top + float(kind) * (h + gap)),
			Vector2(w, h))
	var cw: float = minf(s.x * 0.26, _unit() * 0.42)
	var ch: float = _unit() * 0.42
	var cgap: float = _unit() * 0.05
	var whole: float = cw * 3.0 + cgap * 2.0
	var left: float = s.x * 0.5 - whole * 0.5
	return Rect2(Vector2(left + float(kind) * (cw + cgap), s.y * 0.54 - ch * 0.5),
		Vector2(cw, ch))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_activate_at((event as InputEventScreenTouch).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_activate_at(mb.position)
	elif event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		var found := -1
		for kind in [Device.Kind.PHONE, Device.Kind.TABLET, Device.Kind.DESKTOP]:
			if _card_rect(kind).has_point(pos):
				found = kind
		if found != _hover:
			_hover = found
			_canvas.queue_redraw()


func _activate_at(pos: Vector2) -> void:
	for kind in [Device.Kind.PHONE, Device.Kind.TABLET, Device.Kind.DESKTOP]:
		if _card_rect(kind).has_point(pos):
			_choose(kind)
			return


func _process(_delta: float) -> void:
	# Mit Tastatur bedienbar, damit am MacBook niemand zur Maus greifen muss.
	if Input.is_action_just_pressed("select_right"):
		_selected = posmod(_selected + 1, 3)
		_canvas.queue_redraw()
	elif Input.is_action_just_pressed("select_left"):
		_selected = posmod(_selected - 1, 3)
		_canvas.queue_redraw()
	elif Input.is_action_just_pressed("accept"):
		_choose(_selected)


func _choose(kind: int) -> void:
	Device.kind = kind
	Device.save()
	chosen.emit(kind)


# --- Darstellung -------------------------------------------------------------

func _draw_screen() -> void:
	var s := _size()
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.035, 0.038, 0.048), true)

	_text(Vector2(s.x * 0.5, s.y * 0.12), "AUTORENNSPIEL", DIM, 0.028, true)
	_text(Vector2(s.x * 0.5, s.y * 0.19), "Womit spielst du?", Color.WHITE, 0.062, true)
	_text(Vector2(s.x * 0.5, s.y * 0.30),
		"Das bestimmt die Steuerung und wie aufwendig gerechnet wird.",
		DIM, 0.026, true)

	for kind in [Device.Kind.PHONE, Device.Kind.TABLET, Device.Kind.DESKTOP]:
		_draw_card(kind)

	_text(Vector2(s.x * 0.5, s.y * 0.93),
		"Antippen, oder mit A und D waehlen und mit Enter bestaetigen.",
		Color(0.55, 0.58, 0.66), 0.024, true)


func _draw_card(kind: int) -> void:
	var rect := _card_rect(kind)
	var active: bool = kind == _selected or kind == _hover
	var fill := Color(0.075, 0.080, 0.098) if not active else Color(0.11, 0.10, 0.13)
	_canvas.draw_rect(rect, fill, true)
	_canvas.draw_rect(rect, ACCENT if active else Color(0.24, 0.26, 0.31), false,
		maxf(1.5, _unit() * (0.004 if active else 0.002)))

	var icon_center := Vector2(rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y * 0.36)
	_draw_icon(kind, icon_center, _unit() * 0.085, ACCENT if active else DIM)

	_text(Vector2(rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y * 0.62),
		Device.NAMES[kind], Color.WHITE, 0.042, true)
	_wrapped(Vector2(rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y * 0.76),
		Device.HINTS[kind], DIM, 0.024, rect.size.x * 0.86)


## Die drei Umrisse werden gezeichnet, nicht geladen - wie alles hier.
func _draw_icon(kind: int, c: Vector2, size: float, col: Color) -> void:
	var w: float
	var h: float
	match kind:
		Device.Kind.PHONE:
			w = size * 0.46
			h = size * 0.92
		Device.Kind.TABLET:
			w = size * 0.74
			h = size * 0.98
		_:
			w = size * 1.30
			h = size * 0.80
	var body := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var thickness: float = maxf(1.5, size * 0.045)

	if kind == Device.Kind.DESKTOP:
		# Deckel und darunter die Tastatur samt Standfuss.
		var lid := Rect2(body.position, Vector2(w, h * 0.78))
		_canvas.draw_rect(lid, col, false, thickness)
		_canvas.draw_rect(lid.grow(-thickness * 2.0), Color(col, 0.16), true)
		var base_y := body.position.y + h * 0.86
		_canvas.draw_line(Vector2(body.position.x - w * 0.10, base_y),
			Vector2(body.position.x + w * 1.10, base_y), col, thickness * 1.4)
	else:
		_canvas.draw_rect(body, col, false, thickness)
		_canvas.draw_rect(body.grow(-thickness * 2.0), Color(col, 0.16), true)
		# Sprechmuschel beim Handy, Knopf beim Tablet.
		if kind == Device.Kind.PHONE:
			_canvas.draw_line(Vector2(c.x - w * 0.18, body.position.y + h * 0.075),
				Vector2(c.x + w * 0.18, body.position.y + h * 0.075), col, thickness)
		else:
			_canvas.draw_arc(Vector2(c.x, body.position.y + h * 0.925), w * 0.10,
				0.0, TAU, 20, col, thickness, true)


func _text(center: Vector2, text: String, color: Color, scale: float,
		centered: bool) -> void:
	var font := ThemeDB.fallback_font
	var size := int(_unit() * scale)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - (width * 0.5 if centered else 0.0), center.y)
	_canvas.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, Color(0, 0, 0, 0.65))
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Bricht den Hinweistext um, falls die Karte schmal ist.
func _wrapped(center: Vector2, text: String, color: Color, scale: float,
		max_width: float) -> void:
	var font := ThemeDB.fallback_font
	var size := int(_unit() * scale)
	var words := text.split(" ")
	var lines: Array[String] = []
	var current := ""
	for word in words:
		var probe: String = word if current.is_empty() else current + " " + word
		if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width \
				and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = probe
	if not current.is_empty():
		lines.append(current)
	for i in lines.size():
		_text(Vector2(center.x, center.y + float(i) * float(size) * 1.25),
			lines[i], color, scale, true)
