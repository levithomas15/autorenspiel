class_name TouchControls
extends CanvasLayer

## Lenkrad und Pedale fuer Geraete ohne Tastatur.
##
## Beides ist stufenlos: das Lenkrad gibt den Einschlag aus seinem Drehwinkel,
## die Pedale aus ihrem Weg. Ueber `Input.action_press(aktion, staerke)`
## landen die Werte in denselben Actions, die auch die Tastatur bedient -
## `car.gd` merkt keinen Unterschied.
##
## Gezeichnet wird alles in `_draw()`, wie der Rest des Projekts ohne eine
## einzige Bilddatei.

signal garage_requested
signal camera_requested

## Maximaler Drehwinkel des Lenkrads. Darueber hinaus laesst es sich nicht
## weiterdrehen - so bleibt der Einschlag gut dosierbar.
const WHEEL_MAX := deg_to_rad(135.0)

## Wie schnell das Lenkrad zurueck in die Mitte laeuft, wenn losgelassen wird.
const RETURN_SPEED := 7.0

const ACCENT := Color(1.0, 0.42, 0.68)
const GAS := Color(0.35, 0.85, 1.0)
const BRAKE := Color(1.0, 0.32, 0.34)

enum Zone { NONE, WHEEL, GAS, BRAKE, HANDBRAKE, CAMERA, GARAGE }

## true = Rennansicht mit Lenkrad und Pedalen, false = Garage mit Pfeilen.
var racing: bool = true:
	set(value):
		racing = value
		if _canvas != null:
			_canvas.queue_redraw()

var _canvas: Control
var _wheel_angle: float = 0.0
var _throttle: float = 0.0
var _brake: float = 0.0
var _handbrake: bool = false

## Welcher Finger bedient gerade was. Der Schluessel ist der Finger-Index,
## damit Lenken und Gasgeben gleichzeitig funktionieren.
var _fingers: Dictionary = {}
var _wheel_grab_offset: float = 0.0

# Garage
var _garage_pulse: float = 0.0


func _ready() -> void:
	layer = 15
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)


# --- Geometrie ---------------------------------------------------------------
# Alle Masse haengen an der kuerzeren Bildschirmseite, damit die Bedienung auf
# einem Handy im Querformat genauso passt wie auf einem iPad.

func _size() -> Vector2:
	return _canvas.size if _canvas != null else Vector2(1920, 1080)


func _unit() -> float:
	return minf(_size().x, _size().y)


func _wheel_center() -> Vector2:
	var s := _size()
	return Vector2(_unit() * 0.235, s.y - _unit() * 0.185)


func _wheel_radius() -> float:
	return _unit() * 0.165


## Die Wegbalken liegen jeweils links neben ihrem Pedal - so bleibt alles
## innerhalb des Bildes, auch am rechten Rand.
func _bar_width() -> float:
	return _unit() * 0.013


func _pedal_rect(gas: bool) -> Rect2:
	var s := _size()
	var w := _unit() * 0.095
	var h := _unit() * 0.30
	var y := s.y - h - _unit() * 0.055
	var right := s.x - _unit() * 0.045 - w
	if gas:
		return Rect2(Vector2(right, y), Vector2(w, h))
	var gap := w + _bar_width() + _unit() * 0.045
	return Rect2(Vector2(right - gap, y), Vector2(w, h))


func _handbrake_rect() -> Rect2:
	var s := _size()
	var w := _unit() * 0.150
	return Rect2(Vector2(s.x * 0.5 - _unit() * 0.30 - w * 0.5, s.y - _unit() * 0.085),
		Vector2(w, _unit() * 0.062))


## Oben in der Mitte - links steht die Rundenanzeige, rechts der Tacho.
func _small_button_rect(slot: int) -> Rect2:
	var s := _size()
	var w := _unit() * 0.115
	var h := _unit() * 0.068
	var gap := _unit() * 0.018
	var count := 2.0 if racing else 1.0
	var total := w * count + gap * (count - 1.0)
	var left := s.x * 0.5 - total * 0.5
	return Rect2(Vector2(left + float(slot) * (w + gap), _unit() * 0.035), Vector2(w, h))


func _arrow_rect(right: bool) -> Rect2:
	var s := _size()
	var w := _unit() * 0.17
	var h := _unit() * 0.17
	var y := s.y - h - _unit() * 0.08
	return Rect2(Vector2(s.x * 0.5 + (_unit() * 0.28 if right else -_unit() * 0.28 - w), y),
		Vector2(w, h))


