class_name CineArt
extends RefCounted
## All the drawing for the first-boot cinematic. Everything is procedural low-poly, like the game.
## Pure functions of time `t` (seconds since the cinematic started): `draw()` paints the scene, `draw_light()`
## paints the additive glow pass (lamps, monitor light, moonlight) onto a second, additively blended item.
##
## Timeline (the score in tools/generate_cinematic_audio.py is cut to the same beats):
##    0.0  night forest, slow push toward the cabin       |  24.0  the PC wakes by itself
##   11.7  inside: he is working at his PC                |  24.6  text types itself, 27.4 the logo appears
##   20.4  the lamp flickers                              |  30.0  the screen glitches and distorts
##   21.0  POWER CUT, he panics and grabs his lantern     |  31.6  he is pulled into the screen
##   33.0  camera pushes into the monitor                 |  38.3  white-out, 40.0 cut into the game world
##
## Coordinates: a 1280x720 "design" space. `vs`/`vo` = cover-scale and offset that map it onto the real
## screen, so the picture fills any aspect ratio (the important action stays in the central 16:9 area).

const T_INT := 11.7
const T_FLICKER := 20.4
const T_CUT := 21.0
const T_WAKE := 24.0
const T_TEXT := 24.6
const T_LOGO := 27.4
const T_GLITCH := 30.0
const T_PULL := 31.6
const T_SUCK := 35.2
const T_ZOOM := 33.0
const T_FLASH := 38.3
const T_END := 40.0

const K := 2.7                      ## the runner's scale inside the room (his proportions are CharacterDrawer's)
const FLOOR := 560.0
const SEAT := Vector2(722.0, 462.0)  ## hip while sitting
const MONITOR := Rect2(925.0, 250.0, 231.0, 130.0)   ## the screen glass, in room coordinates
const END_COL := Color(0.80, 0.92, 1.0)              ## the colour the cinematic ends on (the game fades in from it)

static var _logo: Texture2D


# ======================================================================================== helpers
static func _e(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _io(x: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(x, 0.0, 1.0))


static func _h(n: float) -> float:
	return Gfx.hash1(n)


## Layer transform: design-space points of a parallax layer (scaled by `s` about world anchor `aw`)
## land so that `aw` appears at screen anchor `an`.
static func _layer(ci: CanvasItem, vs: float, vo: Vector2, s: float, aw: Vector2, an: Vector2) -> void:
	ci.draw_set_transform(vo + (an - aw * s) * vs, 0.0, Vector2(vs * s, vs * s))


## Intensity of the screen distortion (also drives the grade shader's tearing in the controller).
static func glitch(t: float) -> float:
	if t < T_GLITCH:
		return 0.0
	return clampf(0.3 + 0.7 * _e((t - T_GLITCH) / 4.5), 0.0, 1.0)


## 0..1 white-out at the very end.
static func whiteout(t: float) -> float:
	return _e((t - T_FLASH) / 1.2)


# ======================================================================================== frame entry
static func draw(ci: CanvasItem, t: float, view: Vector2) -> void:
	var vs := maxf(view.x / 1280.0, view.y / 720.0)
	var vo := (view - Vector2(1280.0, 720.0) * vs) * 0.5
	ci.draw_set_transform(vo, 0.0, Vector2(vs, vs))
	ci.draw_rect(Rect2(-1500.0, -1000.0, 4300.0, 2700.0), Color(0.008, 0.006, 0.016))
	if t < T_INT:
		exterior(ci, t, vs, vo)
	else:
		interior(ci, t, vs, vo)
	# screen-space overlays
	ci.draw_set_transform(vo, 0.0, Vector2(vs, vs))
	var fa := _e((t - 10.5) / 1.1) * (1.0 - _e((t - T_INT) / 1.6))   # the window's warm light swallows the lens, then lets go
	if fa > 0.0:
		ci.draw_rect(Rect2(-1500.0, -1000.0, 4300.0, 2700.0), Color(1.0, 0.84, 0.52, 0.96 * fa))
	var wa := whiteout(t)
	if wa > 0.0:
		ci.draw_rect(Rect2(-1500.0, -1000.0, 4300.0, 2700.0), Color(END_COL.r, END_COL.g, END_COL.b, wa))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func draw_light(ci: CanvasItem, t: float, view: Vector2) -> void:
	var vs := maxf(view.x / 1280.0, view.y / 720.0)
	var vo := (view - Vector2(1280.0, 720.0) * vs) * 0.5
	if t < T_INT:
		exterior_light(ci, t, vs, vo)
	else:
		interior_light(ci, t, vs, vo)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ======================================================================================== EXTERIOR
static func _ext_z(t: float) -> float:
	return pow(16.0, _io(t / 11.6))


static func _ext_anchor(t: float) -> Vector2:
	return Vector2(628.0, 468.0).lerp(Vector2(640.0, 360.0), _e(t / 9.5)) + Vector2(sin(t * 0.8) * 2.0, cos(t * 0.6) * 1.5)


const HOUSE := Vector2(628.0, 468.0)   ## the lit window: where the camera is heading


static func exterior(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	var z := _ext_z(t)
	var an := _ext_anchor(t)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.03, HOUSE, an)
	_sky(ci, t)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.10, HOUSE, an)
	_hills(ci)
	Gfx.glow_ellipse(ci, Vector2(640.0, 505.0), 1100.0, 90.0, Color(0.30, 0.36, 0.66, 0.16))
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.26, HOUSE, an)
	_trees(ci, 1.0, 46, -760.0, 62.0, 506.0, 150.0, 250.0, Color(0.032, 0.046, 0.10), 150.0, false)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.50, HOUSE, an)
	Gfx.glow_ellipse(ci, Vector2(640.0, 520.0), 1000.0, 60.0, Color(0.34, 0.42, 0.75, 0.13))
	_trees(ci, 5.0, 26, -680.0, 112.0, 516.0, 230.0, 380.0, Color(0.018, 0.028, 0.068), 170.0, true)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 1.0, HOUSE, an)
	_house(ci, t, z)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 1.55, HOUSE, an)
	_foreground(ci, t)


static func exterior_light(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	var z := _ext_z(t)
	var an := _ext_anchor(t)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 1.0, HOUSE, an)
	var fl := 0.9 + 0.1 * sin(t * 7.0) * sin(t * 3.1)
	Gfx.glow(ci, HOUSE, 170.0, Color(1.0, 0.70, 0.30, 0.42 * fl))
	Gfx.glow_ellipse(ci, Vector2(628.0, 505.0), 190.0, 28.0, Color(1.0, 0.66, 0.28, 0.20 * fl))
	for i in 12:
		var h1 := _h(float(i) * 2.3 + 40.0)
		var h2 := _h(float(i) * 5.1 + 41.0)
		var fp := Vector2(330.0 + h1 * 640.0 + sin(t * 0.6 + h1 * 9.0) * 22.0, 430.0 + h2 * 85.0 + cos(t * 0.5 + h2 * 7.0) * 12.0)
		var pu := 0.5 + 0.5 * sin(t * (1.2 + h1) + h2 * 30.0)
		Gfx.glow(ci, fp, 9.0 + 5.0 * pu, Color(0.8, 1.0, 0.4, 0.25 + 0.5 * pu))


