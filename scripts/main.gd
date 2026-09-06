extends Node3D

## Einstiegspunkt: legt die Eingaben an und wechselt zwischen Garage und Rennen.

enum State { DEVICE, GARAGE, RACE }

const LAPS_TOTAL := 5
const COUNTDOWN := 3.6

var state: int = State.DEVICE
var selected_index: int = 0

var _device_select: DeviceSelect = null
var _touch: TouchControls = null
var _garage: Garage = null
var _track: Track = null
var _car: Car = null
var _camera: ChaseCamera = null
var _hud: Hud = null

var _lap: int = 1
var _lap_time: float = 0.0
var _last_time: float = 0.0
var _best_time: float = 0.0
var _progress: float = 0.0
var _half_passed: bool = false
var _countdown: float = 0.0
var _off_track: bool = false

## Kleine Diagnoseanzeige unten rechts. Sie ueberlebt den Szenenwechsel und
## verraet, wie schnell das Spiel auf dem jeweiligen Geraet tatsaechlich
## laeuft - ohne das laesst sich ein "reagiert nicht" aus der Ferne nicht
## einordnen. Mit F1 ausblendbar.
var _diag_layer: CanvasLayer = null
var _diag_label: Label = null

## Dreimal in die obere rechte Ecke tippen oeffnet das Admin-Panel.
const CORNER_TAPS := 3
const CORNER_WINDOW := 2.0
var _admin: AdminPanel = null
var _corner_taps: int = 0
var _corner_deadline: float = 0.0

## Wie lange der Autopilot schon steht oder abseits ist.
var _stuck_time: float = 0.0


func _ready() -> void:
	# Godot erzeugt aus jeder Beruehrung zusaetzlich einen kuenstlichen
	# Mausklick. Wer beide Ereignisarten behandelt - und das tun hier alle
	# Bildschirme - bekommt jede Beruehrung doppelt. Im Admin-Panel wurde ein
	# Schalter dadurch zweimal umgelegt und blieb, wie er war.
	Input.set_emulate_mouse_from_touch(false)
	_setup_input()
	_build_diagnostics()
	# Eine frueher getroffene Wahl wird uebernommen; sonst erst fragen.
	Cheats.apply_world(get_tree())
	if Device.load_saved():
		Device.apply_to(get_viewport())
		_enter_garage()
	else:
		_enter_device_select()


func _build_diagnostics() -> void:
	_diag_layer = CanvasLayer.new()
	_diag_layer.name = "Diagnose"
	_diag_layer.layer = 20
	add_child(_diag_layer)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	label.offset_left = -430.0
	label.offset_right = -12.0
	label.offset_top = 10.0
	label.offset_bottom = 40.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.65, 0.95, 0.75))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diag_layer.add_child(label)
	_diag_label = label


func _update_diagnostics() -> void:
	if _diag_label == null:
		return
	if Input.is_key_pressed(KEY_F1):
		_diag_layer.visible = false
	var size := get_viewport().get_visible_rect().size
	_diag_label.text = "%d fps   %dx%d   %s" % [
		Engine.get_frames_per_second(), int(size.x), int(size.y),
		RenderingServer.get_video_adapter_name()]


# --- Eingaben ---------------------------------------------------------------
## Die Actions werden zur Laufzeit registriert. Damit bleibt project.godot
## schlank und die Belegung steht an einer Stelle.
func _setup_input() -> void:
	var bindings := {
		"throttle": {"keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_A],
			"axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
		"brake": {"keys": [KEY_S, KEY_DOWN], "buttons": [JOY_BUTTON_B],
			"axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
		"steer_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [],
			"axes": [[JOY_AXIS_LEFT_X, -1.0]]},
		"steer_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [],
			"axes": [[JOY_AXIS_LEFT_X, 1.0]]},
		"handbrake": {"keys": [KEY_SPACE], "buttons": [JOY_BUTTON_X], "axes": []},
		"reset": {"keys": [KEY_R], "buttons": [JOY_BUTTON_Y], "axes": []},
		"camera": {"keys": [KEY_C], "buttons": [JOY_BUTTON_RIGHT_SHOULDER], "axes": []},
		"lights": {"keys": [KEY_L], "buttons": [], "axes": []},
		"select_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT],
			"axes": []},
		"select_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT],
			"axes": []},
		"orbit_left": {"keys": [KEY_Q], "buttons": [], "axes": []},
		"orbit_right": {"keys": [KEY_E], "buttons": [], "axes": []},
		"accept": {"keys": [KEY_ENTER, KEY_KP_ENTER], "buttons": [JOY_BUTTON_START],
			"axes": []},
		"back": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_BACK], "axes": []},
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.22)
		var binding: Dictionary = bindings[action]
		for key in binding["keys"]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		for button in binding["buttons"]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
		for axis in binding["axes"]:
			var event := InputEventJoypadMotion.new()
			event.axis = axis[0]
			event.axis_value = axis[1]
			InputMap.action_add_event(action, event)


