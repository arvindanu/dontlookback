class_name FancyButton
extends Control
## Animated custom button. Styles: PRIMARY (crimson, glowing), GHOST (outlined glass),
## ICON (round glass), SWATCH (colour chip, optionally locked).

signal pressed

enum Style { PRIMARY, GHOST, ICON, SWATCH }

var label := ""
var icon: StringName = &""
var style: int = Style.GHOST
var accent := Cfg.COL_CRIMSON
var swatch := Color.WHITE
var glyph: StringName = &""   ## SWATCH style: draw this DRESS / ACCESSORIES glyph instead of a colour chip
var locked := false
var selected := false
var sub_label := ""       ## small text (e.g. unlock cost)
var font_size := 26
var _hover := 0.0
var _press := 0.0
var _down := false
var _hovering := false
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _process(dt: float) -> void:
	_t += dt
	_hover = lerpf(_hover, 1.0 if _hovering else 0.0, 1.0 - exp(-14.0 * dt))
	_press = lerpf(_press, 1.0 if _down else 0.0, 1.0 - exp(-28.0 * dt))
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
		Audio.play(&"ui_click", -8.0, 1.15)
	else:
		if _down and Rect2(Vector2.ZERO, size).has_point(mb.position):
			pressed.emit()
		_down = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovering = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false
		_down = false


func _draw() -> void:
	var sc := 1.0 - 0.05 * _press
	draw_set_transform(size * 0.5 * (1.0 - sc), 0.0, Vector2(sc, sc))
	match style:
		Style.PRIMARY:
			_draw_primary()
		Style.ICON:
			_draw_icon()
		Style.SWATCH:
			_draw_swatch()
		_:
			_draw_ghost()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _sb(fill: Color, border: Color, radius: int, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _draw_primary() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pulse := 0.5 + 0.5 * sin(_t * 2.6)
	var rad := int(size.y * 0.22)
	Gfx.glow_ellipse(self, size * 0.5, size.x * 0.80, size.y * 1.20, Color(accent.r, accent.g, accent.b, 0.30 + 0.14 * pulse + 0.18 * _hover))
	var fill := accent.darkened(0.20).lerp(accent, 0.30 * _hover + 0.4 * _press)
	draw_style_box(_sb(fill, Color(1, 1, 1, 0.42 + 0.25 * _hover), rad, 3), r)
	draw_style_box(_sb(Color(0, 0, 0, 0), Color(1.0, 0.75, 0.8, 0.10 + 0.22 * pulse), rad + 5, 2), r.grow(5.0))   # breathing outer ring: invites the tap
	draw_line(Vector2(size.y * 0.22, 4.0), Vector2(size.x - size.y * 0.22, 4.0), Color(1, 1, 1, 0.24), 2.0)   # sheen
	var f := GameState.spaced(GameState.f_bold, 4.0)
	var fs := int(font_size)
	if label == "":
		# icon only: optically centred (a play triangle's visual weight sits left of its bounding box)
		var ic0 := size.y * 0.52
		UIDraw.icon(self, icon, size * 0.5 - Vector2(ic0 * 0.07, 0.0), ic0, Color(1, 1, 1, 0.97))
		return
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ic := size.y * 0.36 if icon != &"" else 0.0
	var total := tw + (ic + 16.0 if icon != &"" else 0.0)
	var x0 := (size.x - total) * 0.5
	if icon != &"":
		UIDraw.icon(self, icon, Vector2(x0 + ic * 0.5, size.y * 0.5), ic, Color(1, 1, 1, 0.95))
		x0 += ic + 16.0
	Gfx.text(self, f, label, Vector2(x0, size.y * 0.5 + fs * 0.34), fs, Color.WHITE, 0, 0.6)


func _draw_ghost() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var b := 0.22 + 0.35 * _hover + 0.3 * _press
	draw_style_box(_sb(Color(0.05, 0.03, 0.09, 0.62 + 0.15 * _hover), Color(1, 1, 1, b), int(size.y * 0.22), 1), r)
	var f := GameState.spaced(GameState.f_bold, 3.0)
	var fs := int(font_size)
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ic := size.y * 0.40 if icon != &"" else 0.0
	var total := tw + (ic + 14.0 if icon != &"" else 0.0)
	var x0 := (size.x - total) * 0.5
	var col := Cfg.COL_BONE.lerp(Color.WHITE, _hover)
	if icon != &"":
		UIDraw.icon(self, icon, Vector2(x0 + ic * 0.5, size.y * 0.5), ic, col)
		x0 += ic + 14.0
	Gfx.text(self, f, label, Vector2(x0, size.y * 0.5 + fs * 0.34), fs, col, 0, 0.5)


func _draw_icon() -> void:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5
	draw_circle(c, rad, Color(0.05, 0.03, 0.09, 0.62 + 0.2 * _hover))
	draw_arc(c, rad - 1.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22 + 0.4 * _hover), 1.5, true)
	UIDraw.icon(self, icon, c, rad * 0.95, Cfg.COL_BONE.lerp(Color.WHITE, _hover))


