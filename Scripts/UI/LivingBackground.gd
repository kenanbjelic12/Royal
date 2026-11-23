class_name LivingBackground
extends CanvasLayer
## "Living" menu backdrop: the painted floating-castle artwork, brought to
## life with flowing waterfalls, waving flags, bobbing balloon and islands
## (shader), flickering torches, drifting clouds and mist, sun rays, birds,
## glittering dust and a slow breathing camera. Everything is placed in the
## artwork's own pixel space, so it stays aligned on every screen size.

const IMAGE := "res://Assets/UI/menu_bg.jpg"
const IMG_SIZE := Vector2(1536, 1024)
## Where the camera centres the picture (castle gate).
const FOCUS := Vector2(768, 560)

const SHADER := """
shader_type canvas_item;
uniform vec4 falls[6];      // waterfalls: x0, y0, x1, y1 in UV
uniform vec4 flags[6];      // flags: x0, y0, x1, y1 in UV
uniform vec4 bobs[2];       // bobbing regions (balloon, far island)
uniform vec2 px = vec2(1.0 / 1536.0, 1.0 / 1024.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float box_mask(vec2 uv, vec4 r, float feather) {
	vec2 a = smoothstep(r.xy, r.xy + feather, uv);
	vec2 b = 1.0 - smoothstep(r.zw - feather, r.zw, uv);
	return a.x * a.y * b.x * b.y;
}
void fragment() {
	vec2 uv = UV;
	// bobbing balloon / floating island (gentle vertical drift)
	for (int i = 0; i < 2; i++) {
		float m = box_mask(uv, bobs[i], 0.02);
		uv.y += m * sin(TIME * (0.9 + float(i) * 0.4) + float(i)) * px.y * 5.0;
	}
	// waving flags (horizontal ripple that grows toward the free end)
	for (int i = 0; i < 6; i++) {
		float m = box_mask(uv, flags[i], 0.004);
		float along = clamp((uv.x - flags[i].x) / max(flags[i].z - flags[i].x, 0.001), 0.0, 1.0);
		uv.y += m * sin(TIME * 5.0 - along * 9.0 + float(i)) * px.y * 2.2 * along;
	}
	vec4 c = texture(TEXTURE, uv);
	// flowing waterfalls: bright streaks scrolling down + foam flicker
	for (int i = 0; i < 6; i++) {
		float m = box_mask(UV, falls[i], 0.003);
		if (m > 0.0) {
			vec2 q = vec2((UV.x - falls[i].x) * 520.0, UV.y * 60.0 - TIME * 4.5);
			float s = smoothstep(0.55, 0.95, noise(q)) * 0.55 + smoothstep(0.7, 1.0, noise(q * 2.3 + 7.0)) * 0.35;
			float lum = dot(c.rgb, vec3(0.333));
			c.rgb += vec3(0.75, 0.9, 1.0) * s * m * smoothstep(0.35, 0.75, lum);
		}
	}
	// soft fade at the top and bottom so the art melts into the sky / cloud sea
	c.a *= smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
	COLOR = c;
}
"""

var stage: Node2D
var _art: Sprite2D
var _t := 0.0
var _clouds: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _rays: Node2D
var _torch_glows: Array[Sprite2D] = []
var _cloud_tex: Texture2D
var _dot_tex: Texture2D

