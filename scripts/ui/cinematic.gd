extends Control
## First-boot cinematic. Plays exactly ONCE, ever (GameState.cinematic_done is saved when it ends or is
## skipped). Fully procedural 2D, like the rest of the game. Timeline:
##    0.0 -  8.0  night forest, slow dolly toward a small house, in through the lit window
##    8.0 - 16.0  inside: the runner at a PC, typing
##   16.0         POWER CUT - the room dies, the PC stays on
##   16.0 - 20.8  panic; the monitor types "404: Alive"
##   20.8 - 24.0  the screen glitches and tears
##   24.0 - 27.6  pulled into the monitor, white flash, straight into the first run

const GAME_SCENE := "res://scenes/game.tscn"
const T_ENTER := 8.0
const T_BLACKOUT := 16.0
const T_TEXT := 18.4
const T_GLITCH := 20.8
const T_PULL := 24.0
const T_FLASH := 27.6
const DUR := 28.3
const WIN := Vector2(672.0, 462.0)    # the cabin's lit window (design space 1280x720)
const MON := Vector2(800.0, 410.0)    # monitor centre inside the room
const HIP := Vector2(520.0, 565.0)    # the seated runner's hip
const BEZ_HALF := Vector2(165.0, 105.0)

var t := 0.0
var _done := false
var _fired := {}
var _type_t := 0.0
var _glitch_t := 0.0
var _hb_t := 0.0
var _base := Transform2D.IDENTITY   # design space -> screen ("cover" fit)
var _cur := Transform2D.IDENTITY    # base * current camera
var _skip: FancyButton
var _amb: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _pc: AudioStreamPlayer
var _mus: AudioStreamPlayer
var _riser: AudioStreamPlayer
var _scan := PackedVector2Array()
var _scan_h := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Transition.boot_fade(1.6)
	_amb = _loop_player("cine_ambience", "Ambience")
	_hum = _loop_player("cine_hum", "Ambience")
	_pc = _loop_player("cine_pc", "Ambience")
	_mus = _one_player("cine_music", "Music")
	_riser = _one_player("cine_riser", "SFX")
	_skip = FancyButton.new()
	_skip.label = "SKIP"
	_skip.style = FancyButton.Style.GHOST
	_skip.font_size = 16
	_skip.modulate.a = 0.0
	_skip.pressed.connect(_finish.bind(true))
	add_child(_skip)
	resized.connect(_place_skip)
	_place_skip()


func _place_skip() -> void:
	var u := Cfg.ui_scale()
	_skip.size = Vector2(124.0, 46.0) * u
	_skip.position = Vector2(size.x - Cfg.safe.z - 34.0 * u - _skip.size.x, maxf(4.0, (size.y * 0.075 - _skip.size.y) * 0.5))


# ------------------------------------------------------------------ audio
func _stream(n: String) -> AudioStreamWAV:
	var path := "res://assets/sounds/%s.wav" % n
	if ResourceLoader.exists(path):
		return load(path) as AudioStreamWAV
	return null


