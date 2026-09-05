class_name Track
extends Node3D

## Prozeduraler Rundkurs. Die Mittellinie ist ein geschlossener Curve3D;
## daraus entstehen Fahrbahn, Randsteine, Grasboeschung und Leitplanken als
## Baender (Ribbons). Die Kurve dient gleichzeitig als Rundenzaehler:
## get_closest_offset() liefert den Streckenfortschritt.

const HALF_WIDTH := 6.6
const CURB_WIDTH := 0.9
const VERGE_WIDTH := 55.0
const BARRIER_OFFSET := 1.6
const BARRIER_HEIGHT := 0.95
const STEP := 3.0

const COLOR_ASPHALT := Color(0.118, 0.121, 0.132)
const COLOR_LINE := Color(0.74, 0.74, 0.72)
const COLOR_CURB_A := Color(0.60, 0.08, 0.07)
const COLOR_CURB_B := Color(0.80, 0.80, 0.78)
const COLOR_GRASS_A := Color(0.19, 0.30, 0.13)
const COLOR_GRASS_B := Color(0.24, 0.36, 0.16)

var curve: Curve3D
var total_length: float = 0.0
var base_y: float = 0.0

var _samples: PackedVector3Array = PackedVector3Array()
var _rights: PackedVector3Array = PackedVector3Array()
var _ups: PackedVector3Array = PackedVector3Array()
var _forwards: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	_build_curve()
	_build_frames()
	_build_road()
	_build_verge()
	_build_barriers()
	_build_start_gantry()
	_scatter_trees()


# --- Mittellinie ------------------------------------------------------------
func _build_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.5
	var count := 30
	var points := PackedVector3Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		# Sternfoermige Radiusfunktion: nie negativ, deshalb kann sich die
		# Strecke nicht selbst schneiden - und sie hat trotzdem schnelle
		# Passagen, enge Kehren und wechselnde Radien.
		var r: float = 300.0 + 90.0 * sin(2.0 * a) + 55.0 * sin(3.0 * a + 0.7) \
			- 40.0 * cos(5.0 * a)
		var y: float = 7.0 * sin(2.0 * a + 1.1) + 4.0 * cos(3.0 * a)
		points.append(Vector3(cos(a) * r, y, sin(a) * r))

	for i in count:
		var prev: Vector3 = points[(i - 1 + count) % count]
		var next: Vector3 = points[(i + 1) % count]
		var tangent := (next - prev) / 6.0
		curve.add_point(points[i], -tangent, tangent)
	# Schleife schliessen
	var t0 := (points[1] - points[count - 1]) / 6.0
	curve.add_point(points[0], -t0, t0)

	total_length = curve.get_baked_length()
	var lowest := 1e9
	for p in points:
		lowest = minf(lowest, p.y)
	base_y = lowest - 3.0


# --- Begleitendes Koordinatensystem entlang der Strecke ---------------------
func _build_frames() -> void:
	var steps := int(total_length / STEP)
	for i in steps:
		var s := float(i) * STEP
		var frame := frame_at(s)
		_samples.append(frame.origin)
		_rights.append(frame.basis.x)
		_ups.append(frame.basis.y)
		_forwards.append(-frame.basis.z)


