class_name MeshLib
extends RefCounted

## Kleine Bibliothek zum Erzeugen prozeduraler Meshes.
## Alle Flaechen werden mit expliziten Normalen und UVs gebaut, damit
## Normal-Maps und Clearcoat sauber funktionieren.

# Godot rendert Vorderseiten im Uhrzeigersinn. Die Quads werden intern
# so umgedreht, dass die uebergebene Normale nach aussen zeigt.
const FLIP_WINDING := true


static func new_surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)


## Dreieck mit einer gemeinsamen Normale.
static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3,
		ua := Vector2.ZERO, ub := Vector2.RIGHT, uc := Vector2.DOWN) -> void:
	if FLIP_WINDING:
		_vert(st, a, n, ua); _vert(st, c, n, uc); _vert(st, b, n, ub)
	else:
		_vert(st, a, n, ua); _vert(st, b, n, ub); _vert(st, c, n, uc)


## Quad, dessen Ecken gegen den Uhrzeigersinn um "n" liegen.
static func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n: Vector3, uv_scale := 1.0) -> void:
	var u0 := Vector2(0, 0) * uv_scale
	var u1 := Vector2(1, 0) * uv_scale
	var u2 := Vector2(1, 1) * uv_scale
	var u3 := Vector2(0, 1) * uv_scale
	add_tri(st, a, b, c, n, u0, u1, u2)
	add_tri(st, a, c, d, n, u0, u2, u3)


## Quad mit individuellen Normalen und UVs (fuer weiche Lofts).
static func add_quad_smooth(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	if FLIP_WINDING:
		_vert(st, a, na, ua); _vert(st, c, nc, uc); _vert(st, b, nb, ub)
		_vert(st, a, na, ua); _vert(st, d, nd, ud); _vert(st, c, nc, uc)
	else:
		_vert(st, a, na, ua); _vert(st, b, nb, ub); _vert(st, c, nc, uc)
		_vert(st, a, na, ua); _vert(st, c, nc, uc); _vert(st, d, nd, ud)


## Erzeugt aus einem Gitter aus Querschnitten (Array[PackedVector3Array])
## eine glatte Huelle. Die Ringe sind geschlossen (u laeuft rundherum).
## Reihenfolge: grid[i] = Ring i, grid[i][j] = Punkt j (gegen den Uhrzeigersinn
## in der XY-Ebene betrachtet von +Z), i waechst entlang +Z.
static func add_loft(st: SurfaceTool, grid: Array, cap_start := true, cap_end := true) -> void:
	var rows := grid.size()
	if rows < 2:
		return
	var cols: int = grid[0].size()
	var normals: Array = []
	for i in rows:
		var ring: PackedVector3Array = grid[i]
		var center := _ring_center(ring)
		var nring := PackedVector3Array()
		nring.resize(cols)
		for j in cols:
			var du: Vector3 = ring[(j + 1) % cols] - ring[(j - 1 + cols) % cols]
			var i0: int = maxi(i - 1, 0)
			var i1: int = mini(i + 1, rows - 1)
			var dv: Vector3 = grid[i1][j] - grid[i0][j]
			var n := du.cross(dv)
			var radial: Vector3 = ring[j] - center
			if n.length_squared() < 1e-12:
				n = radial
			# Die Querschnitte sind sternfoermig um ihren Mittelpunkt, deshalb
			# zeigt die Normale immer vom Mittelpunkt weg. Das macht das Ergebnis
			# unabhaengig davon, in welcher Richtung der Ring aufgebaut wurde.
			if n.dot(radial) < 0.0:
				n = -n
			nring[j] = n.normalized()
		normals.append(nring)

	for i in rows - 1:
		var v0 := float(i) / float(rows - 1)
		var v1 := float(i + 1) / float(rows - 1)
		for j in cols:
			var jn := (j + 1) % cols
			var u0 := float(j) / float(cols)
			var u1 := float(j + 1) / float(cols)
			add_quad_smooth(st,
				grid[i][j], grid[i][jn], grid[i + 1][jn], grid[i + 1][j],
				normals[i][j], normals[i][jn], normals[i + 1][jn], normals[i + 1][j],
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1))

	if cap_start:
		_cap_ring(st, grid[0], _ring_center(grid[1]))
	if cap_end:
		_cap_ring(st, grid[rows - 1], _ring_center(grid[rows - 2]))