# --- Zustandswechsel --------------------------------------------------------
func _clear_scene() -> void:
	if _touch != null:
		_touch.release_all()
	for child in get_children():
		# Die Diagnoseanzeige bleibt ueber den Szenenwechsel hinweg stehen.
		if child == _diag_layer:
			continue
		remove_child(child)
		child.queue_free()
	_device_select = null
	_touch = null
	_garage = null
	_track = null
	_car = null
	_camera = null
	_hud = null


func _enter_device_select() -> void:
	_clear_scene()
	state = State.DEVICE
	_device_select = DeviceSelect.new()
	_device_select.chosen.connect(_on_device_chosen)
	add_child(_device_select)


func _on_device_chosen(_kind: int) -> void:
	Device.apply_to(get_viewport())
	_enter_garage()


func _enter_garage() -> void:
	_clear_scene()
	state = State.GARAGE
	_garage = Garage.new()
	_garage.index = selected_index
	_garage.car_chosen.connect(_on_car_chosen)
	add_child(_garage)
	_add_touch_controls(false)


## Lenkrad und Pedale gibt es nur, wo keine Tastatur zu erwarten ist.
func _add_touch_controls(racing: bool) -> void:
	if not Device.uses_touch():
		return
	_touch = TouchControls.new()
	_touch.racing = racing
	if racing:
		_touch.garage_requested.connect(_enter_garage)
		_touch.camera_requested.connect(_cycle_camera)
	else:
		_touch.garage_requested.connect(_enter_device_select)
	add_child(_touch)


func _cycle_camera() -> void:
	if _camera != null and _hud != null:
		_hud.show_message(_camera.next_mode(), 1.2)


func _on_car_chosen(index: int) -> void:
	selected_index = index
	_start_race()


func _start_race() -> void:
	_clear_scene()
	state = State.RACE

	add_child(WorldEnv.race())
	add_child(WorldEnv.sun())

	_track = Track.new()
	_track.name = "Track"
	add_child(_track)

	var spec: Dictionary = CarData.all()[selected_index]
	_car = Car.create(spec)
	add_child(_car)
	_car.global_transform = _track.start_transform()
	# Waehrend des Countdowns steht das Fahrzeug still.
	_car.freeze = true

	_camera = ChaseCamera.new()
	_camera.target = _car
	add_child(_camera)

	_hud = Hud.new()
	add_child(_hud)
	_add_touch_controls(true)
	_hud.set_car_name(spec["name"])

	_lap = 1
	_lap_time = 0.0
	_last_time = 0.0
	_best_time = 0.0
	_half_passed = false
	_countdown = COUNTDOWN
	_progress = _track.progress_at(_car.global_position)


# --- Ablauf -----------------------------------------------------------------
## Die Ecke ist ein Quadrat von 13 Prozent der kuerzeren Bildschirmseite -
## gross genug fuer einen Daumen, klein genug um nicht im Weg zu sein.
func _corner_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var side: float = minf(size.x, size.y) * 0.13
	return Rect2(Vector2(size.x - side, 0.0), Vector2(side, side))


func _unhandled_input(event: InputEvent) -> void:
	if _admin != null:
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
	if pos == Vector2.INF or not _corner_rect().has_point(pos):
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now > _corner_deadline:
		_corner_taps = 0
	_corner_taps += 1
	_corner_deadline = now + CORNER_WINDOW
	if _corner_taps >= CORNER_TAPS:
		_corner_taps = 0
		_open_admin()


func _open_admin() -> void:
	if _admin != null:
		return
	_admin = AdminPanel.new()
	_admin.closed.connect(_close_admin)
	add_child(_admin)


func _close_admin() -> void:
	if _admin == null:
		return
	_admin.queue_free()
	_admin = null
	# Der Regenbogenlack fuer alle wirkt erst beim naechsten Aufbau.
	if state == State.GARAGE and _garage != null:
		_enter_garage()


func _process(delta: float) -> void:
	_update_diagnostics()
	if _admin != null:
		return
	if state == State.DEVICE:
		return
	if state == State.GARAGE:
		# Zurueck fuehrt zur Geraetewahl, damit sie sich aendern laesst.
		if Input.is_action_just_pressed("back"):
			_enter_device_select()
		return
	_process_race(delta)


