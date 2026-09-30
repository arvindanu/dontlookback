extends CanvasLayer
## Shown when the creature catches you. Big RUN AGAIN button = fast "one more run" loop.

var _meters := 0.0
var _score := 0.0
var _shards := 0
var _result := {}
var _buttons: Array[Button] = []


func setup(meters: float, score: float, shards: int, result: Dictionary) -> void:
	_meters = meters
	_score = score
	_shards = shards
	_result = result


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := UIKit.label("CONSUMED", 110, Color(0.85, 0.08, 0.18))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	box.add_child(UIKit.label("%d m   |   %d pts" % [int(_meters), int(_score)], 44))
	box.add_child(UIKit.label("Shards collected: %d   |   Best: %d" % [_shards, GameState.best_score], 26, Color(0.75, 0.7, 0.82)))
	if _result.get("new_best", false):
		box.add_child(UIKit.label("NEW BEST", 34, Color(1.0, 0.85, 0.3)))
	for n in _result.get("unlocked", []):
		box.add_child(UIKit.label("New scarf unlocked: %s" % n, 26, Color(0.6, 0.9, 1.0)))

	var again := UIKit.button("RUN AGAIN", 46)
	again.custom_minimum_size = Vector2(420.0, 96.0)
	again.pressed.connect(_on_again)
	var c1 := CenterContainer.new()
	c1.add_child(again)
	box.add_child(c1)
	var menu := UIKit.button("MENU", 26, Color(0.5, 0.4, 0.6))
	menu.custom_minimum_size = Vector2(240.0, 60.0)
	menu.pressed.connect(_on_menu)
	var c2 := CenterContainer.new()
	c2.add_child(menu)
	box.add_child(c2)

	# guard against a still-held finger instantly hitting a button
	_buttons = [again, menu]
	for b in _buttons:
		b.disabled = true
	get_tree().create_timer(0.8).timeout.connect(_enable)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.6)


func _enable() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.disabled = false


func _on_again() -> void:
	Audio.play(&"ui_click")
	get_tree().reload_current_scene()


func _on_menu() -> void:
	Audio.play(&"ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu()
