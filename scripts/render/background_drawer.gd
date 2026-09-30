class_name BackgroundDrawer
extends RefCounted
## Parallax world: sky, moon, hills, ruins, dead trees, gravestones, ground, fog, and a
## fast foreground grass layer. Colours drift from dusk-violet to blood-black with `dark`.

const G := Cfg.GROUND_Y
const X0 := -760.0
const X1 := Cfg.VIEW_W + 760.0
const TREE_STEP := 230.0


static func draw(ci: CanvasItem, dist: float, t: float, dark: float, fog: float) -> void:
	var top := Color(0.09, 0.08, 0.20).lerp(Color(0.05, 0.0, 0.02), dark)
	var bot := Color(0.34, 0.25, 0.40).lerp(Color(0.27, 0.02, 0.06), dark)
	ci.draw_polygon(PackedVector2Array([Vector2(X0, -200), Vector2(X1, -200), Vector2(X1, G), Vector2(X0, G)]), PackedColorArray([top, top, bot, bot]))
	# moon (swells and reddens)
	var mc := Color(0.92, 0.9, 0.84).lerp(Color(0.85, 0.12, 0.16), dark)
	var mp := Vector2(1010.0, 140.0)
	Gfx.glow(ci, mp, 190.0 + dark * 90.0, Color(mc.r, mc.g, mc.b, 0.28))
	ci.draw_circle(mp, 44.0 + dark * 28.0, mc)
	# far hills
	var hill := Color(0.12, 0.09, 0.20).lerp(Color(0.08, 0.01, 0.04), dark)
	var pts := PackedVector2Array()
	var off := dist * 0.05
	var x := X0
	while x <= X1:
		var wx := x + off
		pts.append(Vector2(x, G - 170.0 - sin(wx * 0.0055) * 60.0 - sin(wx * 0.016) * 26.0))
		x += 40.0
	pts.append(Vector2(X1, G))
	pts.append(Vector2(X0, G))
	ci.draw_colored_polygon(pts, hill)
	# ruined chapels (parallax 0.14)
	var rc := Color(0.09, 0.06, 0.15).lerp(Color(0.05, 0.0, 0.03), dark)
	var o14 := dist * 0.14
	for i in range(int(floorf((o14 + X0) / 1100.0)) - 1, int(ceilf((o14 + X1) / 1100.0)) + 1):
		var fi := float(i)
		if Gfx.hash1(fi + 40.0) < 0.35:
			continue
		var rx := fi * 1100.0 - o14 + Gfx.hash1(fi) * 300.0
		var rh := 150.0 + Gfx.hash1(fi + 2.0) * 90.0
		ci.draw_rect(Rect2(rx, G - rh, 90.0, rh), rc)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(rx - 8.0, G - rh), Vector2(rx + 45.0, G - rh - 80.0), Vector2(rx + 98.0, G - rh)]), rc)
		ci.draw_rect(Rect2(rx + 90.0, G - rh * 0.55, 70.0, rh * 0.55), rc)
	# dead trees (parallax 0.3)
	var tc := Color(0.07, 0.05, 0.13).lerp(Color(0.03, 0.0, 0.02), dark)
	var o3 := dist * 0.3
	for i in range(int(floorf((o3 + X0) / TREE_STEP)) - 1, int(ceilf((o3 + X1) / TREE_STEP)) + 1):
		var fi := float(i)
		_tree(ci, fi * TREE_STEP - o3 + Gfx.hash1(fi) * 110.0, 190.0 + Gfx.hash1(fi + 7.0) * 190.0, fi, tc)
	# fog bands
	var fa := 0.07 + fog * 0.14
	for i in 4:
		var fx := fposmod(float(i) * 830.0 - dist * 0.2 + t * 18.0, X1 - X0) + X0
		Gfx.glow_ellipse(ci, Vector2(fx, G - 30.0 - float(i) * 26.0), 420.0, 62.0, Color(0.55, 0.48, 0.66, fa))
	# gravestones + fence posts (parallax 0.7)
	var nc := Color(0.06, 0.045, 0.10).lerp(Color(0.025, 0.0, 0.015), dark)
	var o7 := dist * 0.7
	for i in range(int(floorf((o7 + X0) / 300.0)) - 1, int(ceilf((o7 + X1) / 300.0)) + 1):
		var fi := float(i)
		var nx := fi * 300.0 - o7 + Gfx.hash1(fi + 4.0) * 140.0
		var nh := 40.0 + Gfx.hash1(fi) * 55.0
		if Gfx.hash1(fi + 9.0) > 0.45:
			ci.draw_rect(Rect2(nx, G - nh, 30.0, nh), nc)
			ci.draw_circle(Vector2(nx + 15.0, G - nh), 15.0, nc)
		else:
			for k in 4:
				ci.draw_rect(Rect2(nx + float(k) * 34.0, G - 60.0 - Gfx.hash1(fi + float(k)) * 20.0, 10.0, 70.0), nc)
			ci.draw_line(Vector2(nx, G - 46.0), Vector2(nx + 112.0, G - 40.0), nc, 6.0)
	# ground
	var gc := Color(0.14, 0.105, 0.19).lerp(Color(0.10, 0.02, 0.05), dark)
	var gb := Color(0.05, 0.03, 0.08).lerp(Color(0.03, 0.0, 0.02), dark)
	ci.draw_polygon(PackedVector2Array([Vector2(X0, G), Vector2(X1, G), Vector2(X1, 780), Vector2(X0, 780)]), PackedColorArray([gc, gc, gb, gb]))
	ci.draw_line(Vector2(X0, G), Vector2(X1, G), Color(0.55, 0.46, 0.68, 0.4), 3.0)
	for i in 22:
		var fi := float(i)
		var mx := fposmod(fi * 137.0 - dist, X1 - X0) + X0
		var my := G + 14.0 + Gfx.hash1(fi) * 90.0
		ci.draw_line(Vector2(mx, my), Vector2(mx + 40.0 + Gfx.hash1(fi + 3.0) * 70.0, my), Color(0, 0, 0, 0.28), 3.0)


