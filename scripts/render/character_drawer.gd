class_name CharacterDrawer
extends RefCounted
## The runner: a hooded figure with a lantern. Fully procedural, so every pose is continuous.
##
## Run cycle: each leg follows a stance/swing path (foot planted and moving back at ground
## speed, then lifting and swinging forward); the hips bounce twice per cycle (lowest in mid
## stance, highest in flight), the torso leans with acceleration, arms counter-swing, the coat
## hem / hood tail / scarf lag behind, and the lantern swings on a real pendulum.
## Poses for jump, fall, slide, dash, landing crouch and stumble are blended on top, then
## legs/arms are solved with two-bone IK.

const SCARF := Color(0.72, 0.69, 0.78)   ## the base neck scarf (fixed ash); cosmetics are layered on top
const COAT := Color(0.28, 0.23, 0.42)
const COAT_D := Color(0.14, 0.11, 0.24)
const COAT_FAR := Color(0.12, 0.09, 0.20)
const TRIM := Color(0.70, 0.64, 0.84)
const BOOT := Color(0.09, 0.07, 0.14)
const RIM := Color(0.78, 0.82, 1.0, 0.45)
const GLASS := Color(1.0, 0.70, 0.28)
const HIP_H := 57.0
const THIGH := 32.0
const SHIN := 32.0
const TORSO := 36.0
const UARM := 20.0
const FARM := 20.0


## Foot path over one gait cycle (u in 0..1). Planted: the foot slides back at exactly ground speed.
## Swing: a Hermite curve that leaves the ground and arrives still moving backward (leg retraction),
## so foot velocity is continuous at toe-off and touch-down - no hitch, no skating.
static func _run_foot(u: float, stance: float, rf: float, rb: float, lift: float) -> Vector2:
	if u < stance:
		return Vector2(lerpf(rf, -rb, u / stance), 0.0)
	var span := 1.0 - stance
	var s := (u - stance) / span
	var vs := -(rf + rb) / stance
	var m0 := vs * 0.25 * span
	var m1 := vs * 0.65 * span
	var s2 := s * s
	var s3 := s2 * s
	var x := (2.0 * s3 - 3.0 * s2 + 1.0) * (-rb) + (s3 - 2.0 * s2 + s) * m0 + (-2.0 * s3 + 3.0 * s2) * rf + (s3 - s2) * m1
	return Vector2(x, -lift * sin(PI * pow(s, 0.8)))


static func _boot_ang(u: float, stance: float) -> float:
	if u < stance:
		var k := u / stance
		return -0.15 * (1.0 - clampf(k * 4.0, 0.0, 1.0)) + 0.5 * pow(k, 3.0)   # toe-off at the end of stance
	var s := (u - stance) / (1.0 - stance)
	return lerpf(0.6, -0.15, s * s * (3.0 - 2.0 * s))


static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, w1: float, w2: float, col: Color, rim_off: Vector2, rim: bool) -> void:
	if rim:
		Gfx.capsule(ci, a + rim_off, b + rim_off, w1 + 2.0, w1 * 0.9 + 1.5, RIM)
		Gfx.capsule(ci, b + rim_off, c + rim_off, w1 * 0.9 + 1.5, w2 + 2.0, RIM)
	Gfx.capsule(ci, a, b, w1, w1 * 0.9, col)
	Gfx.capsule(ci, b, c, w1 * 0.9, w2, col)


static func _boot(ci: CanvasItem, ankle: Vector2, ang: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(-7.0, -5.0), Vector2(5.0, -6.0), Vector2(13.0, 0.0), Vector2(14.0, 5.0), Vector2(-7.0, 5.0)])
	for i in pts.size():
		pts[i] = ankle + pts[i].rotated(ang)
	ci.draw_colored_polygon(pts, col)