func _draw_swatch() -> void:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5 - 4.0
	if glyph != &"":
		_draw_dress_tile(c, rad)
		return
	if selected:
		Gfx.glow(self, c, rad * 2.0, Color(swatch.r, swatch.g, swatch.b, 0.35))
		draw_arc(c, rad + 4.0, 0.0, TAU, 40, Color(1, 1, 1, 0.95), 3.0, true)
	else:
		draw_arc(c, rad + 3.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12 + 0.3 * _hover), 1.5, true)
	var col := swatch.darkened(0.78) if locked else swatch
	draw_circle(c, rad, col)
	draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.3, Color(1, 1, 1, 0.12 if locked else 0.22))
	if locked:
		UIDraw.icon(self, &"lock", c + Vector2(0.0, -rad * 0.12), rad * 0.8, Color(1, 1, 1, 0.75))
		if sub_label != "":
			Gfx.text(self, GameState.f_bold, sub_label, c + Vector2(0.0, rad * 0.72), int(rad * 0.46), Color(1, 1, 1, 0.8), 1, 0.4)
	elif selected:
		UIDraw.icon(self, &"check", c, rad * 0.8, Color(0, 0, 0, 0.55))


func _draw_dress_tile(c: Vector2, rad: float) -> void:
	var ac := swatch
	if selected:
		Gfx.glow(self, c, rad * 2.1, Color(ac.r, ac.g, ac.b, 0.30))
	draw_circle(c, rad, Color(0.07, 0.045, 0.12, 0.94))
	var ring_a := 1.0 if selected else (0.34 + 0.34 * _hover)
	if locked:
		ring_a *= 0.45
	draw_arc(c, rad - 1.0, 0.0, TAU, 44, Color(ac.r, ac.g, ac.b, ring_a), 3.0 if selected else 1.6, true)
	var gcol := Color(ac.r, ac.g, ac.b, 0.95)
	if locked:
		gcol = Color(ac.r * 0.35, ac.g * 0.35, ac.b * 0.35, 0.8)
	UIDraw.dress_glyph(self, glyph, c + Vector2(0.0, -rad * (0.2 if locked else 0.0)), rad * 1.0, gcol)
	if locked and sub_label != "":
		var fs := int(rad * 0.36)
		var tw := GameState.f_bold.get_string_size(sub_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UIDraw.icon(self, &"lock", Vector2(c.x - tw * 0.5 - rad * 0.2, c.y + rad * 0.66), rad * 0.34, Color(1, 1, 1, 0.75))
		Gfx.text(self, GameState.f_bold, sub_label, Vector2(c.x + rad * 0.12, c.y + rad * 0.78), fs, Color(1, 1, 1, 0.82), 1, 0.4)
	elif selected:
		draw_circle(c + Vector2(rad * 0.72, -rad * 0.72), rad * 0.27, ac)
		UIDraw.icon(self, &"check", c + Vector2(rad * 0.72, -rad * 0.72), rad * 0.36, Color(0, 0, 0, 0.7))
