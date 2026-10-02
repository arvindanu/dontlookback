extends Node
## Main menu. The live game runs behind it ("attract" mode, runner shifted to the right third,
## and every so often it glances back). UI is a left-aligned column of custom controls with
## three pages: main, settings, scarves. Everything is laid out from the real viewport size,
## so it fills any 16:9..21:9 (or taller) screen and is rebuilt if the window changes.

const GAME_SCENE := "res://scenes/game.tscn"
const VERSION := "v1.0.0"

var _layer: CanvasLayer
var _root: Control
var _pages := {}
var _page: StringName = &"main"
var _info: Label
var _swatches: Array[FancyButton] = []
var _rebuild_queued := false


class LeftShade extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.66, 0), Vector2(w * 0.66, h), Vector2(0, h)]),
			PackedColorArray([Color(0.01, 0, 0.02, 0.82), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.01, 0, 0.02, 0.82)]))
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.62), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)]))


class StatsBar extends Control:
	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var u := Cfg.ui_scale()
		var items := [
			["BEST SCORE", str(GameState.best_score), &"star"],
			["FARTHEST", "%d M" % GameState.best_meters, &"dash"],
			["SHARDS", str(GameState.total_shards), &"gem"],
		]
		for i in 3:
			var x := float(i) * 200.0 * u
			draw_line(Vector2(x, 6.0 * u), Vector2(x, 76.0 * u), Color(1, 1, 1, 0.12), 1.0)
			UIDraw.icon(self, items[i][2], Vector2(x + 24.0 * u, 20.0 * u), 15.0 * u, Color(Cfg.COL_BONE.r, Cfg.COL_BONE.g, Cfg.COL_BONE.b, 0.5))
			Gfx.text(self, GameState.spaced(GameState.f_bold, 3.0), items[i][0], Vector2(x + 42.0 * u, 26.0 * u), int(12.0 * u), Color(1, 1, 1, 0.5), 0, 0.4)
			Gfx.text(self, GameState.f_num, items[i][1], Vector2(x + 16.0 * u, 70.0 * u), int(42.0 * u), Cfg.COL_BONE, 0, 0.8)


func _ready() -> void:
	var bg = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	bg.attract = true
	add_child(bg)
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	get_viewport().size_changed.connect(_queue_rebuild)
	_build()
	Transition.boot_fade()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_do_rebuild")


func _do_rebuild() -> void:
	_rebuild_queued = false
	_build()


