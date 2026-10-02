class_name CreatureDrawer
extends RefCounted
## The follower. A near-black silhouette (world layer) whose eyes, mouth and core burn through
## the darkness on the additive layer. It grows with distance run; the longer you look at it the
## wider its jaw opens, the further its arms reach, and shadow tendrils crawl toward your feet.

const G := Cfg.GROUND_Y
const HINGE := Vector2(12.0, -246.0)


static func scale_for(cr: Creature, dark: float, extra: float) -> float:
	return 1.0 + dark * 0.45 + cr.aggression * 0.18 + extra


static func _jaw(k: float) -> PackedVector2Array:
	var open := 0.12 + k * 0.55
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(32, -2), Vector2(38, 12), Vector2(20, 30), Vector2(-4, 16)])
	for i in pts.size():
		pts[i] = HINGE + pts[i].rotated(open)
	return pts


static func draw_body(ci: CanvasItem, x: float, cr: Creature, dark: float, look_a: float, t: float, extra: float) -> void:
	var s := scale_for(cr, dark, extra)
	var k := clampf(look_a + cr.aggression * 0.6 + extra, 0.0, 1.0)
	var vis := clampf(1.25 - cr.gap / 520.0 + look_a * 0.5, 0.4, 1.0)
	ci.draw_set_transform(Vector2(x, G), 0.0, Vector2(s, s))
	var body := Color(0.008, 0.0, 0.016, vis)
	var rim := Color(0.85, 0.07, 0.15, (0.25 + look_a * 0.5 + cr.aggression * 0.4) * vis)
	Gfx.glow(ci, Vector2(0.0, -140.0), 290.0, Color(0.5, 0.0, 0.1, (0.2 + look_a * 0.25 + cr.aggression * 0.22) * vis))
	var thr := cr.threat()

	# shadow tendrils crawling along the ground toward the runner
	if thr > 0.15:
		var reach := minf((cr.gap - 60.0) / s, 60.0 + thr * 330.0)
		for i in 4:
			var pts := PackedVector2Array()
			for j in 10:
				var u := float(j) / 9.0
				pts.append(Vector2(lerpf(30.0, 30.0 + reach, u), -6.0 - float(i) * 9.0 + sin(t * 4.0 + float(j) * 0.9 + float(i)) * 7.0 * u))
			ci.draw_polyline(pts, Color(0.01, 0.0, 0.02, vis * 0.9), 6.0 - float(i), true)

	# tattered cloak, two ragged layers
	for layer in 2:
		var cloak := PackedVector2Array()
		var spread := 190.0 + float(layer) * 70.0
		for i in 12:
			var u := float(i) / 11.0
			cloak.append(Vector2(-58.0 - u * spread, -(210.0 - u * 150.0) + sin(t * 3.0 + u * 5.0 + float(layer)) * 16.0 * u))
		for i in range(11, -1, -1):
			var u2 := float(i) / 11.0
			var rag := 0.0 if i % 2 == 0 else 26.0
			cloak.append(Vector2(-58.0 - u2 * spread * 0.92, -rag - 4.0 + sin(t * 2.4 + u2 * 6.0) * 8.0))
		ci.draw_colored_polygon(cloak, Color(0.008, 0.0, 0.016, vis * (0.75 if layer == 0 else 0.55)))

	# running legs
	var ph := t * (5.0 + cr.aggression * 3.0)
	var hip := Vector2(-6.0, -112.0)
	for i in 2:
		var pp := ph + PI * float(i)
		var foot := Vector2(sin(pp) * 52.0 + 10.0, -maxf(0.0, cos(pp)) * 36.0)
		var knee := Gfx.ik(hip, foot, 62.0, 62.0, -1.0)
		ci.draw_polyline(PackedVector2Array([hip, knee, foot]), body, 13.0, true)
		ci.draw_line(foot, foot + Vector2(22.0, 2.0), body, 7.0, true)

	# hunched torso, spine spikes, skull, jaw
	var torso := PackedVector2Array([Vector2(-58, -96), Vector2(-60, -150), Vector2(-46, -200), Vector2(-20, -236), Vector2(16, -238), Vector2(34, -210), Vector2(42, -160), Vector2(36, -110), Vector2(20, -92)])
	ci.draw_colored_polygon(torso, body)
	for i in 3:
		var a := torso[i + 1]
		var b := torso[i + 2]
		var d := (b - a).normalized()
		var n := Vector2(d.y, -d.x)
		ci.draw_colored_polygon(PackedVector2Array([a.lerp(b, 0.25), a.lerp(b, 0.75), a.lerp(b, 0.5) + n * (18.0 + float(i) * 2.0)]), body)
	var skull := PackedVector2Array()
	for i in 18:
		var ang := TAU * float(i) / 18.0
		skull.append(Vector2(cos(ang) * 22.0, sin(ang) * 40.0).rotated(0.35) + Vector2(18.0, -264.0))
	ci.draw_colored_polygon(skull, body)
	ci.draw_colored_polygon(_jaw(k), body)
	ci.draw_polyline(Gfx.closed(torso), rim, 3.0, true)
	ci.draw_polyline(Gfx.closed(skull), rim, 3.0, true)

	# long arms with hooked claws
	for i in 2:
		var sh := Vector2(18.0 - float(i) * 26.0, -196.0 - float(i) * 10.0)
		var reach2 := 150.0 + cr.aggression * 90.0 + sin(t * 4.0 + float(i) * 2.1) * 16.0
		var target := Vector2(reach2, -70.0 + float(i) * 34.0 + sin(t * 5.0 + float(i) * 1.7) * 20.0)
		var hand := sh + (target - sh).limit_length(219.0)
		var el := Gfx.ik(sh, hand, 110.0, 110.0, -1.0)
		ci.draw_polyline(PackedVector2Array([sh, el, hand]), body, 14.0, true)
		for f in 4:
			var fa := 0.25 + float(f) * 0.33 + sin(t * 6.0 + float(f)) * 0.14
			var m1 := hand + Vector2(cos(fa), sin(fa)) * (20.0 + cr.aggression * 8.0)
			var m2 := m1 + Vector2(cos(fa + 0.9), sin(fa + 0.9)) * 16.0
			ci.draw_polyline(PackedVector2Array([hand, m1, m2]), body, 4.0, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func draw_glow(ci: CanvasItem, x: float, cr: Creature, look_a: float, t: float, extra: float, dark: float) -> void:
	var s := scale_for(cr, dark, extra)
	var vis := clampf(1.5 - cr.gap / 420.0 + look_a * 0.6, 0.35, 1.0)
	var k := clampf(look_a + cr.aggression * 0.6 + extra, 0.0, 1.0)
	ci.draw_set_transform(Vector2(x, G), 0.0, Vector2(s, s))
	# chest core: a furnace behind the ribs, brighter the angrier it is
	var beat := 0.75 + 0.25 * sin(t * (4.0 + cr.aggression * 6.0))
	Gfx.glow(ci, Vector2(-10.0, -160.0), 70.0, Color(1.0, 0.1, 0.12, (0.12 + k * 0.3) * vis * beat))
	for c in 3:
		var cy := -190.0 + float(c) * 28.0
		ci.draw_polyline(PackedVector2Array([Vector2(-30.0, cy), Vector2(-14.0, cy + 8.0), Vector2(-2.0, cy - 2.0), Vector2(14.0, cy + 6.0)]), Color(1.0, 0.18, 0.2, (0.25 + k * 0.5) * vis * beat), 2.0, true)
	# eyes
	var eye := Color(1.0, 0.85 - 0.75 * k, 0.75 - 0.7 * k, vis)
	var blink := 0.15 if fmod(t * 0.7 + 0.3, 3.2) < 0.12 else 1.0
	for i in 2:
		var e := Vector2(14.0 + float(i) * 20.0, -270.0 + float(i) * 3.0)
		Gfx.glow(ci, e, 54.0, Color(1.0, 0.1, 0.15, 0.55 * vis))
		var hw := 9.0 + k * 3.0
		ci.draw_polyline(PackedVector2Array([e + Vector2(-hw, -3.5 * blink), e + Vector2(hw, 4.0 * blink)]), eye, (5.5 + k * 3.0) * blink, true)
	# open mouth: red throat + teeth on both jaws
	if k > 0.2:
		var jaw := _jaw(k)
		var throat := PackedVector2Array([HINGE + Vector2(2.0, 1.0), HINGE + Vector2(34.0, -2.0), jaw[1] + Vector2(2.0, 2.0), jaw[0] + Vector2(2.0, 2.0)])
		ci.draw_colored_polygon(throat, Color(0.9, 0.06, 0.1, 0.55 * k * vis))
		var tooth := Color(0.96, 0.93, 0.86, k * vis)
		for i in 6:
			var u := 0.1 + float(i) / 6.0 * 0.85
			var top_p := HINGE + Vector2(2.0 + u * 34.0, -2.0 + u * 0.0)
			var bot_p := jaw[0].lerp(jaw[1], u)
			ci.draw_line(top_p, top_p + Vector2(0.0, 6.0 + k * 6.0), tooth, 2.2, true)
			ci.draw_line(bot_p, bot_p + Vector2(0.0, -(5.0 + k * 6.0)), tooth, 2.2, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
