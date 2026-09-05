class_name Car
extends VehicleBody3D

## Fahrzeug auf Basis von VehicleBody3D. Die vier Raeder haengen an
## VehicleWheel3D-Knoten; Motor, Lenkung, Abtrieb und Luftwiderstand
## werden hier simuliert.

const IDLE_RPM := 900.0

var spec: Dictionary = {}
var rpm: float = IDLE_RPM
var gear: int = 1
var speed_kmh: float = 0.0
var forward_speed: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
## Wird von aussen gesetzt: 1.0 auf Asphalt, kleiner abseits der Strecke.
var grip_multiplier: float = 1.0

var _steer: float = 0.0
var max_rpm: float = 8800.0
var _base_friction: float = 3.2
var _wheels: Array[VehicleWheel3D] = []
var _tail_material: StandardMaterial3D = null
var _beams: Node3D = null
var _audio: EngineAudio = null


static func create(car_spec: Dictionary) -> Car:
	var car := Car.new()
	car.spec = car_spec
	car.name = "Car"
	car.mass = car_spec["mass"]
	car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Tiefer Schwerpunkt - ohne ihn neigt VehicleBody3D zum Umkippen.
	var com_z: float = 0.35 if car_spec["drive"] == "rwd" else 0.0
	car.center_of_mass = Vector3(0.0, 0.32, com_z)
	car.linear_damp = 0.02
	car.angular_damp = 0.15
	car.continuous_cd = true

	car._build_collision()
	car._build_wheels()
	car.add_child(CarBuilder.build(car_spec))
	car._collect_references()
	car.max_rpm = 16000.0 if car_spec["drive"] == "awd" and car_spec["gears"] <= 2 else 8800.0

	var audio := EngineAudio.new()
	audio.configure(car_spec)
	car.add_child(audio)
	car._audio = audio
	return car


func _build_collision() -> void:
	var length: float = spec["length"]
	var w: float = MeshLib.sample_curve(spec["body"], 0.5, 1)

	var lower := CollisionShape3D.new()
	var lower_box := BoxShape3D.new()
	# Der Koerper sinkt unter Last um den Einfederweg. Der Kollisionskoerper
	# sitzt deshalb hoeher als der sichtbare Unterboden, sonst setzt das Auto
	# im eingefederten Zustand auf der Fahrbahn auf.
	lower_box.size = Vector3(w * 1.9, 0.30, length * 0.94)
	lower.shape = lower_box
	lower.position = Vector3(0, 0.38, 0)
	add_child(lower)

	var upper := CollisionShape3D.new()
	var upper_box := BoxShape3D.new()
	var cabin: Array = spec["cabin"]
	upper_box.size = Vector3(w * 1.6, 0.55, length * (cabin[1] - cabin[0]) + 0.4)
	upper.shape = upper_box
	upper.position = Vector3(0, 0.72, (((cabin[0] + cabin[1]) * 0.5) - 0.5) * length)
	add_child(upper)


func _build_wheels() -> void:
	var th: float = spec["track_half"]
	var drive: String = spec["drive"]
	for axle in ["front", "rear"]:
		var is_front := axle == "front"
		var z: float = spec["front_axle_z"] if is_front else spec["rear_axle_z"]
		var radius: float = spec["wheel_radius_front"] if is_front else spec["wheel_radius_rear"]
		var width: float = spec["tire_width_front"] if is_front else spec["tire_width_rear"]
		for s in [-1.0, 1.0]:
			var wheel := VehicleWheel3D.new()
			wheel.name = "Wheel%s%s" % [axle.capitalize(), "R" if s > 0.0 else "L"]
			# Der Knoten sitzt am Federbeinpunkt, also um die Federlaenge
			# oberhalb der Radmitte.
			wheel.position = Vector3(s * th, radius + 0.22, z)
			wheel.wheel_radius = radius
			wheel.wheel_rest_length = 0.22
			wheel.wheel_friction_slip = _base_friction * (1.0 if is_front else 1.08)
			wheel.wheel_roll_influence = 0.06
			wheel.suspension_travel = 0.20
			wheel.suspension_stiffness = 55.0
			wheel.suspension_max_force = 12000.0
			wheel.damping_compression = 0.75
			wheel.damping_relaxation = 1.05
			wheel.use_as_steering = is_front
			wheel.use_as_traction = (not is_front) if drive == "rwd" else true
			wheel.add_child(WheelBuilder.build(radius, width, s, spec["rim_color"],
				spec["rim_style"], spec["rim_spokes"]))
			add_child(wheel)
			_wheels.append(wheel)