static func _sky(ci: CanvasItem, t: float) -> void:
	Gfx.vquad(ci, -1600.0, 2900.0, -1400.0, 330.0, Color(0.008, 0.012, 0.045), Color(0.04, 0.05, 0.13))
	Gfx.vquad(ci, -1600.0, 2900.0, 330.0, 560.0, Color(0.04, 0.05, 0.13), Color(0.13, 0.15, 0.30))
	for i in 110:
		var h1 := _h(float(i) * 3.1)
		var h2 := _h(float(i) * 7.7 + 1.0)
		var sp := Vector2(-250.0 + h1 * 1780.0, -300.0 + h2 * 700.0)
		var tw := 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (1.0 + 2.0 * h1) + h2 * 40.0))
		ci.draw_circle(sp, 0.7 + 1.1 * h2 * h2, Color(0.8, 0.86, 1.0, tw * (1.0 - clampf((sp.y - 150.0) / 300.0, 0.0, 0.8))))
	var mp := Vector2(930.0, 150.0)
	Gfx.glow(ci, mp, 380.0, Color(0.35, 0.45, 0.9, 0.35))
	Gfx.glow(ci, mp, 150.0, Color(0.7, 0.8, 1.0, 0.35))
	ci.draw_circle(mp, 46.0, Color(0.86, 0.9, 1.0))
	ci.draw_circle(mp + Vector2(-14.0, -10.0), 9.0, Color(0.74, 0.8, 0.94))
	ci.draw_circle(mp + Vector2(16.0, 12.0), 12.0, Color(0.78, 0.84, 0.96))
	ci.draw_circle(mp + Vector2(8.0, -22.0), 5.0, Color(0.74, 0.8, 0.94))
	for i in 3:
		var cx := fposmod(t * (6.0 + 3.0 * float(i)) + float(i) * 400.0, 1700.0) - 300.0
		Gfx.glow_ellipse(ci, Vector2(cx, 120.0 + float(i) * 55.0), 210.0, 14.0, Color(0.35, 0.42, 0.7, 0.16))


static func _hills(ci: CanvasItem) -> void:
	for r in 2:
		var pts := PackedVector2Array()
		var base := 462.0 + float(r) * 26.0
		pts.append(Vector2(-1600.0, 900.0))
		for i in range(0, 53):
			var x := -1600.0 + float(i) * 80.0
			pts.append(Vector2(x, base - 22.0 * sin(x * 0.0045 + float(r) * 2.0) - 12.0 * sin(x * 0.012 + 1.0 + float(r))))
		pts.append(Vector2(2700.0, 900.0))
		ci.draw_colored_polygon(pts, Color(0.05, 0.06, 0.14).lerp(Color(0.02, 0.025, 0.07), float(r) * 0.6))


## A row of low-poly pines. `clear` leaves a gap around the cabin; `facets` adds the moonlit side of each tier.
static func _trees(ci: CanvasItem, sd: float, count: int, x0: float, step: float, base: float, h0: float, h1: float, col: Color, clear: float, facets: bool) -> void:
	for i in count:
		var hh := _h(sd + float(i) * 1.7)
		var x := x0 + float(i) * step + (_h(sd * 3.0 + float(i)) - 0.5) * step * 0.6
		if absf(x - 640.0) < clear:
			continue
		var h := lerpf(h0, h1, hh)
		var w := h * 0.32
		ci.draw_rect(Rect2(x - w * 0.06, base - h * 0.14, w * 0.12, h * 0.16), col)
		for k in 3:
			var top := base - h * (1.0 - 0.22 * float(k))
			var bot := base - h * (0.52 - 0.22 * float(k))
			var half := w * (0.50 + 0.22 * float(k))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bot), Vector2(x - half, bot)]), col)
			if facets:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bot), Vector2(x + half * 0.15, bot)]), col.lightened(0.16))


static func _house(ci: CanvasItem, t: float, z: float) -> void:
	# ground, a moonlit rim of grass, and the path to the door
	ci.draw_rect(Rect2(-2500.0, 500.0, 6000.0, 1800.0), Color(0.02, 0.03, 0.055))
	Gfx.vquad(ci, -2500.0, 3700.0, 500.0, 548.0, Color(0.06, 0.075, 0.14), Color(0.02, 0.03, 0.055))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(662.0, 500.0), Vector2(684.0, 500.0), Vector2(860.0, 900.0), Vector2(500.0, 900.0)]), Color(0.10, 0.11, 0.18))
	for i in 14:
		var gx := 330.0 + float(i) * 44.0
		ci.draw_line(Vector2(gx, 502.0), Vector2(gx + sin(t * 1.3 + float(i)) * 3.0, 490.0 - _h(float(i)) * 8.0), Color(0.05, 0.08, 0.12), 1.6)
	# the cabin
	Gfx.vquad(ci, 565.0, 715.0, 438.0, 500.0, Color(0.15, 0.11, 0.11), Color(0.07, 0.055, 0.06))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(640.0, 438.0), Vector2(715.0, 438.0), Vector2(715.0, 500.0), Vector2(640.0, 500.0)]), Color(0.18, 0.14, 0.17, 0.35))
	for i in 10:
		ci.draw_line(Vector2(565.0 + 15.0 * float(i), 438.0), Vector2(565.0 + 15.0 * float(i), 500.0), Color(0, 0, 0, 0.28), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(544.0, 442.0), Vector2(640.0, 388.0), Vector2(736.0, 442.0)]), Color(0.05, 0.04, 0.07))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(640.0, 388.0), Vector2(736.0, 442.0), Vector2(640.0, 442.0)]), Color(0.09, 0.08, 0.14))
	ci.draw_line(Vector2(640.0, 388.0), Vector2(736.0, 442.0), Color(0.55, 0.62, 0.9, 0.55), 1.6)
	ci.draw_rect(Rect2(684.0, 396.0, 16.0, 34.0), Color(0.06, 0.05, 0.08))
	ci.draw_rect(Rect2(681.0, 392.0, 22.0, 6.0), Color(0.09, 0.08, 0.12))
	for i in 7:   # chimney smoke
		var f := float(i) / 7.0
		var sp := Vector2(692.0 + sin(t * 0.7 + float(i)) * 6.0 + float(i) * 3.5, 388.0 - float(i) * 14.0 - fposmod(t * 9.0, 14.0))
		ci.draw_circle(sp, 5.0 + float(i) * 1.8, Color(0.5, 0.55, 0.75, 0.20 * (1.0 - f)))
	ci.draw_rect(Rect2(660.0, 456.0, 24.0, 44.0), Color(0.04, 0.03, 0.05))
	ci.draw_circle(Vector2(678.0, 480.0), 1.6, Color(0.85, 0.7, 0.4))
	# the window: warm, a figure at a desk just visible inside it
	var fl := 0.9 + 0.1 * sin(t * 7.0) * sin(t * 3.1)
	ci.draw_rect(Rect2(605.0, 449.0, 46.0, 38.0), Color(0.05, 0.04, 0.05))
	Gfx.vquad(ci, 610.0, 646.0, 454.0, 482.0, Color(1.0, 0.82, 0.45).darkened(1.0 - fl), Color(0.85, 0.55, 0.25).darkened(1.0 - fl))
	ci.draw_rect(Rect2(610.0, 474.0, 36.0, 3.0), Color(0.2, 0.12, 0.08))                                  # desk
	ci.draw_rect(Rect2(636.0, 464.0, 8.0, 10.0), Color(0.28, 0.58, 0.92))                                    # monitor glow
	ci.draw_circle(Vector2(623.0, 466.0), 4.2, Color(0.08, 0.05, 0.08))                                    # head
	ci.draw_colored_polygon(PackedVector2Array([Vector2(616.0, 482.0), Vector2(618.0, 470.0), Vector2(628.0, 470.0), Vector2(631.0, 482.0)]), Color(0.1, 0.07, 0.12))
	ci.draw_line(Vector2(628.0, 454.0), Vector2(628.0, 482.0), Color(0.05, 0.04, 0.05), 2.0)
	ci.draw_line(Vector2(610.0, 468.0), Vector2(646.0, 468.0), Color(0.05, 0.04, 0.05), 2.0)
	# a fence
	for i in 8:
		var fx := 520.0 + float(i) * 12.0
		ci.draw_rect(Rect2(fx, 484.0, 3.0, 16.0), Color(0.05, 0.04, 0.06))
		ci.draw_rect(Rect2(740.0 + float(i) * 12.0, 484.0, 3.0, 16.0), Color(0.05, 0.04, 0.06))
	ci.draw_line(Vector2(520.0, 490.0), Vector2(610.0, 490.0), Color(0.05, 0.04, 0.06), 1.4)
	ci.draw_line(Vector2(740.0, 490.0), Vector2(830.0, 490.0), Color(0.05, 0.04, 0.06), 1.4)


