class_name WorldEnv
extends RefCounted
## Shared lighting setup so monsters look the same in the arena, menus and on
## card portraits (consistent visual identity).

static func make_environment(bright := 1.0) -> Environment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3d8fe6")
	sky_mat.sky_horizon_color = Color("#bfe6ff")
	sky_mat.ground_horizon_color = Color("#bfe6ff")
	sky_mat.ground_bottom_color = Color("#4d7a3a")
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color("#b8c8ff")
	env.ambient_light_energy = 0.9 * bright
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05 * bright
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	return env

static func add_lights(parent: Node, shadows := true, sun_yaw := -35.0, sun_pitch := -58.0) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(sun_pitch, sun_yaw, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = shadows
	sun.shadow_opacity = 0.72
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	parent.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_color = Color("#9fc4ff")
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	parent.add_child(fill)
	return sun