## Position und Ausrichtung an einer Streckenposition, inklusive Ueberhoehung.
func frame_at(offset: float) -> Transform3D:
	var s := fposmod(offset, total_length)
	var pos := curve.sample_baked(s, true)
	var ahead := curve.sample_baked(fposmod(s + 2.0, total_length), true)
	var behind := curve.sample_baked(fposmod(s - 2.0, total_length), true)
	var forward := (ahead - behind)
	if forward.length_squared() < 1e-6:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	# In Godot blickt ein Knoten entlang -Z. Fuer eine rechtshaendige Basis
	# gilt damit: rechts = vorne x oben, oben = rechts x vorne.
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()

	# Ueberhoehung aus der Kruemmung: schnelle Kurven werden angeschraegt.
	var f_ahead := (curve.sample_baked(fposmod(s + 12.0, total_length), true) - ahead).normalized()
	var f_behind := (behind - curve.sample_baked(fposmod(s - 12.0, total_length), true)).normalized()
	var turn: float = f_behind.cross(f_ahead).dot(Vector3.UP)
	# Eine Drehung um +forward senkt die rechte Seite, deshalb das Minus:
	# in einer Linkskurve (turn > 0) soll die linke, innere Seite tiefer liegen.
	var bank: float = clampf(-turn * 2.4, -0.13, 0.13)
	right = right.rotated(forward, bank).normalized()
	up = right.cross(forward).normalized()

	# Transform3D erwartet -Z als Blickrichtung.
	return Transform3D(Basis(right, up, -forward), pos)


func _frame_index(i: int) -> int:
	return posmod(i, _samples.size())


func _point(i: int, lateral: float, height: float) -> Vector3:
	var k := _frame_index(i)
	return _samples[k] + _rights[k] * lateral + _ups[k] * height


# --- Fahrbahn ---------------------------------------------------------------
func _build_road() -> void:
	var st := MeshLib.new_surface()
	# Spalten quer zur Fahrbahn. Doppelte Positionen erzeugen harte Farbkanten.
	var columns: Array = [
		-HALF_WIDTH, -HALF_WIDTH + 0.20, -HALF_WIDTH + 0.42,
		-0.10, 0.10, HALF_WIDTH - 0.42, HALF_WIDTH - 0.20, HALF_WIDTH,
	]
	var strip_colors: Array = [
		COLOR_ASPHALT, COLOR_LINE, COLOR_ASPHALT, COLOR_ASPHALT,
		COLOR_ASPHALT, COLOR_LINE, COLOR_ASPHALT,
	]
	var steps := _samples.size()
	for i in steps:
		# Start-Ziel-Karo und gestrichelte Mittellinie
		var dashed: bool = (i / 3) % 2 == 0
		var on_grid: bool = i < 2
		for c in columns.size() - 1:
			var col: Color = strip_colors[c]
			if c == 3:
				col = COLOR_LINE if dashed else COLOR_ASPHALT
			if on_grid:
				col = COLOR_LINE if (c % 2 == 0) else Color(0.06, 0.06, 0.06)
			var a := _point(i, columns[c], 0.0)
			var b := _point(i, columns[c + 1], 0.0)
			var d := _point(i + 1, columns[c], 0.0)
			var e := _point(i + 1, columns[c + 1], 0.0)
			_quad(st, a, b, e, d, col, float(i) * STEP * 0.1)

	# Randsteine
	for i in steps:
		var col: Color = COLOR_CURB_A if (i / 2) % 2 == 0 else COLOR_CURB_B
		for side in [-1.0, 1.0]:
			var inner: float = side * HALF_WIDTH
			var outer: float = side * (HALF_WIDTH + CURB_WIDTH)
			var a := _point(i, inner, 0.005)
			var b := _point(i, outer, 0.075)
			var d := _point(i + 1, inner, 0.005)
			var e := _point(i + 1, outer, 0.075)
			if side > 0.0:
				_quad(st, a, b, e, d, col, 0.0)
			else:
				_quad(st, b, a, d, e, col, 0.0)

	var mesh_instance := MeshLib.finish(st, Mats.asphalt(), "Road")
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	_add_static_collision(mesh_instance.mesh, "RoadBody")