static func _tree(ci: CanvasItem, x: float, h: float, sd: float, col: Color) -> void:
	var lean := (Gfx.hash1(sd) - 0.5) * 30.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 14.0, G), Vector2(x + 14.0, G), Vector2(x + lean + 4.0, G - h), Vector2(x + lean - 4.0, G - h)]), col)
	for k in 5:
		var y := G - h * (0.32 + 0.14 * float(k))
		var dir := 1.0 if Gfx.hash1(sd * 9.0 + float(k)) > 0.5 else -1.0
		var l := 50.0 + Gfx.hash1(sd * 3.0 + float(k)) * 70.0
		var a := Vector2(x + lean * (0.3 + 0.14 * float(k)), y)
		var b := a + Vector2(dir * l, -l * 0.6)
		ci.draw_line(a, b, col, 6.0 - float(k) * 0.7)
		ci.draw_line(b, b + Vector2(dir * l * 0.35, -l * 0.5), col, 3.0)
	if Gfx.hash1(sd + 11.0) > 0.82:   # a noose, because of course
		var r := Vector2(x + 44.0, G - h * 0.55)
		ci.draw_line(r, r + Vector2(0.0, 110.0), col, 3.0)
		ci.draw_arc(r + Vector2(0.0, 124.0), 13.0, 0.0, TAU, 14, col, 3.0)


## Glowing eyes watching from the trees (additive layer). Appear as the world darkens.
static func draw_eyes(ci: CanvasItem, dist: float, t: float, dark: float) -> void:
	if dark < 0.3:
		return
	var o3 := dist * 0.3
	for i in range(int(floorf((o3 + X0) / TREE_STEP)) - 1, int(ceilf((o3 + X1) / TREE_STEP)) + 1):
		var fi := float(i)
		if Gfx.hash1(fi + 3.0) < 0.55 or fmod(t * 0.7 + Gfx.hash1(fi) * 10.0, 4.0) > 3.6:
			continue
		var ex := fi * TREE_STEP - o3 + Gfx.hash1(fi) * 110.0
		var ey := G - 80.0 - Gfx.hash1(fi + 5.0) * 150.0
		var a := clampf((dark - 0.3) * 2.0, 0.0, 1.0)
		Gfx.glow(ci, Vector2(ex, ey), 18.0, Color(1.0, 0.1, 0.15, 0.5 * a))
		ci.draw_rect(Rect2(ex - 9.0, ey - 2.0, 6.0, 4.0), Color(1.0, 0.35, 0.35, a))
		ci.draw_rect(Rect2(ex + 3.0, ey - 2.0, 6.0, 4.0), Color(1.0, 0.35, 0.35, a))


## Fast, near-black grass blades that sell speed and depth. Drawn after the player.
static func draw_foreground(ci: CanvasItem, dist: float, t: float) -> void:
	var col := Color(0.01, 0.0, 0.02, 0.95)
	var o := dist * 1.35
	for i in 34:
		var fi := float(i)
		var bx := fposmod(fi * 96.0 - o, X1 - X0) + X0
		var bh := 40.0 + Gfx.hash1(fi) * 60.0
		var sway := sin(t * 2.0 + fi) * 6.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, 740.0), Vector2(bx + 14.0, 740.0), Vector2(bx + sway - 3.0, 740.0 - bh)]), col)