func _start_rect() -> Rect2:
	var s := _size()
	var w := _unit() * 0.34
	var h := _unit() * 0.13
	return Rect2(Vector2(s.x * 0.5 - w * 0.5, s.y - h - _unit() * 0.10), Vector2(w, h))


# --- Eingabe -----------------------------------------------------------------

func _zone_at(pos: Vector2) -> int:
	if racing:
		if pos.distance_to(_wheel_center()) <= _wheel_radius() * 1.25:
			return Zone.WHEEL
		if _pedal_rect(true).has_point(pos):
			return Zone.GAS
		if _pedal_rect(false).has_point(pos):
			return Zone.BRAKE
		if _handbrake_rect().grow(_unit() * 0.02).has_point(pos):
			return Zone.HANDBRAKE
	if _small_button_rect(0).grow(_unit() * 0.015).has_point(pos):
		return Zone.GARAGE
	if racing and _small_button_rect(1).grow(_unit() * 0.015).has_point(pos):
		return Zone.CAMERA
	return Zone.NONE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position)
	elif event is InputEventMouseButton:
		# Damit sich die Bedienung auch mit der Maus pruefen laesst.
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(-1, mb.position)
			else:
				_release(-1)
	elif event is InputEventMouseMotion:
		if _fingers.has(-1):
			_move(-1, (event as InputEventMouseMotion).position)


func _press(index: int, pos: Vector2) -> void:
	var zone := _zone_at(pos)
	if zone == Zone.NONE:
		if not racing:
			_press_garage(pos)
		return
	_fingers[index] = zone
	match zone:
		Zone.WHEEL:
			_wheel_grab_offset = _angle_to(pos) - _wheel_angle
		Zone.GAS:
			_throttle = _pedal_travel(pos, true)
		Zone.BRAKE:
			_brake = _pedal_travel(pos, false)
		Zone.HANDBRAKE:
			_handbrake = true
		Zone.CAMERA:
			camera_requested.emit()
		Zone.GARAGE:
			garage_requested.emit()
	_canvas.queue_redraw()


func _move(index: int, pos: Vector2) -> void:
	if not _fingers.has(index):
		return
	match int(_fingers[index]):
		Zone.WHEEL:
			_wheel_angle = clampf(_angle_to(pos) - _wheel_grab_offset,
				-WHEEL_MAX, WHEEL_MAX)
		Zone.GAS:
			_throttle = _pedal_travel(pos, true)
		Zone.BRAKE:
			_brake = _pedal_travel(pos, false)
	_canvas.queue_redraw()


func _release(index: int) -> void:
	if not _fingers.has(index):
		return
	match int(_fingers[index]):
		Zone.GAS:
			_throttle = 0.0
		Zone.BRAKE:
			_brake = 0.0
		Zone.HANDBRAKE:
			_handbrake = false
	_fingers.erase(index)
	_canvas.queue_redraw()


func _angle_to(pos: Vector2) -> float:
	var d := pos - _wheel_center()
	return atan2(d.x, -d.y)


## Wie weit ist das Pedal durchgetreten? Weiter unten heisst weiter durch -
## wie bei einem echten Pedal, das sich um seinen oberen Punkt dreht.
func _pedal_travel(pos: Vector2, gas: bool) -> float:
	var rect := _pedal_rect(gas)
	var t: float = (pos.y - rect.position.y) / rect.size.y
	# Wer das Pedal ueberhaupt trifft, meint mindestens ein Viertel Gas.
	return clampf(0.25 + t * 0.85, 0.0, 1.0)


# --- Weitergabe an die Actions ----------------------------------------------

func _process(delta: float) -> void:
	if not racing:
		_garage_pulse += delta
		_canvas.queue_redraw()
		return

	# Lenkrad laeuft zurueck in die Mitte, solange niemand es haelt.
	if not _fingers.values().has(Zone.WHEEL) and absf(_wheel_angle) > 0.001:
		_wheel_angle = move_toward(_wheel_angle, 0.0, RETURN_SPEED * WHEEL_MAX * delta)
		_canvas.queue_redraw()

	var steer: float = _wheel_angle / WHEEL_MAX
	_set_action("steer_left", maxf(-steer, 0.0))
	_set_action("steer_right", maxf(steer, 0.0))
	_set_action("throttle", _throttle)
	_set_action("brake", _brake)
	_set_action("handbrake", 1.0 if _handbrake else 0.0)