## Big dark trunks at the frame edges. They scale fastest, so they sweep past as the camera moves in.
static func _foreground(ci: CanvasItem, t: float) -> void:
	for side in 2:
		var sx := 80.0 if side == 0 else 1200.0
		var d := 1.0 if side == 0 else -1.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 34.0, 800.0), Vector2(sx - 24.0, 100.0), Vector2(sx + 20.0, 90.0), Vector2(sx + 40.0, 800.0)]), Color(0.006, 0.008, 0.02))
		for b in 3:
			var by := 230.0 + float(b) * 120.0
			var tip := Vector2(sx + d * (150.0 + float(b) * 20.0), by - 70.0 + sin(t * 0.5 + float(b)) * 4.0)
			Gfx.capsule(ci, Vector2(sx, by), tip, 20.0, 5.0, Color(0.006, 0.008, 0.02))
	var bxs := [-70.0, 70.0, 200.0, 1090.0, 1210.0, 1350.0]   # only at the frame edges, never in front of the cabin
	for i in bxs.size():
		ci.draw_circle(Vector2(bxs[i], 610.0), 55.0 + _h(float(i) + 9.0) * 35.0, Color(0.005, 0.008, 0.018))
	Gfx.glow_ellipse(ci, Vector2(640.0, 540.0), 900.0, 50.0, Color(0.4, 0.5, 0.8, 0.12))


# ======================================================================================== INTERIOR
static func _int_z(t: float) -> float:
	var z := lerpf(1.0, 1.08, _io((t - T_INT) / 9.3))        # a slow push-in while he works
	z = lerpf(z, 1.55, _e((t - T_WAKE) / 7.0))               # toward the monitor as it wakes
	return lerpf(z, 7.0, pow(_e((t - T_ZOOM) / 5.6), 1.6))   # and finally INTO the screen


static func _int_anchor(t: float) -> Vector2:
	var a := Vector2(660.0, 360.0).lerp(Vector2(900.0, 330.0), _e((t - T_WAKE) / 6.0))
	return a.lerp(MONITOR.position + MONITOR.size * 0.5, _e((t - T_ZOOM) / 4.0))


## Camera shake: a jolt at the power cut, then a growing tremor with the glitch.
static func _shake(t: float) -> Vector2:
	var g := glitch(t)
	var n := floorf(t * 22.0)
	var s := Vector2(_h(n) - 0.5, _h(n + 7.0) - 0.5) * 9.0 * g * g
	if t > T_CUT:
		s += Vector2(sin(t * 71.0), cos(t * 53.0)) * 5.0 * exp(-(t - T_CUT) * 6.0)
	return s


## 1 = the lamp is on. It stutters for the last 0.6 s and dies exactly at T_CUT.
static func _lamp(t: float) -> float:
	if t < T_FLICKER:
		return 1.0
	if t >= T_CUT:
		return 0.0
	var u := (t - T_FLICKER) / (T_CUT - T_FLICKER)
	var f := 1.0 - u * 0.45
	if sin(u * 47.0) * sin(u * 29.0 + 1.0) > 0.25:
		f *= 0.15
	if u > 0.93:
		f = 0.0
	return f


