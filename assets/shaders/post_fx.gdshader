shader_type canvas_item;
render_mode unshaded;

// Full-screen post effect: dynamic lighting mask, vignette, chromatic aberration,
// glitch bands, film grain, creeping red edge, flashes. One texture read x3.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 light_pos = vec2(0.31, 0.75);
uniform float light_radius = 0.4;
uniform float darkness = 0.5;
uniform float threat = 0.0;
uniform float look = 0.0;
uniform float pulse = 0.0;
uniform float glitch = 0.0;
uniform float aberration = 0.0;
uniform float grain = 0.05;
uniform float desat = 0.0;
uniform float fog = 0.0;
uniform vec4 flash_col = vec4(0.0);
uniform float aspect = 1.7777778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// glitch: random horizontal bands shift sideways
	float band = floor(uv.y * 26.0);
	float n = hash(vec2(band, floor(TIME * 16.0)));
	float gband = step(0.90, n) * glitch;
	uv.x += (n - 0.5) * 0.09 * gband;
	// chromatic aberration grows with threat / looking
	vec2 c = uv - 0.5;
	float ab = aberration + threat * 0.0025 + look * 0.0025 + pulse * 0.0015 + gband * 0.01;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ab * 2.0).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ab * 2.0).b;
	// lantern-style lighting around the runner
	vec2 d = (uv - light_pos) * vec2(aspect, 1.0);
	float lit = 1.0 - smoothstep(light_radius * 0.12, light_radius, length(d));
	float dk = darkness * (1.0 - lit);
	col *= 1.0 - dk;
	col = mix(col, col * vec3(0.72, 0.78, 1.05), dk * 0.55);
	// horror grading
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), desat);
	col = mix(col, vec3(0.30, 0.28, 0.36) * (0.4 + l), fog * 0.3);
	float edge = 1.0 - smoothstep(0.0, 0.42, uv.x);
	col = mix(col, col * vec3(0.55, 0.04, 0.08), threat * edge * 0.85);
	float v = smoothstep(0.30, 0.95, length(c * vec2(1.0, 0.85) * 1.25));
	col *= 1.0 - v * (0.55 + look * 0.25 + pulse * 0.12);
	col += vec3(0.30, 0.0, 0.03) * v * threat * (0.5 + pulse * 0.5);
	col += (hash(uv * vec2(1280.0, 720.0) + fract(TIME) * 97.0) - 0.5) * grain;
	col = mix(col, flash_col.rgb, flash_col.a);
	COLOR = vec4(col, 1.0);
}