static func draw(ci: CanvasItem, p: PlayerCtl, origin: Vector2, flip: float, dress: StringName) -> void:
	var lift := clampf((Cfg.GROUND_Y - p.y) / 300.0, 0.0, 1.0)
	# contact shadow + a longer one thrown away from the lantern
	Gfx.glow_ellipse(ci, Vector2(origin.x - 4.0, Cfg.GROUND_Y + 5.0), 42.0 * (1.0 - lift * 0.5), 9.0, Color(0, 0, 0, 0.6 * (1.0 - lift * 0.6)))
	Gfx.glow_ellipse(ci, Vector2(origin.x - 52.0, Cfg.GROUND_Y + 6.0), 64.0 * (1.0 - lift * 0.4), 8.0, Color(0, 0, 0, 0.28 * (1.0 - lift * 0.7)))

	var sq := p.squash
	var sc := Vector2((1.0 + sq * 0.22) * flip, 1.0 - sq * 0.32)
	ci.draw_set_transform(origin, 0.0, sc)
	var rim_off := Vector2(2.4 * flip, -1.6)

	# ------------------------------------------------------------ pose
	var u := fposmod(p.stride, 1.0)
	var sn := clampf(p.speed / 1100.0, 0.0, 1.0)
	var stance := lerpf(0.42, 0.30, sn)
	var sa := p.slide_a
	var aa := p.air_a * (1.0 - sa)
	var ra := (1.0 - aa) * (1.0 - sa)
	var da := p.dash_curve()
	var fall_w := clampf(p.vy / 1400.0 + 0.5, 0.0, 1.0)
	var crouch := maxf(sq, 0.0) * 46.0 + minf(sq, 0.0) * 22.0
	var bob := cos(TAU * 2.0 * (u - stance * 0.5)) * (4.0 + 5.0 * sn) * ra

	var hip := Vector2(lerpf(0.0, 8.0, sa), lerpf(-(HIP_H - 3.0 * sn) + bob + crouch, -27.0, sa) - 6.0 * aa)
	var ang := lerpf(lerpf(p.lean + sin(TAU * u) * 0.025 * ra, lerpf(-0.06, 0.2, fall_w), aa), -1.18, sa)
	var td := Vector2(sin(ang), -cos(ang))
	var fwd := Vector2(-td.y, td.x)   # "forward" relative to the torso
	var shoulder := hip + td * TORSO
	var head := shoulder + td * 16.0 + Vector2(1.0 + 2.0 * sn, -bob * 0.22)

	# stride sized so the planted foot moves back exactly as far as the ground moves under it
	var travel := clampf(p.speed * stance / maxf(p.cadence(), 0.5), 38.0, 100.0)
	var ankles: Array[Vector2] = []
	var knees: Array[Vector2] = []
	var boot_a: Array[float] = []
	var hands: Array[Vector2] = []
	var elbows: Array[Vector2] = []
	for i in 2:
		var ui := fposmod(u + 0.5 * float(i), 1.0)
		var run_f := _run_foot(ui, stance, travel * 0.46 + da * 8.0, travel * 0.54 + da * 6.0, 15.0 + 11.0 * sn + da * 8.0)
		var rise_f := Vector2(20.0, -32.0) if i == 0 else Vector2(-16.0, -12.0)
		var drop_f := Vector2(16.0, -3.0) if i == 0 else Vector2(-10.0, -12.0)
		var slide_f := Vector2(60.0, -9.0) if i == 0 else Vector2(40.0, -3.0)
		var f := run_f.lerp(rise_f.lerp(drop_f, fall_w), aa).lerp(slide_f, sa)
		f.y = minf(f.y, 0.0)
		var ankle := f + Vector2(0.0, -5.0)
		ankles.append(ankle)
		knees.append(Gfx.ik(hip, ankle, THIGH, SHIN, -1.0))
		boot_a.append(lerpf(lerpf(_boot_ang(ui, stance), lerpf(0.5, 0.15, fall_w), aa), -0.35, sa))

		# Natural cross-body gait: each arm swings OPPOSITE to the leg on its own side, which means it
		# moves WITH the opposite leg (left leg + right arm forward together, then right leg + left arm).
		# Phase comes from that side's actual leg phase, so arms and legs can never drift apart.
		var leg_ph := fposmod(u + 0.5 * float(i), 1.0)
		var swing := -cos(TAU * (leg_ph - 0.96))   # + = arm forward
		var amp := (13.0 if i == 0 else 24.0) + 6.0 * sn   # the near arm carries the lantern, so it swings less
		var run_h := shoulder + Vector2(swing * amp - 2.0 + (6.0 if i == 0 else 0.0), 22.0 - maxf(swing, 0.0) * (8.0 if i == 0 else 13.0))
		var dash_h := shoulder + Vector2(-36.0 - float(i) * 6.0, 10.0 + float(i) * 8.0)
		var rise_h := shoulder + (Vector2(26.0, -26.0) if i == 0 else Vector2(-14.0, -24.0))
		var drop_h := shoulder + (Vector2(30.0, -8.0) if i == 0 else Vector2(-24.0, -4.0))
		var slide_h := (shoulder + Vector2(30.0, 6.0)) if i == 0 else Vector2(-54.0, -3.0)
		var h := run_h.lerp(dash_h, da).lerp(rise_h.lerp(drop_h, fall_w), aa).lerp(slide_h, sa)
		h = shoulder + (h - shoulder).limit_length(UARM + FARM - 1.0)
		hands.append(h)
		elbows.append(Gfx.ik(shoulder, h, UARM, FARM, 1.0))

	var lantern_pt := hands[0] + Vector2(sin(p.lan_ang), cos(p.lan_ang)) * 17.0
	p.lantern_world = origin + Vector2(lantern_pt.x * sc.x, lantern_pt.y * sc.y)

	_dress_back(ci, dress, p, shoulder, td)

	# ------------------------------------------------------------ far side
	_limb(ci, hip + Vector2(-2.0, 0.0), knees[1], ankles[1], 13.0, 9.0, COAT_FAR, rim_off, false)
	_boot(ci, ankles[1], boot_a[1], Color(0.06, 0.05, 0.10))
	_limb(ci, shoulder, elbows[1], hands[1], 9.0, 7.0, COAT_FAR, rim_off, false)
	# hood tail
	var hp := p.hood
	for i in range(1, hp.size()):
		Gfx.capsule(ci, head + fwd * -6.0 + hp[i - 1], head + fwd * -6.0 + hp[i], lerpf(11.0, 4.0, float(i - 1) / 3.0), lerpf(11.0, 4.0, float(i) / 3.0), COAT_D)

	# ------------------------------------------------------------ torso + coat
	var hem_front := hip + fwd * 12.0 + Vector2(0.0, 13.0)
	var hem_back := hip + p.coat_pt
	var coat := PackedVector2Array([shoulder - fwd * 11.0, shoulder + fwd * 11.0, hem_front, hem_back])
	Gfx.vgrad(ci, coat, shoulder.y, maxf(hem_back.y, hem_front.y), COAT, COAT_D)
	Gfx.capsule(ci, hip + td * 8.0, shoulder, 22.0, 25.0, COAT)
	ci.draw_line(shoulder + fwd * 11.0 + rim_off, hem_front + rim_off, RIM, 2.0, true)
	ci.draw_line(hip - fwd * 10.0, hip + fwd * 11.0, TRIM, 4.0, true)   # belt
	ci.draw_circle(hip + fwd * 1.0, 2.6, Color(0.95, 0.8, 0.4))

	# ------------------------------------------------------------ near side
	_limb(ci, hip + Vector2(2.0, 0.0), knees[0], ankles[0], 14.0, 10.0, COAT, rim_off, true)
	_boot(ci, ankles[0], boot_a[0], BOOT)
	_limb(ci, shoulder, elbows[0], hands[0], 10.0, 8.0, COAT, rim_off, true)
	ci.draw_circle(hands[0], 5.0, Color(0.82, 0.76, 0.84))
	# lantern on a short chain
	var lc := lantern_pt
	ci.draw_line(hands[0], lc + Vector2(0.0, -8.0).rotated(p.lan_ang * 0.6), BOOT, 1.6, true)
	var cage := PackedVector2Array([Vector2(-6.5, -8.0), Vector2(6.5, -8.0), Vector2(7.5, 9.0), Vector2(-7.5, 9.0)])
	var glass := PackedVector2Array([Vector2(-4.5, -5.5), Vector2(4.5, -5.5), Vector2(5.0, 6.5), Vector2(-5.0, 6.5)])
	for i in 4:
		cage[i] = lc + cage[i].rotated(p.lan_ang * 0.5)
		glass[i] = lc + glass[i].rotated(p.lan_ang * 0.5)
	ci.draw_colored_polygon(cage, Color(0.10, 0.08, 0.13))
	ci.draw_colored_polygon(glass, GLASS)
	ci.draw_colored_polygon(PackedVector2Array([lc + Vector2(-7.5, -8.0).rotated(p.lan_ang * 0.5), lc + Vector2(0.0, -14.0).rotated(p.lan_ang * 0.5), lc + Vector2(7.5, -8.0).rotated(p.lan_ang * 0.5)]), Color(0.10, 0.08, 0.13))

	# ------------------------------------------------------------ head
	Gfx.capsule(ci, shoulder, shoulder + td * 9.0, 11.0, 10.0, Color(0.72, 0.66, 0.78))   # neck
	ci.draw_circle(head + rim_off, 16.8, RIM)
	ci.draw_circle(head, 15.5, COAT)
	ci.draw_circle(head + fwd * 4.5 + Vector2(0.0, 0.5), 10.6, Color(0.035, 0.025, 0.06))   # shadowed face
	ci.draw_arc(head, 15.2, ang - 2.2, ang + 0.4, 14, TRIM, 1.8, true)   # hood trim
	ci.draw_circle(head + fwd * 9.0 + Vector2(0.0, -1.0), 2.4, Color(0.96, 0.93, 1.0))   # one wide eye
	ci.draw_circle(head + fwd * 9.8 + Vector2(0.0, -1.0), 1.0, Color(0.03, 0.02, 0.06))

	# ------------------------------------------------------------ scarf
	var neck := shoulder + td * 5.0
	var sp := p.scarf
	for i in range(1, sp.size()):
		var wdt := lerpf(11.0, 3.5, float(i) / float(sp.size()))
		ci.draw_line(neck + sp[i - 1] + Vector2(0.0, 2.0), neck + sp[i] + Vector2(0.0, 2.0), SCARF.darkened(0.45), wdt, true)
	for i in range(1, sp.size()):
		var wdt2 := lerpf(10.0, 3.0, float(i) / float(sp.size()))
		ci.draw_line(neck + sp[i - 1], neck + sp[i], SCARF, wdt2, true)
	_dress_front(ci, dress, p, shoulder, head, td, fwd)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ------------------------------------------------------------------ DRESS / ACCESSORIES
