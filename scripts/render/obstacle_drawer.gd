class_name ObstacleDrawer
extends RefCounted
## Obstacles are BIG, shaded and colour-coded so they read instantly even in near-darkness:
##   amber rim + up-chevron = JUMP     cyan rim + down-chevron = SLIDE     red rim + double-chevron = DASH
## World layer: volumetric bodies (gradient fills, bevels, cracks, ambient occlusion, cast shadows).
## Glow layer (above the darkness shader): action-coloured rim, ground decal and floating chevron.

const G := Cfg.GROUND_Y
const STONE_TOP := Color(0.34, 0.30, 0.44)
const STONE_BOT := Color(0.10, 0.08, 0.15)
const RIM_MOON := Color(0.75, 0.80, 1.0, 0.35)
const PIVOT_Y := -140.0


static func action_color(o: Obstacle) -> Color:
	match o.kind:
		Obstacle.Kind.HANGING, Obstacle.Kind.CROW:
			return Cfg.COL_SLIDE
		Obstacle.Kind.WALL:
			return Cfg.COL_DASH
	return Cfg.COL_JUMP


# ------------------------------------------------------------------ shapes
static func grave_poly(x: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := w * 0.5
	pts.append(Vector2(x - 8.0, G))
	pts.append(Vector2(x - 2.0, G - h * 0.5))
	for i in 11:
		var a := PI + PI * float(i) / 10.0
		pts.append(Vector2(x + r + cos(a) * r, G - h + r + sin(a) * r))
	pts.append(Vector2(x + w + 2.0, G - h * 0.5))
	pts.append(Vector2(x + w + 8.0, G))
	return pts


static func tusk_poly(x0: float, bw: float, h: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, G), Vector2(x0 + bw, G),
		Vector2(x0 + bw * 0.78 + lean * 0.4, G - h * 0.55),
		Vector2(x0 + bw * 0.5 + lean, G - h),
		Vector2(x0 + bw * 0.22 + lean * 0.3, G - h * 0.55),
	])


static func spikes_outline(x: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x, G)])
	var n := 5
	var sw := w / float(n)
	for i in n:
		pts.append(Vector2(x + (float(i) + 0.5) * sw, G - h))
		if i < n - 1:
			pts.append(Vector2(x + (float(i) + 1.0) * sw, G - h * 0.28))
	pts.append(Vector2(x + w, G))
	return pts


## Slab polygon relative to its pivot (for the swing).
static func hanging_local(w: float) -> PackedVector2Array:
	var b := Obstacle.HANG_BOTTOM - PIVOT_Y
	var tl := top_y() - PIVOT_Y
	var pts := PackedVector2Array([Vector2(-w * 0.5, tl), Vector2(w * 0.5, tl), Vector2(w * 0.5, b - 44.0)])
	var n := 6
	var sw := w / float(n)
	for i in n:
		pts.append(Vector2(w * 0.5 - (float(i) + 0.5) * sw, b))
		pts.append(Vector2(w * 0.5 - (float(i) + 1.0) * sw, b - 44.0))
	return pts


## Where tall structures must start so they always reach the top of the (possibly taller) screen.
static func top_y() -> float:
	return minf(-160.0, -Cfg.oy - 80.0)


static func _sway(o: Obstacle, t: float) -> float:
	return sin(t * 1.3 + o.seed_v) * 0.012


# ------------------------------------------------------------------ world layer
static func draw_shadow(ci: CanvasItem, o: Obstacle, sx: float, light_x: float) -> void:
	if o.kind == Obstacle.Kind.PIT or o.kind == Obstacle.Kind.CROW:
		return
	var mid := sx + o.w * 0.5
	var d := mid - light_x
	var dirn := 1.0 if d >= 0.0 else -1.0
	var k := clampf(300.0 / (absf(d) + 140.0), 0.3, 1.7)   # closer to the lantern = longer shadow
	var hh := o.h if (o.kind == Obstacle.Kind.GRAVE or o.kind == Obstacle.Kind.SPIKES) else 170.0
	var a := clampf(1.0 - absf(d) / 1100.0, 0.25, 1.0)
	Gfx.glow_ellipse(ci, Vector2(mid + dirn * hh * 0.42 * k, G + 7.0), o.w * 0.55 + hh * 0.55 * k, 12.0 + hh * 0.05, Color(0, 0, 0, 0.6 * a))
	Gfx.glow_ellipse(ci, Vector2(mid, G + 3.0), o.w * 0.75, 11.0, Color(0, 0, 0, 0.55))   # contact AO