func _ready() -> void:
	layer = -10
	# sky gradient behind the artwork (screen space)
	var g := Gradient.new()
	g.set_color(0, Color("#2a5bc4"))
	g.add_point(0.45, Color("#8cc3f2"))
	g.set_color(g.get_point_count() - 1, Color("#eef5fd"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	_sky = TextureRect.new()
	_sky.texture = gt
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	stage = Node2D.new()
	add_child(stage)
	_art = Sprite2D.new()
	_art.texture = load(IMAGE)
	_art.centered = false
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	sm.shader = sh
	var falls := [Rect2(478, 632, 46, 370), Rect2(1002, 830, 58, 194), Rect2(1118, 700, 34, 200),
		Rect2(1290, 300, 24, 150), Rect2(1398, 492, 24, 74), Rect2(338, 790, 24, 72)]
	var flags := [Rect2(762, 70, 82, 40), Rect2(936, 148, 66, 40), Rect2(1043, 322, 64, 34),
		Rect2(567, 220, 52, 30), Rect2(492, 262, 40, 26), Rect2(655, 270, 30, 24)]
	var bobs := [Rect2(100, 60, 190, 290), Rect2(1190, 230, 240, 260)]
	sm.set_shader_parameter("falls", PackedVector4Array(falls.map(_uv_rect)))
	sm.set_shader_parameter("flags", PackedVector4Array(flags.map(_uv_rect)))
	sm.set_shader_parameter("bobs", PackedVector4Array(bobs.map(_uv_rect)))
	_art.material = sm
	stage.add_child(_art)
	_cloud_tex = _make_cloud_texture()
	_dot_tex = VFX.soft_dot_texture()
	_add_sun_rays(Vector2(1530, 420))
	_add_clouds()
	_add_torch(Vector2(633, 582))
	_add_torch(Vector2(882, 582))
	_add_dust()
	_add_mist()
	for i in 3:
		_spawn_bird_flock(randf_range(0.0, 6.0))
	get_viewport().size_changed.connect(_fit)
	_fit()

func _uv_rect(r: Rect2) -> Vector4:
	return Vector4(r.position.x / IMG_SIZE.x, r.position.y / IMG_SIZE.y, r.end.x / IMG_SIZE.x, r.end.y / IMG_SIZE.y)

var _sky: TextureRect
var _base_scale := 1.0
var _base_pos := Vector2.ZERO

## Cover-fit the artwork to the screen, keeping the castle in view.
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y > vs.x:
		# portrait: show the whole floating island; sky above, cloud sea below
		_base_scale = vs.x / 1060.0
		_base_pos = Vector2(vs.x * 0.5 - FOCUS.x * _base_scale, vs.y * 0.47 - FOCUS.y * _base_scale)
	else:
		_base_scale = maxf(vs.x / IMG_SIZE.x, vs.y / IMG_SIZE.y) * 1.05
		var shown := IMG_SIZE * _base_scale
		var pos := vs * 0.5 - FOCUS * _base_scale
		pos.x = clampf(pos.x, vs.x - shown.x, 0.0)
		pos.y = clampf(pos.y, vs.y - shown.y, 0.0)
		_base_pos = pos

func _process(delta: float) -> void:
	_t += delta
	# breathing camera: slow zoom and drift around the focus point
	var z := 1.0 + 0.025 * (0.5 - 0.5 * cos(_t * 0.18))
	var drift := Vector2(sin(_t * 0.07) * 10.0, cos(_t * 0.09) * 6.0)
	stage.scale = Vector2.ONE * _base_scale * z
	var vs := get_viewport().get_visible_rect().size
	var focus_screen := _base_pos + FOCUS * _base_scale
	stage.position = focus_screen - FOCUS * _base_scale * z + drift
	stage.position.x = clampf(stage.position.x, vs.x - IMG_SIZE.x * stage.scale.x, 0.0)
	if vs.y <= vs.x:
		stage.position.y = clampf(stage.position.y, vs.y - IMG_SIZE.y * stage.scale.y, 0.0)
	for c in _clouds:
		var s: Sprite2D = c.node
		s.position.x += c.speed * delta
		if s.position.x > IMG_SIZE.x + 300:
			s.position.x = -300
	for b in _birds:
		var n: Node2D = b.node
		n.position += b.vel * delta
		for wing in n.get_children():
			(wing as Node2D).scale.y = 0.6 + 0.4 * sin(_t * 9.0 + wing.get_index())
		if n.position.x > IMG_SIZE.x + 80 or n.position.x < -80:
			b.node.queue_free()
	_birds = _birds.filter(func(b): return is_instance_valid(b.node))
	if _birds.size() < 2 and randf() < delta * 0.15:
		_spawn_bird_flock(0.0)
	if _rays:
		_rays.rotation = sin(_t * 0.1) * 0.06
		_rays.modulate.a = 0.75 + 0.25 * sin(_t * 0.6)
	for g in _torch_glows:
		var f := 0.85 + 0.15 * sin(_t * 17.0 + g.position.x) + 0.08 * sin(_t * 31.0)
		g.scale = Vector2.ONE * 1.6 * f
		g.modulate.a = 0.55 * f

# ------------------------------------------------------------------ pieces
func _make_cloud_texture() -> Texture2D:
	var w := 256
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var blobs := [Vector3(0.3, 0.6, 0.28), Vector3(0.5, 0.5, 0.34), Vector3(0.7, 0.6, 0.26), Vector3(0.45, 0.7, 0.3), Vector3(0.62, 0.42, 0.22)]
	for y in h:
		for x in w:
			var p := Vector2(float(x) / w, float(y) / h * 0.5)
			var a := 0.0
			for b: Vector3 in blobs:
				var d := p.distance_to(Vector2(b.x, b.y * 0.5)) / (b.z * 0.5)
				a = maxf(a, clampf(1.0 - d * d, 0.0, 1.0))
			var shade := lerpf(1.0, 0.88, float(y) / h)
			img.set_pixel(x, y, Color(shade, shade, minf(shade + 0.04, 1.0), a * 0.9))
	return ImageTexture.create_from_image(img)

func _add_clouds() -> void:
	# low cloud sea (in front of island bases) and high wisps
	var specs := [
		[Vector2(-100, 930), 2.6, 9.0, 0.55], [Vector2(520, 980), 3.2, 6.0, 0.6], [Vector2(1150, 940), 2.8, 8.0, 0.5],
		[Vector2(300, 860), 1.8, 12.0, 0.35], [Vector2(1300, 820), 1.6, 11.0, 0.3],
		[Vector2(200, 120), 1.4, 4.0, 0.35], [Vector2(1100, 90), 1.2, 5.0, 0.3], [Vector2(700, 40), 1.0, 3.5, 0.25],
		# cloud sea under the island and high clouds above the artwork (portrait screens)
		[Vector2(0, 1080), 4.0, 7.0, 0.95], [Vector2(700, 1120), 4.4, 5.0, 0.95], [Vector2(1400, 1090), 4.0, 6.5, 0.95],
		[Vector2(350, 1260), 4.6, 4.0, 1.0], [Vector2(1100, 1300), 4.8, 4.5, 1.0], [Vector2(-200, 1420), 5.0, 3.5, 1.0],
		[Vector2(800, 1500), 5.0, 3.0, 1.0], [Vector2(300, -120), 2.4, 3.0, 0.7], [Vector2(1250, -180), 2.8, 2.5, 0.6],
		[Vector2(800, -320), 3.0, 2.0, 0.5],
	]
	for sp in specs:
		var s := Sprite2D.new()
		s.texture = _cloud_tex
		s.position = sp[0]
		s.scale = Vector2.ONE * sp[1]
		s.modulate.a = sp[3]
		stage.add_child(s)
		_clouds.append({"node": s, "speed": sp[2]})

func _add_mist() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(0.92, 0.95, 1.0, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var s := Sprite2D.new()
	s.texture = gt
	s.centered = false
	s.position = Vector2(0, 860)
	s.scale = Vector2(IMG_SIZE.x / 8.0, 170.0 / 128.0)
	stage.add_child(s)

func _add_sun_rays(at: Vector2) -> void:
	_rays = Node2D.new()
	_rays.position = at
	stage.add_child(_rays)
	for i in 9:
		var poly := Polygon2D.new()
		var a := deg_to_rad(150 + i * 8.5)
		var w := deg_to_rad(2.2 + (i % 3))
		var r := 1300.0
		poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2(cos(a - w), sin(a - w)) * r, Vector2(cos(a + w), sin(a + w)) * r])
		poly.vertex_colors = PackedColorArray([Color(1, 0.95, 0.75, 0.22), Color(1, 0.95, 0.75, 0.0), Color(1, 0.95, 0.75, 0.0)])
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		poly.material = m
		_rays.add_child(poly)

func _add_torch(at: Vector2) -> void:
	var glow := Sprite2D.new()
	glow.texture = _dot_tex
	glow.position = at + Vector2(0, -6)
	glow.modulate = Color(1.0, 0.6, 0.2, 0.55)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	stage.add_child(glow)
	_torch_glows.append(glow)
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 26
	p.lifetime = 0.7
	p.texture = _dot_tex
	p.material = m
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, 3)
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 0.18
	p.scale_amount_max = 0.35
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.4, 0.9))
	g.add_point(0.4, Color(1.0, 0.45, 0.1, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.5, 0.1, 0.05, 0.0))
	p.color_ramp = g
	stage.add_child(p)
	var embers := CPUParticles2D.new()
	embers.position = at
	embers.amount = 6
	embers.lifetime = 1.6
	embers.texture = _dot_tex
	embers.material = m
	embers.direction = Vector2(0, -1)
	embers.spread = 35.0
	embers.gravity = Vector2(6, -20)
	embers.initial_velocity_min = 30.0
	embers.initial_velocity_max = 70.0
	embers.scale_amount_min = 0.04
	embers.scale_amount_max = 0.08
	embers.color = Color(1.0, 0.7, 0.3)
	stage.add_child(embers)