func _loop_player(n: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -60.0
	add_child(p)
	var st := _stream(n)
	if st != null:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() >> 1
		p.stream = st
		p.play()
	return p


func _one_player(n: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -60.0
	add_child(p)
	p.stream = _stream(n)   # a missing file just leaves the player silent
	return p


func _set_db(p: AudioStreamPlayer, db: float, k: float) -> void:
	p.volume_db = lerpf(p.volume_db, db, k)


func _once(key: String, at: float) -> bool:
	if t >= at and not _fired.has(key):
		_fired[key] = true
		return true
	return false


## Levels follow the story: wind outside -> muffled room + mains hum -> power cut (hum dies, the PC's fan
## and whine come up louder) -> riser + music swell -> everything fades out into the flash.
func _audio(dt: float) -> void:
	var out := clampf((DUR - t) / 0.5, 0.0, 1.0)
	var odb := linear_to_db(maxf(out, 0.0001))
	var k := 1.0 - exp(-6.0 * dt)
	var inside := smoothstep(T_ENTER - 0.8, T_ENTER + 0.4, t)
	_set_db(_amb, lerpf(-13.0, -23.0, inside) + (4.0 if t >= T_BLACKOUT else 0.0) + odb, k)
	var hum_db := -60.0
	if t >= T_ENTER - 0.4 and t < T_BLACKOUT:
		hum_db = -27.0 + 5.0 * smoothstep(T_BLACKOUT - 2.0, T_BLACKOUT, t)
	_set_db(_hum, hum_db, 1.0 - exp(-14.0 * dt))
	var pc_db := -60.0
	if t >= T_ENTER:
		pc_db = -38.0
	if t >= T_BLACKOUT:
		pc_db = -19.0 + 5.0 * smoothstep(T_GLITCH, T_PULL, t) + odb
	_set_db(_pc, pc_db, k)
	_pc.pitch_scale = 1.0 + 0.05 * smoothstep(T_GLITCH, T_PULL, t) + 0.04 * sin(t * 30.0) * smoothstep(T_GLITCH, T_GLITCH + 1.0, t)
	_set_db(_mus, -22.0 + 12.0 * smoothstep(0.0, T_FLASH, t) + odb, k)
	_riser.volume_db = -13.0 + odb


func _cues(dt: float) -> void:
	if _once("music", 0.4) and _mus.stream != null:
		_mus.play()
	if t > T_ENTER + 0.6 and t < T_BLACKOUT - 0.5:   # typing
		_type_t -= dt
		if _type_t <= 0.0:
			_type_t = randf_range(0.07, 0.28)
			Audio.play(&"cine_type", randf_range(-14.0, -9.0), randf_range(0.9, 1.2))
	if _once("enter", T_ENTER - 0.3):
		Audio.play(&"look_in", -12.0, 0.65)   # a soft rush as we slip through the glass
	for ft in [T_BLACKOUT - 1.05, T_BLACKOUT - 0.5, T_BLACKOUT - 0.28]:   # the lights stutter first
		if _once("fl%.2f" % ft, ft):
			Audio.play(&"cine_zap", -9.0, randf_range(0.9, 1.1))
	if _once("off", T_BLACKOUT):
		Audio.play(&"cine_power_off", -2.0, 1.0)
		Audio.play(&"boom", -10.0, 0.8)
	if _once("riser", T_BLACKOUT + 0.3) and _riser.stream != null:
		_riser.play()
	if t > T_BLACKOUT + 0.8 and t < T_PULL:   # a heartbeat that speeds up
		_hb_t -= dt
		if _hb_t <= 0.0:
			var k := smoothstep(T_BLACKOUT + 0.8, T_PULL, t)
			_hb_t = lerpf(1.0, 0.45, k)
			Audio.play(&"heartbeat", lerpf(-12.0, -3.0, k), 1.0 + 0.1 * k)
	if _once("wake", T_TEXT - 0.4):
		Audio.play(&"cine_wake", -4.0, 1.0)
	if t > T_GLITCH - 0.3 and t < T_PULL:   # digital stutter
		_glitch_t -= dt
		if _glitch_t <= 0.0:
			_glitch_t = randf_range(0.18, 0.5)
			Audio.play(&"cine_glitch", randf_range(-9.0, -3.0), randf_range(0.8, 1.3))
	for wt in [T_GLITCH + 0.5, T_GLITCH + 1.9, T_PULL - 0.8]:
		if _once("wh%.2f" % wt, wt):
			Audio.play_whisper()
	if _once("pull", T_PULL - 0.2):
		Audio.play(&"cine_pull", -3.0, 1.0)
	if _once("hit", T_FLASH - 0.15):
		Audio.play(&"cine_impact", -1.0, 1.0)
		Audio.play(&"boom", -3.0, 0.7)


# ------------------------------------------------------------------ flow
func _process(delta: float) -> void:
	if _done:
		return
	var dt := minf(delta, 0.1)
	t += dt
	_skip.modulate.a = smoothstep(0.9, 1.7, t) * 0.85
	_cues(dt)
	_audio(dt)
	queue_redraw()
	if t >= DUR:
		_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_finish(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_finish(true)


## Completed or skipped: remember it locally, then go into the first run.
## Completed = we are already full-screen white, so the scene swap is invisible (the game opens with the
## same flash fading out). Skipped = the normal fade through black.
func _finish(skipped: bool) -> void:
	if _done:
		return
	_done = true
	GameState.mark_cinematic_done()
	GameState.from_cinematic = not skipped
	if skipped:
		Transition.go(GAME_SCENE)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)


func _exit_tree() -> void:
	if not _done:   # closed some other way: still counts as seen
		GameState.mark_cinematic_done()


# ------------------------------------------------------------------ camera helpers
func _cam(z: float, f: Vector2, pan: Vector2 = Vector2.ZERO) -> void:
	_cur = _base * Transform2D(Vector2(z, 0.0), Vector2(0.0, z), f + pan - f * z)
	draw_set_transform_matrix(_cur)


func _cam2(z: float, c: Vector2) -> void:
	_cur = _base * Transform2D(Vector2(z, 0.0), Vector2(0.0, z), Vector2(640.0, 360.0) - c * z)
	draw_set_transform_matrix(_cur)


func _lt(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


# ------------------------------------------------------------------ frame
func _draw() -> void:
	var W := size.x
	var H := size.y
	var s := maxf(W / 1280.0, H / 720.0)
	_base = Transform2D(Vector2(s, 0.0), Vector2(0.0, s), Vector2((W - 1280.0 * s) * 0.5, (H - 720.0 * s) * 0.5))
	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.008, 0.004, 0.016))
	if t < T_ENTER:
		_exterior()
	else:
		_interior()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_overlays(W, H)


# ================================================================== EXTERIOR
func _exterior() -> void:
	var k := clampf(t / T_ENTER, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var z := pow(34.0, e)   # a slow start that accelerates toward the window
	var pan := (Vector2(640.0, 360.0) - WIN) * e + Vector2(sin(t * 0.25) * 12.0 * (1.0 - e), 0.0)
	# sky, stars, moon, one thin cloud (barely parallaxes)
	_cam(1.0 + (z - 1.0) * 0.02, WIN, pan * 0.02)
	Gfx.vquad(self, -1600.0, 2900.0, -1300.0, 470.0, Color(0.02, 0.025, 0.09), Color(0.17, 0.12, 0.30))
	Gfx.glow_ellipse(self, Vector2(640.0, 470.0), 1500.0, 170.0, Color(0.55, 0.40, 0.55, 0.22))
	for i in 90:
		var fi := float(i)
		var tw := 0.55 + 0.45 * sin(t * (1.0 + Gfx.hash1(fi + 5.0) * 2.0) + fi)
		draw_circle(Vector2(-300.0 + Gfx.hash1(fi) * 1900.0, -250.0 + Gfx.hash1(fi + 100.0) * 640.0), 0.8 + Gfx.hash1(fi + 9.0) * 1.1, Color(1.0, 0.96, 0.9, 0.6 * tw))
	var moon := Vector2(930.0, 140.0)
	Gfx.glow(self, moon, 340.0, Color(0.75, 0.8, 1.0, 0.20))
	Gfx.glow(self, moon, 110.0, Color(0.85, 0.88, 1.0, 0.30))
	draw_circle(moon, 38.0, Color(0.93, 0.93, 0.86))
	draw_circle(moon + Vector2(-10.0, -6.0), 8.0, Color(0.74, 0.74, 0.7, 0.55))
	draw_circle(moon + Vector2(12.0, 9.0), 5.5, Color(0.74, 0.74, 0.7, 0.55))
	Gfx.glow_ellipse(self, Vector2(400.0 + fposmod(t * 6.0, 600.0), 120.0), 260.0, 22.0, Color(0.5, 0.5, 0.75, 0.10))
	# mountains, far forest, near forest
	_cam(1.0 + (z - 1.0) * 0.06, WIN, pan * 0.06)
	_ridge(430.0, 70.0, 0.0060, Color(0.07, 0.06, 0.15), 1.0)
	_ridge(450.0, 55.0, 0.0090, Color(0.05, 0.045, 0.11), 3.0)
	_cam(1.0 + (z - 1.0) * 0.2, WIN, pan * 0.2)
	_pines(470.0, 150.0, 70.0, Color(0.035, 0.04, 0.09), 1.0)
	_cam(1.0 + (z - 1.0) * 0.45, WIN, pan * 0.45)
	_pines(490.0, 215.0, 105.0, Color(0.02, 0.025, 0.055), 7.0)
	# the clearing + the house (full parallax: this is what we fly into)
	_cam(z, WIN, pan)
	Gfx.vquad(self, -1600.0, 2900.0, 500.0, 1100.0, Color(0.035, 0.045, 0.07), Color(0.01, 0.012, 0.02))
	_house()
	# drifting mist, fireflies, framing trunks
	_cam(1.0 + (z - 1.0) * 0.9, WIN, pan * 0.9)
	for i in 4:
		var mx := fposmod(float(i) * 420.0 + t * (6.0 + float(i) * 2.0), 2200.0) - 500.0
		Gfx.glow_ellipse(self, Vector2(mx, 497.0 + float(i) * 6.0), 380.0, 30.0, Color(0.55, 0.6, 0.85, 0.08))
	_cam(1.0 + (z - 1.0) * 1.1, WIN, pan * 1.1)
	for i in 16:
		var fi2 := float(i)
		var fp := Vector2(300.0 + Gfx.hash1(fi2 + 200.0) * 700.0, 330.0 + Gfx.hash1(fi2 + 210.0) * 190.0) + Vector2(sin(t * 0.6 + fi2) * 20.0, cos(t * 0.5 + fi2 * 1.7) * 14.0)
		Gfx.glow(self, fp, 5.0, Color(1.0, 0.85, 0.45, 0.5 * (0.5 + 0.5 * sin(t * 2.0 + fi2 * 2.0))))
	_cam(1.0 + (z - 1.0) * 1.5, WIN, pan * 1.5)
	_trunk(40.0, 90.0, -1.0)
	_trunk(1240.0, 80.0, 1.0)


func _ridge(base: float, amp: float, fq: float, col: Color, ph: float) -> void:
	var pts := PackedVector2Array()
	var x := -1600.0
	while x <= 2900.0:
		pts.append(Vector2(x, base - amp * (0.55 + 0.45 * sin(x * fq + ph)) - amp * 0.35 * sin(x * fq * 2.7 + ph * 2.0)))
		x += 70.0
	pts.append(Vector2(2900.0, 900.0))
	pts.append(Vector2(-1600.0, 900.0))
	draw_colored_polygon(pts, col)


func _pines(base: float, h: float, step: float, col: Color, seed_v: float) -> void:
	var x := -1500.0
	var i := 0
	while x < 2800.0:
		var hh := h * (0.65 + Gfx.hash1(seed_v + float(i)) * 0.7)
		_pine(Vector2(x + Gfx.hash1(seed_v + float(i) * 3.7) * step * 0.6, base), hh, hh * 0.34, col)
		x += step
		i += 1
	draw_rect(Rect2(-1600.0, base - 2.0, 4500.0, 400.0), col)


func _pine(b: Vector2, h: float, w: float, col: Color) -> void:
	var r := PackedVector2Array()
	for j in 4:
		var yj := b.y - h + h * (0.30 + 0.19 * float(j))
		var wj := w * (0.42 + 0.19 * float(j))
		r.append(Vector2(wj, yj))
		if j < 3:
			r.append(Vector2(wj * 0.42, yj - h * 0.015))
	var pts := PackedVector2Array([Vector2(b.x, b.y - h)])
	for q in r:
		pts.append(Vector2(b.x + q.x, q.y))
	pts.append(Vector2(b.x + 3.0, b.y))
	pts.append(Vector2(b.x - 3.0, b.y))
	for i in range(r.size() - 1, -1, -1):
		pts.append(Vector2(b.x - r[i].x, r[i].y))
	draw_colored_polygon(pts, col)


func _trunk(x: float, w: float, side: float) -> void:
	var col := Color(0.012, 0.01, 0.02)
	draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, 900.0), Vector2(x + w * 0.5, 900.0), Vector2(x + w * 0.34, -500.0), Vector2(x - w * 0.34, -500.0)]), col)
	draw_line(Vector2(x, 210.0), Vector2(x - side * 190.0, 120.0), col, 16.0, true)
	draw_line(Vector2(x, 330.0), Vector2(x - side * 140.0, 290.0), col, 11.0, true)


