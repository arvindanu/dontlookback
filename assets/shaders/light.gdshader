shader_type canvas_item;
render_mode unshaded;

// PASS A - runs on the WORLD layer only. Lantern lighting: the world is dark and cold,
// and a warm pool of light follows the runner's lantern (with warm bounce near its core).
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 light_pos = vec2(0.35, 0.75);
uniform float light_radius = 0.4;
uniform float darkness = 0.5;
uniform vec3 light_col = vec3(1.0, 0.72, 0.42);
uniform float warm = 0.35;
uniform float desat = 0.0;
uniform float fog = 0.0;
uniform float aspect = 1.7777778;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	vec2 d = (uv - light_pos) * vec2(aspect, 1.0);
	float dist = length(d);
	float lit = 1.0 - smoothstep(light_radius * 0.10, light_radius, dist);
	float core = 1.0 - smoothstep(0.0, light_radius * 0.45, dist);
	float dk = darkness * (1.0 - lit);
	col *= 1.0 - dk;
	col = mix(col, col * vec3(0.70, 0.78, 1.08), dk * 0.6);            // cold, blue shadows
	col += col * light_col * (lit * lit * warm + core * 0.25);          // warm lantern bounce
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), desat);
	col = mix(col, vec3(0.30, 0.28, 0.36) * (0.4 + l), fog * 0.3);
	COLOR = vec4(col, 1.0);
}