static func draw_body(ci: CanvasItem, o: Obstacle, sx: float, t: float, dark: float) -> void:
	var col := action_color(o)
	var rim := Color(col.r, col.g, col.b, 0.85)
	match o.kind:
		Obstacle.Kind.GRAVE:
			_grave(ci, o, sx, rim, dark)
		Obstacle.Kind.SPIKES:
			_spikes(ci, o, sx, rim)
		Obstacle.Kind.HANGING:
			_hanging(ci, o, sx, t, rim)
		Obstacle.Kind.PIT:
			_pit(ci, o, sx, t)
		Obstacle.Kind.WALL:
			_wall(ci, o, sx, t)
		Obstacle.Kind.CROW:
			_crow(ci, o, sx, t)


static func _grave(ci: CanvasItem, o: Obstacle, sx: float, rim: Color, dark: float) -> void:
	var pts := grave_poly(sx, o.w, o.h)
	Gfx.vgrad(ci, pts, G - o.h, G, STONE_TOP, STONE_BOT)
	# chiselled inner panel (inset shadow + lit lower edge)
	var inner := grave_poly(sx + o.w * 0.17, o.w * 0.66, o.h * 0.62)
	Gfx.vgrad(ci, inner, G - o.h * 0.68, G - o.h * 0.05, Color(0.06, 0.05, 0.10, 0.65), Color(0.05, 0.04, 0.09, 0.15))
	var cx := sx + o.w * 0.5
	var ty := G - o.h + o.w * 0.5
	var dk := Color(0.04, 0.03, 0.08, 0.95)
	ci.draw_line(Vector2(cx, ty - 14.0), Vector2(cx, ty + 40.0), dk, 7.0)
	ci.draw_line(Vector2(cx - 18.0, ty + 2.0), Vector2(cx + 18.0, ty + 2.0), dk, 7.0)
	ci.draw_line(Vector2(cx + 2.0, ty - 12.0), Vector2(cx + 2.0, ty + 38.0), Color(0.75, 0.78, 1.0, 0.18), 2.0)   # chisel highlight
	ci.draw_polyline(PackedVector2Array([Vector2(sx + 16.0, G - 12.0), Vector2(sx + 30.0, G - o.h * 0.35), Vector2(sx + 22.0, G - o.h * 0.5), Vector2(sx + 34.0, G - o.h * 0.62)]), dk, 3.0, true)   # crack
	# moss + dead flowers at the foot
	Gfx.glow_ellipse(ci, Vector2(sx + 14.0, G - 6.0), 30.0, 10.0, Color(0.1, 0.25, 0.22, 0.55))
	Gfx.glow_ellipse(ci, Vector2(sx + o.w - 16.0, G - 8.0), 26.0, 9.0, Color(0.1, 0.22, 0.2, 0.5))
	# lit edge on the moon side + bevelled top
	ci.draw_polyline(PackedVector2Array([pts[pts.size() - 4], pts[pts.size() - 3], pts[pts.size() - 2], pts[pts.size() - 1]]), RIM_MOON, 3.0, true)
	var top_arc := PackedVector2Array()
	for i in range(2, 11):
		top_arc.append(pts[i] + Vector2(0.0, 5.0))
	ci.draw_polyline(top_arc, Color(0.8, 0.82, 1.0, 0.22), 2.5, true)
	ci.draw_polyline(Gfx.closed(pts), rim, 3.5, true)


static func _spikes(ci: CanvasItem, o: Obstacle, sx: float, rim: Color) -> void:
	# a ribcage mound with tusks, each tusk its own shaded polygon
	var n := 5
	var sw := o.w / float(n)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 6.0, G), Vector2(sx + 14.0, G - 22.0), Vector2(sx + o.w - 14.0, G - 22.0), Vector2(sx + o.w + 6.0, G)]), Color(0.13, 0.10, 0.17))
	for i in n:
		var fi := float(i)
		var hh := o.h * (1.0 if i % 2 == 0 else 0.72 + Gfx.hash1(o.seed_v + fi) * 0.12)
		var lean := (Gfx.hash1(o.seed_v + fi * 3.0) - 0.5) * 26.0
		var poly := tusk_poly(sx + fi * sw + 3.0, sw - 6.0, hh, lean)
		Gfx.vgrad(ci, poly, G - hh, G, Color(0.86, 0.80, 0.68), Color(0.26, 0.22, 0.26))
		ci.draw_line(poly[2], poly[3], Color(1.0, 0.98, 0.9, 0.35), 2.0)
		ci.draw_line(poly[1] + Vector2(-6.0, -6.0), poly[2] + Vector2(-4.0, 6.0), Color(0, 0, 0, 0.25), 2.0)
	ci.draw_polyline(spikes_outline(sx, o.w, o.h), rim, 3.0, true)


