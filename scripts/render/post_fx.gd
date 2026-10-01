extends ColorRect
## Drives one of the two full-screen shader passes.
##   kind = "light" : lantern lighting on the world layer      (light.gdshader)
##   kind = "grade" : bloom / aberration / vignette / grain    (grade.gdshader)

@export var kind: String = "light"

var game = null
var _mat: ShaderMaterial


func setup(g) -> void:
	game = g
	_mat = material as ShaderMaterial


func update_fx() -> void:
	if _mat == null or game == null:
		return
	var g = game
	var aspect := Cfg.view_w / Cfg.view_h
	_mat.set_shader_parameter("aspect", aspect)
	if kind == "light":
		var fog: float = g.fog_amount()
		_mat.set_shader_parameter("light_pos", g.light_uv())
		_mat.set_shader_parameter("light_radius", g.light_radius())
		_mat.set_shader_parameter("darkness", 0.50 + g.dark * 0.32 + fog * 0.10)
		_mat.set_shader_parameter("desat", g.dark * 0.30 + g.look_a * 0.12 + g.death_desat)
		_mat.set_shader_parameter("fog", fog)
		return
	var thr: float = g.creature.threat()
	var low: bool = GameState.low_fx
	var gl: float = g.look_a * 0.6 + (0.3 if thr > 0.75 else 0.0)
	_mat.set_shader_parameter("threat", thr)
	_mat.set_shader_parameter("look", g.look_a)
	_mat.set_shader_parameter("pulse", g.pulse)
	_mat.set_shader_parameter("glitch", 0.0 if low else gl)
	_mat.set_shader_parameter("aberration", 0.0 if low else 0.0008 + g.player.dash_curve() * 0.006)
	_mat.set_shader_parameter("grain", 0.0 if low else 0.05 + g.dark * 0.05)
	_mat.set_shader_parameter("bloom", 0.0 if low else 0.45)
	var c: Color = g.flash_col
	_mat.set_shader_parameter("flash_col", Color(c.r, c.g, c.b, g.flash_a))
