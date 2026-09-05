class_name ChaseCamera
extends Camera3D

## Verfolgerkamera mit weicher Federung. Vier Perspektiven, umschaltbar
## mit der Kamerataste.

enum Mode { CHASE_FAR, CHASE_NEAR, HOOD, COCKPIT }

const MODE_NAMES := ["Verfolger weit", "Verfolger nah", "Motorhaube", "Cockpit"]

var target: Node3D = null
var mode: int = Mode.CHASE_FAR

var _smoothed_position: Vector3 = Vector3.ZERO
var _smoothed_look: Vector3 = Vector3.ZERO
var _initialised: bool = false
var _base_fov: float = 72.0


func _ready() -> void:
	fov = _base_fov
	near = 0.08
	far = 2200.0
	current = true


func next_mode() -> String:
	mode = (mode + 1) % Mode.size()
	_initialised = false
	return MODE_NAMES[mode]


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var basis := target.global_transform.basis
	var origin := target.global_transform.origin
	var speed := 0.0
	if target is RigidBody3D:
		speed = (target as RigidBody3D).linear_velocity.length()

	var desired_position: Vector3
	var desired_look: Vector3
	var stiffness := 9.0

	match mode:
		Mode.CHASE_NEAR:
			desired_position = origin + basis.y * 1.35 + basis.z * 4.6
			desired_look = origin + basis.y * 0.85 - basis.z * 9.0
			stiffness = 11.0
		Mode.HOOD:
			desired_position = origin + basis.y * 1.02 - basis.z * 0.55
			desired_look = origin + basis.y * 1.0 - basis.z * 16.0
			stiffness = 26.0
		Mode.COCKPIT:
			desired_position = origin + basis.y * 1.02 + basis.z * 0.28 - basis.x * 0.36
			desired_look = origin + basis.y * 1.02 - basis.z * 16.0
			stiffness = 26.0
		_:
			# Bei hohem Tempo faellt die Kamera etwas zurueck und tiefer.
			var pull: float = clampf(speed / 70.0, 0.0, 1.0)
			desired_position = origin + basis.y * (1.85 + pull * 0.25) \
				+ basis.z * (6.4 + pull * 1.6)
			desired_look = origin + basis.y * 1.0 - basis.z * 11.0
			stiffness = 8.0

	if not _initialised:
		_smoothed_position = desired_position
		_smoothed_look = desired_look
		_initialised = true

	var weight: float = clampf(stiffness * delta, 0.0, 1.0)
	_smoothed_position = _smoothed_position.lerp(desired_position, weight)
	_smoothed_look = _smoothed_look.lerp(desired_look, clampf(weight * 1.4, 0.0, 1.0))

	global_position = _smoothed_position
	var up: Vector3 = basis.y.lerp(Vector3.UP, 0.55).normalized()
	if _smoothed_look.distance_to(global_position) > 0.05:
		look_at(_smoothed_look, up)

	# Sichtfeld waechst mit dem Tempo - der klassische Geschwindigkeitseindruck.
	var target_fov: float = _base_fov + clampf(speed / 78.0, 0.0, 1.0) * 22.0
	if mode == Mode.COCKPIT or mode == Mode.HOOD:
		target_fov = 78.0 + clampf(speed / 78.0, 0.0, 1.0) * 14.0
	fov = lerpf(fov, target_fov, clampf(3.0 * delta, 0.0, 1.0))