func _house() -> void:
	var flick := 0.5 + 0.5 * sin(t * 9.0) * sin(t * 3.1)
	var wcol := Color(1.0, 0.72, 0.38).lerp(Color(0.62, 0.82, 1.0), 0.22 + 0.2 * flick)   # lamp light + a flickering monitor
	Gfx.glow_ellipse(self, Vector2(672.0, 506.0), 120.0, 22.0, Color(wcol.r, wcol.g, wcol.b, 0.20))
	Gfx.glow(self, WIN, 80.0, Color(wcol.r, wcol.g, wcol.b, 0.18))
	for i in 7:
		var u := fposmod(t * 0.12 + float(i) / 7.0, 1.0)
		Gfx.glow(self, Vector2(697.0 + u * 40.0 + sin(u * 6.0 + float(i)) * 6.0, 402.0 - u * 90.0), 7.0 + u * 22.0, Color(0.5, 0.5, 0.65, 0.12 * (1.0 - u)))
	var roof := Color(0.035, 0.03, 0.055)
	draw_rect(Rect2(690.0, 404.0, 14.0, 34.0), roof)   # chimney
	draw_colored_polygon(PackedVector2Array([Vector2(548.0, 444.0), Vector2(640.0, 396.0), Vector2(732.0, 444.0)]), roof)
	draw_rect(Rect2(562.0, 442.0, 156.0, 60.0), Color(0.055, 0.045, 0.075))
	draw_line(Vector2(562.0, 442.0), Vector2(562.0, 502.0), Color(0.5, 0.55, 0.9, 0.12), 1.2)   # moon-side rim
	draw_rect(Rect2(596.0, 460.0, 24.0, 42.0), Color(0.02, 0.015, 0.03))   # door
	draw_rect(Rect2(592.0, 500.0, 32.0, 4.0), Color(0.03, 0.025, 0.045))
	# a lantern hanging by the door: the only other warm light in the woods
	Gfx.glow(self, Vector2(634.0, 470.0), 26.0, Color(1.0, 0.62, 0.26, 0.40 * (0.8 + 0.2 * sin(t * 11.0))))
	draw_rect(Rect2(631.5, 466.0, 5.0, 8.0), Color(1.0, 0.8, 0.45))
	# the window: lamp-lit, a hooded figure at a glowing monitor
	var fr := Color(0.02, 0.015, 0.03)
	draw_rect(Rect2(WIN.x - 15.0, WIN.y - 13.0, 30.0, 26.0), fr)
	draw_rect(Rect2(WIN.x - 13.0, WIN.y - 11.0, 26.0, 22.0), wcol)
	draw_rect(Rect2(WIN.x + 2.0, WIN.y - 4.0, 9.0, 8.0), Color(0.55, 0.85, 1.0))
	draw_circle(Vector2(WIN.x - 6.0, WIN.y - 1.0), 3.6, Color(0.07, 0.05, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(WIN.x - 11.0, WIN.y + 11.0), Vector2(WIN.x - 10.0, WIN.y + 4.0), Vector2(WIN.x - 6.0, WIN.y + 2.5), Vector2(WIN.x - 2.0, WIN.y + 4.0), Vector2(WIN.x - 1.0, WIN.y + 11.0)]), Color(0.07, 0.05, 0.12))
	draw_line(Vector2(WIN.x, WIN.y - 11.0), Vector2(WIN.x, WIN.y + 11.0), fr, 1.4)
	draw_line(Vector2(WIN.x - 13.0, WIN.y), Vector2(WIN.x + 13.0, WIN.y), fr, 1.4)


