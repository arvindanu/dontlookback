extends CanvasLayer
## Full-screen cinematic ending. Almost black, with just enough translucency that the frozen world
## (the creature looming, its eyes burning) shows through. Everything is laid out from the screen
## HEIGHT (k = height / 720) so no aspect ratio can distort it; the title is additionally capped by
## width, and the stack is measured so no label can ever touch the number below it.
##   letterbox bars close in -> dark vignette -> "CONSUMED" slams in letter by letter with glitch
##   bursts (the ONLY place screen tearing is allowed) -> score counts up -> stats spread edge to
##   edge -> buttons fade in.
## Tap anywhere during the reveal to skip to the end (keeps "one more run" fast).

const LINES: Array[String] = [
	"It was right behind you the whole time.",
	"You looked. Of course you looked.",
	"Almost.",
	"It remembers your face.",
	"One more run. You know you want to.",
]
const READY_T := 1.9   ## seconds before the buttons are live

var _meters := 0.0
var _score := 0.0
var _shards := 0
var _result := {}
var _game = null
var _stage: Stage


class Stage extends Control:
	const LIVE_T := 1.9   ## seconds before the buttons accept taps
	var meters := 0.0
	var score := 0.0
	var shards := 0
	var best := 0
	var new_best := false
	var unlocked: Array = []
	var line := ""
	var buttons: Array = []
	var t := 0.0
	var _pulse := 0.0
	var _tick := 0.0
	var _slammed := false
	var _counted := false
	var _scan := PackedVector2Array()
	var _scan_h := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(layout)

	## Buttons follow the real screen size, so a rotated / resized window can never leave them behind.
	func layout() -> void:
		if buttons.size() != 2:
			return
		var k := size.y / 720.0
		var bh := 58.0 * k
		var w1 := 330.0 * k
		var w2 := 190.0 * k
		var gap := 20.0 * k
		var x0 := (size.x - (w1 + w2 + gap)) * 0.5
		var by := size.y * 0.835
		buttons[0].position = Vector2(x0, by)
		buttons[0].size = Vector2(w1, bh)
		buttons[0].font_size = int(26.0 * k)
		buttons[1].position = Vector2(x0 + w1 + gap, by)
		buttons[1].size = Vector2(w2, bh)
		buttons[1].font_size = int(18.0 * k)

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and t < 2.4:
			t = 2.4   # skip the reveal

	func _process(dt: float) -> void:
		t += dt
		_pulse = pow(maxf(0.0, sin(t * 4.4)), 8.0)   # a slow heartbeat the whole screen throbs to
		if not _slammed and t >= 0.3:
			_slammed = true
			Audio.play(&"sting", -7.0, 0.7)
		_tick -= dt
		if t > 1.1 and t < 2.35 and _tick <= 0.0:
			_tick = 0.055
			Audio.play(&"ui_click", -24.0, 0.7 + (t - 1.1) * 0.8)
		if not _counted and t >= 2.35:
			_counted = true
			if new_best:
				Audio.play(&"powerup", -9.0, 1.0)
		var reveal := clampf((t - 1.8) / 0.4, 0.0, 1.0)
		for b in buttons:
			b.modulate.a = reveal
			b.mouse_filter = Control.MOUSE_FILTER_STOP if t > LIVE_T else Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _e(k: float) -> float:
		return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)

	func _draw() -> void:
		var W := size.x
		var H := size.y
		var k := H / 720.0   # every size below scales with the screen height
		var red := Cfg.COL_CRIMSON
		var bone := Cfg.COL_BONE
		var wash := _e(t / 0.9)

		# ---- grade: almost black, a whisper of translucency, a dark blood vignette on all four edges
		draw_rect(Rect2(0.0, 0.0, W, H), Color(0.004, 0.0, 0.010, 0.93 * wash))
		var edge := Color(0.20, 0.0, 0.03, 0.55 * wash * (0.85 + 0.15 * _pulse))
		var clear := Color(0.20, 0.0, 0.03, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W * 0.28, 0), Vector2(W * 0.28, H), Vector2(0, H)]), PackedColorArray([edge, clear, clear, edge]))
		draw_polygon(PackedVector2Array([Vector2(W * 0.72, 0), Vector2(W, 0), Vector2(W, H), Vector2(W * 0.72, H)]), PackedColorArray([clear, edge, edge, clear]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H * 0.30), Vector2(0, H * 0.30)]), PackedColorArray([edge, edge, clear, clear]))
		draw_polygon(PackedVector2Array([Vector2(0, H * 0.70), Vector2(W, H * 0.70), Vector2(W, H), Vector2(0, H)]), PackedColorArray([clear, clear, edge, edge]))

		# ---- title: capped by BOTH width and height, so ultra-wide or tall screens can't blow it up
		var f := GameState.spaced(GameState.f_display, 8.0 * k)
		var word := "CONSUMED"
		var base := 160
		var wb := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x
		var fs := int(minf(float(base) * W * 0.78 / maxf(wb, 1.0), 168.0 * k))
		var tw := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := (W - tw) * 0.5
		var ty := H * 0.285
		var zoom := 1.0 + 0.04 * _e(t / 6.0) + 0.012 * _pulse
		var piv := Vector2(W * 0.5, ty - float(fs) * 0.3)
		Gfx.glow_ellipse(self, piv, tw * 0.62, float(fs) * 0.75, Color(red.r, red.g, red.b, 0.30 * wash * (0.8 + 0.2 * _pulse)))
		draw_set_transform(piv * (1.0 - zoom), 0.0, Vector2(zoom, zoom))
		var glitch := (t > 0.25 and t < 0.9 and fmod(t, 0.22) < 0.07) or (t > 1.0 and fmod(t, 2.4) < 0.16)
		var jx := (sin(t * 93.0) * 16.0 + 6.0) * k if glitch else 0.0
		for pass_i in 3:   # 0 red ghost, 1 cyan ghost (only while glitching), 2 the word itself
			if pass_i < 2 and not glitch:
				continue
			for i in word.length():
				var kk := _e((t - 0.30 - float(i) * 0.06) / 0.30)
				if kk <= 0.0:
					continue
				var px := tx + f.get_string_size(word.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var py := ty + (1.0 - kk) * -50.0 * k
				var ch := word.substr(i, 1)
				if pass_i == 0:
					draw_string(f, Vector2(px + jx, py), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.1, 0.2, 0.55 * kk))
				elif pass_i == 1:
					draw_string(f, Vector2(px - jx * 0.8, py + 3.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1.0, 0.40 * kk))
				else:
					var heat := _e((t - 0.40 - float(i) * 0.06) / 0.5)
					var col := Color.WHITE.lerp(red.lightened(0.18), heat)
					col.a = kk
					draw_string(f, Vector2(px + 3.0, py + 5.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7 * kk))
					draw_string(f, Vector2(px, py), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)

		# ---- flavour line
		var fa := _e((t - 1.2) / 0.5)
		Gfx.text(self, GameState.spaced(GameState.f_ui, 2.0), line, Vector2(W * 0.5, H * 0.365), int(23.0 * k), Color(1, 1, 1, 0.66 * fa), 1, 0.6)

		# ---- score: the number's height is measured, and the label is stacked ABOVE it with a clear gap
		var sa := _e((t - 1.0) / 0.4)
		var sfs := int(108.0 * k)
		var cap := float(sfs) * 0.74                   # digit height of the numeral face
		var lab_y := H * 0.425                          # baseline of "SCORE"
		var num_y := lab_y + 18.0 * k + cap             # baseline of the number: always below the label
		Gfx.text(self, GameState.spaced(GameState.f_bold, 5.0), "SCORE", Vector2(W * 0.5, lab_y), int(16.0 * k), Color(1, 1, 1, 0.55 * sa), 1, 0.4)
		var ce := _e((t - 1.1) / 1.25)
		if ce >= 1.0:
			Gfx.glow_ellipse(self, Vector2(W * 0.5, num_y - cap * 0.5), W * 0.2, H * 0.08, Color(bone.r, bone.g, bone.b, 0.04 + 0.05 * _pulse))
		Gfx.text(self, GameState.f_num, str(int(score * ce)), Vector2(W * 0.5, num_y), sfs, Color(bone.r, bone.g, bone.b, sa), 1, 0.9)

		# ---- NEW BEST / unlocks (stacked below the number)
		var ba := _e((t - 2.0) / 0.4)
		var row_y := num_y + 20.0 * k
		if new_best and ba > 0.0:
			var bw := 190.0 * k
			var bh := 34.0 * k
			var bx := W * 0.5 - bw * 0.5
			var pill := StyleBoxFlat.new()
			pill.bg_color = Color(1.0, 0.8, 0.3, 0.16 * ba)
			pill.border_color = Color(1.0, 0.82, 0.32, 0.9 * ba)
			pill.set_border_width_all(1)
			pill.set_corner_radius_all(int(bh * 0.5))
			pill.anti_aliasing = true
			draw_style_box(pill, Rect2(bx, row_y, bw, bh))
			UIDraw.icon(self, &"star", Vector2(bx + 24.0 * k, row_y + bh * 0.5), 17.0 * k, Color(UIDraw.GOLD.r, UIDraw.GOLD.g, UIDraw.GOLD.b, ba))
			Gfx.text(self, GameState.spaced(GameState.f_bold, 4.0), "NEW BEST", Vector2(bx + bw * 0.58, row_y + bh * 0.5 + 6.0 * k), int(16.0 * k), Color(UIDraw.GOLD.r, UIDraw.GOLD.g, UIDraw.GOLD.b, ba), 1, 0.4)
			var sh := fposmod(t * 0.7, 1.6) - 0.3   # shimmer sweep
			draw_line(Vector2(bx + bw * sh, row_y + 2.0), Vector2(bx + bw * sh - 14.0 * k, row_y + bh - 2.0), Color(1, 1, 1, 0.26 * ba), 6.0 * k)
			row_y += bh + 10.0 * k
		if unlocked.size() > 0 and ba > 0.0:
			var skin: Dictionary = {}
			for s in GameState.SKINS:
				if s["name"] == unlocked[0]:
					skin = s
			var msg := "New scarf unlocked: %s" % unlocked[0]
			var mw := GameState.f_ui.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * k)).x
			if not skin.is_empty():
				var sc: Color = skin["color"]
				Gfx.glow(self, Vector2(W * 0.5 - mw * 0.5 - 22.0 * k, row_y + 14.0 * k), 30.0 * k, Color(sc.r, sc.g, sc.b, 0.5 * ba))
				draw_circle(Vector2(W * 0.5 - mw * 0.5 - 22.0 * k, row_y + 14.0 * k), 11.0 * k, Color(sc.r, sc.g, sc.b, ba))
			Gfx.text(self, GameState.f_ui, msg, Vector2(W * 0.5, row_y + 20.0 * k), int(19.0 * k), Color(UIDraw.CYAN.r, UIDraw.CYAN.g, UIDraw.CYAN.b, ba), 1, 0.5)

		# ---- stats: hairline across the full width, three columns
		var ta := _e((t - 1.6) / 0.5)
		if ta > 0.0:
			var ly := H * 0.705
			draw_line(Vector2(0.0, ly), Vector2(W, ly), Color(1, 1, 1, 0.10 * ta), 1.0)
			var se := _e((t - 1.7) / 1.0)
			var cols := [
				["DISTANCE", str(int(meters * se)) + " M"],
				["SHARDS", str(int(float(shards) * se))],
				["BEST SCORE", str(best)],
			]
			for i in 3:
				var x: float = W * (0.2 + 0.3 * float(i))
				Gfx.text(self, GameState.spaced(GameState.f_bold, 4.0), cols[i][0], Vector2(x, H * 0.742), int(14.0 * k), Color(1, 1, 1, 0.5 * ta), 1, 0.4)
				Gfx.text(self, GameState.f_num, cols[i][1], Vector2(x, H * 0.808), int(52.0 * k), Color(bone.r, bone.g, bone.b, ta), 1, 0.8)
			for x2 in [W * 0.35, W * 0.65]:
				draw_line(Vector2(x2, H * 0.718), Vector2(x2, H * 0.818), Color(1, 1, 1, 0.12 * ta), 1.0)

		# ---- cinematic letterbox
		var bar := H * 0.07 * _e(t / 0.7)
		draw_rect(Rect2(0.0, 0.0, W, bar), Color.BLACK)
		draw_rect(Rect2(0.0, H - bar, W, bar), Color.BLACK)
		draw_line(Vector2(0.0, bar), Vector2(W, bar), Color(red.r, red.g, red.b, 0.5 * wash), 1.5)
		draw_line(Vector2(0.0, H - bar), Vector2(W, H - bar), Color(red.r, red.g, red.b, 0.5 * wash), 1.5)

		# ---- film grain lines + glitch tears (this screen is the only place tearing is allowed)
		if absf(_scan_h - H) > 0.5:
			_scan_h = H
			_scan = PackedVector2Array()
			var yy := 0.0
			while yy < H:
				_scan.append(Vector2(0.0, yy))
				_scan.append(Vector2(W, yy))
				yy += 5.0
		draw_multiline(_scan, Color(0, 0, 0, 0.07 * wash), 1.0)
		if glitch:
			var q := int(t * 30.0)
			for n in 5:
				var gy := Gfx.hash1(float(q * 7 + n)) * H
				var gh := 3.0 + Gfx.hash1(float(q * 3 + n)) * 18.0
				draw_rect(Rect2(0.0, gy, W, gh), Color(1.0, 0.15, 0.25, 0.10))
				var gx := Gfx.hash1(float(q * 5 + n)) * W * 0.5
				draw_rect(Rect2(gx, gy + gh * 0.5, W * 0.5, 2.0), Color(1, 1, 1, 0.22))
		if t < 0.35:   # impact flash as the creature closes its jaws
			draw_rect(Rect2(0.0, 0.0, W, H), Color(1, 1, 1, 0.5 * (1.0 - t / 0.35)))