func _set_action(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func release_all() -> void:
	for action in ["steer_left", "steer_right", "throttle", "brake", "handbrake"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _exit_tree() -> void:
	release_all()


# --- Garage ------------------------------------------------------------------

func _press_garage(pos: Vector2) -> void:
	if _start_rect().has_point(pos):
		Input.action_press("accept")
		await get_tree().process_frame
		Input.action_release("accept")
	elif _arrow_rect(true).has_point(pos):
		Input.action_press("select_right")
		await get_tree().process_frame
		Input.action_release("select_right")
	elif _arrow_rect(false).has_point(pos):
		Input.action_press("select_left")
		await get_tree().process_frame
		Input.action_release("select_left")


# --- Darstellung -------------------------------------------------------------

func _draw_controls() -> void:
	if racing:
		_draw_wheel()
		_draw_pedal(true)
		_draw_pedal(false)
		_draw_handbrake()
		_draw_small_button(1, "KAMERA")
	else:
		_draw_arrow(false)
		_draw_arrow(true)
		_draw_start()
	_draw_small_button(0, "GARAGE" if racing else "GERAET")


func _draw_wheel() -> void:
	var c := _wheel_center()
	var r := _wheel_radius()
	var held: bool = _fingers.values().has(Zone.WHEEL)
	# Halbdurchsichtig, damit die Strecke dahinter sichtbar bleibt. Beim
	# Anfassen wird es etwas deutlicher.
	var alpha: float = 0.80 if held else 0.55

	# Schattierter Ring: mehrere Boegen mit leicht versetzter Helligkeit
	# ergeben den Eindruck eines runden, angefassten Kranzes.
	var rim := r * 0.19
	_canvas.draw_arc(c, r, 0.0, TAU, 96, Color(0.06, 0.07, 0.09, alpha * 0.75), rim * 1.5, true)
	_canvas.draw_arc(c, r, 0.0, TAU, 96, Color(0.20, 0.21, 0.25, alpha), rim, true)
	_canvas.draw_arc(c, r - rim * 0.30, 0.0, TAU, 96,
		Color(0.34, 0.36, 0.43, alpha * 0.6), rim * 0.30, true)

	# Die Speichen drehen sich mit.
	var spokes := [0.0, deg_to_rad(125.0), deg_to_rad(-125.0)]
	for base: float in spokes:
		var a: float = base + _wheel_angle
		var dir := Vector2(sin(a), -cos(a))
		_canvas.draw_line(c + dir * (r * 0.24), c + dir * (r - rim * 0.4),
			Color(0.17, 0.18, 0.22, alpha), r * 0.115, true)
		_canvas.draw_line(c + dir * (r * 0.24), c + dir * (r - rim * 0.4),
			Color(0.30, 0.32, 0.38, alpha * 0.8), r * 0.05, true)

	# Nabe
	_canvas.draw_circle(c, r * 0.27, Color(0.13, 0.14, 0.17, alpha))
	_canvas.draw_arc(c, r * 0.27, 0.0, TAU, 48,
		ACCENT if held else Color(0.32, 0.34, 0.40), r * 0.035, true)

	# Markierung oben: zeigt den Einschlag auf einen Blick.
	var top := c + Vector2(sin(_wheel_angle), -cos(_wheel_angle)) * (r - rim * 0.1)
	_canvas.draw_circle(top, r * 0.085, ACCENT)

	# Zwei ruhende Marken links und rechts als Bezugspunkt.
	for side: float in [-1.0, 1.0]:
		var a := deg_to_rad(90.0) * side
		var p := c + Vector2(sin(a), -cos(a)) * (r * 1.22)
		_canvas.draw_circle(p, r * 0.028, Color(1, 1, 1, 0.22))


func _draw_pedal(gas: bool) -> void:
	var rect := _pedal_rect(gas)
	var travel: float = _throttle if gas else _brake
	var tint: Color = GAS if gas else BRAKE

	# Der Schacht, in dem das Pedal sitzt.
	_canvas.draw_rect(rect.grow(_unit() * 0.012), Color(0, 0, 0, 0.32), true)

	# Das Pedal selbst kippt beim Treten nach hinten: es wird oben schmaler
	# und rutscht nach unten. Das ergibt den perspektivischen Eindruck.
	var press: float = travel
	var top_inset: float = rect.size.x * 0.18 * press
	var shift: float = rect.size.y * 0.10 * press
	var quad := PackedVector2Array([
		rect.position + Vector2(top_inset, shift),
		rect.position + Vector2(rect.size.x - top_inset, shift),
		rect.position + Vector2(rect.size.x, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y),
	])
	var base := Color(0.16, 0.17, 0.20).lerp(tint, 0.10 + press * 0.45)
	_canvas.draw_colored_polygon(quad, base)

	# Riffelung - Querstege wie auf einem Gummipedal.
	var steps := 7
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var left := quad[0].lerp(quad[3], t)
		var right := quad[1].lerp(quad[2], t)
		_canvas.draw_line(left, right, Color(0, 0, 0, 0.22), maxf(1.0, rect.size.x * 0.02))

	# Rand
	var outline := PackedVector2Array(quad)
	outline.append(quad[0])
	_canvas.draw_polyline(outline, tint.lerp(Color.WHITE, 0.15) if press > 0.02
		else Color(0.35, 0.37, 0.43), maxf(1.5, rect.size.x * 0.025), true)

	# Wegbalken links daneben: wie weit ist durchgetreten?
	var bar_w := _bar_width()
	var bar := Rect2(rect.position - Vector2(bar_w + _unit() * 0.010, 0.0),
		Vector2(bar_w, rect.size.y))
	_canvas.draw_rect(bar, Color(1, 1, 1, 0.10), true)
	if press > 0.01:
		var filled := Rect2(bar.position + Vector2(0.0, bar.size.y * (1.0 - press)),
			Vector2(bar_w, bar.size.y * press))
		_canvas.draw_rect(filled, tint, true)

	_label(Vector2(rect.position.x + rect.size.x * 0.5,
		rect.position.y - _unit() * 0.042), "GAS" if gas else "BREMSE", tint, 0.026)


func _draw_handbrake() -> void:
	var rect := _handbrake_rect()
	var col: Color = ACCENT if _handbrake else Color(0.30, 0.32, 0.38)
	_canvas.draw_rect(rect, Color(0, 0, 0, 0.30), true)
	_canvas.draw_rect(rect, col, false, maxf(1.5, _unit() * 0.003))
	_label(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - _unit() * 0.016),
		"HANDBREMSE", col, 0.022)


func _draw_small_button(slot: int, text: String) -> void:
	var rect := _small_button_rect(slot)
	_canvas.draw_rect(rect, Color(0, 0, 0, 0.30), true)
	_canvas.draw_rect(rect, Color(0.42, 0.45, 0.52), false, maxf(1.0, _unit() * 0.002))
	_label(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - _unit() * 0.015),
		text, Color(0.80, 0.83, 0.88), 0.024)


