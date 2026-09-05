class_name CarBuilder
extends RefCounted

## Baut aus einer Definition aus car_data.gd ein vollstaendiges Fahrzeugmodell.
## Lokales Koordinatensystem: -Z ist vorne, +X rechts, y = 0 ist die Fahrbahn.

const RING_SEGMENTS := 44
const STATIONS := 72


## Querschnittsring an der Laengsposition t (0 = Front, 1 = Heck).
static func _ring(spec: Dictionary, t: float, inflate := 0.0,
		arc_from := 0.0, arc_to := TAU, count := RING_SEGMENTS,
		open_arc := false) -> PackedVector3Array:
	var body: Array = spec["body"]
	var length: float = spec["length"]
	var w: float = MeshLib.sample_curve(body, t, 1) + inflate
	var y_bot: float = MeshLib.sample_curve(body, t, 2) - inflate
	var y_top: float = MeshLib.sample_curve(body, t, 3) + inflate
	var n_top: float = maxf(MeshLib.sample_curve(body, t, 4), 2.0)
	var n_bot: float = maxf(MeshLib.sample_curve(body, t, 5), 2.0)
	var yc := (y_top + y_bot) * 0.5
	var h := (y_top - y_bot) * 0.5
	var z := (t - 0.5) * length

	var ring := PackedVector3Array()
	for j in count:
		var f: float = float(j) / float(count - 1 if open_arc else count)
		var u: float = lerpf(arc_from, arc_to, f)
		var cu := cos(u)
		var su := sin(u)
		var n: float = n_top if su >= 0.0 else n_bot
		var x: float = w * signf(cu) * pow(absf(cu), 2.0 / n)
		var y: float = yc + h * signf(su) * pow(absf(su), 2.0 / n)
		ring.append(Vector3(x, y, z))
	return ring


static func _ring_center(spec: Dictionary, t: float) -> Vector3:
	var body: Array = spec["body"]
	var y_bot: float = MeshLib.sample_curve(body, t, 2)
	var y_top: float = MeshLib.sample_curve(body, t, 3)
	return Vector3(0.0, (y_top + y_bot) * 0.5, (t - 0.5) * spec["length"])