func setup(meters: float, score: float, shards: int, result: Dictionary, game) -> void:
	_meters = meters
	_score = score
	_shards = shards
	_result = result
	_game = game


func _ready() -> void:
	_stage = Stage.new()
	_stage.meters = _meters
	_stage.score = _score
	_stage.shards = _shards
	_stage.best = GameState.best_score
	_stage.new_best = _result.get("new_best", false)
	_stage.unlocked = _result.get("unlocked", [])
	_stage.line = LINES.pick_random()
	_stage.size = Vector2(Cfg.view_w, Cfg.view_h)
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # always exactly the whole screen

	var again := FancyButton.new()
	again.label = "RUN AGAIN"
	again.icon = &"retry"
	again.style = FancyButton.Style.PRIMARY
	again.pressed.connect(_on_again)
	_stage.add_child(again)
	var menu := FancyButton.new()
	menu.label = "MENU"
	menu.icon = &"home"
	menu.style = FancyButton.Style.GHOST
	menu.pressed.connect(_on_menu)
	_stage.add_child(menu)
	for b in [again, menu]:
		b.modulate.a = 0.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.buttons = [again, menu]
	_stage.layout()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and _stage != null and _stage.t > READY_T:
		if k.keycode == KEY_ENTER or k.keycode == KEY_SPACE:
			_on_again()


func _on_again() -> void:
	_game.restart()


func _on_menu() -> void:
	_game.to_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _game != null:
		_game.to_menu()