# ================================================================== INTERIOR
func _interior() -> void:
	var push := smoothstep(0.0, T_PULL - T_ENTER, t - T_ENTER)
	var tp := clampf((t - T_PULL) / (T_FLASH - T_PULL), 0.0, 1.0)
	var ep := tp * tp
	var gk := smoothstep(T_GLITCH, T_GLITCH + 0.8, t)
	# slow dolly-in; during the pull it dives into the monitor
	var z := (1.0 + 0.30 * push) * pow(22.0, ep)
	var c := Vector2(640.0, 400.0).lerp(Vector2(700.0, 410.0), push).lerp(MON, ep)
	var shake := Vector2(sin(t * 53.0) + sin(t * 37.3), cos(t * 47.0) + sin(t * 61.0)) * (1.2 * gk + 5.0 * ep)
	if t >= T_BLACKOUT:   # the jolt of the power cut
		shake += Vector2(sin(t * 80.0), cos(t * 70.0)) * 9.0 * exp(-(t - T_BLACKOUT) * 9.0)
	_cam2(z, c + shake)
	var lights := 1.0
	if t >= T_BLACKOUT:
		lights = 0.0
	elif absf(t - (T_BLACKOUT - 1.05)) < 0.07 or absf(t - (T_BLACKOUT - 0.5)) < 0.06 or absf(t - (T_BLACKOUT - 0.28)) < 0.05:
		lights = 0.25   # flicker before the cut
	_room(lights)
	draw_rect(Rect2(-1600.0, -900.0, 4500.0, 2600.0), Color(0.004, 0.008, 0.03, (1.0 - lights) * 0.86))   # the dark
	_monitor(gk, ep)
	var cpos := _char(lights, ep)
	draw_set_transform_matrix(_cur)
	_pull_fx(cpos)


