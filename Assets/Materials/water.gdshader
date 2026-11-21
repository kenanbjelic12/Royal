shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Stylised river water: two layers of scrolling value noise, foam near banks.
uniform vec4 shallow_color : source_color = vec4(0.36, 0.85, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.08, 0.42, 0.88, 1.0);
uniform vec2 flow = vec2(0.35, 0.0);
uniform float bank_half_width = 1.0;
uniform float alpha = 0.9;
uniform bool vertical_fall = false;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (!vertical_fall) {
		VERTEX.y += sin(wpos.x * 1.7 + TIME * 2.0) * 0.025 + cos(wpos.z * 2.3 + TIME * 1.6) * 0.02;
	}
}

void fragment() {
	vec2 uv;
	float edge;
	if (vertical_fall) {
		uv = vec2(UV.x * 4.0, UV.y * 3.0 - TIME * 2.2);
		edge = 0.25;
	} else {
		uv = wpos.xz * 0.7 + flow * TIME;
		edge = smoothstep(0.55, 1.0, abs(wpos.z) / bank_half_width);
	}
	float n = noise(uv * 2.0) * 0.6 + noise(uv * 5.3 + vec2(TIME * 0.4, -TIME * 0.3)) * 0.4;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(n * 0.7 + edge * 0.6, 0.0, 1.0));
	float foam = smoothstep(0.72, 0.9, n * 0.8 + edge * 0.55);
	if (vertical_fall) {
		foam = smoothstep(0.45, 0.8, noise(vec2(UV.x * 9.0, UV.y * 2.0 - TIME * 3.0)));
	}
	col = mix(col, vec3(1.0), foam * 0.85);
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	EMISSION = col * 0.12;
}
