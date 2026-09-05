class_name WheelBuilder
extends RefCounted

## Baut ein komplettes Rad: Reifen mit gerundeten Schultern, Felge mit Speichen,
## Bremsscheibe und Sattel. Die Drehachse ist X, die Aussenseite zeigt nach +X,
## wenn "side" 1.0 ist (rechte Fahrzeugseite), sonst nach -X.

static func build(radius: float, width: float, side: float, rim_color: Color,
		rim_style: String, spokes: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Wheel"

	var rim_radius: float = radius * 0.70
	var half := width * 0.5

	# --- Reifen -------------------------------------------------------------
	var tire := MeshLib.new_surface()
	MeshLib.add_cylinder_x(tire, Vector3.ZERO, radius, radius, width * 0.66, 40, false)
	# Schultern: leichter Radiusabfall zu beiden Seiten
	MeshLib.add_cylinder_x(tire, Vector3(half * 0.83, 0, 0), radius, radius * 0.955,
		width * 0.34, 40, false)
	MeshLib.add_cylinder_x(tire, Vector3(-half * 0.83, 0, 0), radius * 0.955, radius,
		width * 0.34, 40, false)
	# Flanken bis zum Felgenhorn
	MeshLib.add_cylinder_x(tire, Vector3(half * 0.97, 0, 0), radius * 0.955,
		rim_radius * 1.04, width * 0.06, 40, false)
	MeshLib.add_cylinder_x(tire, Vector3(-half * 0.97, 0, 0), rim_radius * 1.04,
		radius * 0.955, width * 0.06, 40, false)
	root.add_child(MeshLib.finish(tire, Mats.rubber(), "Tire"))

	# --- Felge --------------------------------------------------------------
	var rim := MeshLib.new_surface()
	# Felgenbett
	MeshLib.add_cylinder_x(rim, Vector3.ZERO, rim_radius, rim_radius, width * 0.96, 32, false)
	# Aussenhorn
	MeshLib.add_disc_x(rim, Vector3(half * 0.98 * side, 0, 0), rim_radius * 0.96,
		rim_radius * 1.04, 32, side)
	# Speichenstern sitzt leicht vertieft
	var face_x: float = side * half * 0.62
	_add_spokes(rim, face_x, side, rim_radius, spokes, rim_style, width)
	# Nabe
	MeshLib.add_cylinder_x(rim, Vector3(face_x + side * 0.02, 0, 0),
		rim_radius * 0.26, rim_radius * 0.22, 0.09, 20, true)
	root.add_child(MeshLib.finish(rim, Mats.metal(rim_color, 0.14), "Rim"))

	# Zentralverschluss
	var nut := MeshLib.new_surface()
	MeshLib.add_cylinder_x(nut, Vector3(face_x + side * 0.075, 0, 0),
		rim_radius * 0.16, rim_radius * 0.13, 0.05, 6, true)
	root.add_child(MeshLib.finish(nut, Mats.metal(Color(0.85, 0.72, 0.30), 0.22), "Nut"))

	# --- Bremse -------------------------------------------------------------
	var disc := MeshLib.new_surface()
	var disc_r: float = rim_radius * 0.86
	MeshLib.add_cylinder_x(disc, Vector3(-side * 0.02, 0, 0), disc_r, disc_r, 0.035, 32, false)
	MeshLib.add_disc_x(disc, Vector3(-side * 0.0375, 0, 0), rim_radius * 0.30, disc_r, 32, -side)
	MeshLib.add_disc_x(disc, Vector3(-side * 0.0025, 0, 0), rim_radius * 0.30, disc_r, 32, side)
	root.add_child(MeshLib.finish(disc, Mats.metal(Color(0.34, 0.35, 0.37), 0.42), "BrakeDisc"))

	var caliper := MeshLib.new_surface()
	MeshLib.add_box(caliper, Vector3(-side * 0.02, disc_r * 0.72, -disc_r * 0.30),
		Vector3(0.115, disc_r * 0.55, 0.20))
	root.add_child(MeshLib.finish(caliper, Mats.matte(Color(0.85, 0.30, 0.06), 0.35), "Caliper"))

	return root


static func _add_spokes(st: SurfaceTool, face_x: float, side: float, rim_radius: float,
		count: int, style: String, width: float) -> void:
	var inner: float = rim_radius * 0.24
	var outer: float = rim_radius * 0.99
	var thickness: float = width * 0.10
	match style:
		"aero":
			# Geschlossene Aeroscheibe mit schmalen Schlitzen
			MeshLib.add_disc_x(st, Vector3(face_x, 0, 0), inner, outer, 48, side)
			for i in count:
				var a := TAU * float(i) / float(count)
				_spoke(st, face_x + side * thickness * 0.6, a, rim_radius * 0.55, outer * 0.92,
					0.030, 0.055, thickness * 0.8)
		"turbo":
			for i in count:
				var a := TAU * float(i) / float(count)
				_spoke(st, face_x, a + 0.16, inner, outer, 0.055, 0.085, thickness)
				_spoke(st, face_x, a - 0.16, inner, outer, 0.045, 0.075, thickness * 0.9)
		_:
			# "double": klassischer Doppelspeichenstern
			for i in count:
				var a := TAU * float(i) / float(count)
				_spoke(st, face_x, a + 0.20, inner, outer, 0.050, 0.090, thickness)
				_spoke(st, face_x, a - 0.20, inner, outer, 0.050, 0.090, thickness)


static func _spoke(st: SurfaceTool, x: float, angle: float, r_in: float, r_out: float,
		w_in: float, w_out: float, thickness: float) -> void:
	var d := Vector3(0.0, sin(angle), cos(angle))
	var t := Vector3(0.0, cos(angle), -sin(angle))
	var ci := d * r_in
	var co := d * r_out
	var half_t := Vector3(thickness * 0.5, 0, 0)
	var base := Vector3(x, 0, 0)
	var loop := [
		ci - t * w_in, ci + t * w_in, co + t * w_out, co - t * w_out,
	]
	var corners := PackedVector3Array()
	for p in loop:
		corners.append(base + p - half_t)
	for p in loop:
		corners.append(base + p + half_t)
	MeshLib.add_hull_box(st, corners)