static func _hanging(ci: CanvasItem, o: Obstacle, sx: float, t: float, rim: Color) -> void:
	var pivot := Vector2(sx + o.w * 0.5, PIVOT_Y)
	ci.draw_set_transform(pivot, _sway(o, t), Vector2.ONE)
	var chain := Color(0.36, 0.33, 0.42)
	for cxx in [-o.w * 0.5 + 30.0, o.w * 0.5 - 30.0]:
		ci.draw_line(Vector2(cxx, top_y() - PIVOT_Y), Vector2(cxx, 300.0), Color(0.05, 0.04, 0.08), 9.0)
		ci.draw_dashed_line(Vector2(cxx, top_y() - PIVOT_Y), Vector2(cxx, 300.0), chain, 6.0, 12.0)
	var pts := hanging_local(o.w)
	var b := Obstacle.HANG_BOTTOM - PIVOT_Y
	Gfx.vgrad(ci, pts, b - 400.0, b, Color(0.22, 0.16, 0.14), Color(0.10, 0.07, 0.09))
	for k in 6:   # vertical planks
		var px := -o.w * 0.5 + float(k) * o.w / 6.0
		ci.draw_line(Vector2(px, top_y() - PIVOT_Y), Vector2(px, b - 44.0), Color(0, 0, 0, 0.35), 2.0)
	for by in [b - 120.0, b - 200.0]:   # iron bands with rivets
		ci.draw_rect(Rect2(-o.w * 0.5, by, o.w, 14.0), Color(0.16, 0.15, 0.2))
		ci.draw_line(Vector2(-o.w * 0.5, by + 1.0), Vector2(o.w * 0.5, by + 1.0), Color(0.6, 0.62, 0.8, 0.3), 1.5)
		for r in 6:
			ci.draw_circle(Vector2(-o.w * 0.5 + 16.0 + float(r) * (o.w - 32.0) / 5.0, by + 7.0), 2.4, Color(0.05, 0.05, 0.08))
	ci.draw_polyline(Gfx.closed(pts), rim, 3.5, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _pit(ci: CanvasItem, o: Obstacle, sx: float, t: float) -> void:
	Gfx.vquad(ci, sx, sx + o.w, G - 3.0, 900.0, Color(0, 0, 0), Color(0.22, 0.01, 0.04))
	for k in 5:   # fangs around the rim
		var fx := sx + 16.0 + float(k) * (o.w - 54.0) / 4.0
		var fh := 34.0 + Gfx.hash1(o.seed_v + float(k)) * 18.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(fx, G - 2.0), Vector2(fx + 24.0, G - 2.0), Vector2(fx + 12.0, G + fh)]), Color(0.66, 0.6, 0.52))
	for hnd in 3:   # grasping hands rising out of the dark
		var hx := sx + o.w * (0.25 + 0.25 * float(hnd))
		var rise := 40.0 + sin(t * 2.4 + float(hnd) * 2.0 + o.seed_v) * 18.0
		var base := Vector2(hx, 700.0)
		var tip := Vector2(hx + sin(t + float(hnd)) * 8.0, G + 110.0 - rise)
		ci.draw_line(base, tip, Color(0.02, 0.0, 0.03), 12.0, true)
		for f in 4:
			var fa := -PI * 0.5 + (float(f) - 1.5) * 0.45 + sin(t * 3.0 + float(f)) * 0.12
			ci.draw_line(tip, tip + Vector2(cos(fa), sin(fa)) * 22.0, Color(0.02, 0.0, 0.03), 4.0, true)
	ci.draw_line(Vector2(sx, G), Vector2(sx, G + 70.0), Color(0.75, 0.7, 0.85, 0.22), 2.0)   # lip highlight


