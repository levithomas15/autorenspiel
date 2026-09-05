class_name Garage
extends Node3D

## Fahrzeugauswahl auf einem Drehteller unter Studiolicht.

signal car_chosen(index: int)

const CARD := Color(0.06, 0.065, 0.08, 0.86)

var index: int = 0

var _specs: Array = []
var _turntable: Node3D
var _camera: Camera3D
var _ui: CanvasLayer
var _name_label: Label
var _subtitle_label: Label
var _stats_label: Label
var _angle: float = 0.6
var _orbit_input: float = 0.0


func _ready() -> void:
	_specs = CarData.all()
	add_child(WorldEnv.garage())
	add_child(WorldEnv.studio_lights())
	_build_stage()
	_build_ui()
	_show(index)


func _build_stage() -> void:
	# Spiegelnder Studioboden - die Reflexion verkauft den Metallic-Lack.
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.035, 0.037, 0.045)
	floor_material.metallic = 0.65
	floor_material.roughness = 0.09
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)

	# Drehteller
	var disc := MeshLib.new_surface()
	MeshLib.add_cylinder_x(disc, Vector3.ZERO, 3.6, 3.6, 0.14, 64, true)
	var disc_node := MeshLib.finish(disc, Mats.metal(Color(0.12, 0.13, 0.16), 0.22), "Turntable")
	disc_node.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))
	disc_node.position = Vector3(0, 0.07, 0)
	add_child(disc_node)

	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	_turntable.position = Vector3(0, 0.14, 0)
	add_child(_turntable)

	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.near = 0.05
	_camera.far = 400.0
	# Leichte Tiefenunschaerfe im Hintergrund
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 12.0
	attributes.dof_blur_far_transition = 6.0
	attributes.dof_blur_amount = 0.06
	_camera.attributes = attributes
	_camera.current = true
	add_child(_camera)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	var title := _label(root, Vector2(64, 48), 22, Color(0.62, 0.68, 0.78))
	title.text = "AUTORENNSPIEL"

	_name_label = _label(root, Vector2(64, 82), 54, Color.WHITE)
	_subtitle_label = _label(root, Vector2(64, 148), 20, Color(1.0, 0.42, 0.68))
	_stats_label = _label(root, Vector2(64, 196), 18, Color(0.78, 0.82, 0.88))

	var footer := _label(root, Vector2(64, 0), 18, Color(0.7, 0.74, 0.8))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(64, -70)
	footer.text = "A / D   Fahrzeug waehlen        Q / E   drehen        " \
		+ "Enter   Losfahren        Esc   Beenden"

	var counter := _label(root, Vector2(0, 0), 18, Color(0.55, 0.6, 0.68))
	counter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	counter.position = Vector2(-220, 52)
	counter.size = Vector2(160, 30)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.text = "%d Fahrzeuge" % _specs.size()


func _label(parent: Node, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(900, float(font_size) * 2.2)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Baut ein rein optisches Fahrzeug (ohne Physik) fuer die Ausstellung.
static func build_showcase(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Showcase"
	root.add_child(CarBuilder.build(spec))
	var th: float = spec["track_half"]
	for axle in ["front", "rear"]:
		var is_front := axle == "front"
		var z: float = spec["front_axle_z"] if is_front else spec["rear_axle_z"]
		var radius: float = spec["wheel_radius_front"] if is_front else spec["wheel_radius_rear"]
		var width: float = spec["tire_width_front"] if is_front else spec["tire_width_rear"]
		for s in [-1.0, 1.0]:
			var wheel := WheelBuilder.build(radius, width, s, spec["rim_color"],
				spec["rim_style"], spec["rim_spokes"])
			wheel.position = Vector3(s * th, radius, z)
			root.add_child(wheel)
	return root


func _show(new_index: int) -> void:
	index = posmod(new_index, _specs.size())
	for child in _turntable.get_children():
		child.queue_free()
	var spec: Dictionary = _specs[index]
	_turntable.add_child(build_showcase(spec))

	_name_label.text = spec["name"]
	_subtitle_label.text = spec["subtitle"]
	var drive_names := {"rwd": "Heckantrieb", "awd": "Allradantrieb"}
	_stats_label.text = "Masse %d kg      Hoechstgeschwindigkeit %d km/h      %s      %s" % [
		int(spec["mass"]),
		int(spec["top_speed"] * 3.6),
		drive_names.get(spec["drive"], "Heckantrieb"),
		"%d Gaenge" % int(spec["gears"]) if int(spec["gears"]) > 2 else "Direktantrieb",
	]


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("select_right"):
		_show(index + 1)
	elif Input.is_action_just_pressed("select_left"):
		_show(index - 1)
	if Input.is_action_just_pressed("accept"):
		car_chosen.emit(index)

	_orbit_input = Input.get_action_strength("orbit_right") \
		- Input.get_action_strength("orbit_left")
	# Der Drehteller laeuft von allein; Q und E drehen zusaetzlich.
	_angle += delta * (0.28 + _orbit_input * 2.2)
	_turntable.rotation.y = _angle

	var height: float = 1.35
	var distance: float = 8.4
	_camera.position = Vector3(sin(_angle * 0.25) * 1.4, height, distance)
	_camera.look_at(Vector3(0.0, 0.72, 0.0), Vector3.UP)