# --- Grasboeschung ----------------------------------------------------------
func _build_verge() -> void:
	var st := MeshLib.new_surface()
	var steps := _samples.size()
	for i in steps:
		for side in [-1.0, 1.0]:
			var inner: float = side * (HALF_WIDTH + CURB_WIDTH)
			var outer: float = side * (HALF_WIDTH + VERGE_WIDTH)
			var a := _point(i, inner, 0.02)
			var d := _point(i + 1, inner, 0.02)
			var b := _samples[_frame_index(i)] + _rights[_frame_index(i)] * outer
			var e := _samples[_frame_index(i + 1)] + _rights[_frame_index(i + 1)] * outer
			b.y = base_y
			e.y = base_y
			var col: Color = COLOR_GRASS_A if (i % 3) == 0 else COLOR_GRASS_B
			if side > 0.0:
				_quad(st, a, b, e, d, col, 0.0)
			else:
				_quad(st, b, a, d, e, col, 0.0)

	var verge := MeshLib.finish(st, Mats.grass(), "Verge")
	verge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(verge)
	_add_static_collision(verge.mesh, "VergeBody")

	# Grosse Grundflaeche darunter, damit der Horizont geschlossen ist.
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	ground.mesh = plane
	ground.position = Vector3(0, base_y - 0.15, 0)
	ground.material_override = Mats.matte(Color(0.17, 0.26, 0.12), 0.98)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


# --- Leitplanken ------------------------------------------------------------
func _build_barriers() -> void:
	var st := MeshLib.new_surface()
	var steps := _samples.size()
	for i in steps:
		for side in [-1.0, 1.0]:
			var lateral: float = side * (HALF_WIDTH + BARRIER_OFFSET)
			var a := _point(i, lateral, 0.10)
			var d := _point(i + 1, lateral, 0.10)
			var b := _point(i, lateral, BARRIER_HEIGHT)
			var e := _point(i + 1, lateral, BARRIER_HEIGHT)
			var col := Color(0.62, 0.64, 0.67)
			# Werbebande in Signalfarbe alle paar Meter
			if (i / 6) % 5 == 0:
				col = Color(0.75, 0.16, 0.14)
			# Die Planke wird von der Strecke aus gesehen - Normale nach innen.
			var inward: Vector3 = -_rights[_frame_index(i)] * side
			_quad(st, a, d, e, b, col, 0.0, inward)
			if i % 3 == 0:
				# Pfosten
				var post_a := _point(i, lateral + side * 0.05, 0.0)
				var post_b := _point(i, lateral + side * 0.05, BARRIER_HEIGHT)
				var post_c := _point(i, lateral + side * 0.05, BARRIER_HEIGHT) \
					+ _forwards[_frame_index(i)] * 0.18
				var post_d := _point(i, lateral + side * 0.05, 0.0) \
					+ _forwards[_frame_index(i)] * 0.18
				_quad(st, post_a, post_d, post_c, post_b, Color(0.35, 0.36, 0.38), 0.0,
					-_rights[_frame_index(i)] * side)

	var barrier := MeshLib.finish(st, Mats.guardrail(), "Barrier")
	add_child(barrier)
	_add_static_collision(barrier.mesh, "BarrierBody")


# --- Start-Ziel-Bruecke -----------------------------------------------------
func _build_start_gantry() -> void:
	var st := MeshLib.new_surface()
	var frame := frame_at(0.0)
	var right := frame.basis.x
	var up := frame.basis.y
	var pos := frame.origin
	var span := HALF_WIDTH + 2.4
	for side in [-1.0, 1.0]:
		var foot := pos + right * (side * span)
		MeshLib.add_box(st, foot + up * 3.0, Vector3(0.5, 6.0, 0.5))
	MeshLib.add_box(st, pos + up * 6.2, Vector3(span * 2.2, 0.7, 0.5))
	var gantry := MeshLib.finish(st, Mats.metal(Color(0.28, 0.29, 0.32), 0.4), "Gantry")
	gantry.transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	add_child(gantry)

	var sign_mesh := MeshLib.new_surface()
	MeshLib.add_box(sign_mesh, pos + up * 6.2 + frame.basis.z * 0.28,
		Vector3(span * 1.4, 1.1, 0.06))
	add_child(MeshLib.finish(sign_mesh, Mats.emissive(Color(0.85, 0.10, 0.16), 1.6),
		"GantrySign"))


