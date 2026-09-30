class_name ObstacleDrawer
extends RefCounted
## Obstacles are BIG and colour-coded so they read instantly in the dark:
##   amber rim + up-chevron = JUMP    cyan rim + down-chevron = SLIDE    red rim + double-chevron = DASH
## The body is drawn in the world layer; the additive rim/warning is drawn in the glow layer
## (above the darkness shader) so it stays visible no matter how black the world gets.

const G := Cfg.GROUND_Y
const BODY := Color(0.17, 0.135, 0.235)
const BODY_DARK := Color(0.09, 0.07, 0.13)


static func action_color(o: Obstacle) -> Color:
	match o.kind:
		Obstacle.Kind.HANGING, Obstacle.Kind.CROW:
			return Cfg.COL_SLIDE
		Obstacle.Kind.WALL:
			return Cfg.COL_DASH
	return Cfg.COL_JUMP


static func grave_poly(x: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := w * 0.5
	pts.append(Vector2(x - 6.0, G))
	pts.append(Vector2(x, G - h + r))
	for i in 9:
		var a := PI + PI * float(i) / 8.0
		pts.append(Vector2(x + r + cos(a) * r, G - h + r + sin(a) * r))
	pts.append(Vector2(x + w, G))
	pts.append(Vector2(x + w + 6.0, G))
	return pts


static func spikes_poly(x: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 5
	var sw := w / float(n)
	pts.append(Vector2(x, G))
	for i in n:
		pts.append(Vector2(x + (float(i) + 0.5) * sw, G - h))
		if i < n - 1:
			pts.append(Vector2(x + (float(i) + 1.0) * sw, G - h * 0.28))
	pts.append(Vector2(x + w, G))
	return pts


static func hanging_poly(x: float, w: float) -> PackedVector2Array:
	var b := Obstacle.HANG_BOTTOM
	var pts := PackedVector2Array([Vector2(x, -140.0), Vector2(x + w, -140.0), Vector2(x + w, b - 42.0)])
	var n := 6
	var sw := w / float(n)
	for i in n:
		pts.append(Vector2(x + w - (float(i) + 0.5) * sw, b))
		pts.append(Vector2(x + w - (float(i) + 1.0) * sw, b - 42.0))
	return pts


# ------------------------------------------------------------------ world layer
static func draw_body(ci: CanvasItem, o: Obstacle, sx: float, t: float) -> void:
	var col := action_color(o)
	var rim := Color(col.r, col.g, col.b, 0.75)
	match o.kind:
		Obstacle.Kind.GRAVE:
			Gfx.glow_ellipse(ci, Vector2(sx + o.w * 0.5, G + 4.0), o.w * 0.85, 15.0, Color(0, 0, 0, 0.55))
			var pts := grave_poly(sx, o.w, o.h)
			ci.draw_colored_polygon(pts, BODY)
			ci.draw_colored_polygon(grave_poly(sx + o.w * 0.25, o.w * 0.5, o.h * 0.55), BODY_DARK)
			var cx := sx + o.w * 0.5
			var ty := G - o.h + o.w * 0.5
			ci.draw_line(Vector2(cx, ty - 16.0), Vector2(cx, ty + 38.0), BODY_DARK, 6.0)
			ci.draw_line(Vector2(cx - 17.0, ty), Vector2(cx + 17.0, ty), BODY_DARK, 6.0)
			ci.draw_polyline(PackedVector2Array([Vector2(sx + 14.0, G - 20.0), Vector2(sx + 30.0, G - 62.0), Vector2(sx + 22.0, G - 90.0)]), BODY_DARK, 3.0)
			ci.draw_polyline(Gfx.closed(pts), rim, 4.0, true)
		Obstacle.Kind.SPIKES:
			Gfx.glow_ellipse(ci, Vector2(sx + o.w * 0.5, G + 4.0), o.w * 0.6, 14.0, Color(0, 0, 0, 0.55))
			var pts := spikes_poly(sx, o.w, o.h)
			ci.draw_colored_polygon(pts, Color(0.62, 0.58, 0.52))
			ci.draw_polyline(Gfx.closed(pts), rim, 4.0, true)
		Obstacle.Kind.HANGING:
			var pts := hanging_poly(sx, o.w)
			for cxx in [sx + 34.0, sx + o.w - 34.0]:   # chains up into the dark
				ci.draw_line(Vector2(cxx, -140.0), Vector2(cxx, 200.0), Color(0.3, 0.27, 0.36), 5.0)
			ci.draw_colored_polygon(pts, BODY)
			ci.draw_rect(Rect2(sx + 14.0, Obstacle.HANG_BOTTOM - 150.0, o.w - 28.0, 12.0), BODY_DARK)
			ci.draw_polyline(Gfx.closed(pts), rim, 4.0, true)
		Obstacle.Kind.PIT:
			ci.draw_rect(Rect2(sx, G - 3.0, o.w, 203.0), Color(0.0, 0.0, 0.0))
			for k in 4:   # fangs on the rim
				var fx := sx + 18.0 + float(k) * (o.w - 60.0) / 3.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(fx, G), Vector2(fx + 26.0, G), Vector2(fx + 13.0, G + 42.0)]), Color(0.6, 0.56, 0.5))
		Obstacle.Kind.WALL:
			var mx := sx + o.w * 0.5
			ci.draw_rect(Rect2(mx - 13.0, -140.0, 26.0, G + 140.0), Color(0.16, 0.03, 0.06))
			var y := -100.0
			while y < G:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(mx - 13.0, y), Vector2(sx, y + 22.0), Vector2(mx - 13.0, y + 44.0)]), Color(0.22, 0.04, 0.08))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(mx + 13.0, y + 22.0), Vector2(sx + o.w, y + 44.0), Vector2(mx + 13.0, y + 66.0)]), Color(0.22, 0.04, 0.08))
				y += 66.0
		Obstacle.Kind.CROW:
			_crow(ci, o, sx, t)