func _add_dust() -> void:
	var p := CPUParticles2D.new()
	p.position = IMG_SIZE * 0.5
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.texture = _dot_tex
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = IMG_SIZE * 0.5
	p.direction = Vector2(0.3, -1)
	p.spread = 40.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 18.0
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.08
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.7, 0.0))
	g.add_point(0.5, Color(1, 0.95, 0.7, 0.8))
	g.set_color(g.get_point_count() - 1, Color(1, 0.95, 0.7, 0.0))
	p.color_ramp = g
	stage.add_child(p)

func _spawn_bird_flock(start_offset: float) -> void:
	var dir := 1.0 if randf() < 0.6 else -1.0
	var flock := Node2D.new()
	flock.position = Vector2(-60.0 if dir > 0 else IMG_SIZE.x + 60.0, randf_range(60, 330)) + Vector2(dir * start_offset * 40.0, 0)
	stage.add_child(flock)
	for i in randi_range(3, 5):
		var bird := Line2D.new()
		bird.points = PackedVector2Array([Vector2(-7, -3), Vector2(0, 2), Vector2(7, -3)])
		bird.width = 2.2
		bird.default_color = Color(0.15, 0.18, 0.3, 0.75)
		bird.position = Vector2(-i * 16.0 * dir, (i % 2) * 9.0 + i * 3.0)
		flock.add_child(bird)
	_birds.append({"node": flock, "vel": Vector2(dir * randf_range(35, 55), randf_range(-4, 4))})