static func build(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CarModel"

	var paint := Mats.car_paint(spec["paint"])
	var accent := Mats.matte(spec["accent"], 0.4)
	var carbon := Mats.carbon()

	_add_shell(root, spec, paint)
	_add_glass(root, spec)
	_add_interior(root, spec)
	_add_fenders(root, spec, paint)
	_add_aero(root, spec, carbon)
	_add_wing(root, spec, carbon, paint)
	_add_lights(root, spec)
	_add_details(root, spec, accent, carbon)
	return root


# --- Karosseriehuelle -------------------------------------------------------
static func _add_shell(root: Node3D, spec: Dictionary, paint: Material) -> void:
	var st := MeshLib.new_surface()
	var grid: Array = []
	for i in STATIONS:
		# Die Enden werden dichter abgetastet, dort ist die Kruemmung am groessten.
		var raw := float(i) / float(STATIONS - 1)
		var t: float = raw - 0.12 * sin(raw * TAU) / TAU
		grid.append(_ring(spec, clampf(t, 0.0, 1.0)))
	MeshLib.add_loft(st, grid, true, true)
	root.add_child(MeshLib.finish(st, paint, "Shell"))


# --- Verglasung -------------------------------------------------------------
static func _add_glass(root: Node3D, spec: Dictionary) -> void:
	var cabin: Array = spec["cabin"]
	var st := MeshLib.new_surface()
	var grid: Array = []
	var inside := PackedVector3Array()
	var rows := 26
	for i in rows:
		var t: float = lerpf(cabin[0], cabin[1], float(i) / float(rows - 1))
		# Minimal aufgeblasen, damit die Scheibe sauber auf dem Lack aufliegt
		# und nicht mit ihm um dieselben Pixel kaempft.
		grid.append(_ring(spec, t, 0.004, PI * 0.12, PI * 0.88, 26, true))
		inside.append(_ring_center(spec, t))
	MeshLib.add_open_patch(st, grid, inside)
	root.add_child(MeshLib.finish(st, Mats.glass(spec["glass_tint"]), "Glass"))


# --- Innenraum (durch die Scheiben sichtbar) --------------------------------
static func _add_interior(root: Node3D, spec: Dictionary) -> void:
	var cabin: Array = spec["cabin"]
	var length: float = spec["length"]
	var z_front: float = (cabin[0] - 0.5) * length
	var z_rear: float = (cabin[1] - 0.5) * length
	var st := MeshLib.new_surface()

	# Armaturenbrett
	MeshLib.add_box(st, Vector3(0, 0.72, z_front + 0.28), Vector3(1.5, 0.22, 0.5))
	# Mitteltunnel
	MeshLib.add_box(st, Vector3(0, 0.55, (z_front + z_rear) * 0.5),
		Vector3(0.28, 0.26, z_rear - z_front))
	# Zwei Schalensitze
	for s in [-1.0, 1.0]:
		var seat_z: float = z_front + (z_rear - z_front) * 0.55
		MeshLib.add_box(st, Vector3(s * 0.36, 0.60, seat_z), Vector3(0.50, 0.14, 0.52))
		MeshLib.add_box(st, Vector3(s * 0.36, 0.86, seat_z + 0.30), Vector3(0.50, 0.56, 0.14))
	# Boden
	MeshLib.add_box(st, Vector3(0, 0.46, (z_front + z_rear) * 0.5),
		Vector3(1.5, 0.05, z_rear - z_front))
	root.add_child(MeshLib.finish(st, Mats.matte(Color(0.05, 0.05, 0.055), 0.75), "Interior"))

	# Lenkrad
	var wheel := MeshLib.new_surface()
	MeshLib.add_torus_arc_x(wheel, Vector3.ZERO, 0.165, 0.022, 0.0, TAU, 26, 8)
	var mi := MeshLib.finish(wheel, Mats.matte(Color(0.07, 0.07, 0.08), 0.5), "SteeringWheel")
	mi.transform = Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -0.42),
		Vector3(-0.36, 0.80, z_front + 0.52))
	root.add_child(mi)

	# Ueberrollbuegel - beim GT-Fahrzeug sichtbares Motorsport-Detail
	if spec["wing"] == "gt":
		var cage := MeshLib.new_surface()
		var top_y: float = MeshLib.sample_curve(spec["body"], cabin[1] - 0.06, 3) - 0.10
		for s in [-1.0, 1.0]:
			var bar := PackedVector3Array()
			bar.append(Vector3(s * 0.62, 0.45, z_rear - 0.10))
			bar.append(Vector3(s * 0.60, top_y * 0.7, z_rear - 0.14))
			bar.append(Vector3(s * 0.52, top_y, z_rear - 0.22))
			_add_tube(cage, bar, 0.035)
		var cross := PackedVector3Array()
		cross.append(Vector3(-0.52, top_y, z_rear - 0.22))
		cross.append(Vector3(0.52, top_y, z_rear - 0.22))
		_add_tube(cage, cross, 0.035)
		root.add_child(MeshLib.finish(cage, Mats.metal(Color(0.5, 0.5, 0.55), 0.3), "RollCage"))


## Rohr entlang eines Polygonzugs.
static func _add_tube(st: SurfaceTool, path: PackedVector3Array, radius: float,
		sides := 10) -> void:
	if path.size() < 2:
		return
	var grid: Array = []
	for i in path.size():
		var p := path[i]
		var dir: Vector3
		if i == 0:
			dir = path[1] - path[0]
		elif i == path.size() - 1:
			dir = path[i] - path[i - 1]
		else:
			dir = path[i + 1] - path[i - 1]
		dir = dir.normalized()
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var right := dir.cross(up).normalized()
		up = right.cross(dir).normalized()
		var ring := PackedVector3Array()
		for j in sides:
			var a := TAU * float(j) / float(sides)
			ring.append(p + right * (cos(a) * radius) + up * (sin(a) * radius))
		grid.append(ring)
	MeshLib.add_loft(st, grid, true, true)


