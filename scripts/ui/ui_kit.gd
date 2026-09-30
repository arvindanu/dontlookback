class_name UIKit
extends RefCounted
## Tiny helpers so menus share one dark, high-contrast look.


static func style(border: Color, fill: Color, radius: int = 8, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


static func button(text: String, font_size: int = 30, accent: Color = Color(0.82, 0.08, 0.18)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(320.0, 80.0)
	b.add_theme_font_override("font", GameState.font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.93, 0.88, 0.95))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", style(accent, Color(0.07, 0.02, 0.06, 0.88)))
	b.add_theme_stylebox_override("hover", style(accent.lightened(0.2), Color(0.12, 0.03, 0.08, 0.92)))
	b.add_theme_stylebox_override("pressed", style(Color.WHITE, accent.darkened(0.3)))
	b.add_theme_stylebox_override("disabled", style(Color(0.3, 0.3, 0.3), Color(0.05, 0.03, 0.05, 0.7)))
	return b


static func label(text: String, size: int, color: Color = Color(0.9, 0.85, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameState.font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l
