extends Control
## HUD + touch controls. Uses raw InputEventScreenTouch indices so several fingers work at
## once (hold LOOK with the left thumb while jumping/sliding with the right). On desktop the
## mouse acts as a single touch, and the keyboard maps through the InputMap actions.
##
##   left thumb : LOOK (hold)  DASH        right thumb : SLIDE (hold)  JUMP (hold = higher)

const BTN := {
	&"look": [Vector2(112.0, 590.0), 82.0],
	&"dash": [Vector2(292.0, 640.0), 58.0],
	&"slide": [Vector2(990.0, 640.0), 58.0],
	&"jump": [Vector2(1168.0, 590.0), 82.0],
}
const PAUSE_POS := Vector2(1236.0, 46.0)
const RESUME_RECT := Rect2(490.0, 300.0, 300.0, 74.0)
const QUIT_RECT := Rect2(490.0, 396.0, 300.0, 74.0)

var game = null
var paused := false
var _touches := {}   # pointer index -> action
var _down := {&"look": false, &"dash": false, &"slide": false, &"jump": false}


func setup(g) -> void:
	game = g


func on_pause_changed(p: bool) -> void:
	paused = p
	if p:
		_release_all()


func _release_all() -> void:
	for idx in _touches.keys():
		var a: StringName = _touches[idx]
		_down[a] = false
		game.on_action(a, false)
	_touches.clear()


func _process(_dt: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if game == null or not game.hud_layer.visible:
		return
	if event.is_action_pressed(&"pause"):
		game.toggle_pause()
		return
	var idx := -1
	var pos := Vector2.ZERO
	var pressed := false
	var touch := event as InputEventScreenTouch
	var mouse := event as InputEventMouseButton
	if touch != null:
		idx = touch.index
		pos = touch.position
		pressed = touch.pressed
	elif mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		idx = 99
		pos = mouse.position
		pressed = mouse.pressed
	else:
		return
	if pressed:
		_pointer_down(idx, pos)
	else:
		_pointer_up(idx)


func _pointer_down(idx: int, pos: Vector2) -> void:
	if paused:
		if RESUME_RECT.has_point(pos):
			game.toggle_pause()
		elif QUIT_RECT.has_point(pos):
			get_tree().paused = false
			get_tree().change_scene_to_file(game.MENU_SCENE)
		return
	if not game.is_playing():
		return
	if pos.distance_to(PAUSE_POS) < 46.0:
		game.toggle_pause()
		return
	var best: StringName = &""
	var best_d := 1.0e9
	for a in BTN:
		var d := pos.distance_to(BTN[a][0] as Vector2)
		if d < (BTN[a][1] as float) + 26.0 and d < best_d:
			best = a
			best_d = d
	if best != &"":
		_touches[idx] = best
		_down[best] = true
		game.on_action(best, true)


func _pointer_up(idx: int) -> void:
	if _touches.has(idx):
		var a: StringName = _touches[idx]
		_touches.erase(idx)
		_down[a] = false
		game.on_action(a, false)


# ------------------------------------------------------------------ drawing
func _txt(s: String, pos: Vector2, size: int, col: Color, align: int = 0) -> void:
	var f: Font = GameState.font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == 1:
		p.x -= w * 0.5
	elif align == 2:
		p.x -= w
	draw_string(f, p + Vector2(2.0, 3.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.75))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	if game == null:
		return
	if game.mode != 1 and not paused:   # 1 == Mode.PLAY; controls hide during death
		return
	var g = game
	# --- top-left: distance & score
	_txt("%d m" % int(g.meters), Vector2(28.0, 58.0), 42, Color(0.92, 0.88, 0.96))
	_txt("%d" % int(g.score), Vector2(30.0, 88.0), 24, Color(0.68, 0.62, 0.76))
	# --- top-right: shards & multiplier (left of the pause button)
	var sx := 1160.0
	_txt("%d" % g.run_shards, Vector2(sx, 50.0), 34, Color(1.0, 0.85, 0.3), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(sx + 18.0, 26.0), Vector2(sx + 28.0, 38.0), Vector2(sx + 18.0, 50.0), Vector2(sx + 8.0, 38.0)]), Color(1.0, 0.85, 0.35))
	var mu: float = g.multiplier()
	if mu > 1.0:
		_txt("x%.1f" % mu, Vector2(sx + 28.0, 88.0), 28, Color(0.78, 0.6, 1.0), 2)
	# pause button
	draw_circle(PAUSE_POS, 26.0, Color(0.05, 0.02, 0.08, 0.5))
	draw_rect(Rect2(PAUSE_POS.x - 9.0, PAUSE_POS.y - 10.0, 6.0, 20.0), Color(1, 1, 1, 0.7))
	draw_rect(Rect2(PAUSE_POS.x + 3.0, PAUSE_POS.y - 10.0, 6.0, 20.0), Color(1, 1, 1, 0.7))
	# --- threat bar with an eye
	var thr: float = g.creature.threat()
	var bx := 480.0
	var blink := 1.0 if (thr < 0.7 or int(g.t * 6.0) % 2 == 0) else 0.45
	draw_arc(Vector2(bx - 26.0, 34.0) + Vector2(0, 9), 16.0, -PI * 0.85, -PI * 0.15, 12, Color(0.8, 0.7, 0.85, blink), 3.0, true)
	draw_arc(Vector2(bx - 26.0, 34.0) - Vector2(0, 9), 16.0, PI * 0.15, PI * 0.85, 12, Color(0.8, 0.7, 0.85, blink), 3.0, true)
	draw_circle(Vector2(bx - 26.0, 34.0), 5.0, Color(1.0, 0.2 + 0.0 * thr, 0.25, blink))
	draw_rect(Rect2(bx, 28.0, 320.0, 12.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bx + 2.0, 30.0, 316.0 * thr, 8.0), Color(0.55 + thr * 0.45, 0.35 - thr * 0.3, 0.4 - thr * 0.3, blink))
	draw_rect(Rect2(bx, 28.0, 320.0, 12.0), Color(0.6, 0.5, 0.7, 0.5), false, 1.5)
	# --- active power-ups
	var px := 640.0
	var items: Array = []
	if g.lantern_t > 0.0:
		items.append(["LANTERN %d" % int(ceilf(g.lantern_t)), Color(1.0, 0.68, 0.24)])
	if g.relic_t > 0.0:
		items.append(["SCORE x2  %d" % int(ceilf(g.relic_t)), Color(0.75, 0.48, 1.0)])
	if g.shield:
		items.append(["WARD", Color(0.33, 0.9, 1.0)])
	for i in items.size():
		_txt(items[i][0], Vector2(px, 74.0 + float(i) * 26.0), 20, items[i][1], 1)
	# --- message
	if g.msg_t > 0.0 and g.msg != "":
		var a := clampf(g.msg_t / 0.5, 0.0, 1.0) * clampf((g.msg_dur - g.msg_t) / 0.15 + 0.2, 0.0, 1.0)
		_txt(g.msg, Vector2(640.0, 190.0), 46, Color(0.94, 0.88, 0.97, a), 1)
	# --- something glints behind you: edge hint while you are NOT looking
	var pk = g.pickup
	if pk != null and g.look_a < 0.4:
		var c: Color = pk.color()
		var pa := 0.5 + 0.4 * sin(g.t * 8.0)
		Gfx.glow(self, Vector2(40.0, 330.0), 46.0, Color(c.r, c.g, c.b, 0.6 * pa))
		draw_circle(Vector2(40.0, 330.0), 7.0, Color(c.r, c.g, c.b, pa))
		_txt("LOOK", Vector2(40.0, 384.0), 18, Color(c.r, c.g, c.b, pa), 1)
	# --- touch buttons
	_button(&"look", Color(1.0, 0.25, 0.32))
	_button(&"dash", Cfg.COL_DASH)
	_button(&"slide", Cfg.COL_SLIDE)
	_button(&"jump", Cfg.COL_JUMP)
	if paused:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.72))
		_txt("PAUSED", Vector2(640.0, 250.0), 72, Color(0.93, 0.88, 0.96), 1)
		_menu_btn(RESUME_RECT, "RESUME")
		_menu_btn(QUIT_RECT, "QUIT TO MENU")


