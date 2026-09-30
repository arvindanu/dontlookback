class_name CreatureDrawer
extends RefCounted
## The follower. Body is a near-black silhouette (world layer); eyes and teeth are additive
## (glow layer) so they burn through the darkness. It grows with distance run, and reaches
## further and opens its mouth the longer you stare at it.

const G := Cfg.GROUND_Y


static func scale_for(cr: Creature, dark: float, extra: float) -> float:
	return 1.0 + dark * 0.45 + cr.aggression * 0.18 + extra


static func draw_body(ci: CanvasItem, x: float, cr: Creature, dark: float, look_a: float, t: float, extra: float) -> void:
	var s := scale_for(cr, dark, extra)
	var vis := clampf(1.25 - cr.gap / 520.0 + look_a * 0.5, 0.35, 1.0)
	ci.draw_set_transform(Vector2(x, G), 0.0, Vector2(s, s))
	var body := Color(0.008, 0.0, 0.016, vis)
	var rim := Color(0.8, 0.06, 0.14, (0.25 + look_a * 0.5 + cr.aggression * 0.4) * vis)
	Gfx.glow(ci, Vector2(0.0, -130.0), 260.0, Color(0.5, 0.0, 0.1, (0.18 + look_a * 0.25 + cr.aggression * 0.2) * vis))

	# tattered cloak streaming behind it
	var cloak := PackedVector2Array()
	for i in 10:
		var u := float(i) / 9.0
		cloak.append(Vector2(-60.0 - u * 190.0, -(200.0 - u * 170.0) + sin(t * 3.0 + u * 5.0) * 16.0 * u))
	cloak.append(Vector2(-250.0, 0.0))
	cloak.append(Vector2(-60.0, 0.0))
	ci.draw_colored_polygon(cloak, Color(0.008, 0.0, 0.016, vis * 0.85))

	# hunched torso + elongated skull
	var torso := PackedVector2Array([
		Vector2(-64.0, 0.0), Vector2(-58.0, -90.0), Vector2(-40.0, -170.0), Vector2(-14.0, -224.0),
		Vector2(20.0, -228.0), Vector2(34.0, -190.0), Vector2(44.0, -120.0), Vector2(58.0, -50.0), Vector2(66.0, 0.0),
	])
	ci.draw_colored_polygon(torso, body)
	var skull := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		skull.append(Vector2(cos(a) * 24.0, sin(a) * 42.0).rotated(0.3) + Vector2(12.0, -262.0))
	ci.draw_colored_polygon(skull, body)
	ci.draw_polyline(Gfx.closed(torso), rim, 3.0, true)
	ci.draw_polyline(Gfx.closed(skull), rim, 3.0, true)

	# long arms that reach further the more you look
	for i in 2:
		var sh := Vector2(18.0 - float(i) * 24.0, -196.0 - float(i) * 10.0)
		var reach := 150.0 + cr.aggression * 90.0 + sin(t * 4.0 + float(i) * 2.1) * 16.0
		var target := Vector2(reach, -70.0 + float(i) * 34.0 + sin(t * 5.0 + float(i) * 1.7) * 20.0)
		var hand := sh + (target - sh).limit_length(219.0)
		var el := Gfx.ik(sh, hand, 110.0, 110.0, -1.0)
		ci.draw_polyline(PackedVector2Array([sh, el, hand]), body, 14.0, true)
		for f in 4:
			var fa := 0.3 + float(f) * 0.35 + sin(t * 6.0 + float(f)) * 0.15
			ci.draw_line(hand, hand + Vector2(cos(fa), sin(fa)) * (30.0 + cr.aggression * 12.0), body, 4.0, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func draw_glow(ci: CanvasItem, x: float, cr: Creature, look_a: float, t: float, extra: float, dark: float) -> void:
	var s := scale_for(cr, dark, extra)
	var vis := clampf(1.5 - cr.gap / 420.0 + look_a * 0.6, 0.3, 1.0)
	var k := clampf(look_a + cr.aggression * 0.6 + extra, 0.0, 1.0)
	ci.draw_set_transform(Vector2(x, G), 0.0, Vector2(s, s))
	var eye := Color(1.0, 0.85 - 0.75 * k, 0.75 - 0.7 * k, vis)
	var blink := 0.15 if fmod(t * 0.7 + 0.3, 3.2) < 0.12 else 1.0
	for i in 2:
		var e := Vector2(2.0 + float(i) * 24.0, -268.0 + float(i) * -2.0)
		Gfx.glow(ci, e, 50.0, Color(1.0, 0.1, 0.15, 0.55 * vis))
		var hw := (9.0 + k * 3.0)
		ci.draw_polyline(PackedVector2Array([e + Vector2(-hw, -3.0 * blink), e + Vector2(hw, 3.0 * blink)]), eye, (5.0 + k * 3.0) * blink, true)
	if k > 0.25:   # the mouth opens
		var open := 6.0 + k * 12.0
		var pts := PackedVector2Array()
		for i in 9:
			pts.append(Vector2(2.0 + float(i) * 3.6, -240.0 + (open if i % 2 == 1 else -2.0)))
		ci.draw_polyline(pts, Color(0.95, 0.92, 0.85, k * vis), 2.5, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