# --- Radlaeufe --------------------------------------------------------------
static func _add_fenders(root: Node3D, spec: Dictionary, paint: Material) -> void:
	var st := MeshLib.new_surface()
	var liner := MeshLib.new_surface()
	var th: float = spec["track_half"]
	for axle in ["front", "rear"]:
		var z: float = spec["front_axle_z"] if axle == "front" else spec["rear_axle_z"]
		var r: float = spec["wheel_radius_front"] if axle == "front" else spec["wheel_radius_rear"]
		var w: float = spec["tire_width_front"] if axle == "front" else spec["tire_width_rear"]
		for s in [-1.0, 1.0]:
			var c := Vector3(s * th, r, z)
			# Aufgesetzte Kotfluegelverbreiterung
			MeshLib.add_torus_arc_x(st, c, r * 1.24, 0.055, PI * 0.06, PI * 0.94, 22, 10)
			# Dunkler Radkasten dahinter
			MeshLib.add_torus_arc_x(liner, c, r * 1.20, w * 0.52, PI * 0.02, PI * 0.98, 20, 8)
	root.add_child(MeshLib.finish(st, paint, "Fenders"))
	root.add_child(MeshLib.finish(liner, Mats.matte(Color(0.02, 0.02, 0.025), 0.9),
		"WheelHousings"))


# --- Splitter, Schweller, Diffusor -----------------------------------------
static func _add_aero(root: Node3D, spec: Dictionary, carbon: Material) -> void:
	var st := MeshLib.new_surface()
	var length: float = spec["length"]
	var z_front: float = -length * 0.5
	var z_rear: float = length * 0.5
	var w_front: float = MeshLib.sample_curve(spec["body"], 0.10, 1)
	var w_rear: float = MeshLib.sample_curve(spec["body"], 0.90, 1)

	# Frontsplitter: flache Platte, vorne breiter als die Nase
	var sp := PackedVector3Array()
	sp.append(Vector3(-w_front * 1.02, 0.055, z_front - 0.10))
	sp.append(Vector3(w_front * 1.02, 0.055, z_front - 0.10))
	sp.append(Vector3(w_front * 0.98, 0.115, z_front + 0.70))
	sp.append(Vector3(-w_front * 0.98, 0.115, z_front + 0.70))
	for i in 4:
		sp.append(sp[i] + Vector3(0, 0.045, 0))
	MeshLib.add_hull_box(st, sp)

	# Seitenschweller
	for s in [-1.0, 1.0]:
		var sk := PackedVector3Array()
		var zf: float = spec["front_axle_z"] + 0.42
		var zr: float = spec["rear_axle_z"] - 0.42
		sk.append(Vector3(s * (w_front * 0.86), 0.075, zf))
		sk.append(Vector3(s * (w_front * 1.00), 0.075, zf))
		sk.append(Vector3(s * (w_rear * 1.00), 0.075, zr))
		sk.append(Vector3(s * (w_rear * 0.86), 0.075, zr))
		for i in 4:
			sk.append(sk[i] + Vector3(0, 0.16, 0))
		MeshLib.add_hull_box(st, sk)

	# Heckdiffusor mit Finnen
	var df := PackedVector3Array()
	df.append(Vector3(-w_rear * 0.90, 0.10, z_rear - 0.75))
	df.append(Vector3(w_rear * 0.90, 0.10, z_rear - 0.75))
	df.append(Vector3(w_rear * 0.86, 0.30, z_rear - 0.02))
	df.append(Vector3(-w_rear * 0.86, 0.30, z_rear - 0.02))
	for i in 4:
		df.append(df[i] + Vector3(0, 0.06, 0))
	MeshLib.add_hull_box(st, df)
	for i in 5:
		var x: float = lerpf(-w_rear * 0.72, w_rear * 0.72, float(i) / 4.0)
		MeshLib.add_box(st, Vector3(x, 0.19, z_rear - 0.38), Vector3(0.035, 0.20, 0.72))

	root.add_child(MeshLib.finish(st, carbon, "Aero"))


