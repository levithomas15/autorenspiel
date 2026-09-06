class_name Mats
extends RefCounted

## Materialfabrik. Alle Texturen werden prozedural aus FastNoiseLite erzeugt,
## damit das Projekt ohne externe Dateien auskommt.

# Die prozeduralen Huellen werden beidseitig gerendert. Das kostet bei diesen
# Polygonzahlen praktisch nichts und macht das Ergebnis unabhaengig davon,
# wie herum die Dreiecke gewickelt sind.
const TWO_SIDED := true

static var _cache: Dictionary = {}


static func _apply_common(m: StandardMaterial3D) -> StandardMaterial3D:
	if TWO_SIDED:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## `low` und `high` begrenzen den Wertebereich der Textur.
##
## Wichtig fuer Rauheitskarten: Godot multipliziert `roughness` mit dem
## Texturwert. Eine ungebremste Rauschtextur laeuft bis 0 herunter und macht
## die Flaeche dort spiegelglatt - der Asphalt warf dann ein riesiges weisses
## Glanzband der Sonne zurueck. Mit einem Boden von etwa 0.7 bleibt die
## Struktur sichtbar, ohne dass die Rauheit zusammenbricht.
static func noise_texture(freq: float, octaves: int, seed_value: int, size := 512,
		normal_map := false, bump := 1.0, low := 0.0, high := 1.0) -> NoiseTexture2D:
	var key := "noise_%f_%d_%d_%d_%s_%f_%f_%f" % [freq, octaves, seed_value, size,
		normal_map, bump, low, high]
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = octaves
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.noise = n
	tex.as_normal_map = normal_map
	tex.bump_strength = bump
	if not normal_map and (low > 0.0 or high < 1.0):
		var ramp := Gradient.new()
		ramp.set_color(0, Color(low, low, low))
		ramp.set_color(1, Color(high, high, high))
		tex.color_ramp = ramp
	_cache[key] = tex
	return tex


## Metallic-Lack mit Klarlackschicht - die Basis fuer alle vier Autos.
static func car_paint(color: Color, metallic := 0.9, roughness := 0.16,
		flake := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.metallic_specular = 0.6
	m.roughness = roughness
	# Feiner Metallic-Effekt: die Rauheit wird minimal aufgebrochen, dadurch
	# funkelt der Lack im Streiflicht wie echter Metallic-Lack.
	if flake > 0.0:
		m.roughness_texture = noise_texture(0.9, 4, 12, 256, false, 1.0, 0.62, 1.0)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness = clampf(roughness + flake * 0.12, 0.02, 1.0)
		m.normal_enabled = true
		m.normal_texture = noise_texture(1.4, 3, 12, 256, true, 0.35)
		m.normal_scale = flake * 0.06
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.03
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	m.uv1_scale = Vector3(3, 3, 3)
	return _apply_common(m)


## Getoentes Glas fuer Scheiben und Kuppeln.
static func glass(tint := Color(0.04, 0.05, 0.07), alpha := 0.72) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.metallic = 0.35
	m.metallic_specular = 0.9
	m.roughness = 0.04
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.0
	# Scheiben und Kuppel sind einlagige Flaechen. Beidseitiges Rendern kostet
	# hier nichts und stellt sicher, dass sie aus jeder Richtung sichtbar sind.
	return _apply_common(m)


## Sichtcarbon fuer Splitter, Diffusor, Fluegel.
static func carbon(tone := Color(0.055, 0.058, 0.065)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tone
	m.metallic = 0.55
	m.metallic_specular = 0.65
	m.roughness = 0.28
	m.normal_enabled = true
	m.normal_texture = noise_texture(6.0, 2, 44, 256, true, 0.6)
	m.normal_scale = 0.35
	m.clearcoat_enabled = true
	m.clearcoat = 0.8
	m.clearcoat_roughness = 0.1
	m.uv1_scale = Vector3(8, 8, 8)
	return _apply_common(m)


static func rubber() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.045, 0.045, 0.05)
	m.metallic = 0.0
	m.roughness = 0.85
	m.normal_enabled = true
	m.normal_texture = noise_texture(9.0, 3, 7, 256, true, 0.8)
	m.normal_scale = 0.5
	m.uv1_scale = Vector3(6, 6, 6)
	return _apply_common(m)


static func metal(color := Color(0.62, 0.65, 0.7), rough := 0.18) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 1.0
	m.metallic_specular = 0.8
	m.roughness = rough
	return _apply_common(m)


static func matte(color: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = rough
	return _apply_common(m)


static func emissive(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return _apply_common(m)


## Scheinwerferglas: klar, leicht spiegelnd, mit Restleuchten.
static func headlight_glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.88, 0.95, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.9
	m.roughness = 0.03
	m.emission_enabled = true
	m.emission = Color(0.75, 0.82, 1.0)
	m.emission_energy_multiplier = 0.6
	return _apply_common(m)


static func asphalt() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# Die eigentliche Farbe kommt aus den Vertex-Farben: so lassen sich
	# Fahrbahn, Randlinien und Start-Ziel-Karo in einem Mesh mischen.
	m.albedo_color = Color.WHITE
	m.metallic = 0.0
	m.roughness = 0.72
	m.roughness_texture = noise_texture(3.0, 4, 91, 512, false, 1.0, 0.72, 1.0)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = noise_texture(4.5, 4, 91, 512, true, 1.1)
	m.normal_scale = 0.8
	m.ao_enabled = true
	m.ao_texture = noise_texture(2.0, 3, 91, 512)
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.35
	m.uv1_scale = Vector3(1, 1, 1)
	m.vertex_color_use_as_albedo = true
	return _apply_common(m)


static func grass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.metallic = 0.0
	m.roughness = 0.95
	m.normal_enabled = true
	m.normal_texture = noise_texture(2.5, 4, 33, 512, true, 1.4)
	m.normal_scale = 1.0
	m.albedo_color = Color.WHITE
	m.uv1_scale = Vector3(1, 1, 1)
	m.vertex_color_use_as_albedo = true
	return _apply_common(m)


## Randsteine und Fahrbahnmarkierungen nutzen Vertex-Farben,
## damit rot/weiss ohne eigene Textur wechseln kann.
static func vertex_colored(rough := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.metallic = 0.0
	m.roughness = rough
	return _apply_common(m)


static func guardrail() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.57, 0.6)
	m.metallic = 0.95
	m.roughness = 0.35
	m.normal_enabled = true
	m.normal_texture = noise_texture(7.0, 2, 55, 256, true, 0.7)
	m.normal_scale = 0.4
	m.vertex_color_use_as_albedo = true
	return _apply_common(m)