func _menu_btn(r: Rect2, label: String) -> void:
	draw_rect(r, Color(0.07, 0.02, 0.06, 0.9))
	draw_rect(r, Color(0.82, 0.08, 0.18), false, 2.0)
	_txt(label, r.get_center() + Vector2(0.0, 12.0), 34, Color(0.95, 0.9, 0.97), 1)


func _button(a: StringName, col: Color) -> void:
	var c: Vector2 = BTN[a][0]
	var r: float = BTN[a][1]
	var down: bool = _down[a]
	var usable := true
	if a == &"dash":
		usable = game.player.dash_cd <= 0.0
	var alpha := 1.0 if usable else 0.45
	draw_circle(c, r, Color(0.06, 0.03, 0.1, 0.8 if down else 0.5))
	if down:
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.2))
	draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(col.r, col.g, col.b, (0.95 if down else 0.55) * alpha), 5.0 if down else 4.0, true)
	var ic := Color(col.r, col.g, col.b, alpha)
	match a:
		&"jump":
			draw_polyline(PackedVector2Array([c + Vector2(-24, 4), c + Vector2(0, -20), c + Vector2(24, 4)]), ic, 8.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-24, 24), c + Vector2(0, 0), c + Vector2(24, 24)]), Color(ic.r, ic.g, ic.b, 0.5 * alpha), 8.0, true)
		&"slide":
			draw_polyline(PackedVector2Array([c + Vector2(-20, -8), c + Vector2(0, 12), c + Vector2(20, -8)]), ic, 7.0, true)
		&"dash":
			draw_polyline(PackedVector2Array([c + Vector2(-20, -16), c + Vector2(-2, 0), c + Vector2(-20, 16)]), ic, 6.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(2, -16), c + Vector2(20, 0), c + Vector2(2, 16)]), ic, 6.0, true)
			var frac: float = game.player.dash_ready_frac()
			if frac < 1.0:
				draw_arc(c, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(col.r, col.g, col.b, 0.9), 5.0, true)
		&"look":
			draw_arc(c + Vector2(0, 26), 40.0, -PI * 0.80, -PI * 0.20, 16, ic, 6.0, true)
			draw_arc(c + Vector2(0, -26), 40.0, PI * 0.20, PI * 0.80, 16, ic, 6.0, true)
			draw_circle(c, 13.0, ic)
			draw_circle(c, 5.0, Color(0, 0, 0, 0.9))
	var labels := {&"jump": "JUMP", &"slide": "SLIDE", &"dash": "DASH", &"look": "LOOK"}
	_txt(labels[a], c + Vector2(0.0, r * 0.62 + 12.0), 15 if r < 70.0 else 18, Color(1, 1, 1, 0.65 * alpha), 1)