static func _wall(ci: CanvasItem, o: Obstacle, sx: float, t: float) -> void:
	var mx := sx + o.w * 0.5
	var col := Color(0.20, 0.03, 0.07)
	var body := PackedVector2Array()
	var y0 := top_y()
	var nseg := int((G - y0) / 60.0) + 2
	for i in nseg:   # twisting bramble trunk
		var yy := y0 + float(i) * 60.0
		body.append(Vector2(mx - 15.0 + sin(yy * 0.03 + o.seed_v) * 5.0, yy))
	for i in range(nseg - 1, -1, -1):
		var yy := y0 + float(i) * 60.0
		body.append(Vector2(mx + 15.0 + sin(yy * 0.03 + o.seed_v + 1.0) * 5.0, yy))
	Gfx.vgrad(ci, body, G - 500.0, G, Color(0.26, 0.05, 0.09), Color(0.08, 0.01, 0.03))
	var y := y0 + 50.0
	var n := 0
	while y < G:   # thorns
		var l := 34.0 + Gfx.hash1(o.seed_v + float(n)) * 18.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(mx - 11.0, y), Vector2(mx - 12.0 - l, y + 18.0 + Gfx.hash1(float(n)) * 8.0), Vector2(mx - 10.0, y + 40.0)]), col)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(mx + 11.0, y + 26.0), Vector2(mx + 12.0 + l, y + 46.0), Vector2(mx + 10.0, y + 66.0)]), col)
		y += 66.0
		n += 1
	Gfx.glow_ellipse(ci, Vector2(mx, G + 2.0), 54.0, 10.0, Color(0, 0, 0, 0.6))   # base AO


static func _crow(ci: CanvasItem, o: Obstacle, sx: float, t: float) -> void:
	var c := Vector2(sx + o.w * 0.5, G - o.y_off)
	var col := Color(0.03, 0.02, 0.06)
	var flap := sin(t * 20.0 + o.seed_v)
	for wing in 2:   # far wing first
		var f := -flap * 0.6 if wing == 0 else flap
		var root := c + Vector2(-2.0 + float(wing) * 6.0, -8.0)
		var tip := root + Vector2(-34.0 + float(wing) * 10.0, -14.0 - 46.0 * f)
		ci.draw_colored_polygon(PackedVector2Array([root + Vector2(16.0, 2.0), tip, root + Vector2(-20.0, 4.0)]), col)
	var body := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		body.append(c + Vector2(cos(a) * 32.0, sin(a) * 15.0))
	ci.draw_colored_polygon(body, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(28.0, -4.0), c + Vector2(62.0, 6.0), c + Vector2(26.0, 8.0)]), col)   # tail
	ci.draw_circle(c + Vector2(-26.0, -5.0), 10.0, col)   # head
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-32.0, -6.0), c + Vector2(-54.0, 1.0), c + Vector2(-32.0, 2.0)]), Color(0.42, 0.32, 0.12))   # beak
	ci.draw_polyline(Gfx.closed(body), Color(Cfg.COL_SLIDE.r, Cfg.COL_SLIDE.g, Cfg.COL_SLIDE.b, 0.55), 2.5, true)


# ------------------------------------------------------------------ glow layer (additive)
static func _outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, a: float) -> void:
	var c := Gfx.closed(pts)
	ci.draw_polyline(c, Color(col.r, col.g, col.b, 0.25 * a), 12.0, true)
	ci.draw_polyline(c, Color(col.r, col.g, col.b, 0.9 * a), 3.0, true)


