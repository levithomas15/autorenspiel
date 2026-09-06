extends Node3D

## Einstiegspunkt: legt die Eingaben an und wechselt zwischen Garage und Rennen.

enum State { GARAGE, RACE }

const LAPS_TOTAL := 5
const COUNTDOWN := 3.6

var state: int = State.GARAGE
var selected_index: int = 0

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


func _ready() -> void:
	_setup_input()
	_build_diagnostics()
	_enter_garage()


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
	for child in get_children():
		# Die Diagnoseanzeige bleibt ueber den Szenenwechsel hinweg stehen.
		if child == _diag_layer:
			continue
		remove_child(child)
		child.queue_free()
	_garage = null
	_track = null
	_car = null
	_camera = null
	_hud = null


func _enter_garage() -> void:
	_clear_scene()
	state = State.GARAGE
	_garage = Garage.new()
	_garage.index = selected_index
	_garage.car_chosen.connect(_on_car_chosen)
	add_child(_garage)


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
	_hud.set_car_name(spec["name"])

	_lap = 1
	_lap_time = 0.0
	_last_time = 0.0
	_best_time = 0.0
	_half_passed = false
	_countdown = COUNTDOWN
	_progress = _track.progress_at(_car.global_position)


# --- Ablauf -----------------------------------------------------------------
func _process(delta: float) -> void:
	_update_diagnostics()
	if state == State.GARAGE:
		if Input.is_action_just_pressed("back"):
			get_tree().quit()
		return
	_process_race(delta)


func _process_race(delta: float) -> void:
	if _car == null or _track == null or _hud == null:
		return

	if Input.is_action_just_pressed("back"):
		_enter_garage()
		return
	if Input.is_action_just_pressed("camera"):
		_hud.show_message(_camera.next_mode(), 1.2)
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


## Abseits der Fahrbahn gibt es deutlich weniger Grip - das haelt Abkuerzungen
## unattraktiv, ohne dass es dafuer eigene Trigger braucht.
func _update_surface() -> void:
	var lateral := _track.lateral_distance(_car.global_position)
	var edge: float = Track.HALF_WIDTH + Track.CURB_WIDTH
	if lateral > edge + 0.4:
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