## Cosmetics that hang BEHIND the body (drawn before the far limbs): cloth that follows the scarf chain.
static func _dress_back(ci: CanvasItem, id: StringName, p: PlayerCtl, shoulder: Vector2, td: Vector2) -> void:
	if id != &"shroud" and id != &"mantle":
		return
	var neck := shoulder + td * 5.0
	var sp := p.scarf
	var n := sp.size()
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in n:
		var k := float(i) / float(n - 1)
		var hw := lerpf(10.0, 22.0, k) if id == &"shroud" else lerpf(8.0, 13.0, k)
		top.append(neck + sp[i] + Vector2(0.0, 2.0 - hw * 0.30))
		bot.append(neck + sp[i] + Vector2(0.0, hw * (1.0 + 0.30 * sin(float(i) * 2.3 + TAU * p.stride))))
	for i in range(1, n):
		var k2 := float(i) / float(n - 1)
		var col := Color(0.30, 0.25, 0.43).lerp(Color(0.10, 0.08, 0.18), k2) if id == &"shroud" else Color(0.06, 0.05, 0.11)
		ci.draw_colored_polygon(PackedVector2Array([top[i - 1], top[i], bot[i], bot[i - 1]]), col)
		ci.draw_colored_polygon(PackedVector2Array([bot[i - 1], bot[i], bot[i] + Vector2(-3.0, 6.0 + 4.0 * sin(float(i) * 3.1))]), col)   # torn hem
	ci.draw_polyline(top, Color(TRIM.r, TRIM.g, TRIM.b, 0.55), 1.6, true)