# --- Baeume -----------------------------------------------------------------
func _scatter_trees() -> void:
	var trunk := MeshLib.new_surface()
	# Beide Teile werden entlang +X gebaut und spaeter aufgerichtet:
	# Stamm von x = 0 bis 2.6, Krone von x = 2.0 bis 6.8.
	MeshLib.add_cylinder_x(trunk, Vector3(1.3, 0, 0), 0.22, 0.16, 2.6, 8, false)
	var trunk_mesh := trunk.commit()
	var crown := MeshLib.new_surface()
	MeshLib.add_cylinder_x(crown, Vector3(4.4, 0, 0), 1.9, 0.02, 4.8, 10, true)
	var crown_mesh := crown.commit()
	if trunk_mesh == null or crown_mesh == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260905
	var transforms: Array[Transform3D] = []
	var steps := _samples.size()
	for i in range(0, steps, 2):
		for side in [-1.0, 1.0]:
			if rng.randf() > 0.55:
				continue
			var lateral: float = side * rng.randf_range(HALF_WIDTH + 16.0,
				HALF_WIDTH + VERGE_WIDTH - 6.0)
			var k := _frame_index(i)
			var p := _samples[k] + _rights[k] * lateral
			p.y = lerpf(_samples[k].y, base_y, clampf(
				(absf(lateral) - HALF_WIDTH - CURB_WIDTH) / (VERGE_WIDTH - CURB_WIDTH),
				0.0, 1.0)) - 0.2
			var scale_factor: float = rng.randf_range(0.8, 1.5)
			# Der Stamm liegt entlang X, also erst aufrichten.
			var basis := Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT,
				rng.randf_range(0.0, TAU))
			transforms.append(Transform3D(basis.scaled(Vector3.ONE * scale_factor), p))

	_add_multimesh(trunk_mesh, transforms, Mats.matte(Color(0.16, 0.11, 0.07), 0.9), "TreeTrunks")
	_add_multimesh(crown_mesh, transforms, Mats.matte(Color(0.10, 0.21, 0.09), 0.95), "TreeCrowns")


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], material: Material,
		node_name: String) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = material
	add_child(node)


# --- Hilfsfunktionen --------------------------------------------------------
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		color: Color, v_offset: float, normal_hint := Vector3.UP) -> void:
	var n := (b - a).cross(d - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	# Die Reihenfolge der Eckpunkte wechselt zwischen linker und rechter
	# Streckenseite, deshalb wird die Normale an einer Vorgabe ausgerichtet.
	if n.dot(normal_hint) < 0.0:
		n = -n
	st.set_color(color)
	st.set_normal(n)
	st.set_uv(Vector2(0.0, v_offset))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, v_offset))
	st.add_vertex(c)
	st.set_uv(Vector2(1.0, v_offset))
	st.add_vertex(b)
	st.set_uv(Vector2(0.0, v_offset))
	st.add_vertex(a)
	st.set_uv(Vector2(0.0, v_offset + 1.0))
	st.add_vertex(d)
	st.set_uv(Vector2(1.0, v_offset))
	st.add_vertex(c)


func _add_static_collision(mesh: Mesh, node_name: String) -> void:
	if mesh == null:
		return
	var body := StaticBody3D.new()
	body.name = node_name
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


# --- Abfragen fuer Rundenlogik und Kamera -----------------------------------
func progress_at(world_position: Vector3) -> float:
	return curve.get_closest_offset(world_position)


## Seitlicher Abstand zur Ideallinie. Groesser als HALF_WIDTH bedeutet:
## das Fahrzeug ist neben der Strecke.
func lateral_distance(world_position: Vector3) -> float:
	var closest := curve.get_closest_point(world_position)
	return Vector2(world_position.x - closest.x, world_position.z - closest.z).length()


func start_transform() -> Transform3D:
	var frame := frame_at(6.0)
	frame.origin += frame.basis.y * 0.5 - frame.basis.x * 2.0
	return frame
