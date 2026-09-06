class_name WorldEnv
extends RefCounted

## Beleuchtung und Post-Processing. Zwei Presets: Rennstrecke bei tief
## stehender Sonne und Studiolicht fuer die Garage.

static func race() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.33, 0.62)
	sky_material.sky_horizon_color = Color(0.68, 0.74, 0.82)
	sky_material.sky_curve = 0.12
	sky_material.sky_energy_multiplier = 1.15
	sky_material.ground_bottom_color = Color(0.12, 0.14, 0.13)
	sky_material.ground_horizon_color = Color(0.55, 0.58, 0.58)
	sky_material.sun_angle_max = 6.0
	sky_material.sun_curve = 0.06
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0

	# Globale Beleuchtung: Farbe des Asphalts faerbt die Karosserie von unten.
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_cascades = 5
	env.sdfgi_min_cell_size = 0.3
	env.sdfgi_energy = 1.1

	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_intensity = 0.7

	# Spiegelungen auf Lack und nasser wirkendem Asphalt
	env.ssr_enabled = true
	env.ssr_max_steps = 56
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 3.0
	env.ssr_depth_tolerance = 0.3

	# Glow ist im Kompatibilitaetsmodus eine teure Vollbildunschaerfe.
	env.glow_enabled = not OS.has_feature("web") and Device.kind == Device.Kind.DESKTOP
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.74, 0.85)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.4
	env.fog_aerial_perspective = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.011
	env.volumetric_fog_length = 220.0
	env.volumetric_fog_gi_inject = 0.6

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	env.adjustment_brightness = 1.0

	var node := WorldEnvironment.new()
	node.name = "RaceEnvironment"
	node.environment = env
	node.camera_attributes = _camera_attributes(1.0)
	return node


static func garage() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.022, 0.024, 0.030)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.34, 0.42)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 3.0
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_out = 6.0

	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.02

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.05

	var node := WorldEnvironment.new()
	node.name = "GarageEnvironment"
	node.environment = env
	node.camera_attributes = _camera_attributes(1.0)
	return node


static func _camera_attributes(exposure: float) -> CameraAttributesPractical:
	var attributes := CameraAttributesPractical.new()
	attributes.exposure_multiplier = exposure
	attributes.dof_blur_far_enabled = false
	attributes.dof_blur_near_enabled = false
	return attributes


## Tief stehende Nachmittagssonne - lange Schatten, warmes Streiflicht auf dem Lack.
static func sun() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(128.0), 0.0)
	light.light_color = Color(1.0, 0.93, 0.83)
	light.light_energy = 2.6
	light.light_angular_distance = 0.6
	light.shadow_enabled = true
	light.shadow_bias = 0.035
	light.shadow_normal_bias = 1.4
	light.shadow_blur = 1.1
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_max_distance = 260.0
	if not Device.shadows_enabled():
		# Auf dem Handy sind Sonnenschatten der teuerste einzelne Posten.
		light.shadow_enabled = false
	elif Device.shadow_distance() < 200.0:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = Device.shadow_distance()
		light.light_angular_distance = 0.0
	light.directional_shadow_split_1 = 0.06
	light.directional_shadow_split_2 = 0.16
	light.directional_shadow_split_3 = 0.42
	light.directional_shadow_blend_splits = true
	return light


## Drei Studioleuchten fuer die Garage: Fuehrungslicht, Aufheller, Kante.
static func studio_lights() -> Node3D:
	var root := Node3D.new()
	root.name = "StudioLights"
	var setups := [
		{"pos": Vector3(4.5, 5.0, 4.0), "color": Color(1.0, 0.96, 0.92), "energy": 26.0,
			"size": 3.0, "shadow": true},
		{"pos": Vector3(-5.5, 3.4, 2.0), "color": Color(0.62, 0.74, 1.0), "energy": 18.0,
			"size": 4.0, "shadow": false},
		{"pos": Vector3(0.0, 3.0, -6.0), "color": Color(1.0, 0.72, 0.86), "energy": 22.0,
			"size": 3.0, "shadow": false},
	]
	for setup in setups:
		var light := OmniLight3D.new()
		light.position = setup["pos"]
		light.light_color = setup["color"]
		light.light_energy = setup["energy"]
		light.omni_range = 22.0
		light.omni_attenuation = 1.4
		light.light_size = setup["size"]
		light.shadow_enabled = setup["shadow"]
		light.shadow_bias = 0.02
		root.add_child(light)
	return root