# ------------------------------------------------------------------ construction
func _page_ctl() -> Control:
	var c := Control.new()
	c.size = Vector2(Cfg.view_w, Cfg.view_h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _label(text: String, font: Font, size: int, col: Color, pos: Vector2, sz: Vector2, align: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align as HorizontalAlignment
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(parent: Control, text: String, ic: StringName, style: int, pos: Vector2, sz: Vector2, fs: int) -> FancyButton:
	var b := FancyButton.new()
	b.label = text
	b.icon = ic
	b.style = style
	b.font_size = fs
	b.position = pos
	b.size = sz
	parent.add_child(b)
	return b


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_swatches.clear()
	var u := Cfg.ui_scale()
	_root = Control.new()
	_root.size = Vector2(Cfg.view_w, Cfg.view_h)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	var shade := LeftShade.new()
	shade.size = _root.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var x0 := Cfg.hud_rect().position.x + 38.0 * u
	_pages = {}
	_pages[&"main"] = _build_main(x0, u)
	_pages[&"settings"] = _build_settings(x0, u)
	_pages[&"scarves"] = _build_scarves(x0, u)
	for k in _pages:
		_root.add_child(_pages[k])
	_show_page(_page, false)


func _build_main(x0: float, u: float) -> Control:
	var p := _page_ctl()
	var tex := load("res://assets/images/logo.png") as Texture2D
	var lw := 600.0 * u
	var lh := 160.0 * u
	if tex != null:
		lh = lw * float(tex.get_height()) / float(tex.get_width())
		var logo := TextureRect.new()
		logo.texture = tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		logo.position = Vector2(x0 - 22.0 * u, 52.0 * u)
		logo.size = Vector2(lw, lh)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(logo)
	else:
		p.add_child(_label("DON'T LOOK BACK", GameState.f_display, int(64.0 * u), Cfg.COL_BONE, Vector2(x0, 70.0 * u), Vector2(lw, 90.0 * u)))
	var ty := 52.0 * u + lh + 4.0 * u
	p.add_child(_label("It has been following you for a long time.", GameState.f_display, int(21.0 * u), Color(0.82, 0.58, 0.66, 0.9), Vector2(x0, ty), Vector2(lw, 32.0 * u)))
	var by := ty + 66.0 * u
	var run := _button(p, "RUN", &"play", FancyButton.Style.PRIMARY, Vector2(x0, by), Vector2(372.0 * u, 88.0 * u), 36)
	run.pressed.connect(_on_play)
	by += 108.0 * u
	var sc := _button(p, "SCARVES", &"scarf", FancyButton.Style.GHOST, Vector2(x0, by), Vector2(178.0 * u, 60.0 * u), 17)
	sc.pressed.connect(_show_page.bind(&"scarves", true))
	var st := _button(p, "SETTINGS", &"gear", FancyButton.Style.GHOST, Vector2(x0 + 194.0 * u, by), Vector2(178.0 * u, 60.0 * u), 17)
	st.pressed.connect(_show_page.bind(&"settings", true))
	var hr := Cfg.hud_rect()
	var bar := StatsBar.new()
	bar.position = Vector2(x0 - 16.0 * u, hr.end.y - 96.0 * u)
	bar.size = Vector2(620.0 * u, 90.0 * u)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bar)
	p.add_child(_label(VERSION, GameState.f_ui, int(13.0 * u), Color(1, 1, 1, 0.35), Vector2(hr.end.x - 120.0 * u, hr.end.y - 18.0 * u), Vector2(120.0 * u, 20.0 * u), 2))
	return p


func _build_settings(x0: float, u: float) -> Control:
	var p := _page_ctl()
	var panel := GlassPanel.new()
	panel.title = "SETTINGS"
	panel.position = Vector2(x0 - 10.0 * u, 48.0 * u)
	panel.size = Vector2(540.0 * u, 624.0 * u)
	p.add_child(panel)
	var rows := [
		["Sound", &"sound", &"sound_on"],
		["Haptics", &"haptic", &"haptics_on"],
		["Screen shake", &"shake", &"shake_on"],
		["Low effects mode", &"fx", &"low_fx"],
		["Battery saver (30 FPS)", &"battery", &"fps30"],
	]
	var y := 104.0 * u
	for r in rows:
		var s := SwitchRow.new()
		s.label = r[0]
		s.icon = r[1]
		s.on = GameState.get(r[2])
		s.position = Vector2(26.0 * u, y)
		s.size = Vector2(panel.size.x - 52.0 * u, 58.0 * u)
		s.toggled.connect(_on_setting.bind(r[2]))
		panel.add_child(s)
		y += 64.0 * u
	panel.add_child(_label("Fonts: Gloock, Big Shoulders, Instrument Sans (SIL Open Font License 1.1).  Made with the Godot Engine.", GameState.f_ui, int(13.0 * u), Color(1, 1, 1, 0.38), Vector2(30.0 * u, y + 8.0 * u), Vector2(panel.size.x - 60.0 * u, 40.0 * u)))
	var back := _button(panel, "BACK", &"back", FancyButton.Style.GHOST, Vector2(26.0 * u, panel.size.y - 82.0 * u), Vector2(panel.size.x - 52.0 * u, 60.0 * u), 18)
	back.pressed.connect(_show_page.bind(&"main", true))
	return p


func _build_scarves(x0: float, u: float) -> Control:
	var p := _page_ctl()
	var panel := GlassPanel.new()
	panel.title = "SCARVES"
	panel.position = Vector2(x0 - 10.0 * u, 48.0 * u)
	panel.size = Vector2(540.0 * u, 590.0 * u)
	p.add_child(panel)
	var sw := 92.0 * u
	var gap := 26.0 * u
	var gx := (panel.size.x - (3.0 * sw + 2.0 * gap)) * 0.5
	for i in GameState.SKINS.size():
		var b := FancyButton.new()
		b.style = FancyButton.Style.SWATCH
		b.position = Vector2(gx + float(i % 3) * (sw + gap), 112.0 * u + float(floori(float(i) / 3.0)) * (sw + gap))
		b.size = Vector2(sw, sw)
		b.swatch = GameState.SKINS[i]["color"]
		b.pressed.connect(_on_swatch.bind(i))
		panel.add_child(b)
		_swatches.append(b)
	_info = _label("", GameState.f_ui, int(18.0 * u), Color(1, 1, 1, 0.75), Vector2(30.0 * u, 350.0 * u), Vector2(panel.size.x - 60.0 * u, 80.0 * u), 1)
	panel.add_child(_info)
	var back := _button(panel, "BACK", &"back", FancyButton.Style.GHOST, Vector2(26.0 * u, panel.size.y - 82.0 * u), Vector2(panel.size.x - 52.0 * u, 60.0 * u), 18)
	back.pressed.connect(_show_page.bind(&"main", true))
	_refresh_scarves()
	return p


func _refresh_scarves(msg: String = "") -> void:
	for i in _swatches.size():
		_swatches[i].locked = not GameState.skin_unlocked(i)
		_swatches[i].selected = (i == GameState.skin)
		_swatches[i].sub_label = str(GameState.SKINS[i]["cost"])
	if _info == null:
		return
	if msg != "":
		_info.text = msg
		return
	var cur: Dictionary = GameState.SKINS[GameState.skin]
	var line := "%s scarf equipped." % String(cur["name"]).to_upper()
	for i in GameState.SKINS.size():
		if not GameState.skin_unlocked(i):
			line += "\nNext: %s at %d shards  (you have %d)" % [String(GameState.SKINS[i]["name"]).to_upper(), int(GameState.SKINS[i]["cost"]), GameState.total_shards]
			break
	_info.text = line


# ------------------------------------------------------------------ behaviour
func _show_page(p: StringName, animate: bool = true) -> void:
	_page = p
	for k in _pages:
		var pg: Control = _pages[k]
		if k == p:
			pg.visible = true
			if animate:
				pg.modulate.a = 0.0
				pg.position.x = -28.0
				var tw := create_tween().set_parallel(true)
				tw.tween_property(pg, "modulate:a", 1.0, 0.22)
				tw.tween_property(pg, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			else:
				pg.modulate.a = 1.0
				pg.position.x = 0.0
		else:
			pg.visible = false


func _on_setting(on: bool, prop: StringName) -> void:
	GameState.set(prop, on)
	GameState.apply_settings()
	GameState.save_data()


func _on_swatch(i: int) -> void:
	if GameState.skin_unlocked(i):
		GameState.skin = i
		GameState.save_data()
		Audio.play(&"powerup", -10.0, 1.3)
		_refresh_scarves()
	else:
		Audio.play(&"hit", -16.0, 1.6)
		_refresh_scarves("Collect %d more shards to unlock the %s scarf." % [int(GameState.SKINS[i]["cost"]) - GameState.total_shards, String(GameState.SKINS[i]["name"]).to_upper()])


func _on_play() -> void:
	Audio.play(&"ui_click")
	Transition.go(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ENTER and _page == &"main":
		_on_play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _page != &"main":
			_show_page(&"main", true)
		else:
			get_tree().quit()