func _room(lights: float) -> void:
	Gfx.vquad(self, -1600.0, 2900.0, -900.0, 650.0, Color(0.085, 0.060, 0.115), Color(0.055, 0.038, 0.085))
	for i in 48:
		draw_line(Vector2(-380.0 + float(i) * 64.0, -900.0), Vector2(-380.0 + float(i) * 64.0, 650.0), Color(0, 0, 0, 0.16), 2.0)
	# window onto the moonlit forest
	var wr := Rect2(140.0, 170.0, 190.0, 230.0)
	draw_rect(wr.grow(10.0), Color(0.03, 0.02, 0.045))
	Gfx.vquad(self, wr.position.x, wr.end.x, wr.position.y, wr.end.y, Color(0.10, 0.14, 0.30), Color(0.22, 0.28, 0.50))
	draw_circle(Vector2(wr.end.x - 46.0, wr.position.y + 50.0), 15.0, Color(0.9, 0.92, 1.0))
	for i in 7:
		_pine(Vector2(wr.position.x + 18.0 + float(i) * 26.0, wr.end.y), 70.0 + Gfx.hash1(float(i) + 40.0) * 60.0, 16.0, Color(0.02, 0.025, 0.06))
	var fr := Color(0.03, 0.02, 0.045)
	draw_line(Vector2(wr.get_center().x, wr.position.y), Vector2(wr.get_center().x, wr.end.y), fr, 7.0)
	draw_line(Vector2(wr.position.x, wr.get_center().y), Vector2(wr.end.x, wr.get_center().y), fr, 7.0)
	draw_colored_polygon(PackedVector2Array([Vector2(150.0, 400.0), Vector2(320.0, 400.0), Vector2(470.0, 650.0), Vector2(130.0, 650.0)]), Color(0.55, 0.65, 1.0, 0.045))
	# shelf of books and a small skull
	draw_rect(Rect2(930.0, 252.0, 320.0, 10.0), Color(0.05, 0.035, 0.06))
	var bx := 940.0
	for i in 11:
		var bh := 44.0 + Gfx.hash1(float(i) + 60.0) * 34.0
		var bw := 14.0 + Gfx.hash1(float(i) + 70.0) * 12.0
		draw_rect(Rect2(bx, 252.0 - bh, bw, bh), Color(0.10 + Gfx.hash1(float(i) + 80.0) * 0.08, 0.05, 0.08 + Gfx.hash1(float(i) + 90.0) * 0.10))
		bx += bw + 2.0
	draw_circle(Vector2(1218.0, 236.0), 12.0, Color(0.55, 0.52, 0.48))
	draw_circle(Vector2(1213.0, 234.0), 3.0, Color(0.03, 0.02, 0.04))
	draw_circle(Vector2(1223.0, 234.0), 3.0, Color(0.03, 0.02, 0.04))
	# floor
	Gfx.vquad(self, -1600.0, 2900.0, 650.0, 1600.0, Color(0.065, 0.045, 0.075), Color(0.02, 0.014, 0.03))
	draw_line(Vector2(-1600.0, 650.0), Vector2(2900.0, 650.0), Color(0, 0, 0, 0.5), 3.0)
	for i in 6:
		draw_line(Vector2(-1600.0, 700.0 + float(i) * 70.0), Vector2(2900.0, 700.0 + float(i) * 70.0), Color(0, 0, 0, 0.14), 2.0)
	# desk
	var wood := Color(0.10, 0.065, 0.075)
	Gfx.glow_ellipse(self, Vector2(880.0, 652.0), 340.0, 16.0, Color(0, 0, 0, 0.45))
	draw_rect(Rect2(540.0, 530.0, 650.0, 16.0), Color(0.16, 0.10, 0.11))
	draw_rect(Rect2(600.0, 546.0, 582.0, 26.0), wood.darkened(0.2))
	draw_rect(Rect2(612.0, 546.0, 16.0, 104.0), wood)
	draw_rect(Rect2(1158.0, 546.0, 16.0, 104.0), wood)
	# keyboard
	draw_rect(Rect2(578.0, 522.0, 132.0, 9.0), Color(0.05, 0.05, 0.08))
	for i in 12:
		draw_line(Vector2(582.0 + float(i) * 10.5, 524.0), Vector2(582.0 + float(i) * 10.5, 529.0), Color(0.2, 0.2, 0.28, 0.8), 1.5)
	# mug + steam
	draw_rect(Rect2(1010.0, 506.0, 26.0, 24.0), Color(0.18, 0.14, 0.16))
	draw_arc(Vector2(1037.0, 518.0), 7.0, -PI * 0.5, PI * 0.5, 10, Color(0.18, 0.14, 0.16), 3.0, true)
	for i in 3:
		var u := fposmod(t * 0.4 + float(i) * 0.33, 1.0)
		Gfx.glow(self, Vector2(1023.0 + sin(u * 6.0 + float(i)) * 5.0, 500.0 - u * 40.0), 6.0 + u * 8.0, Color(0.8, 0.85, 1.0, 0.08 * (1.0 - u)))
	# desk lamp (warm; dead after the cut)
	var lc := Color(0.07, 0.05, 0.07)
	draw_line(Vector2(1140.0, 530.0), Vector2(1112.0, 440.0), lc, 5.0, true)
	draw_line(Vector2(1112.0, 440.0), Vector2(1060.0, 404.0), lc, 5.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(1030.0, 402.0), Vector2(1086.0, 388.0), Vector2(1100.0, 418.0), Vector2(1044.0, 426.0)]), lc)
	if lights > 0.0:
		Gfx.glow_ellipse(self, Vector2(900.0, 330.0), 500.0, 300.0, Color(1.0, 0.7, 0.4, 0.07 * lights))
		Gfx.glow_ellipse(self, Vector2(1060.0, 520.0), 300.0, 120.0, Color(1.0, 0.68, 0.34, 0.26 * lights))
		Gfx.glow(self, Vector2(1062.0, 414.0), 70.0, Color(1.0, 0.8, 0.5, 0.35 * lights))
		draw_colored_polygon(PackedVector2Array([Vector2(1040.0, 424.0), Vector2(1092.0, 414.0), Vector2(1190.0, 540.0), Vector2(980.0, 540.0)]), Color(1.0, 0.72, 0.4, 0.06 * lights))