# --- Heckfluegel ------------------------------------------------------------
static func _add_wing(root: Node3D, spec: Dictionary, carbon: Material,
		paint: Material) -> void:
	var style: String = spec["wing"]
	var length: float = spec["length"]
	var z_rear: float = length * 0.5
	var w_rear: float = MeshLib.sample_curve(spec["body"], 0.86, 1)
	var deck_y: float = MeshLib.sample_curve(spec["body"], 0.86, 3)
	var st := MeshLib.new_surface()

	match style:
		"gt":
			# Grosser Fluegel auf zwei Schwanenhals-Streben, Blatt oberhalb des Dachs.
			var wing_y: float = MeshLib.sample_curve(spec["body"], 0.55, 3) + 0.02
			var wing_z: float = z_rear - 0.24
			var span: float = w_rear * 1.02
			var chord := 0.36
			var blade := PackedVector3Array()
			blade.append(Vector3(-span, wing_y - 0.02, wing_z - chord * 0.5))
			blade.append(Vector3(span, wing_y - 0.02, wing_z - chord * 0.5))
			blade.append(Vector3(span, wing_y - 0.10, wing_z + chord * 0.5))
			blade.append(Vector3(-span, wing_y - 0.10, wing_z + chord * 0.5))
			blade.append(Vector3(-span, wing_y + 0.035, wing_z - chord * 0.5))
			blade.append(Vector3(span, wing_y + 0.035, wing_z - chord * 0.5))
			blade.append(Vector3(span, wing_y - 0.055, wing_z + chord * 0.5))
			blade.append(Vector3(-span, wing_y - 0.055, wing_z + chord * 0.5))
			MeshLib.add_hull_box(st, blade)
			# Endplatten
			for s in [-1.0, 1.0]:
				var ep := PackedVector3Array()
				ep.append(Vector3(s * span, wing_y - 0.18, wing_z - chord * 0.85))
				ep.append(Vector3(s * span, wing_y - 0.18, wing_z + chord * 0.85))
				ep.append(Vector3(s * (span + 0.03), wing_y - 0.18, wing_z + chord * 0.85))
				ep.append(Vector3(s * (span + 0.03), wing_y - 0.18, wing_z - chord * 0.85))
				for i in 4:
					ep.append(ep[i] + Vector3(0, 0.30, 0))
				MeshLib.add_hull_box(st, ep)
			# Schwanenhals-Streben von unten an das Blatt
			for s in [-1.0, 1.0]:
				var path := PackedVector3Array()
				path.append(Vector3(s * span * 0.52, deck_y - 0.06, wing_z + 0.24))
				path.append(Vector3(s * span * 0.52, (deck_y + wing_y) * 0.5, wing_z + 0.16))
				path.append(Vector3(s * span * 0.52, wing_y - 0.02, wing_z + 0.02))
				path.append(Vector3(s * span * 0.52, wing_y - 0.012, wing_z - 0.06))
				_add_tube(st, path, 0.030, 10)
		"ducktail":
			var lip := PackedVector3Array()
			lip.append(Vector3(-w_rear * 0.94, deck_y - 0.04, z_rear - 0.52))
			lip.append(Vector3(w_rear * 0.94, deck_y - 0.04, z_rear - 0.52))
			lip.append(Vector3(w_rear * 0.86, deck_y + 0.09, z_rear - 0.10))
			lip.append(Vector3(-w_rear * 0.86, deck_y + 0.09, z_rear - 0.10))
			for i in 4:
				lip.append(lip[i] + Vector3(0, 0.05, 0))
			MeshLib.add_hull_box(st, lip)
		"active":
			var blade2 := PackedVector3Array()
			blade2.append(Vector3(-w_rear * 0.92, deck_y + 0.02, z_rear - 0.34))
			blade2.append(Vector3(w_rear * 0.92, deck_y + 0.02, z_rear - 0.34))
			blade2.append(Vector3(w_rear * 0.92, deck_y - 0.01, z_rear - 0.10))
			blade2.append(Vector3(-w_rear * 0.92, deck_y - 0.01, z_rear - 0.10))
			for i in 4:
				blade2.append(blade2[i] + Vector3(0, 0.030, 0))
			MeshLib.add_hull_box(st, blade2)
		_:
			var lip2 := PackedVector3Array()
			lip2.append(Vector3(-w_rear * 0.92, deck_y - 0.01, z_rear - 0.26))
			lip2.append(Vector3(w_rear * 0.92, deck_y - 0.01, z_rear - 0.26))
			lip2.append(Vector3(w_rear * 0.86, deck_y + 0.05, z_rear - 0.06))
			lip2.append(Vector3(-w_rear * 0.86, deck_y + 0.05, z_rear - 0.06))
			for i in 4:
				lip2.append(lip2[i] + Vector3(0, 0.035, 0))
			MeshLib.add_hull_box(st, lip2)

	# Der GT-Fluegel wirkt in Wagenfarbe zu massiv - er bleibt Carbon,
	# die kleinen Lippen bekommen dagegen Lack.
	var mat: Material = carbon if style in ["gt", "active"] else paint
	root.add_child(MeshLib.finish(st, mat, "Wing"))