func _draw_arrow(right: bool) -> void:
	var rect := _arrow_rect(right)
	var c := rect.position + rect.size * 0.5
	var r := rect.size.x * 0.5
	_canvas.draw_circle(c, r, Color(0, 0, 0, 0.34))
	_canvas.draw_arc(c, r, 0.0, TAU, 48, Color(0.42, 0.45, 0.52), maxf(1.5, r * 0.05), true)
	var s: float = 1.0 if right else -1.0
	var tri := PackedVector2Array([
		c + Vector2(r * 0.30 * s, 0.0),
		c + Vector2(-r * 0.18 * s, -r * 0.34),
		c + Vector2(-r * 0.18 * s, r * 0.34),
	])
	_canvas.draw_colored_polygon(tri, ACCENT)


func _draw_start() -> void:
	var rect := _start_rect()
	# Leichtes Pulsieren, damit klar ist, wo es weitergeht.
	var pulse: float = 0.5 + 0.5 * sin(_garage_pulse * 2.6)
	_canvas.draw_rect(rect, Color(0, 0, 0, 0.42), true)
	_canvas.draw_rect(rect, ACCENT.lerp(Color.WHITE, pulse * 0.35), false,
		maxf(2.0, _unit() * 0.004))
	_label(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - _unit() * 0.026),
		"LOSFAHREN", Color.WHITE, 0.042)


func _label(center_top: Vector2, text: String, color: Color, scale: float) -> void:
	var font := ThemeDB.fallback_font
	var size := int(_unit() * scale)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center_top.x - width * 0.5, center_top.y + float(size) * 0.85)
	_canvas.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, Color(0, 0, 0, 0.7))
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