static func interior(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	var z := _int_z(t)
	var aw := _int_anchor(t)
	var an := Vector2(640.0, 360.0) + _shake(t)
	var cs := vs * z
	var ct := vo + (an - aw * z) * vs
	ci.draw_set_transform(ct, 0.0, Vector2(cs, cs))
	var lamp := _lamp(t)
	_room(ci, t, lamp)
	_chair(ci, t, cs, ct)
	ci.draw_set_transform(ct, 0.0, Vector2(cs, cs))
	_monitor_body(ci)
	_person_scene(ci, t, cs, ct)
	ci.draw_set_transform(ct, 0.0, Vector2(cs, cs))
	var in_hand: float = _pose(t)["lan"]
	if in_hand < 0.5:   # his lantern, waiting on the desk until he grabs it
		_lantern(ci, Vector2(777.0, 393.0), 0.0, 0.0, 1.0, 1.0)
	# the room is lit by the lamp: when it dies the room goes (nearly) black
	var dk := 0.84 * (1.0 - lamp)
	if dk > 0.0:
		ci.draw_rect(Rect2(-1500.0, -1000.0, 4300.0, 2700.0), Color(0.006, 0.01, 0.035, dk))
	_window_glass(ci, t)
	screen(ci, t)


static func _room(ci: CanvasItem, t: float, lamp: float) -> void:
	# back wall + floor
	Gfx.vquad(ci, -1500.0, 2800.0, -800.0, FLOOR, Color(0.21, 0.14, 0.11), Color(0.13, 0.085, 0.07))
	for i in range(-2, 30):
		ci.draw_line(Vector2(float(i) * 48.0, -800.0), Vector2(float(i) * 48.0, FLOOR), Color(0, 0, 0, 0.20), 1.6)
	ci.draw_rect(Rect2(-1500.0, FLOOR - 16.0, 4300.0, 16.0), Color(0.09, 0.06, 0.05))
	Gfx.vquad(ci, -1500.0, 2800.0, FLOOR, 1200.0, Color(0.12, 0.075, 0.06), Color(0.05, 0.03, 0.03))
	for i in 5:
		ci.draw_line(Vector2(-1500.0, FLOOR + 24.0 + float(i) * float(i) * 9.0), Vector2(2800.0, FLOOR + 24.0 + float(i) * float(i) * 9.0), Color(0, 0, 0, 0.25), 2.0)
	# window frame (the glass is drawn later, above the darkness: it carries moonlight)
	ci.draw_rect(Rect2(62.0, 102.0, 236.0, 226.0), Color(0.08, 0.05, 0.04))
	ci.draw_rect(Rect2(50.0, 326.0, 260.0, 12.0), Color(0.10, 0.065, 0.05))
	# shelf with books
	ci.draw_rect(Rect2(360.0, 252.0, 240.0, 8.0), Color(0.12, 0.08, 0.06))
	for i in 9:
		var hh := _h(float(i) * 2.9 + 3.0)
		var bk := Color(0.22 + 0.3 * _h(float(i)), 0.12 + 0.2 * _h(float(i) + 4.0), 0.12 + 0.2 * _h(float(i) + 8.0))
		ci.draw_rect(Rect2(370.0 + float(i) * 24.0, 252.0 - 34.0 - hh * 18.0, 20.0, 34.0 + hh * 18.0), bk)
	# wall clock: the second hand stops dead when the power does
	var cc := Vector2(470.0, 150.0)
	ci.draw_circle(cc, 34.0, Color(0.11, 0.075, 0.06))
	ci.draw_circle(cc, 29.0, Color(0.80, 0.76, 0.68))
	for i in 12:
		var ta := TAU * float(i) / 12.0
		ci.draw_line(cc + Vector2(sin(ta), -cos(ta)) * 24.0, cc + Vector2(sin(ta), -cos(ta)) * 28.0, Color(0.2, 0.15, 0.12), 1.4)
	ci.draw_line(cc, cc + Vector2(sin(2.2), -cos(2.2)) * 15.0, Color(0.1, 0.07, 0.06), 3.0)
	ci.draw_line(cc, cc + Vector2(sin(5.1), -cos(5.1)) * 22.0, Color(0.1, 0.07, 0.06), 2.0)
	var sa := TAU * fposmod(minf(t, T_CUT) * 1.0, 60.0) / 60.0
	ci.draw_line(cc, cc + Vector2(sin(sa), -cos(sa)) * 24.0, Color(0.7, 0.1, 0.1), 1.2)
	# pin board with notes
	ci.draw_rect(Rect2(610.0, 150.0, 110.0, 84.0), Color(0.28, 0.2, 0.12))
	for i in 5:
		ci.draw_rect(Rect2(620.0 + float(i % 3) * 32.0, 160.0 + float(floori(float(i) / 3.0)) * 34.0, 24.0, 26.0), Color(0.9, 0.82 - 0.2 * float(i % 2), 0.4 + 0.3 * float(i % 2)))
	# desk
	ci.draw_rect(Rect2(600.0, 416.0, 670.0, 14.0), Color(0.30, 0.19, 0.12))
	ci.draw_rect(Rect2(600.0, 416.0, 670.0, 3.0), Color(0.46, 0.31, 0.2))
	ci.draw_rect(Rect2(612.0, 430.0, 16.0, FLOOR - 430.0), Color(0.19, 0.12, 0.08))
	ci.draw_rect(Rect2(1244.0, 430.0, 16.0, FLOOR - 430.0), Color(0.19, 0.12, 0.08))
	ci.draw_rect(Rect2(612.0, 470.0, 648.0, 8.0), Color(0.17, 0.11, 0.07))
	# desk lamp
	ci.draw_colored_polygon(PackedVector2Array([Vector2(606.0, 416.0), Vector2(650.0, 416.0), Vector2(644.0, 408.0), Vector2(612.0, 408.0)]), Color(0.11, 0.11, 0.14))
	Gfx.capsule(ci, Vector2(628.0, 410.0), Vector2(646.0, 350.0), 6.0, 6.0, Color(0.13, 0.13, 0.16))
	Gfx.capsule(ci, Vector2(646.0, 350.0), Vector2(672.0, 318.0), 6.0, 6.0, Color(0.13, 0.13, 0.16))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(650.0, 300.0), Vector2(704.0, 308.0), Vector2(718.0, 336.0), Vector2(660.0, 330.0)]), Color(0.17, 0.16, 0.2))
	ci.draw_circle(Vector2(690.0, 331.0), 6.5, Color(0.25, 0.22, 0.2).lerp(Color(1.0, 0.92, 0.65), lamp))
	# keyboard + mug
	ci.draw_rect(Rect2(800.0, 405.0, 140.0, 11.0), Color(0.11, 0.11, 0.14))
	for i in 14:
		ci.draw_rect(Rect2(804.0 + float(i) * 9.6, 402.0, 7.0, 3.0), Color(0.2, 0.2, 0.27))
	ci.draw_rect(Rect2(950.0, 394.0, 22.0, 22.0), Color(0.7, 0.68, 0.64))
	ci.draw_arc(Vector2(973.0, 404.0), 6.0, -PI * 0.5, PI * 0.5, 8, Color(0.7, 0.68, 0.64), 3.0)
	for i in 3:
		var sx0 := 956.0 + float(i) * 6.0
		var sy0 := 388.0 - fposmod(t * 14.0 + float(i) * 6.0, 18.0)
		ci.draw_line(Vector2(sx0, sy0), Vector2(sx0 + sin(t * 2.0 + float(i)) * 3.0, sy0 - 8.0), Color(0.9, 0.9, 1.0, 0.16 * (1.0 - (388.0 - sy0) / 18.0)), 2.0)
	# the PC tower, its fan, its cable
	Gfx.vquad(ci, 1195.0, 1268.0, 318.0, 416.0, Color(0.09, 0.09, 0.13), Color(0.05, 0.05, 0.08))
	for i in 5:
		ci.draw_line(Vector2(1202.0, 356.0 + float(i) * 6.0), Vector2(1214.0, 356.0 + float(i) * 6.0), Color(0, 0, 0, 0.5), 1.4)
	ci.draw_circle(Vector2(1206.0, 332.0), 3.0, Color(0.3, 0.6, 1.0))
	ci.draw_circle(Vector2(1206.0, 344.0), 2.4, Color(0.55, 0.12, 0.1).lerp(Color(1.0, 0.25, 0.15), 0.5 + 0.5 * sin(t * 23.0) * sin(t * 7.0)))
	var fc := Vector2(1236.0, 380.0)
	ci.draw_circle(fc, 24.0, Color(0.03, 0.03, 0.05))
	for i in 5:
		var fa := t * 16.0 + TAU * float(i) / 5.0
		ci.draw_colored_polygon(PackedVector2Array([fc, fc + Vector2(cos(fa), sin(fa)) * 20.0, fc + Vector2(cos(fa + 0.55), sin(fa + 0.55)) * 20.0]), Color(0.15, 0.15, 0.2))
	ci.draw_arc(fc, 23.0, 0.0, TAU, 20, Color(0.2, 0.2, 0.26), 1.4)
	var plug := Vector2(1240.0, 536.0).lerp(Vector2(1190.0, 552.0), _e((t - T_CUT - 0.05) / 0.4))
	ci.draw_polyline(PackedVector2Array([Vector2(1268.0, 398.0), Vector2(1280.0, 440.0), Vector2(1272.0, 500.0), plug + Vector2(10.0, -6.0), plug]), Color(0.06, 0.06, 0.08), 3.0)
	ci.draw_rect(Rect2(1210.0, 518.0, 34.0, 34.0), Color(0.72, 0.69, 0.62))
	ci.draw_circle(Vector2(1220.0, 535.0), 2.4, Color(0.15, 0.12, 0.1))
	ci.draw_circle(Vector2(1234.0, 535.0), 2.4, Color(0.15, 0.12, 0.1))
	ci.draw_rect(Rect2(plug.x - 8.0, plug.y - 6.0, 16.0, 12.0), Color(0.08, 0.08, 0.1))
	# his lantern, waiting on the desk until he grabs it


static func _window_glass(ci: CanvasItem, t: float) -> void:
	Gfx.vquad(ci, 72.0, 288.0, 112.0, 318.0, Color(0.04, 0.07, 0.19), Color(0.11, 0.15, 0.30))
	for i in 14:
		ci.draw_circle(Vector2(80.0 + _h(float(i) * 1.3) * 200.0, 120.0 + _h(float(i) * 2.9) * 110.0), 1.1, Color(0.8, 0.88, 1.0, 0.5 + 0.4 * sin(t + float(i))))
	Gfx.glow(ci, Vector2(232.0, 168.0), 70.0, Color(0.5, 0.65, 1.0, 0.35))
	ci.draw_circle(Vector2(232.0, 168.0), 15.0, Color(0.86, 0.9, 1.0))
	for i in 6:
		var tx := 82.0 + float(i) * 38.0
		var th := 60.0 + _h(float(i) + 12.0) * 40.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tx, 318.0 - th), Vector2(tx + 24.0, 318.0), Vector2(tx - 24.0, 318.0)]), Color(0.02, 0.03, 0.07))
	ci.draw_line(Vector2(180.0, 112.0), Vector2(180.0, 318.0), Color(0.08, 0.05, 0.04), 7.0)
	ci.draw_line(Vector2(72.0, 215.0), Vector2(288.0, 215.0), Color(0.08, 0.05, 0.04), 7.0)