static func _crow(ci: CanvasItem, o: Obstacle, sx: float, t: float) -> void:
	var c := Vector2(sx + o.w * 0.5, G - o.y_off)
	var col := Color(0.03, 0.02, 0.06)
	var flap := sin(t * 20.0 + o.seed_v)
	var body := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		body.append(c + Vector2(cos(a) * 32.0, sin(a) * 16.0))
	for wing in 2:
		var f := flap if wing == 0 else -flap * 0.6
		var tip := c + Vector2(-30.0 + float(wing) * 14.0, -8.0 - 42.0 * f - 10.0)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14.0, -6.0), c + Vector2(20.0, -6.0), tip]), col)
	ci.draw_colored_polygon(body, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-28.0, -3.0), c + Vector2(-52.0, 3.0), c + Vector2(-28.0, 8.0)]), Color(0.3, 0.24, 0.1))
	ci.draw_polyline(Gfx.closed(body), Color(Cfg.COL_SLIDE.r, Cfg.COL_SLIDE.g, Cfg.COL_SLIDE.b, 0.6), 3.0, true)


# ------------------------------------------------------------------ glow layer (additive)
static func _outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, a: float) -> void:
	var c := Gfx.closed(pts)
	ci.draw_polyline(c, Color(col.r, col.g, col.b, 0.28 * a), 13.0, true)
	ci.draw_polyline(c, Color(col.r, col.g, col.b, 0.95 * a), 3.5, true)