func _monitor(gk: float, ep: float) -> void:
	var q := int(t * 24.0)
	var jit := Vector2.ZERO
	if gk > 0.0 and Gfx.hash1(float(q) * 1.7) < 0.55 * gk:
		jit = Vector2((Gfx.hash1(float(q) * 3.1) - 0.5) * 22.0, (Gfx.hash1(float(q) * 5.3) - 0.5) * 6.0) * gk
	var m := MON + jit * 0.5
	var bez := Rect2(m - BEZ_HALF, BEZ_HALF * 2.0)
	var lit := 1.0 if t >= T_BLACKOUT else 0.55
	Gfx.glow_ellipse(self, m, 420.0, 300.0, Color(0.35, 0.72, 1.0, (0.10 + 0.10 * lit) * (0.85 + 0.15 * sin(t * 40.0) * gk)))
	Gfx.glow_ellipse(self, Vector2(m.x, 560.0), 300.0, 40.0, Color(0.4, 0.75, 1.0, 0.12 * lit))
	draw_rect(Rect2(m.x - 10.0, bez.end.y, 20.0, 18.0), Color(0.05, 0.05, 0.07))
	draw_rect(Rect2(m.x - 50.0, bez.end.y + 16.0, 100.0, 6.0), Color(0.06, 0.06, 0.08))
	draw_rect(bez, Color(0.045, 0.045, 0.065))
	draw_rect(bez, Color(1, 1, 1, 0.07), false, 1.5)
	_screen(Rect2(m.x - 153.0, m.y - 93.0, 306.0, 186.0), gk, ep)


func _screen(r: Rect2, gk: float, ep: float) -> void:
	var q := int(t * 24.0)
	var tb := t - T_BLACKOUT
	var cold := smoothstep(T_BLACKOUT, T_BLACKOUT + 1.5, t)
	var bg := Color(0.04, 0.075, 0.13).lerp(Color(0.02, 0.10, 0.14), cold)
	if tb > 0.0 and tb < 0.35:
		bg = bg.lerp(Color(0.85, 0.95, 1.0), (1.0 - tb / 0.35) * 0.8)   # it should have gone dark too - it only blinks
	draw_rect(r, bg)
	# the code the runner was writing; after the cut the lines delete themselves one by one
	if t < T_BLACKOUT + 3.4:
		var cols := [Color(0.5, 0.85, 1.0), Color(1.0, 0.75, 0.4), Color(0.9, 0.88, 0.85), Color(0.75, 0.6, 1.0)]
		var scroll := floorf(t * 1.6)
		for i in 10:
			var vis := 1.0
			if t > T_BLACKOUT + 1.0:
				vis = clampf(1.0 - (t - (T_BLACKOUT + 1.0 + float(i) * 0.2)) / 0.25, 0.0, 1.0)
			if vis <= 0.0:
				continue
			var w := 40.0 + Gfx.hash1(float(i) + scroll * 1.3) * (r.size.x - 80.0) * 0.7
			if i == 9 and t < T_BLACKOUT:
				w *= fposmod(t * 1.5, 1.0)   # the line being typed
			var cc: Color = cols[i % 4]
			var ind := 18.0 if Gfx.hash1(float(i) * 3.0 + scroll) > 0.5 else 0.0
			draw_rect(Rect2(r.position.x + 14.0 + ind, r.position.y + 16.0 + float(i) * 17.0, w, 6.0), Color(cc.r, cc.g, cc.b, 0.8 * vis))
	# "404: Alive", typed out
	if t >= T_TEXT:
		var s := "404: Alive"
		var f: Font = GameState.f_display
		var fs := 46
		var n := clampi(int((t - T_TEXT) / 0.13), 0, s.length())
		var ctr := r.get_center() + Vector2(0.0, 14.0)
		var x0 := ctr.x - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
		var a := 1.0 - smoothstep(0.35, 0.6, ep)   # glyph bitmaps would blur at the final zoom: the vortex takes over
		var shown := s.substr(0, n)
		if fmod(t, 0.8) < 0.5:
			shown += "_"
		Gfx.glow_ellipse(self, ctr + Vector2(0.0, -14.0), 160.0, 40.0, Color(0.5, 0.9, 1.0, 0.18 * a))
		if gk > 0.0:
			var d := (Gfx.hash1(float(q) * 2.3) - 0.5) * 22.0 * gk
			draw_string(f, Vector2(x0 + d, ctr.y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.1, 0.25, 0.6 * a))
			draw_string(f, Vector2(x0 - d, ctr.y + 2.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.9, 1.0, 0.5 * a))
		draw_string(f, Vector2(x0, ctr.y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.97, 1.0, a))
	# glitch: tearing bars, noise blocks, a rolling bright band, whiteout flickers
	if gk > 0.0:
		for n2 in 7:
			var gy := r.position.y + Gfx.hash1(float(q * 7 + n2)) * r.size.y
			var gh := minf(2.0 + Gfx.hash1(float(q * 3 + n2)) * 16.0, r.end.y - gy)
			var c2 := Color(1.0, 0.1, 0.25, 0.28 * gk) if n2 % 2 == 0 else Color(0.2, 0.95, 1.0, 0.25 * gk)
			draw_rect(Rect2(r.position.x, gy, r.size.x, gh), c2)
		for n3 in 24:
			var nx := r.position.x + Gfx.hash1(float(q * 11 + n3)) * (r.size.x - 12.0)
			var ny := r.position.y + Gfx.hash1(float(q * 13 + n3)) * (r.size.y - 8.0)
			draw_rect(Rect2(nx, ny, 4.0 + Gfx.hash1(float(n3)) * 8.0, 3.0), Color(1, 1, 1, 0.25 * gk))
		var ry := r.position.y + fposmod(t * 140.0, r.size.y + 40.0) - 20.0
		var yy := maxf(ry, r.position.y)
		var hh := minf(ry + 28.0, r.end.y) - yy
		if hh > 0.0:
			draw_rect(Rect2(r.position.x, yy, r.size.x, hh), Color(0.8, 0.95, 1.0, 0.12 * gk))
		if Gfx.hash1(float(q) * 11.0) > 0.93:
			draw_rect(r, Color(1, 1, 1, 0.45 * gk))
	for i in 23:
		draw_line(Vector2(r.position.x, r.position.y + float(i) * 8.0), Vector2(r.end.x, r.position.y + float(i) * 8.0), Color(0, 0, 0, 0.12), 1.0)
	# the vortex that takes the runner
	if ep > 0.0:
		var c := r.get_center()
		Gfx.glow_ellipse(self, c, r.size.x * 0.9, r.size.y * 0.9, Color(0.7, 0.95, 1.0, 0.55 * ep))
		for i in 9:
			var u := fposmod(t * 0.9 + float(i) / 9.0, 1.0)
			draw_arc(c, (1.0 - u) * r.size.y * 0.5, u * 7.0, u * 7.0 + 4.2, 28, Color(0.8, 0.97, 1.0, 0.55 * ep * u), 2.0 + 3.0 * ep, true)