func _process_race(delta: float) -> void:
	if _car == null or _track == null or _hud == null:
		return

	if Input.is_action_just_pressed("back"):
		_enter_garage()
		return
	if Input.is_action_just_pressed("camera"):
		_cycle_camera()
	if Input.is_action_just_pressed("lights"):
		_car.toggle_headlights()
	if Input.is_action_just_pressed("reset"):
		_respawn()

	if _countdown > 0.0:
		var before := int(ceil(_countdown - 0.6))
		_countdown -= delta
		var after := int(ceil(_countdown - 0.6))
		if after != before:
			if after > 0:
				_hud.show_message(str(after), 1.0)
			elif after == 0:
				_hud.show_message("LOS!", 1.4)
		if _countdown <= 0.0:
			_car.freeze = false
	else:
		_lap_time += delta

	_update_surface()
	_update_lap()
	_hud.update_readouts(_car, _lap, LAPS_TOTAL, _lap_time, _last_time, _best_time,
		_off_track)


## Der Autopilot rechnet im festen Physiktakt. In `_process` haenge sein
## Ergebnis an der Bildrate, und dieselbe Strecke endete mal sauber und mal
## in der Leitplanke.
func _physics_process(_delta: float) -> void:
	if state == State.RACE and _car != null and _track != null:
		_update_autopilot()


## Solange der Autopilot laeuft, kommen Gas, Bremse und Lenkung von ihm.
func _update_autopilot() -> void:
	var wanted: bool = Cheats.is_on(Cheats.Kind.AUTOPILOT)
	if _car.external_control != wanted:
		_car.external_control = wanted
		_car.external_input = Vector3.ZERO
	if not wanted:
		_stuck_time = 0.0
		return
	_car.external_input = Autopilot.drive(_car, _track)

	# Sicherheitsnetz. "Faehrt ohne zu crashen" muss auch dann gelten, wenn
	# die Regelung einmal danebenliegt: wer steht oder neben der Strecke
	# gelandet ist, wird zurueckgesetzt statt haengen zu bleiben.
	var lateral: float = _track.lateral_distance(_car.global_position)
	if _car.speed_kmh < 6.0 or lateral > Track.HALF_WIDTH + Track.CURB_WIDTH:
		_stuck_time += get_physics_process_delta_time()
	else:
		_stuck_time = 0.0
	if _stuck_time > 1.5:
		_stuck_time = 0.0
		_respawn()


## Abseits der Fahrbahn gibt es deutlich weniger Grip - das haelt Abkuerzungen
## unattraktiv, ohne dass es dafuer eigene Trigger braucht.
func _update_surface() -> void:
	var lateral := _track.lateral_distance(_car.global_position)
	var edge: float = Track.HALF_WIDTH + Track.CURB_WIDTH
	if Cheats.is_on(Cheats.Kind.NO_OFFTRACK):
		_off_track = lateral > edge + 0.4
		_car.grip_multiplier = 1.0
	elif lateral > edge + 0.4:
		_off_track = true
		_car.grip_multiplier = 0.42
	elif lateral > Track.HALF_WIDTH:
		_off_track = false
		_car.grip_multiplier = 0.82
	else:
		_off_track = false
		_car.grip_multiplier = 1.0

	# Sicherheitsnetz, falls das Fahrzeug irgendwo hinausfliegt.
	if _car.global_position.y < _track.base_y - 8.0:
		_respawn()


func _update_lap() -> void:
	var length := _track.total_length
	var current := _track.progress_at(_car.global_position)
	var previous := _progress
	_progress = current

	if current > length * 0.4 and current < length * 0.75:
		_half_passed = true

	# Start-Ziel-Linie wird ueberfahren, wenn der Fortschritt vom Ende der
	# Strecke auf den Anfang springt.
	var crossed := previous > length * 0.8 and current < length * 0.2
	if not (crossed and _half_passed):
		return

	_half_passed = false
	_last_time = _lap_time
	if _best_time <= 0.0 or _last_time < _best_time:
		_best_time = _last_time
		_hud.show_message("Bestzeit  " + Hud.format_time(_last_time), 3.0)
	else:
		_hud.show_message(Hud.format_time(_last_time), 2.0)
	_lap_time = 0.0
	_lap += 1

	if _lap > LAPS_TOTAL:
		_lap = LAPS_TOTAL
		_hud.show_message("Zielflagge - Beste Runde " + Hud.format_time(_best_time), 6.0)


func _respawn() -> void:
	var offset := _track.progress_at(_car.global_position)
	_car.reset_to(_track.frame_at(offset))
	_hud.show_message("Zurueckgesetzt", 1.2)
