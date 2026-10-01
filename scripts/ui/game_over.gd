extends CanvasLayer
## "CONSUMED" screen: the frozen world stays visible on the left, the result card slides in on
## the right with counting numbers, a NEW BEST badge and any scarf you unlocked.

const LINES: Array[String] = [
	"It was right behind you the whole time.",
	"You looked. Of course you looked.",
	"Almost.",
	"It remembers your face.",
	"One more run. You know you want to.",
]

var _meters := 0.0
var _score := 0.0
var _shards := 0
var _result := {}
var _game = null


class ResultPanel extends GlassPanel:
	var meters := 0.0
	var score := 0.0
	var shards := 0
	var best := 0
	var new_best := false
	var unlocked: Array = []
	var line := ""
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		super._draw()
		var u := Cfg.ui_scale()
		var cx := size.x * 0.5
		var k := clampf((_t - 0.25) / 1.1, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		# title
		Gfx.glow_ellipse(self, Vector2(cx, 84.0 * u), 230.0 * u, 50.0 * u, Color(Cfg.COL_CRIMSON.r, Cfg.COL_CRIMSON.g, Cfg.COL_CRIMSON.b, 0.30))
		Gfx.text(self, GameState.spaced(GameState.f_display, 3.0), "CONSUMED", Vector2(cx, 100.0 * u), int(66.0 * u), Cfg.COL_CRIMSON.lightened(0.15), 1, 0.9)
		Gfx.text(self, GameState.f_ui, line, Vector2(cx, 134.0 * u), int(18.0 * u), Color(1, 1, 1, 0.55), 1, 0.4)
		draw_line(Vector2(cx - 120.0 * u, 152.0 * u), Vector2(cx + 120.0 * u, 152.0 * u), Color(1, 1, 1, 0.12), 1.0)
		# score
		Gfx.text(self, GameState.spaced(GameState.f_bold, 4.0), "SCORE", Vector2(cx, 190.0 * u), int(15.0 * u), Color(1, 1, 1, 0.5), 1, 0.4)
		Gfx.text(self, GameState.f_num, str(int(score * e)), Vector2(cx, 262.0 * u), int(92.0 * u), Cfg.COL_BONE, 1, 0.9)
		if new_best:
			var bw := 170.0 * u
			var pill := StyleBoxFlat.new()
			pill.bg_color = Color(1.0, 0.8, 0.3, 0.16)
			pill.border_color = Color(1.0, 0.82, 0.32, 0.9)
			pill.set_border_width_all(1)
			pill.set_corner_radius_all(int(15.0 * u))
			pill.anti_aliasing = true
			draw_style_box(pill, Rect2(cx - bw * 0.5, 276.0 * u, bw, 30.0 * u))
			UIDraw.icon(self, &"star", Vector2(cx - bw * 0.5 + 20.0 * u, 291.0 * u), 15.0 * u, UIDraw.GOLD)
			Gfx.text(self, GameState.spaced(GameState.f_bold, 3.0), "NEW BEST", Vector2(cx + 10.0 * u, 297.0 * u), int(15.0 * u), UIDraw.GOLD, 1, 0.4)
			var sh := fposmod(_t * 0.7, 1.6) - 0.3   # shimmer sweep
			draw_line(Vector2(cx - bw * 0.5 + bw * sh, 278.0 * u), Vector2(cx - bw * 0.5 + bw * sh - 14.0 * u, 304.0 * u), Color(1, 1, 1, 0.28), 6.0 * u)
		# stat trio
		var sy := 350.0 * u
		var cols := [
			["DISTANCE", str(int(meters * e)) + " M", &""],
			["SHARDS", str(int(float(shards) * e)), &"gem"],
			["BEST", str(best), &"star"],
		]
		for i in 3:
			var x: float = size.x * (0.2 + 0.3 * float(i))
			Gfx.text(self, GameState.spaced(GameState.f_bold, 3.0), cols[i][0], Vector2(x, sy), int(13.0 * u), Color(1, 1, 1, 0.45), 1, 0.4)
			Gfx.text(self, GameState.f_num, cols[i][1], Vector2(x, sy + 38.0 * u), int(40.0 * u), Cfg.COL_BONE, 1, 0.8)
		# unlocks
		if unlocked.size() > 0:
			var uy := 428.0 * u
			var skin: Dictionary = {}
			for s in GameState.SKINS:
				if s["name"] == unlocked[0]:
					skin = s
			if not skin.is_empty():
				var sc: Color = skin["color"]
				Gfx.glow(self, Vector2(cx - 120.0 * u, uy), 30.0 * u, Color(sc.r, sc.g, sc.b, 0.5))
				draw_circle(Vector2(cx - 120.0 * u, uy), 12.0 * u, sc)
			Gfx.text(self, GameState.f_ui, "New scarf unlocked: %s" % unlocked[0], Vector2(cx - 96.0 * u, uy + 6.0 * u), int(18.0 * u), UIDraw.CYAN, 0, 0.5)


func setup(meters: float, score: float, shards: int, result: Dictionary, game) -> void:
	_meters = meters
	_score = score
	_shards = shards
	_result = result
	_game = game


func _ready() -> void:
	var u := Cfg.ui_scale()
	var hr := Cfg.hud_rect()
	var root := Control.new()
	root.size = Vector2(Cfg.view_w, Cfg.view_h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var shade := Control.new()   # darkens the right side where the card sits
	shade.size = root.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(_draw_shade.bind(shade))
	root.add_child(shade)

	var w := 560.0 * u
	var h := 560.0 * u
	var panel := ResultPanel.new()
	panel.size = Vector2(w, h)
	panel.meters = _meters
	panel.score = _score
	panel.shards = _shards
	panel.best = GameState.best_score
	panel.new_best = _result.get("new_best", false)
	panel.unlocked = _result.get("unlocked", [])
	panel.line = LINES.pick_random()
	var final_pos := Vector2(hr.end.x - w, maxf((Cfg.view_h - h) * 0.5, hr.position.y))
	panel.position = final_pos + Vector2(70.0, 0.0)
	root.add_child(panel)

	var bx := 40.0 * u
	var bw := w - 80.0 * u
	var again := FancyButton.new()
	again.label = "RUN AGAIN"
	again.icon = &"retry"
	again.style = FancyButton.Style.PRIMARY
	again.font_size = 26
	again.position = Vector2(bx, 456.0 * u)
	again.size = Vector2(bw * 0.62 - 8.0 * u, 70.0 * u)
	again.pressed.connect(_on_again)
	panel.add_child(again)
	var menu := FancyButton.new()
	menu.label = "MENU"
	menu.icon = &"home"
	menu.style = FancyButton.Style.GHOST
	menu.font_size = 18
	menu.position = Vector2(bx + bw * 0.62 + 8.0 * u, 456.0 * u)
	menu.size = Vector2(bw * 0.38 - 8.0 * u, 70.0 * u)
	menu.pressed.connect(_on_menu)
	panel.add_child(menu)
	# guard against a still-held finger instantly hitting a button
	again.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().create_timer(0.9).timeout.connect(_enable.bind([again, menu]))

	root.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.5)
	tw.tween_property(panel, "position:x", final_pos.x, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw_shade(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_polygon(PackedVector2Array([Vector2(w * 0.35, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.35, h)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.72), Color(0, 0, 0, 0.72), Color(0, 0, 0, 0)]))


func _enable(btns: Array) -> void:
	for b in btns:
		if is_instance_valid(b):
			b.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_again() -> void:
	_game.restart()


func _on_menu() -> void:
	_game.to_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _game != null:
		_game.to_menu()
