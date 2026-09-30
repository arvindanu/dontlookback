class_name CharacterDrawer
extends RefCounted
## Procedural runner. Every joint is blended between run / air / slide / dash poses and the
## legs & arms are solved with two-bone IK, so transitions are continuous (no sprite popping).
## Squash & stretch comes from PlayerCtl's spring; the whole body flips when looking back.

const BODY := Color(0.62, 0.57, 0.72)
const BACK := Color(0.36, 0.32, 0.44)
const COAT := Color(0.24, 0.2, 0.32)


static func draw(ci: CanvasItem, p: PlayerCtl, flip: float, skin: Color) -> void:
	# contact shadow shrinks as you leave the ground
	var lift := clampf((Cfg.GROUND_Y - p.y) / 300.0, 0.0, 1.0)
	Gfx.glow_ellipse(ci, Vector2(Cfg.PLAYER_X, Cfg.GROUND_Y + 3.0), 40.0 * (1.0 - lift * 0.5), 9.0, Color(0, 0, 0, 0.6 * (1.0 - lift * 0.6)))

	var sq := p.squash
	ci.draw_set_transform(Vector2(Cfg.PLAYER_X, p.y), 0.0, Vector2((1.0 + sq * 0.55) * flip, 1.0 - sq))

	var ph := p.stride
	var sa := p.slide_a
	var aa := p.air_a * (1.0 - sa)
	var da := p.dash_curve()
	var fall_w := clampf(p.vy / 1400.0 + 0.5, 0.0, 1.0)

	var bob := absf(sin(ph)) * 5.0 * (1.0 - aa) * (1.0 - sa)
	var hip := Vector2(lerpf(0.0, 6.0, sa), lerpf(-53.0 + bob, -26.0, sa) - 5.0 * aa)
	var ang := lerpf(lerpf(p.lean, lerpf(-0.06, 0.2, fall_w), aa), -1.15, sa)
	var td := Vector2(sin(ang), -cos(ang))
	var shoulder := hip + td * 38.0
	var head := shoulder + td * 25.0

	var feet: Array[Vector2] = []
	var knees: Array[Vector2] = []
	var hands: Array[Vector2] = []
	var elbows: Array[Vector2] = []
	for i in 2:
		var phi := ph + PI * float(i)
		var run_f := Vector2(sin(phi) * (30.0 + da * 16.0), -maxf(0.0, cos(phi)) * (22.0 + da * 12.0))
		var rise_f := Vector2(20.0, -32.0) if i == 0 else Vector2(-16.0, -14.0)
		var drop_f := Vector2(26.0, -8.0) if i == 0 else Vector2(-22.0, -18.0)
		var slide_f := Vector2(58.0, -8.0) if i == 0 else Vector2(44.0, -2.0)
		var f := run_f.lerp(rise_f.lerp(drop_f, fall_w), aa).lerp(slide_f, sa)
		f.y = minf(f.y, 0.0)
		feet.append(f)
		knees.append(Gfx.ik(hip, f, 28.0, 28.0, -1.0))

		var phh := phi + PI
		var run_h := shoulder + Vector2(sin(phh) * 28.0, 24.0 + cos(phh) * 10.0)
		var dash_h := shoulder + Vector2(-40.0, 8.0 + float(i) * 8.0)
		var rise_h := shoulder + (Vector2(24.0, -30.0) if i == 0 else Vector2(-16.0, -22.0))
		var drop_h := shoulder + (Vector2(30.0, -12.0) if i == 0 else Vector2(-26.0, -6.0))
		var slide_h := Vector2(-56.0, -3.0) if i == 0 else shoulder + Vector2(26.0, -4.0)
		var h := run_h.lerp(dash_h, da).lerp(rise_h.lerp(drop_h, fall_w), aa).lerp(slide_h, sa)
		var reach := (h - shoulder).limit_length(46.0)
		h = shoulder + reach
		hands.append(h)
		elbows.append(Gfx.ik(shoulder, h, 24.0, 24.0, 1.0))

	# back limbs (darker), coat, torso, front limbs, head, scarf
	_leg(ci, hip, knees[1], feet[1], BACK)
	_arm(ci, shoulder, elbows[1], hands[1], BACK)
	var coat := PackedVector2Array([
		shoulder + Vector2(-10.0, 2.0), shoulder + Vector2(10.0, 2.0),
		hip + Vector2(14.0 + da * 8.0, 6.0), hip + Vector2(-18.0 - speed_flow(p) - da * 22.0, 14.0 + sin(p.t * 12.0) * 3.0),
	])
	ci.draw_colored_polygon(coat, COAT)
	ci.draw_line(hip, shoulder + td * 3.0, BODY, 22.0, true)
	_leg(ci, hip, knees[0], feet[0], BODY)
	_arm(ci, shoulder, elbows[0], hands[0], BODY)

	ci.draw_circle(head + Vector2(-3.0, -1.0), 15.5, COAT)          # hood
	ci.draw_circle(head + Vector2(3.0, 0.0), 10.5, Color(0.8, 0.74, 0.82))   # face
	ci.draw_circle(head + Vector2(7.5, -1.5), 2.6, Color(0.05, 0.03, 0.08))  # eye
	ci.draw_circle(head + Vector2(8.3, -2.2), 1.0, Color.WHITE)

	var neck := shoulder + td * 6.0
	var n := p.scarf.size()
	for i in range(1, n):
		ci.draw_line(neck + p.scarf[i - 1], neck + p.scarf[i], skin, lerpf(10.0, 3.5, float(i) / float(n)), true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func speed_flow(p: PlayerCtl) -> float:
	return clampf(p.speed / 1100.0, 0.0, 1.0) * 14.0


static func _leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([hip, knee, foot]), col, 10.0, true)
	ci.draw_circle(knee, 5.0, col)
	ci.draw_line(foot + Vector2(-3.0, 0.0), foot + Vector2(12.0, 0.0), col, 9.0, true)   # boot


static func _arm(ci: CanvasItem, sh: Vector2, elbow: Vector2, hand: Vector2, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([sh, elbow, hand]), col, 8.0, true)
	ci.draw_circle(hand, 5.0, col)