static func _chair(ci: CanvasItem, t: float, cs: float, ct: Vector2) -> void:
	var u := _e((t - T_CUT - 0.1) / 0.75)
	var pos := Vector2(714.0 - 150.0 * u, FLOOR)
	ci.draw_set_transform(ct + pos * cs, -1.35 * u, Vector2(cs, cs))
	var dark := Color(0.10, 0.10, 0.12)
	ci.draw_rect(Rect2(-6.0, -90.0, 12.0, 82.0), dark)
	Gfx.capsule(ci, Vector2(-52.0, -8.0), Vector2(52.0, -8.0), 9.0, 9.0, dark)
	for i in 3:
		ci.draw_circle(Vector2(-50.0 + float(i) * 50.0, -3.0), 6.0, Color(0.05, 0.05, 0.06))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-44.0, -100.0), Vector2(95.0, -100.0), Vector2(90.0, -82.0), Vector2(-40.0, -82.0)]), Color(0.14, 0.11, 0.2))
	Gfx.capsule(ci, Vector2(-34.0, -96.0), Vector2(-40.0, -232.0), 18.0, 15.0, Color(0.16, 0.13, 0.23))
	ci.draw_line(Vector2(-27.0, -108.0), Vector2(-32.0, -222.0), Color(0.3, 0.26, 0.4, 0.6), 2.0)


static func _monitor_body(ci: CanvasItem) -> void:
	var r := MONITOR.grow(14.0)
	Gfx.capsule(ci, Vector2(1040.0, 416.0), Vector2(1040.0, 392.0), 16.0, 11.0, Color(0.07, 0.07, 0.09))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(1000.0, 416.0), Vector2(1080.0, 416.0), Vector2(1070.0, 407.0), Vector2(1010.0, 407.0)]), Color(0.06, 0.06, 0.08))
	ci.draw_rect(r, Color(0.045, 0.045, 0.06))
	ci.draw_line(r.position, r.position + Vector2(r.size.x, 0.0), Color(0.4, 0.45, 0.6, 0.35), 1.6)
	ci.draw_circle(Vector2(r.position.x + r.size.x * 0.5, r.end.y - 6.0), 1.6, Color(0.3, 0.6, 1.0))


## Joint-by-joint pose of the runner at time t, in room coordinates. Phases: typing, startle at the cut,
## standing up and grabbing his lantern, backing away, freezing, clutching his head, being dragged to the
## screen (stretching toward it) and swallowed (shrinking into it).
static func _pose(t: float) -> Dictionary:
	var stand_hy := FLOOR - 57.0 * K
	var hip := SEAT
	var ang := 0.20
	var h0 := Vector2(832.0, 405.0)
	var h1 := Vector2(860.0, 406.0)
	var f0 := Vector2(806.0, FLOOR - 14.0)
	var f1 := Vector2(780.0, FLOOR - 14.0)
	var head := Vector2.ZERO
	var wide := 1.0
	var lan := 0.0
	var lit := 0.0
	var lan_ang := 0.0
	var rot := 0.0
	var sx := 1.0
	var sy := 1.0
	var ss := 1.0
	var vis := 1.0
	var tre := 0.0
	if t < T_CUT + 0.1:
		hip = SEAT + Vector2(0.0, sin(t * 1.1) * 1.2)
		ang = 0.20 + 0.012 * sin(t * 0.9)
		h0 = Vector2(832.0 + 4.0 * sin(t * 9.0), 405.0 - 2.5 * absf(sin(t * 9.5)))
		h1 = Vector2(860.0 + 4.0 * sin(t * 7.7 + 1.0), 406.0 - 2.5 * absf(sin(t * 8.3)))
		head = Vector2(sin(t * 0.5) * 0.8, 0.0)
	else:
		var s1 := _e((t - T_CUT - 0.1) / 0.45)
		var s2 := _e((t - 21.5) / 1.0)
		var s3 := _e((t - 22.2) / 1.8)
		var hx := lerpf(SEAT.x - 36.0 * s1, 585.0, s3)
		var hy := lerpf(SEAT.y - 14.0 * s1, stand_hy, s2)
		ang = lerpf(lerpf(0.20, -0.5, s1), -0.12, s2)
		var walk := 1.0 - _e((t - 23.5) / 0.4)
		var ph := (t - 22.2) * 4.6
		var mv := walk * _e((t - 22.0) / 0.3)
		tre = 0.25 + 0.6 * _e((t - T_WAKE) / 1.0)
		wide = lerpf(1.0, 1.75, s1)
		# glitch: he crouches and clutches his head
		var gc := _e((t - T_GLITCH) / 0.5)
		hy += 16.0 * gc
		hip = Vector2(hx, hy)
		var sh := hip + Vector2(sin(ang), -cos(ang)) * (36.0 * K)
		var hd := sh + Vector2(sin(ang), -cos(ang)) * (16.0 * K)
		# arms: hands thrown up -> grab the lantern -> hold it low; the free hand goes to his mouth, then his head
		var up0 := sh + Vector2(55.0, -75.0)
		var up1 := sh + Vector2(18.0, -95.0)
		var g := _e((t - 21.85) / 0.45)
		var lift := _e((t - 22.3) / 0.6)
		h0 = Vector2(832.0, 405.0).lerp(up0, s1)
		h0 = h0.lerp(Vector2(777.0, 378.0), g)
		h0 = h0.lerp(sh + Vector2(40.0, 52.0), lift)
		h1 = Vector2(860.0, 406.0).lerp(up1, s1)
		h1 = h1.lerp(sh + Vector2(34.0, -36.0), _e((t - T_WAKE) / 0.5))
		h1 = h1.lerp(hd + Vector2(-12.0, 6.0), gc)
		lan = _e((t - 21.95) / 0.1)
		lit = _e((t - 22.0) / 0.6)
		lan_ang = 0.3 * sin(t * 4.0) * (0.4 + tre)
		# legs: seated -> standing -> a stumbling walk backwards
		var l0 := Vector2(806.0, FLOOR - 14.0).lerp(Vector2(hx + 22.0, FLOOR - 14.0), s2)
		var l1 := Vector2(780.0, FLOOR - 14.0).lerp(Vector2(hx - 18.0, FLOOR - 14.0), s2)
		f0 = l0 + Vector2(sin(ph) * 14.0 * mv, -maxf(0.0, sin(ph)) * 20.0 * mv)
		f1 = l1 + Vector2(sin(ph + PI) * 14.0 * mv, -maxf(0.0, sin(ph + PI)) * 20.0 * mv)
		head = Vector2(sin(t * 31.0), cos(t * 27.0)) * 1.8 * tre + Vector2(sin(t * 7.0) * 3.0 * s1 * (1.0 - s3), 0.0)
		# dragged into the screen
		var p := _e((t - T_PULL) / 3.6)
		if p > 0.0:
			var q := pow(p, 1.8)
			var c := MONITOR.position + MONITOR.size * 0.5
			hip = Vector2(lerpf(hx, 870.0, q), lerpf(hy, 300.0, q * q))
			ang = lerpf(ang, 1.45, p)
			var sh2 := hip + Vector2(sin(ang), -cos(ang)) * (36.0 * K)
			h0 = sh2 + Vector2(66.0, 10.0)
			h1 = sh2 + Vector2(60.0, -16.0) + Vector2(sin(t * 40.0), cos(t * 33.0)) * 3.0
			f0 = hip + Vector2(-80.0, 34.0)
			f1 = hip + Vector2(-98.0, 12.0)
			sx = 1.0 + 0.9 * q
			sy = 1.0 - 0.3 * q
			var sk := _e((t - T_SUCK) / 0.9)
			ss = 1.0 - 0.92 * sk
			vis = 1.0 - _e((t - T_SUCK - 0.6) / 0.4)
			rot = 0.0
			lan_ang = 0.0
			head = Vector2.ZERO
			tre = 0.0
			wide = 2.0
			var pos2 := c + (hip - c) * ss
			var d := {"hip": hip, "pos": pos2, "ang": ang, "h0": h0, "h1": h1, "f0": f0, "f1": f1, "head": head, "wide": wide, "rot": rot, "sx": sx, "sy": sy, "ss": ss, "vis": vis, "lan": lan, "lit": lit, "lan_ang": lan_ang}
			d["lpos"] = pos2 + (h0 - hip) * ss + Vector2(0.0, 17.0 * K * ss)
			return d
	var out := {"hip": hip, "pos": hip, "ang": ang, "h0": h0, "h1": h1, "f0": f0, "f1": f1, "head": head, "wide": wide, "rot": rot, "sx": sx, "sy": sy, "ss": ss, "vis": vis, "lan": lan, "lit": lit, "lan_ang": lan_ang}
	out["lpos"] = h0 + Vector2(sin(lan_ang), cos(lan_ang)) * 17.0 * K if lan > 0.5 else Vector2(777.0, 393.0)
	return out