## Cosmetics worn ON the head / shoulders (drawn after the scarf).
static func _dress_front(ci: CanvasItem, id: StringName, p: PlayerCtl, shoulder: Vector2, head: Vector2, td: Vector2, fwd: Vector2) -> void:
	match id:
		&"mantle":   # a fan of black feathers over the shoulder
			for k in 7:
				var r := -1.35 + float(k) * 0.16 + sin(TAU * p.stride + float(k) * 0.8) * 0.06
				var dir := (-fwd).rotated(r)
				var base := shoulder + td * 2.0 + dir * 3.0
				var ln := 23.0 - absf(float(k) - 3.0) * 1.8
				var side := Vector2(-dir.y, dir.x) * 4.5
				ci.draw_colored_polygon(PackedVector2Array([base + side, base + dir * ln, base - side]), Color(0.07, 0.06, 0.12))
				ci.draw_line(base + side, base + dir * ln, Color(0.55, 0.5, 0.9, 0.55), 1.2, true)
		&"antlers":   # pale bone antlers, near one bright, far one dim
			for s in 2:
				var near := s == 1
				var col := Color(0.93, 0.88, 0.76) if near else Color(0.62, 0.58, 0.52)
				var wd := 3.4 if near else 2.5
				var b := head + td * 12.0 + fwd * (-1.0 if near else -6.0)
				var p1 := b + td * 10.0 - fwd * 5.0
				var p2 := p1 + td * 9.0 + fwd * 4.0
				ci.draw_polyline(PackedVector2Array([b, p1, p2]), col, wd, true)
				ci.draw_line(p1, p1 + td * 3.0 - fwd * 10.0, col, wd * 0.8, true)
				ci.draw_line(p2, p2 + td * 7.0 + fwd * 5.0, col, wd * 0.8, true)
				ci.draw_line(p2, p2 + td * 5.0 - fwd * 4.0, col, wd * 0.7, true)
		&"mask":   # cracked bone plate over the face, the one wide eye still burning in the socket
			var c := head + fwd * 5.2 + Vector2(0.0, 1.0)
			var pts := PackedVector2Array()
			for i in 12:
				var a := TAU * float(i) / 12.0
				pts.append(c + fwd * cos(a) * 8.0 + td * sin(a) * 11.0)
			ci.draw_colored_polygon(pts, Color(0.92, 0.89, 0.80))
			ci.draw_circle(head + fwd * 9.0 + Vector2(0.0, -1.0), 3.4, Color(0.03, 0.02, 0.06))
			ci.draw_circle(head + fwd * 9.8 + Vector2(0.0, -1.0), 1.5, Color(0.92, 0.12, 0.2))
			ci.draw_line(c + td * 10.0 - fwd * 1.0, c + td * 2.0 + fwd * 2.5, Color(0.22, 0.16, 0.22), 1.2, true)
			for i in 3:
				var ty := c - td * (4.5 + float(i) * 2.4)
				ci.draw_line(ty + fwd * 1.0, ty + fwd * 6.0, Color(0.25, 0.2, 0.25), 1.1, true)
		&"veil":   # translucent crimson veil: over the face and streaming from the hood
			ci.draw_colored_polygon(PackedVector2Array([head + td * 9.0 + fwd * 2.0, head + td * 7.0 + fwd * 12.0, head - td * 8.0 + fwd * 10.0, head - td * 13.0 + fwd * 1.0]), Color(0.45, 0.02, 0.1, 0.40))
			var hp := p.hood
			for i in range(1, hp.size()):
				var a0 := head - fwd * 6.0 + hp[i - 1]
				var a1 := head - fwd * 6.0 + hp[i]
				var w1 := lerpf(13.0, 6.0, float(i - 1) / 3.0)
				var w2 := lerpf(13.0, 6.0, float(i) / 3.0)
				ci.draw_colored_polygon(PackedVector2Array([a0 + Vector2(0.0, -w1), a1 + Vector2(0.0, -w2), a1 + Vector2(0.0, w2 + 6.0), a0 + Vector2(0.0, w1 + 6.0)]), Color(0.55, 0.04, 0.14, 0.58))
				ci.draw_line(a1 + Vector2(0.0, w2 + 6.0), a1 + Vector2(-2.0, w2 + 15.0), Color(0.8, 0.1, 0.2, 0.5), 1.1, true)
		&"halo":   # a broken ring of pale gold floating above the hood
			var hc := head + td * 31.0 + Vector2(0.0, sin(TAU * p.stride * 2.0) * 1.2)
			var gold := Color(1.0, 0.82, 0.38)
			Gfx.glow(ci, hc, 34.0, Color(gold.r, gold.g, gold.b, 0.22))
			var ring := PackedVector2Array()
			for i in 15:
				var a2 := 0.5 + TAU * 0.86 * float(i) / 14.0
				ring.append(hc + fwd * cos(a2) * 14.0 + td * sin(a2) * 3.6)
			ci.draw_polyline(ring, Color(gold.r, gold.g, gold.b, 0.95), 2.6, true)
			ci.draw_polyline(ring, Color(1.0, 1.0, 1.0, 0.5), 1.0, true)