# --- Leuchten ---------------------------------------------------------------
static func _add_lights(root: Node3D, spec: Dictionary) -> void:
	var length: float = spec["length"]
	var z_front: float = -length * 0.5
	var z_rear: float = length * 0.5
	var w_front: float = MeshLib.sample_curve(spec["body"], 0.12, 1)
	var w_rear: float = MeshLib.sample_curve(spec["body"], 0.92, 1)
	var y_front: float = MeshLib.sample_curve(spec["body"], 0.12, 3) - 0.10
	var y_rear: float = MeshLib.sample_curve(spec["body"], 0.92, 3) - 0.18

	var head := MeshLib.new_surface()
	if spec["headlight"] == "round":
		# Runde Hauptscheinwerfer - das Markenzeichen dieser Karosserieform.
		for s in [-1.0, 1.0]:
			var c := Vector3(s * w_front * 0.74, y_front, z_front + 0.34)
			_add_disc_z(head, c, 0.0, 0.145, 24)
			_add_disc_z(head, c + Vector3(0, 0, -0.02), 0.0, 0.115, 24)
	else:
		for s in [-1.0, 1.0]:
			var lamp := PackedVector3Array()
			var x0: float = s * w_front * 0.34
			var x1: float = s * w_front * 0.93
			lamp.append(Vector3(x0, y_front - 0.02, z_front + 0.30))
			lamp.append(Vector3(x1, y_front + 0.05, z_front + 0.42))
			lamp.append(Vector3(x1, y_front + 0.05, z_front + 0.50))
			lamp.append(Vector3(x0, y_front - 0.02, z_front + 0.38))
			for i in 4:
				lamp.append(lamp[i] + Vector3(0, 0.075, 0))
			MeshLib.add_hull_box(head, lamp)
	root.add_child(MeshLib.finish(head, Mats.headlight_glass(), "Headlights"))

	# Echte Scheinwerfer, per Taste L zuschaltbar
	var lamps := Node3D.new()
	lamps.name = "HeadlightBeams"
	lamps.visible = false
	for s in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(s * w_front * 0.72, y_front, z_front + 0.30)
		spot.rotation = Vector3(-0.06, PI, 0)
		spot.light_color = Color(0.85, 0.90, 1.0)
		spot.light_energy = 12.0
		spot.spot_range = 70.0
		spot.spot_angle = 32.0
		spot.spot_attenuation = 0.6
		spot.shadow_enabled = false
		lamps.add_child(spot)
	root.add_child(lamps)

	# Heckleuchtenband
	var tail := MeshLib.new_surface()
	var tl := PackedVector3Array()
	tl.append(Vector3(-w_rear * 0.90, y_rear, z_rear - 0.08))
	tl.append(Vector3(w_rear * 0.90, y_rear, z_rear - 0.08))
	tl.append(Vector3(w_rear * 0.88, y_rear, z_rear + 0.01))
	tl.append(Vector3(-w_rear * 0.88, y_rear, z_rear + 0.01))
	for i in 4:
		tl.append(tl[i] + Vector3(0, 0.085, 0))
	MeshLib.add_hull_box(tail, tl)
	var tail_mi := MeshLib.finish(tail, Mats.emissive(Color(1.0, 0.09, 0.06), 2.2), "Taillights")
	root.add_child(tail_mi)


## Kreisscheibe in der XY-Ebene, Normale entlang -Z (Front des Fahrzeugs).
static func _add_disc_z(st: SurfaceTool, center: Vector3, inner: float, outer: float,
		segments: int) -> void:
	var n := Vector3(0, 0, -1)
	for j in segments:
		var a0 := TAU * float(j) / float(segments)
		var a1 := TAU * float(j + 1) / float(segments)
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		if inner <= 0.0:
			MeshLib.add_tri(st, center, center + d1 * outer, center + d0 * outer, n)
		else:
			MeshLib.add_quad(st, center + d0 * inner, center + d0 * outer,
				center + d1 * outer, center + d1 * inner, n)