## The runner. Seated in profile; typing -> recoils from the dead room -> frozen, staring at the words ->
## floated and stretched toward the screen. Returns the hip position (for the particle stream).
func _char(lights: float, ep: float) -> Vector2:
	var tb := t - T_BLACKOUT
	var cut := t >= T_BLACKOUT
	var panic := smoothstep(0.0, 0.25, tb) if cut else 0.0
	var calm := smoothstep(T_TEXT - 0.2, T_TEXT + 1.2, t)
	var glide := smoothstep(T_GLITCH, T_PULL, t)
	var recoil := smoothstep(0.0, 0.35, tb) * (1.0 - calm) if cut else 0.0
	var lean := lerpf(0.30, -0.30, recoil) + 0.22 * calm + 0.55 * glide + 0.9 * ep
	lean += sin(t * 36.0) * 0.018 * panic * (1.0 - calm)
	var pos := HIP + Vector2(-26.0 * recoil + 40.0 * glide, -4.0 * sin(t * 2.0) * glide)
	pos = pos.lerp(MON + Vector2(-20.0, 30.0), ep)
	var shrink := lerpf(1.0, 0.12, ep)
	var sc := Vector2(shrink * (1.0 + 1.3 * ep), shrink * (1.0 - 0.3 * ep))
	draw_set_transform_matrix(_cur * Transform2D(Vector2(sc.x, 0.0), Vector2(0.0, sc.y), pos))
	var lit := lerpf(0.40, 1.0, lights)
	var coat := _lt(CharacterDrawer.COAT, lit)
	var coat_d := _lt(CharacterDrawer.COAT_D, lit)
	var coat_f := _lt(CharacterDrawer.COAT_FAR, lit)
	var trim := _lt(CharacterDrawer.TRIM, lit)
	var skin := _lt(Color(0.82, 0.76, 0.84), lit)
	var chair := _lt(Color(0.14, 0.10, 0.18), lit)
	var rim := Color(0.55, 0.85, 1.0, 0.30 * (1.0 - lights * 0.6))
	var td := Vector2(sin(lean), -cos(lean))
	var fwd := Vector2(-td.y, td.x)
	var shake := Vector2(sin(t * 47.0), cos(t * 41.0)) * 2.2 * panic * (1.0 - calm)
	var shoulder := td * 74.0
	var head := shoulder + td * 24.0 + shake
	# hand targets: typing -> hands to the face -> limp in the lap -> reaching for the screen
	var typing := 0.0 if cut else 1.0
	var tn := (Vector2(606.0, 519.0) - HIP) + Vector2(sin(t * 34.0) * 3.0, sin(t * 29.0 + 1.0) * 2.5) * typing
	var tf := (Vector2(640.0, 520.0) - HIP) + Vector2(sin(t * 31.0 + 2.0) * 3.0, sin(t * 37.0) * 2.5) * typing
	var hn := tn.lerp(head + Vector2(16.0, 18.0), panic).lerp(Vector2(46.0, -6.0), calm).lerp(Vector2(150.0, -92.0), glide) + shake
	var hf := tf.lerp(head + Vector2(8.0, 28.0), panic).lerp(Vector2(30.0, -2.0), calm).lerp(Vector2(160.0, -70.0), glide) + shake
	hn = shoulder + (hn - shoulder).limit_length(103.0)
	hf = shoulder + (hf - shoulder).limit_length(103.0)
	# chair
	draw_rect(Rect2(-40.0, 6.0, 74.0, 14.0), chair)
	draw_rect(Rect2(-46.0, -78.0, 14.0, 90.0), chair)
	draw_line(Vector2(0.0, 20.0), Vector2(0.0, 74.0), chair, 6.0)
	draw_line(Vector2(-40.0, 80.0), Vector2(40.0, 80.0), chair, 7.0)
	# far arm + hood tail
	var fe := Gfx.ik(shoulder, hf, 52.0, 52.0, 1.0)
	Gfx.capsule(self, shoulder, fe, 17.0, 14.0, coat_f)
	Gfx.capsule(self, fe, hf, 14.0, 11.0, coat_f)
	Gfx.capsule(self, head - fwd * 10.0, head - fwd * 30.0 + Vector2(0.0, 18.0), 24.0, 8.0, coat_d)
	# legs (seated) + boot
	var knee := Vector2(58.0, -4.0)
	var ankle := Vector2(66.0, 78.0)
	Gfx.capsule(self, Vector2.ZERO, knee, 26.0, 20.0, coat_d)
	Gfx.capsule(self, knee, ankle, 20.0, 16.0, coat_d)
	draw_colored_polygon(PackedVector2Array([ankle + Vector2(-8.0, -6.0), ankle + Vector2(10.0, -5.0), ankle + Vector2(24.0, 2.0), ankle + Vector2(24.0, 9.0), ankle + Vector2(-8.0, 9.0)]), _lt(CharacterDrawer.BOOT, lit))
	# torso + coat
	var coat_poly := PackedVector2Array([shoulder - fwd * 22.0, shoulder + fwd * 22.0, fwd * 24.0 + Vector2(0.0, 14.0), -fwd * 26.0 + Vector2(0.0, 14.0)])
	Gfx.vgrad(self, coat_poly, shoulder.y, 14.0, coat, coat_d)
	Gfx.capsule(self, td * 10.0, shoulder, 44.0, 50.0, coat)
	draw_line(shoulder + fwd * 22.0 + Vector2(3.0, -1.0), fwd * 24.0 + Vector2(3.0, 14.0), rim, 3.0, true)   # monitor light on the coat
	draw_line(-fwd * 22.0, fwd * 24.0, trim, 7.0, true)
	# near arm + hand
	var ne := Gfx.ik(shoulder, hn, 52.0, 52.0, 1.0)
	Gfx.capsule(self, shoulder, ne, 19.0, 16.0, coat)
	Gfx.capsule(self, ne, hn, 16.0, 12.0, coat)
	draw_circle(hn, 8.0, skin)
	# head: hood, shadowed face, the one wide eye (it opens wider with fear)
	Gfx.capsule(self, shoulder, shoulder + td * 18.0, 22.0, 20.0, skin)
	draw_circle(head + Vector2(3.0, -1.5), 30.0, rim)
	draw_circle(head, 28.0, coat)
	draw_circle(head + fwd * 9.0 + Vector2(0.0, 1.0), 19.0, Color(0.035, 0.025, 0.06))
	draw_arc(head, 27.5, lean - 2.2, lean + 0.4, 18, trim, 3.0, true)
	var eye := head + fwd * 17.0 + Vector2(0.0, -2.0)
	draw_circle(eye, lerpf(4.0, 8.0, panic), Color(0.96, 0.93, 1.0))
	draw_circle(eye + fwd * 1.6, lerpf(1.8, 1.0, panic), Color(0.03, 0.02, 0.06))
	return pos


