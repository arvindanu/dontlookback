shader_type canvas_item;
render_mode unshaded;

// PASS B - runs on top of world + glow layers, below the HUD. Bloom, chromatic aberration,
// glitch bands, filmic grade, vignette, creeping red edge, grain, flashes.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float threat = 0.0;
uniform float look = 0.0;
uniform float pulse = 0.0;
uniform float glitch = 0.0;
uniform float aberration = 0.0;
uniform float grain = 0.05;
uniform float bloom = 0.4;
uniform vec4 flash_col = vec4(0.0);
uniform float aspect = 1.7777778;

const vec2 K[8] = vec2[8](
	vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
	vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 26.0);
	float n = hash(vec2(band, floor(TIME * 16.0)));
	float gband = step(0.90, n) * glitch;
	uv.x += (n - 0.5) * 0.09 * gband;
	vec2 c = uv - 0.5;
	float ab = aberration + threat * 0.0025 + look * 0.0025 + pulse * 0.0015 + gband * 0.01;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ab * 2.0).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ab * 2.0).b;
	if (bloom > 0.001) {
		vec3 b = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float r = (i % 2 == 0) ? 0.006 : 0.015;
			vec3 s = texture(screen_tex, uv + K[i] * vec2(1.0 / aspect, 1.0) * r).rgb;
			b += max(s - 0.5, vec3(0.0));
		}
		col += b * bloom * 0.3;
	}
	// filmic grade: gentle S-curve, indigo shadows, slightly warm highlights
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.22);
	col += vec3(0.010, 0.006, 0.030) * (1.0 - col);
	// creeping red at the left edge (where the creature is) + vignette
	float edge = 1.0 - smoothstep(0.0, 0.42, uv.x);
	col = mix(col, col * vec3(0.55, 0.04, 0.08), threat * edge * 0.85);
	float v = smoothstep(0.30, 0.95, length(c * vec2(1.0, 0.85) * 1.25));
	col *= 1.0 - v * (0.55 + look * 0.25 + pulse * 0.12);
	col += vec3(0.30, 0.0, 0.03) * v * threat * (0.5 + pulse * 0.5);
	col += (hash(uv * vec2(1280.0, 720.0) + fract(TIME) * 97.0) - 0.5) * grain;
	col = mix(col, flash_col.rgb, flash_col.a);
	COLOR = vec4(col, 1.0);
}