## Lantern in the game's own construction (cage, glass, cap). `c` = its centre, `sc` = scale in room px per unit.
static func _lantern(ci: CanvasItem, c: Vector2, ang: float, lit: float, sc: float, a: float) -> void:
	var s := K * sc
	var cage := PackedVector2Array([Vector2(-6.5, -8.0), Vector2(6.5, -8.0), Vector2(7.5, 9.0), Vector2(-7.5, 9.0)])
	var glass := PackedVector2Array([Vector2(-4.5, -5.5), Vector2(4.5, -5.5), Vector2(5.0, 6.5), Vector2(-5.0, 6.5)])
	for i in 4:
		cage[i] = c + (cage[i] * s).rotated(ang)
		glass[i] = c + (glass[i] * s).rotated(ang)
	ci.draw_colored_polygon(cage, Color(0.10, 0.08, 0.13, a))
	ci.draw_colored_polygon(glass, Color(0.30, 0.20, 0.10, a).lerp(CharacterDrawer.GLASS, lit))
	ci.draw_colored_polygon(PackedVector2Array([c + (Vector2(-7.5, -8.0) * s).rotated(ang), c + (Vector2(0.0, -14.0) * s).rotated(ang), c + (Vector2(7.5, -8.0) * s).rotated(ang)]), Color(0.10, 0.08, 0.13, a))


static func _a(c: Color, v: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * v)


static func _person_scene(ci: CanvasItem, t: float, cs: float, ct: Vector2) -> void:
	var p := _pose(t)
	var vis: float = p["vis"]
	if vis <= 0.01:
		return
	var hip: Vector2 = p["hip"]
	var pos: Vector2 = p["pos"]
	var ss: float = p["ss"]
	var ang: float = p["ang"]
	var head_off: Vector2 = p["head"]
	var wide: float = p["wide"]
	var lan_ang: float = p["lan_ang"]
	var lit: float = p["lit"]
	var lan: float = p["lan"]
	var rot: float = p["rot"]
	var sx: float = p["sx"]
	var sy: float = p["sy"]
	var ph0: Vector2 = p["h0"]
	var ph1: Vector2 = p["h1"]
	var pf0: Vector2 = p["f0"]
	var pf1: Vector2 = p["f1"]
	var h0 := (ph0 - hip) / K
	var h1 := (ph1 - hip) / K
	var f0 := (pf0 - hip) / K
	var f1 := (pf1 - hip) / K
	ci.draw_set_transform(ct + pos * cs, rot, Vector2(cs * K * ss * sx, cs * K * ss * sy))
	var coat := _a(CharacterDrawer.COAT, vis)
	var coat_d := _a(CharacterDrawer.COAT_D, vis)
	var coat_far := _a(CharacterDrawer.COAT_FAR, vis)
	var trim := _a(CharacterDrawer.TRIM, vis)
	var rim_off := Vector2(2.4, -1.6)
	var td := Vector2(sin(ang), -cos(ang))
	var fwd := Vector2(-td.y, td.x)
	var sh := td * CharacterDrawer.TORSO
	var head := sh + td * 16.0 + head_off
	var kn0 := Gfx.ik(Vector2(2.0, 0.0), f0, CharacterDrawer.THIGH, CharacterDrawer.SHIN, -1.0)
	var kn1 := Gfx.ik(Vector2(-2.0, 0.0), f1, CharacterDrawer.THIGH, CharacterDrawer.SHIN, -1.0)
	var el0 := Gfx.ik(sh, h0, CharacterDrawer.UARM, CharacterDrawer.FARM, 1.0)
	var el1 := Gfx.ik(sh, h1, CharacterDrawer.UARM, CharacterDrawer.FARM, 1.0)
	# far side
	CharacterDrawer._limb(ci, Vector2(-2.0, 0.0), kn1, f1, 13.0, 9.0, coat_far, rim_off, false)
	CharacterDrawer._boot(ci, f1 + Vector2(0.0, 5.0), 0.0, _a(CharacterDrawer.BOOT, vis))
	CharacterDrawer._limb(ci, sh, el1, h1, 9.0, 7.0, coat_far, rim_off, false)
	# hood tail + the ash scarf, hanging behind the neck
	var tail := head - fwd * 6.0
	for i in 3:
		Gfx.capsule(ci, tail + Vector2(-float(i) * 7.0, float(i) * 3.0), tail + Vector2(-float(i + 1) * 7.0, float(i + 1) * 3.0), 11.0 - float(i) * 3.0, 11.0 - float(i + 1) * 3.0, coat_d)
	var neck := sh + td * 5.0
	Gfx.capsule(ci, neck, neck + Vector2(-9.0, 9.0), 10.0, 8.0, _a(Color(0.72, 0.69, 0.78), vis))
	Gfx.capsule(ci, neck + Vector2(-9.0, 9.0), neck + Vector2(-13.0, 26.0), 8.0, 5.0, _a(Color(0.72, 0.69, 0.78), vis))
	# torso + coat
	var hem_front := fwd * 12.0 + Vector2(0.0, 13.0)
	var hem_back := Vector2(-16.0, 14.0)
	Gfx.vgrad(ci, PackedVector2Array([sh - fwd * 11.0, sh + fwd * 11.0, hem_front, hem_back]), sh.y, maxf(hem_back.y, hem_front.y), coat, coat_d)
	Gfx.capsule(ci, td * 8.0, sh, 22.0, 25.0, coat)
	ci.draw_line(sh + fwd * 11.0 + rim_off, hem_front + rim_off, _a(CharacterDrawer.RIM, vis), 2.0, true)
	ci.draw_line(-fwd * 10.0, fwd * 11.0, trim, 4.0, true)
	ci.draw_circle(fwd * 1.0, 2.6, Color(0.95, 0.8, 0.4, vis))
	# near side
	CharacterDrawer._limb(ci, Vector2(2.0, 0.0), kn0, f0, 14.0, 10.0, coat, rim_off, true)
	CharacterDrawer._boot(ci, f0 + Vector2(0.0, 5.0), 0.0, _a(CharacterDrawer.BOOT, vis))
	CharacterDrawer._limb(ci, sh, el0, h0, 10.0, 8.0, coat, rim_off, true)
	ci.draw_circle(h0, 5.0, Color(0.82, 0.76, 0.84, vis))
	CharacterDrawer._limb(ci, sh, el1, h1, 10.0, 8.0, coat, rim_off, true)
	ci.draw_circle(h1, 5.0, Color(0.82, 0.76, 0.84, vis))
	if lan > 0.5:   # the lantern on its short chain, from his near hand
		var lc := h0 + Vector2(sin(lan_ang), cos(lan_ang)) * 17.0
		ci.draw_line(h0, lc + Vector2(0.0, -8.0).rotated(lan_ang * 0.6), _a(CharacterDrawer.BOOT, vis), 1.6, true)
		_lantern(ci, lc, lan_ang * 0.5, lit, 1.0 / K, vis)
	# head: shadowed hood, one wide eye. Fear = a wider, paler eye with a pinpoint pupil.
	ci.draw_circle(head + rim_off, 16.8, _a(CharacterDrawer.RIM, vis))
	ci.draw_circle(head, 15.5, coat)
	ci.draw_circle(head + fwd * 4.5 + Vector2(0.0, 0.5), 10.6, Color(0.035, 0.025, 0.06, vis))
	ci.draw_arc(head, 15.2, ang - 2.2, ang + 0.4, 14, trim, 1.8, true)
	ci.draw_circle(head + fwd * 9.0 + Vector2(0.0, -1.0), 2.4 * wide, Color(0.96, 0.93, 1.0, vis))
	ci.draw_circle(head + fwd * (9.0 + 0.8 * wide) + Vector2(0.0, -1.0), 1.0 / sqrt(wide), Color(0.03, 0.02, 0.06, vis))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ======================================================================================== THE SCREEN
