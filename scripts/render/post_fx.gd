extends ColorRect
## Drives the full-screen shader (lighting, vignette, glitch, aberration, grain, flashes).

var game = null
var _mat: ShaderMaterial


func setup(g) -> void:
	game = g
	_mat = material as ShaderMaterial


func update_fx() -> void:
	if _mat == null or game == null:
		return
	var g = game
	var thr: float = g.creature.threat()
	var low: bool = GameState.low_fx
	var fog: float = g.fog_amount()
	_mat.set_shader_parameter("light_pos", g.light_uv())
	_mat.set_shader_parameter("light_radius", g.light_radius())
	_mat.set_shader_parameter("darkness", 0.50 + g.dark * 0.32 + fog * 0.10)
	_mat.set_shader_parameter("threat", thr)
	_mat.set_shader_parameter("look", g.look_a)
	_mat.set_shader_parameter("pulse", g.pulse)
	var gl: float = g.look_a * 0.6 + (0.3 if thr > 0.75 else 0.0)
	_mat.set_shader_parameter("glitch", 0.0 if low else gl)
	_mat.set_shader_parameter("aberration", 0.0 if low else 0.0008 + g.player.dash_curve() * 0.006)
	_mat.set_shader_parameter("grain", 0.0 if low else 0.05 + g.dark * 0.05)
	_mat.set_shader_parameter("desat", g.dark * 0.35 + g.look_a * 0.15)
	_mat.set_shader_parameter("fog", fog)
	var c: Color = g.flash_col
	_mat.set_shader_parameter("flash_col", Color(c.r, c.g, c.b, g.flash_a))