# --- Lufteinlaesse, Spiegel, Auspuff ---------------------------------------
static func _add_details(root: Node3D, spec: Dictionary, accent: Material,
		carbon: Material) -> void:
	var length: float = spec["length"]
	var z_front: float = -length * 0.5
	var z_rear: float = length * 0.5
	var dark := MeshLib.new_surface()

	# Frontgrill und zwei aeussere Einlaesse
	var w_front: float = MeshLib.sample_curve(spec["body"], 0.08, 1)
	MeshLib.add_box(dark, Vector3(0, 0.30, z_front + 0.16), Vector3(w_front * 0.85, 0.16, 0.22))
	for s in [-1.0, 1.0]:
		MeshLib.add_box(dark, Vector3(s * w_front * 0.66, 0.42, z_front + 0.20),
			Vector3(0.34, 0.14, 0.20))
	# Seitliche Einlaesse vor den Hinterraedern
	var w_side: float = MeshLib.sample_curve(spec["body"], 0.70, 1)
	for s in [-1.0, 1.0]:
		MeshLib.add_box(dark, Vector3(s * w_side * 0.99, 0.62, spec["rear_axle_z"] - 0.62),
			Vector3(0.08, 0.22, 0.50))
	# Heckabschluss / Motorgitter
	MeshLib.add_box(dark, Vector3(0, MeshLib.sample_curve(spec["body"], 0.90, 3) - 0.06,
		z_rear - 0.60), Vector3(w_side * 1.1, 0.06, 0.55))
	root.add_child(MeshLib.finish(dark, Mats.matte(Color(0.03, 0.03, 0.035), 0.65), "Intakes"))

	# Aussenspiegel
	var mirrors := MeshLib.new_surface()
	var cabin: Array = spec["cabin"]
	var t_mirror: float = cabin[0] + 0.04
	var w_mirror: float = MeshLib.sample_curve(spec["body"], t_mirror, 1)
	var y_mirror: float = MeshLib.sample_curve(spec["body"], t_mirror, 3) - 0.16
	var z_mirror: float = (t_mirror - 0.5) * length
	for s in [-1.0, 1.0]:
		var stalk := PackedVector3Array()
		stalk.append(Vector3(s * w_mirror * 0.92, y_mirror - 0.02, z_mirror))
		stalk.append(Vector3(s * (w_mirror + 0.16), y_mirror + 0.06, z_mirror - 0.03))
		_add_tube(mirrors, stalk, 0.022, 8)
		MeshLib.add_box(mirrors, Vector3(s * (w_mirror + 0.20), y_mirror + 0.09, z_mirror - 0.04),
			Vector3(0.10, 0.09, 0.20))
	root.add_child(MeshLib.finish(mirrors, carbon, "Mirrors"))

	# Auspuff
	if spec["exhaust"] != "none":
		var pipes := MeshLib.new_surface()
		var offsets: Array = [-0.13, 0.13] if spec["exhaust"] == "twin_center" \
			else [-0.62, -0.40, 0.40, 0.62]
		for ox in offsets:
			_add_pipe_z(pipes, Vector3(ox, 0.30, z_rear - 0.10), 0.055, 0.22)
		root.add_child(MeshLib.finish(pipes, Mats.metal(Color(0.32, 0.33, 0.35), 0.22),
			"Exhaust"))

	# Akzentstreifen auf der Motorhaube
	var stripe := MeshLib.new_surface()
	var t0 := 0.14
	var t1 := 0.30
	var rows := 8
	var grid: Array = []
	var inside := PackedVector3Array()
	for i in rows:
		var t: float = lerpf(t0, t1, float(i) / float(rows - 1))
		grid.append(_ring(spec, t, 0.006, PI * 0.42, PI * 0.58, 8, true))
		inside.append(_ring_center(spec, t))
	MeshLib.add_open_patch(stripe, grid, inside)
	root.add_child(MeshLib.finish(stripe, accent, "Stripe"))


## Rohrstueck entlang der Z-Achse (Auspuffendrohr).
static func _add_pipe_z(st: SurfaceTool, center: Vector3, radius: float, length: float) -> void:
	var path := PackedVector3Array()
	path.append(center - Vector3(0, 0, length * 0.5))
	path.append(center + Vector3(0, 0, length * 0.5))
	_add_tube(st, path, radius, 14)