const CODE_COLS := [Color(0.40, 0.92, 0.62), Color(0.42, 0.72, 1.0), Color(1.0, 0.72, 0.42), Color(0.82, 0.62, 1.0)]
const TERM_LINES := ["> connection lost", "> searching for user...", "> user found."]


static func screen(ci: CanvasItem, t: float) -> void:
	var r := MONITOR
	var g := glitch(t)
	if t < T_WAKE:
		ci.draw_rect(r, Color(0.02, 0.035, 0.07))
		_code(ci, r, minf(t, T_CUT))
		if t >= T_CUT:   # the display quivers but does not die
			ci.draw_rect(r, Color(0.0, 0.0, 0.02, 0.30 + 0.25 * sin(t * 40.0) * sin(t * 13.0)))
	elif t < T_TEXT:
		ci.draw_rect(r, Color(0.0, 0.0, 0.0))
		var nb := 1.0 - _e((t - T_WAKE) / 0.5)   # one burst of static as it comes up
		for i in 14:
			var ny := r.position.y + _h(float(i) + floorf(t * 30.0)) * r.size.y
			ci.draw_rect(Rect2(r.position.x, ny, r.size.x, 2.0 + 4.0 * _h(float(i) * 3.0)), Color(0.8, 0.9, 1.0, 0.5 * nb))
		if fposmod(t, 0.8) < 0.45:
			ci.draw_rect(Rect2(r.position.x + 12.0, r.position.y + 14.0, 7.0, 11.0), Color(0.5, 1.0, 0.7))
	elif t < T_ZOOM + 3.2:
		ci.draw_rect(r, Color(0.0, 0.01, 0.02))
		_terminal(ci, r, t, g)
	else:
		ci.draw_rect(r, Color(0.0, 0.01, 0.02))
		_tunnel(ci, r, t)
	# scanlines + a faint glass sheen
	for i in range(0, 33):
		ci.draw_line(r.position + Vector2(0.0, float(i) * 4.0), r.position + Vector2(r.size.x, float(i) * 4.0), Color(0, 0, 0, 0.16), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.5, 0.0), r.position + Vector2(r.size.x * 0.25, r.size.y), r.position + Vector2(0.0, r.size.y)]), Color(1, 1, 1, 0.035))


static func _code(ci: CanvasItem, r: Rect2, t: float) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 12.0), Color(0.06, 0.08, 0.14))
	for i in 3:
		ci.draw_circle(r.position + Vector2(8.0 + float(i) * 8.0, 6.0), 2.0, Color(0.9 - 0.3 * float(i), 0.3 + 0.3 * float(i), 0.3))
	ci.draw_rect(Rect2(r.position.x, r.position.y + 12.0, 30.0, r.size.y - 12.0), Color(0.03, 0.045, 0.09))
	var off := fposmod(t * 14.0, 10.0)
	var base := floori(t * 1.4)
	var last_end := r.position
	for i in 12:
		var idx := float(base + i)
		var hh := _h(idx * 1.37)
		var ind := floorf(_h(idx * 2.11) * 4.0) * 12.0
		var ln := 22.0 + hh * 130.0
		var y := r.position.y + 18.0 + float(i) * 10.0 - off
		if y < r.position.y + 13.0 or y > r.end.y - 4.0:
			continue
		ci.draw_rect(Rect2(r.position.x + 4.0, y, 18.0, 3.0), Color(0.25, 0.3, 0.45, 0.6))
		var col: Color = CODE_COLS[int(floorf(_h(idx * 3.7) * 4.0)) % 4]
		ci.draw_rect(Rect2(r.position.x + 36.0 + ind, y, minf(ln, r.size.x - 44.0 - ind), 3.0), Color(col.r, col.g, col.b, 0.85))
		if hh > 0.45:
			ci.draw_rect(Rect2(r.position.x + 36.0 + ind + minf(ln, r.size.x - 44.0 - ind) + 5.0, y, 24.0 + 30.0 * hh, 3.0), Color(0.85, 0.85, 0.95, 0.55))
		last_end = Vector2(r.position.x + 36.0 + ind + minf(ln, r.size.x - 44.0 - ind) + 4.0, y)
	if fposmod(t, 0.9) < 0.55:
		ci.draw_rect(Rect2(last_end.x, last_end.y - 3.0, 4.0, 9.0), Color(0.9, 0.95, 1.0, 0.9))


static func _terminal(ci: CanvasItem, r: Rect2, t: float, g: float) -> void:
	var f: Font = GameState.f_ui
	var starts := [T_TEXT, T_TEXT + 1.2, T_TEXT + 2.3]
	for i in TERM_LINES.size():
		var s: String = TERM_LINES[i]
		var n := clampi(int((t - starts[i]) * 26.0), 0, s.length())
		if n <= 0:
			continue
		var jx := 0.0
		if g > 0.0 and _h(float(i) + floorf(t * 14.0)) > 0.6:
			jx = (_h(float(i) * 3.0 + floorf(t * 14.0)) - 0.5) * 22.0 * g
		ci.draw_string(f, r.position + Vector2(12.0 + jx + 1.0, 24.0 + float(i) * 14.0 + 1.0), s.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.0, 0.3, 0.2, 0.7))
		ci.draw_string(f, r.position + Vector2(12.0 + jx, 24.0 + float(i) * 14.0), s.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 1.0, 0.75))
	# the title card
	var la := _e((t - T_LOGO) / 0.9)
	if la <= 0.0:
		return
	if _logo == null:
		_logo = load("res://assets/images/logo.png") as Texture2D
	if _logo == null:
		return
	var w := r.size.x * 0.86
	var h := w * float(_logo.get_height()) / float(_logo.get_width())
	var c := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.66)
	var flick := 0.8 + 0.2 * sin(t * 45.0) * sin(t * 11.0)
	if g <= 0.0:
		ci.draw_texture_rect(_logo, Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), false, Color(1, 1, 1, la * flick))
		return
	# glitching: the title is cut into strips that slide apart, with colour-split ghosts behind it
	var n := 12
	var tw := float(_logo.get_width())
	var th := float(_logo.get_height())
	for k in 2:
		var ghost := Color(1.0, 0.1, 0.3, 0.45 * g) if k == 0 else Color(0.1, 0.9, 1.0, 0.45 * g)
		var dx := (3.0 + 5.0 * g) * (1.0 if k == 0 else -1.0)
		ci.draw_texture_rect(_logo, Rect2(c.x - w * 0.5 + dx, c.y - h * 0.5, w, h), false, ghost)
	for i in n:
		var sy := th * float(i) / float(n)
		var hs := _h(float(i) + floorf(t * 13.0) * 1.7)
		var sl := (hs - 0.5) * 34.0 * g * (1.0 if hs > 0.35 else 0.0)
		ci.draw_texture_rect_region(_logo, Rect2(c.x - w * 0.5 + sl, c.y - h * 0.5 + h * float(i) / float(n), w, h / float(n)), Rect2(0.0, sy, tw, th / float(n)), Color(1, 1, 1, la * flick))
	for i in 5:   # blocks of corruption
		var bx := r.position.x + _h(float(i) + floorf(t * 17.0)) * r.size.x
		var by := r.position.y + _h(float(i) * 4.0 + floorf(t * 17.0)) * r.size.y
		ci.draw_rect(Rect2(bx, by, 10.0 + 40.0 * _h(float(i) * 9.0), 2.0 + 5.0 * _h(float(i) * 6.0)), Color(0.9, 0.95, 1.0, 0.7 * g))