static func draw_glow(ci: CanvasItem, o: Obstacle, sx: float, t: float) -> void:
	var col := action_color(o)
	var pass_fade := clampf((sx + o.w - (Cfg.PLAYER_X - 60.0)) / 200.0, 0.0, 1.0)
	var a := pass_fade * (0.8 + 0.2 * sin(t * 6.0 + o.seed_v))
	var mid := sx + o.w * 0.5
	var ind_y := G - 200.0
	var dir := 0
	# coloured decal on the ground under every hazard: readable at a glance, even when the world is black
	if o.kind != Obstacle.Kind.CROW:
		Gfx.glow_ellipse(ci, Vector2(mid, G + 8.0), o.w * 0.75 + 30.0, 13.0, Color(col.r, col.g, col.b, 0.42 * a))
	match o.kind:
		Obstacle.Kind.GRAVE:
			_outline(ci, grave_poly(sx, o.w, o.h), col, a)
			ind_y = G - o.h - 50.0
			dir = 1
		Obstacle.Kind.SPIKES:
			_outline(ci, spikes_outline(sx, o.w, o.h), col, a)
			ind_y = G - o.h - 50.0
			dir = 1
		Obstacle.Kind.HANGING:
			var pivot := Vector2(mid, PIVOT_Y)
			ci.draw_set_transform(pivot, _sway(o, t), Vector2.ONE)
			_outline(ci, hanging_local(o.w), col, a)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			Gfx.glow_ellipse(ci, Vector2(mid, Obstacle.HANG_BOTTOM - 6.0), o.w * 0.6, 40.0, Color(col.r, col.g, col.b, 0.2 * a))
			ind_y = G - 42.0
			dir = 2
		Obstacle.Kind.PIT:
			Gfx.glow_ellipse(ci, Vector2(mid, G + 70.0), o.w * 0.7, 100.0, Color(1.0, 0.1, 0.12, 0.45 * a))
			ci.draw_line(Vector2(sx, G), Vector2(sx, G + 130.0), Color(col.r, col.g, col.b, 0.95 * a), 4.0)
			ci.draw_line(Vector2(sx + o.w, G), Vector2(sx + o.w, G + 130.0), Color(col.r, col.g, col.b, 0.95 * a), 4.0)
			var dx := sx
			while dx < sx + o.w:   # dashed hazard tape across the gap
				ci.draw_line(Vector2(dx, G - 2.0), Vector2(minf(dx + 22.0, sx + o.w), G - 2.0), Color(col.r, col.g, col.b, 0.9 * a), 5.0)
				dx += 40.0
			ind_y = G - 110.0
			dir = 1
		Obstacle.Kind.WALL:
			var p := 0.7 + 0.3 * sin(t * 9.0 + o.seed_v)
			Gfx.glow_ellipse(ci, Vector2(mid, G * 0.5), 140.0, G * 0.62, Color(1.0, 0.08, 0.15, 0.2 * p * pass_fade))
			ci.draw_line(Vector2(mid, top_y()), Vector2(mid, G), Color(1.0, 0.25, 0.3, 0.95 * a), 4.0)
			var y := top_y() + 50.0
			var n := 0
			while y < G:
				var l := 34.0 + Gfx.hash1(o.seed_v + float(n)) * 18.0
				ci.draw_polyline(PackedVector2Array([Vector2(mid - 11.0, y), Vector2(mid - 12.0 - l, y + 20.0), Vector2(mid - 10.0, y + 40.0)]), Color(1.0, 0.3, 0.35, 0.8 * a), 2.5, true)
				ci.draw_polyline(PackedVector2Array([Vector2(mid + 11.0, y + 26.0), Vector2(mid + 12.0 + l, y + 46.0), Vector2(mid + 10.0, y + 66.0)]), Color(1.0, 0.3, 0.35, 0.8 * a), 2.5, true)
				y += 66.0
				n += 1
			ind_y = G - 215.0
			dir = 3
		Obstacle.Kind.CROW:
			var c := Vector2(mid, G - o.y_off)
			Gfx.glow(ci, c + Vector2(-26.0, -5.0), 28.0, Color(1.0, 0.1, 0.15, 0.85 * pass_fade))
			ci.draw_rect(Rect2(c.x - 30.0, c.y - 8.0, 7.0, 4.0), Color(1.0, 0.55, 0.55, pass_fade))
			ci.draw_line(c + Vector2(64.0, 0.0), c + Vector2(190.0, 0.0), Color(col.r, col.g, col.b, 0.35 * pass_fade), 3.0)
			ind_y = G - 42.0
			dir = 2
	var ind_a := clampf((1450.0 - sx) / 250.0, 0.0, 1.0) * clampf((sx - (Cfg.PLAYER_X + 20.0)) / 120.0, 0.0, 1.0)
	if ind_a > 0.01 and dir > 0:
		_chevron(ci, Vector2(mid, ind_y + sin(t * 6.0 + o.seed_v) * 6.0), dir, col, ind_a * 0.9)


## dir: 1 = up (jump), 2 = down (slide), 3 = double right (dash)
static func _chevron(ci: CanvasItem, c: Vector2, dir: int, col: Color, a: float) -> void:
	Gfx.glow(ci, c, 44.0, Color(col.r, col.g, col.b, 0.35 * a))
	ci.draw_arc(c, 26.0, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.5 * a), 2.5, true)
	var line := Color(col.r, col.g, col.b, a)
	if dir == 3:
		for k in 2:
			var o := Vector2(float(k) * 14.0 - 7.0, 0.0)
			ci.draw_polyline(PackedVector2Array([c + o + Vector2(-7.0, -13.0), c + o + Vector2(7.0, 0.0), c + o + Vector2(-7.0, 13.0)]), line, 5.0, true)
		return
	var s := -1.0 if dir == 1 else 1.0
	ci.draw_polyline(PackedVector2Array([c + Vector2(-13.0, -s * 4.0), c + Vector2(0.0, s * 8.0), c + Vector2(13.0, -s * 4.0)]), line, 5.0, true)