static func draw_glow(ci: CanvasItem, o: Obstacle, sx: float, t: float) -> void:
	var col := action_color(o)
	var pass_fade := clampf((sx + o.w - (Cfg.PLAYER_X - 60.0)) / 200.0, 0.0, 1.0)
	var a := pass_fade * (0.78 + 0.22 * sin(t * 6.0 + o.seed_v))
	var mid := sx + o.w * 0.5
	var ind_y := G - 200.0
	var dir := 0
	match o.kind:
		Obstacle.Kind.GRAVE:
			_outline(ci, grave_poly(sx, o.w, o.h), col, a)
			ind_y = G - o.h - 46.0
			dir = 1
		Obstacle.Kind.SPIKES:
			_outline(ci, spikes_poly(sx, o.w, o.h), col, a)
			ind_y = G - o.h - 46.0
			dir = 1
		Obstacle.Kind.HANGING:
			_outline(ci, hanging_poly(sx, o.w), col, a)
			Gfx.glow_ellipse(ci, Vector2(mid, Obstacle.HANG_BOTTOM - 10.0), o.w * 0.6, 40.0, Color(col.r, col.g, col.b, 0.22 * a))
			ind_y = G - 42.0
			dir = 2
		Obstacle.Kind.PIT:
			Gfx.glow_ellipse(ci, Vector2(mid, G + 60.0), o.w * 0.7, 90.0, Color(1.0, 0.1, 0.12, 0.5 * a))
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
			Gfx.glow_ellipse(ci, Vector2(mid, G * 0.5), 130.0, G * 0.62, Color(1.0, 0.08, 0.15, 0.2 * p * pass_fade))
			ci.draw_line(Vector2(mid, -100.0), Vector2(mid, G), Color(1.0, 0.25, 0.3, 0.95 * a), 5.0)
			var y := -100.0
			while y < G:
				ci.draw_polyline(PackedVector2Array([Vector2(mid - 13.0, y), Vector2(sx, y + 22.0), Vector2(mid - 13.0, y + 44.0)]), Color(1.0, 0.3, 0.35, 0.8 * a), 2.5, true)
				ci.draw_polyline(PackedVector2Array([Vector2(mid + 13.0, y + 22.0), Vector2(sx + o.w, y + 44.0), Vector2(mid + 13.0, y + 66.0)]), Color(1.0, 0.3, 0.35, 0.8 * a), 2.5, true)
				y += 66.0
			ind_y = G - 210.0
			dir = 3
		Obstacle.Kind.CROW:
			var c := Vector2(mid, G - o.y_off)
			Gfx.glow(ci, c + Vector2(-22.0, -4.0), 26.0, Color(1.0, 0.1, 0.15, 0.8 * pass_fade))
			ci.draw_rect(Rect2(c.x - 26.0, c.y - 6.0, 6.0, 4.0), Color(1.0, 0.5, 0.5, pass_fade))
			ci.draw_line(c + Vector2(30.0, 0.0), c + Vector2(150.0, 0.0), Color(col.r, col.g, col.b, 0.35 * pass_fade), 3.0)
			ind_y = G - 42.0
			dir = 2
	# action chevron: fades in as the hazard nears, out once it is on top of you
	var ind_a := clampf((1450.0 - sx) / 250.0, 0.0, 1.0) * clampf((sx - (Cfg.PLAYER_X + 20.0)) / 120.0, 0.0, 1.0)
	if ind_a > 0.01 and dir > 0:
		_chevron(ci, Vector2(mid, ind_y + sin(t * 6.0 + o.seed_v) * 6.0), dir, col, ind_a * 0.85)


## dir: 1 = up (jump), 2 = down (slide), 3 = double right (dash)
static func _chevron(ci: CanvasItem, c: Vector2, dir: int, col: Color, a: float) -> void:
	Gfx.glow(ci, c, 40.0, Color(col.r, col.g, col.b, 0.35 * a))
	var line := Color(col.r, col.g, col.b, a)
	if dir == 3:
		for k in 2:
			var o := Vector2(float(k) * 18.0 - 9.0, 0.0)
			ci.draw_polyline(PackedVector2Array([c + o + Vector2(-8.0, -18.0), c + o + Vector2(8.0, 0.0), c + o + Vector2(-8.0, 18.0)]), line, 6.0, true)
		return
	var s := -1.0 if dir == 1 else 1.0
	ci.draw_polyline(PackedVector2Array([c + Vector2(-18.0, -s * 8.0 + 4.0 * s), c + Vector2(0.0, s * 10.0 - 4.0 * s), c + Vector2(18.0, -s * 8.0 + 4.0 * s)]), line, 6.0, true)