func _collect_references() -> void:
	var model := get_node_or_null("CarModel")
	if model == null:
		return
	var tail := model.get_node_or_null("Taillights")
	if tail != null and tail.material_override is StandardMaterial3D:
		_tail_material = tail.material_override
	_beams = model.get_node_or_null("HeadlightBeams")


func toggle_headlights() -> void:
	if _beams != null:
		_beams.visible = not _beams.visible


func reset_to(target: Transform3D) -> void:
	var t := target
	t.origin += Vector3.UP * 0.6
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
	_steer = 0.0
	global_transform = t


func _physics_process(delta: float) -> void:
	forward_speed = -global_transform.basis.z.dot(linear_velocity)
	var speed := linear_velocity.length()
	speed_kmh = speed * 3.6

	throttle_input = Input.get_action_strength("throttle")
	brake_input = Input.get_action_strength("brake")
	var steer_input := Input.get_action_strength("steer_left") \
		- Input.get_action_strength("steer_right")

	_update_steering(steer_input, delta)
	_update_drivetrain(speed)
	_update_grip()
	_apply_aero(speed)
	_update_lights()

	if _audio != null:
		_audio.update(rpm / max_rpm, throttle_input)


func _update_steering(input: float, delta: float) -> void:
	var max_steer: float = spec["steer_max"]
	# Bei hohem Tempo wird der Lenkeinschlag begrenzt, sonst reicht ein
	# Tastendruck fuer einen Dreher.
	var speed_factor: float = clampf(1.0 - absf(forward_speed) / 65.0, 0.28, 1.0)
	var target: float = input * max_steer * speed_factor
	var rate: float = 4.2 if absf(target) > absf(_steer) else 7.0
	_steer = move_toward(_steer, target, rate * max_steer * delta)
	steering = _steer


func _update_drivetrain(speed: float) -> void:
	var top: float = spec["top_speed"]
	var gears: int = spec["gears"]
	var per_gear: float = top / float(gears)
	var abs_fwd := absf(forward_speed)

	gear = clampi(int(abs_fwd / per_gear) + 1, 1, gears)
	var frac: float = clampf(fposmod(abs_fwd, per_gear) / per_gear, 0.0, 1.0)
	var target_rpm: float = lerpf(IDLE_RPM, max_rpm, clampf(frac + 0.12, 0.0, 1.0))
	if abs_fwd < 1.0:
		target_rpm = lerpf(IDLE_RPM, max_rpm * 0.55, throttle_input)
	rpm = lerpf(rpm, target_rpm, 0.18)

	# Drehmomentverlauf mit Maximum bei rund 70 Prozent der Nenndrehzahl
	var rev := rpm / max_rpm
	var torque: float = 0.55 + 0.75 * sin(clampf(rev, 0.0, 1.0) * PI * 0.92)
	var speed_limit: float = clampf(1.0 - pow(speed / top, 3.0), 0.0, 1.0)
	var power: float = spec["power"]

	var reversing := forward_speed < 0.6 and brake_input > 0.1 and throttle_input < 0.1
	if reversing:
		engine_force = -power * 0.42 * brake_input
		brake = 0.0
	else:
		engine_force = power * torque * throttle_input * speed_limit * grip_multiplier
		brake = spec["brake_force"] * brake_input
		if Input.is_action_pressed("handbrake"):
			brake = spec["brake_force"] * 1.4
			engine_force = 0.0

	# Motorbremse
	if throttle_input < 0.05 and brake_input < 0.05 and abs_fwd > 1.0:
		brake = 3.5


func _update_grip() -> void:
	for wheel in _wheels:
		var base: float = _base_friction * (1.0 if wheel.use_as_steering else 1.08)
		wheel.wheel_friction_slip = base * grip_multiplier


func _apply_aero(speed: float) -> void:
	if speed < 0.5:
		return
	var v2 := speed * speed
	# Abtrieb entlang der Fahrzeughochachse, damit er in Kurvenueberhoehungen
	# in die richtige Richtung wirkt.
	apply_central_force(-global_transform.basis.y * spec["downforce"] * v2)
	apply_central_force(-linear_velocity.normalized() * 0.62 * v2)


func _update_lights() -> void:
	if _tail_material == null:
		return
	var braking: bool = brake_input > 0.05 or Input.is_action_pressed("handbrake")
	var target: float = 9.0 if braking else 2.2
	_tail_material.emission_energy_multiplier = lerpf(
		_tail_material.emission_energy_multiplier, target, 0.25)