## Light streaming from the runner into the screen as it pulls them in.
func _pull_fx(cpos: Vector2) -> void:
	if t < T_GLITCH + 1.0:
		return
	var a := smoothstep(T_GLITCH + 1.0, T_PULL + 0.5, t)
	for i in 26:
		var fi := float(i)
		var u := fposmod(t * (0.9 + 0.5 * a) + Gfx.hash1(fi), 1.0)
		var src := cpos + Vector2(-20.0, -50.0) + Vector2((Gfx.hash1(fi + 7.0) - 0.5) * 90.0, (Gfx.hash1(fi + 3.0) - 0.5) * 140.0)
		var p0 := src.lerp(MON, u * u)
		var p1 := src.lerp(MON, minf(u * u + 0.06, 1.0))
		var wob := Vector2(0.0, sin(u * 9.0 + fi) * 14.0 * (1.0 - u))
		draw_line(p0 + wob, p1 + wob, Color(0.7, 0.95, 1.0, 0.7 * a * (1.0 - u * 0.4)), 1.5 + 2.0 * a, true)


# ================================================================== OVERLAYS (screen space)
func _overlays(W: float, H: float) -> void:
	# global tearing while the screen glitches and pulls
	if t > T_GLITCH and t < T_FLASH:
		var q := int(t * 30.0)
		var amt := smoothstep(T_GLITCH, T_GLITCH + 0.8, t) * (0.6 + 0.4 * smoothstep(T_PULL, T_FLASH, t))
		for n in int(6.0 * amt) + 1:
			if Gfx.hash1(float(q * 13 + n)) < 0.6 * amt:
				var gy := Gfx.hash1(float(q * 7 + n)) * H
				var gh := 3.0 + Gfx.hash1(float(q * 3 + n)) * 22.0
				draw_rect(Rect2(0.0, gy, W, gh), Color(1.0, 0.15, 0.3, 0.12) if n % 2 == 0 else Color(0.2, 0.9, 1.0, 0.12))
				draw_rect(Rect2(Gfx.hash1(float(q * 5 + n)) * W * 0.5, gy + gh * 0.5, W * 0.5, 2.0), Color(1, 1, 1, 0.22 * amt))
	if t >= T_BLACKOUT and t < T_BLACKOUT + 0.5:   # the instant the power dies
		draw_rect(Rect2(0.0, 0.0, W, H), Color(0, 0, 0, (1.0 - (t - T_BLACKOUT) / 0.5) * 0.55))
	# vignette
	var edge := Color(0, 0, 0, 0.62)
	var clear := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W * 0.28, 0), Vector2(W * 0.28, H), Vector2(0, H)]), PackedColorArray([edge, clear, clear, edge]))
	draw_polygon(PackedVector2Array([Vector2(W * 0.72, 0), Vector2(W, 0), Vector2(W, H), Vector2(W * 0.72, H)]), PackedColorArray([clear, edge, edge, clear]))
	# scanlines + grain
	if absf(_scan_h - H) > 0.5:
		_scan_h = H
		_scan = PackedVector2Array()
		var yy := 0.0
		while yy < H:
			_scan.append(Vector2(0.0, yy))
			_scan.append(Vector2(W, yy))
			yy += 5.0
	draw_multiline(_scan, Color(0, 0, 0, 0.07), 1.0)
	var gq := int(t * 20.0)
	for i in 40:
		draw_rect(Rect2(Gfx.hash1(float(gq * 17 + i)) * W, Gfx.hash1(float(gq * 31 + i)) * H, 2.0, 2.0), Color(1, 1, 1, 0.05))
	# through the lit window: the exterior dissolves into warm light, the room fades up out of it
	var warm := smoothstep(T_ENTER - 1.0, T_ENTER, t) * (1.0 - smoothstep(T_ENTER, T_ENTER + 1.0, t))
	draw_rect(Rect2(0.0, 0.0, W, H), Color(1.0, 0.74, 0.42, warm))
	# letterbox
	var bar := H * 0.075
	draw_rect(Rect2(0.0, 0.0, W, bar), Color.BLACK)
	draw_rect(Rect2(0.0, H - bar, W, bar), Color.BLACK)
	# the final flash: we leave the monitor and arrive in the game
	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.82, 0.95, 1.0, smoothstep(T_FLASH - 0.7, T_FLASH, t)))