## What lies beyond the glass: a tunnel of rectangles rushing toward you.
static func _tunnel(ci: CanvasItem, r: Rect2, t: float) -> void:
	var c := r.position + r.size * 0.5
	var sp := (t - T_ZOOM) * 0.7
	for i in 14:
		var f := fposmod(float(i) / 14.0 + sp, 1.0)
		var k := pow(f, 2.2)
		var hw := r.size.x * 0.5 * (0.06 + 1.4 * k)
		var hh := r.size.y * 0.5 * (0.06 + 1.4 * k)
		var col := Color(0.3, 0.9, 1.0, 1.0 * (1.0 - f)) if i % 2 == 0 else Color(1.0, 0.3, 0.7, 0.9 * (1.0 - f))
		ci.draw_rect(Rect2(c.x - hw + (_h(float(i) + floorf(t * 20.0)) - 0.5) * 6.0, c.y - hh, hw * 2.0, hh * 2.0), col, false, 2.4 + 4.0 * k)
	for i in 30:
		var ang := _h(float(i) * 1.9) * TAU
		var d := fposmod(_h(float(i) * 4.4) + sp * 1.7, 1.0)
		ci.draw_line(c + Vector2(cos(ang), sin(ang)) * d * 120.0, c + Vector2(cos(ang), sin(ang)) * (d * 120.0 + 18.0 * d), Color(0.8, 0.95, 1.0, 0.8 * d), 1.2)


# ======================================================================================== LIGHT PASS (additive)
static func _mon_i(t: float) -> float:
	var v := 0.22
	if t >= T_CUT and t < T_WAKE:
		v = 0.22 + 0.06 * sin(t * 30.0)
	if t >= T_WAKE:
		v = 0.55 - 0.2 * _e((t - T_WAKE) / 2.0)
	if t >= T_GLITCH:
		v = 0.4 + 0.5 * glitch(t) * (0.5 + 0.5 * sin(t * 37.0 + _h(floorf(t * 18.0)) * 9.0))
	return v


static func interior_light(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	var z := _int_z(t)
	var aw := _int_anchor(t)
	var an := Vector2(640.0, 360.0) + _shake(t)
	ci.draw_set_transform(vo + (an - aw * z) * vs, 0.0, Vector2(vs * z, vs * z))
	var lamp := _lamp(t)
	var mc := MONITOR.position + MONITOR.size * 0.5
	# lamp
	if lamp > 0.0:
		Gfx.glow(ci, Vector2(690.0, 331.0), 470.0, Color(1.0, 0.72, 0.36, 0.22 * lamp))
		Gfx.glow_ellipse(ci, Vector2(780.0, 420.0), 280.0, 40.0, Color(1.0, 0.7, 0.35, 0.18 * lamp))
		Gfx.glow(ci, Vector2(640.0, 330.0), 760.0, Color(1.0, 0.7, 0.4, 0.08 * lamp))
	# moonlight through the window
	var nl := 1.0 - lamp
	Gfx.glow(ci, Vector2(700.0, 330.0), 650.0, Color(0.30, 0.42, 0.9, 0.09 * nl))   # cold ambient fill, so he stays readable in the dark
	Gfx.glow_ellipse(ci, Vector2(180.0, 215.0), 270.0, 230.0, Color(0.3, 0.45, 0.9, 0.08 + 0.09 * nl))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(80.0, 318.0), Vector2(290.0, 318.0), Vector2(470.0, FLOOR), Vector2(150.0, FLOOR)]), Color(0.5, 0.65, 1.0, 0.040 + 0.035 * nl))
	Gfx.glow_ellipse(ci, Vector2(310.0, FLOOR + 14.0), 190.0, 22.0, Color(0.5, 0.65, 1.0, 0.10 + 0.08 * nl))
	# the monitor: cool light that keeps pouring out of a machine with no power
	var mi := _mon_i(t)
	var g := glitch(t)
	var mcol := Color(0.35, 0.72, 1.0).lerp(Color(1.0, 0.25, 0.55), 0.55 * g * (1.0 if sin(t * 29.0) > 0.0 else 0.0))
	Gfx.glow(ci, mc, 620.0, Color(mcol.r, mcol.g, mcol.b, 0.42 * mi))
	Gfx.glow_ellipse(ci, Vector2(mc.x, 420.0), 340.0, 44.0, Color(mcol.r, mcol.g, mcol.b, 0.38 * mi))
	Gfx.glow(ci, Vector2(1206.0, 332.0), 20.0, Color(0.3, 0.6, 1.0, 0.7))
	Gfx.glow(ci, Vector2(1206.0, 344.0), 14.0, Color(1.0, 0.2, 0.15, 0.45 + 0.4 * sin(t * 23.0) * sin(t * 7.0)))
	# the power cut: a spark at the socket
	var sp := exp(-(t - T_CUT) * 13.0) if t >= T_CUT else 0.0
	if sp > 0.02:
		Gfx.glow(ci, Vector2(1227.0, 536.0), 130.0, Color(0.8, 0.9, 1.0, 0.9 * sp))
		for i in 7:
			var ra := _h(float(i) * 2.2) * TAU
			ci.draw_line(Vector2(1227.0, 536.0), Vector2(1227.0, 536.0) + Vector2(cos(ra), sin(ra) - 0.4) * (14.0 + 40.0 * (1.0 - sp)), Color(1.0, 0.95, 0.7, sp), 1.6)
	# his lantern lights up in his hand
	var p := _pose(t)
	var lit: float = p["lit"]
	if lit > 0.0 and float(p["vis"]) > 0.05:
		var lp: Vector2 = p["lpos"]
		Gfx.glow(ci, lp, 330.0 * float(p["ss"]), Color(1.0, 0.72, 0.3, 0.55 * lit * float(p["vis"])))
	# sparks of data streaming from him into the screen
	var pp := _e((t - T_PULL) / 3.6)
	if pp > 0.0 and t < T_SUCK + 1.6:
		var hp: Vector2 = p["pos"]
		Gfx.glow(ci, hp, 230.0 * float(p["ss"]), Color(0.4, 0.85, 1.0, 0.30 * pp * float(p["vis"])))
		for i in 26:
			var f := fposmod(_h(float(i) * 1.7) + t * (0.8 + _h(float(i)) * 0.8), 1.0)
			var origin := hp + Vector2((_h(float(i) * 3.3) - 0.5) * 120.0, (_h(float(i) * 5.1) - 0.5) * 140.0)
			var q := origin.lerp(mc, f)
			var sz := 3.0 + 6.0 * _h(float(i) * 7.0)
			ci.draw_rect(Rect2(q.x - sz * 0.5, q.y - sz * 0.5, sz, sz), Color(0.5, 0.95, 1.0, 0.8 * pp * (1.0 - f)))
	# the screen is overwhelmingly bright by the time we are inside it
	var zz := _e((t - T_ZOOM - 2.0) / 3.0)
	if zz > 0.0:
		Gfx.glow(ci, mc, 700.0, Color(0.6, 0.9, 1.0, 0.5 * zz))