## Offene Flaeche (nicht rundum geschlossen) aus einem Punktgitter, z.B. die
## Glaskuppel ueber der Fahrgastzelle. "inside" enthaelt pro Reihe einen Punkt
## im Koerperinneren, damit die Normalen nach aussen zeigen.
static func add_open_patch(st: SurfaceTool, grid: Array, inside: PackedVector3Array) -> void:
	var rows := grid.size()
	if rows < 2:
		return
	var cols: int = grid[0].size()
	if cols < 2:
		return
	var normals: Array = []
	for i in rows:
		var ring: PackedVector3Array = grid[i]
		var nring := PackedVector3Array()
		nring.resize(cols)
		for j in cols:
			var j0: int = maxi(j - 1, 0)
			var j1: int = mini(j + 1, cols - 1)
			var i0: int = maxi(i - 1, 0)
			var i1: int = mini(i + 1, rows - 1)
			var n: Vector3 = (ring[j1] - ring[j0]).cross(grid[i1][j] - grid[i0][j])
			var radial: Vector3 = ring[j] - inside[i]
			if n.length_squared() < 1e-12:
				n = radial
			if n.dot(radial) < 0.0:
				n = -n
			nring[j] = n.normalized()
		normals.append(nring)

	for i in rows - 1:
		var v0 := float(i) / float(rows - 1)
		var v1 := float(i + 1) / float(rows - 1)
		for j in cols - 1:
			var u0 := float(j) / float(cols - 1)
			var u1 := float(j + 1) / float(cols - 1)
			add_quad_smooth(st,
				grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j],
				normals[i][j], normals[i][j + 1], normals[i + 1][j + 1], normals[i + 1][j],
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1))


static func _ring_center(ring: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	return c / float(max(ring.size(), 1))


## Schliesst einen Ring mit einem Dreiecksfaecher. Die Normale wird aus der
## Ringebene bestimmt und vom Koerperinneren weggedreht.
static func _cap_ring(st: SurfaceTool, ring: PackedVector3Array, inner_ref: Vector3) -> void:
	var c := _ring_center(ring)
	var cols := ring.size()
	if cols < 3:
		return
	var n := (ring[0] - c).cross(ring[cols / 3] - c)
	if n.length_squared() < 1e-12:
		n = c - inner_ref
	if n.dot(c - inner_ref) < 0.0:
		n = -n
	n = n.normalized()
	for j in cols:
		add_tri(st, c, ring[j], ring[(j + 1) % cols], n)


## Achsenparalleler Quader.
static func add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var p := []
	for i in 8:
		p.append(center + Vector3(
			h.x * (1.0 if (i & 1) else -1.0),
			h.y * (1.0 if (i & 2) else -1.0),
			h.z * (1.0 if (i & 4) else -1.0)))
	# +X, -X, +Y, -Y, +Z, -Z
	add_quad(st, p[1], p[5], p[7], p[3], Vector3.RIGHT)
	add_quad(st, p[4], p[0], p[2], p[6], Vector3.LEFT)
	add_quad(st, p[2], p[3], p[7], p[6], Vector3.UP)
	add_quad(st, p[4], p[5], p[1], p[0], Vector3.DOWN)
	add_quad(st, p[5], p[4], p[6], p[7], Vector3.BACK)
	add_quad(st, p[0], p[1], p[3], p[2], Vector3.FORWARD)


## Quader mit frei waehlbaren Eckpunkten (fuer Keile, Spoiler, Diffusor).
static func add_hull_box(st: SurfaceTool, c: PackedVector3Array) -> void:
	# c: 0..3 = untere Flaeche (vorne links, vorne rechts, hinten rechts, hinten links)
	#    4..7 = obere Flaeche in gleicher Reihenfolge
	var mid := Vector3.ZERO
	for v in c:
		mid += v
	mid /= 8.0
	_hull_face(st, c[4], c[5], c[6], c[7], mid)
	_hull_face(st, c[3], c[2], c[1], c[0], mid)
	_hull_face(st, c[0], c[1], c[5], c[4], mid)
	_hull_face(st, c[2], c[3], c[7], c[6], mid)
	_hull_face(st, c[1], c[2], c[6], c[5], mid)
	_hull_face(st, c[3], c[0], c[4], c[7], mid)


static func _hull_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		mid: Vector3) -> void:
	var n := _face_normal(a, b, c)
	if n.dot((a + b + c + d) * 0.25 - mid) < 0.0:
		n = -n
	add_quad(st, a, b, c, d, n)


static func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	return n.normalized() if n.length_squared() > 1e-12 else Vector3.UP


## Zylinder entlang der X-Achse (Raeder, Auspuff, Streben).
static func add_cylinder_x(st: SurfaceTool, center: Vector3, radius_a: float, radius_b: float,
		length: float, segments := 24, caps := true) -> void:
	var x0 := center.x - length * 0.5
	var x1 := center.x + length * 0.5
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	for j in segments:
		var a := TAU * float(j) / float(segments)
		var dir := Vector3(0.0, sin(a), cos(a))
		ring_a.append(Vector3(x0, center.y, center.z) + dir * radius_a)
		ring_b.append(Vector3(x1, center.y, center.z) + dir * radius_b)
	for j in segments:
		var jn := (j + 1) % segments
		var n := ((ring_a[j] - Vector3(x0, center.y, center.z)).normalized())
		var nn := ((ring_a[jn] - Vector3(x0, center.y, center.z)).normalized())
		add_quad_smooth(st, ring_a[j], ring_b[j], ring_b[jn], ring_a[jn],
			n, n, nn, nn,
			Vector2(float(j) / segments, 0), Vector2(float(j) / segments, 1),
			Vector2(float(jn) / segments, 1), Vector2(float(jn) / segments, 0))
	if caps:
		var ca := Vector3(x0, center.y, center.z)
		var cb := Vector3(x1, center.y, center.z)
		for j in segments:
			var jn := (j + 1) % segments
			add_tri(st, ca, ring_a[j], ring_a[jn], Vector3.LEFT)
			add_tri(st, cb, ring_b[jn], ring_b[j], Vector3.RIGHT)


## Scheibe (Ring) in der YZ-Ebene, Normale entlang X.
static func add_disc_x(st: SurfaceTool, center: Vector3, inner: float, outer: float,
		segments := 24, face := 1.0) -> void:
	var n := Vector3(face, 0, 0)
	for j in segments:
		var a0 := TAU * float(j) / float(segments)
		var a1 := TAU * float(j + 1) / float(segments)
		var d0 := Vector3(0.0, sin(a0), cos(a0))
		var d1 := Vector3(0.0, sin(a1), cos(a1))
		var p0 := center + d0 * inner
		var p1 := center + d1 * inner
		var p2 := center + d1 * outer
		var p3 := center + d0 * outer
		if face > 0.0:
			add_quad(st, p0, p3, p2, p1, n)
		else:
			add_quad(st, p0, p1, p2, p3, n)


## Torus-Segment um die X-Achse (Radlaufverbreiterungen).
static func add_torus_arc_x(st: SurfaceTool, center: Vector3, major: float, minor: float,
		angle_from: float, angle_to: float, arc_seg := 20, ring_seg := 10,
		squash := 1.0) -> void:
	var grid: Array = []
	for i in arc_seg + 1:
		var t := float(i) / float(arc_seg)
		var a: float = lerpf(angle_from, angle_to, t)
		var c := center + Vector3(0.0, sin(a) * major * squash, cos(a) * major)
		var ring := PackedVector3Array()
		for j in ring_seg:
			var b := TAU * float(j) / float(ring_seg)
			var radial := Vector3(0.0, sin(a), cos(a))
			ring.append(c + radial * (cos(b) * minor) + Vector3(sin(b) * minor, 0, 0))
		grid.append(ring)
	add_loft(st, grid, true, true)


## Fertiges MeshInstance3D aus einem SurfaceTool bauen.
static func finish(st: SurfaceTool, material: Material, name := "Part") -> MeshInstance3D:
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## Catmull-Rom Interpolation ueber eine Stuetzstellen-Liste [[t, v0, v1, ...], ...]
static func sample_curve(controls: Array, t: float, channel: int) -> float:
	var n := controls.size()
	if n == 0:
		return 0.0
	if n == 1:
		return controls[0][channel]
	var i := 0
	while i < n - 2 and t > float(controls[i + 1][0]):
		i += 1
	var t0: float = controls[i][0]
	var t1: float = controls[i + 1][0]
	var f: float = 0.0 if is_equal_approx(t0, t1) else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	var p1: float = controls[i][channel]
	var p2: float = controls[i + 1][channel]
	var p0: float = controls[maxi(i - 1, 0)][channel]
	var p3: float = controls[mini(i + 2, n - 1)][channel]
	# Catmull-Rom
	var f2 := f * f
	var f3 := f2 * f
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f3)
