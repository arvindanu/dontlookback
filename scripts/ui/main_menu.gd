extends Node
## Main menu: the live game runs behind it in "attract" mode (it even peeks back now and then).

const GAME_SCENE := "res://scenes/game.tscn"

var _title: Label
var _info: Label
var _skin_row: HBoxContainer


func _ready() -> void:
	var bg = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	bg.attract = true
	add_child(bg)

	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	_title = UIKit.label("DON'T LOOK BACK", 96, Color(0.94, 0.88, 0.96))
	_title.add_theme_color_override("font_outline_color", Color(0.75, 0.05, 0.15))
	_title.add_theme_constant_override("outline_size", 6)
	box.add_child(_title)
	box.add_child(UIKit.label("It has been following you for a long time.", 26, Color(0.75, 0.55, 0.65)))

	_skin_row = HBoxContainer.new()
	_skin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_skin_row.add_theme_constant_override("separation", 14)
	box.add_child(_skin_row)
	_info = UIKit.label("", 22, Color(0.75, 0.7, 0.82))
	box.add_child(_info)
	_refresh()

	var play := UIKit.button("RUN", 48)
	play.custom_minimum_size = Vector2(380.0, 96.0)
	play.pressed.connect(_on_play)
	var pc := CenterContainer.new()
	pc.add_child(play)
	box.add_child(pc)

	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 10)
	box.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 10)
	box.add_child(row2)
	_add_toggle(row1, "Sound", &"sound_on")
	_add_toggle(row1, "Haptics", &"haptics_on")
	_add_toggle(row1, "Shake", &"shake_on")
	_add_toggle(row2, "Low FX", &"low_fx")
	_add_toggle(row2, "30 FPS", &"fps30")
	box.add_child(UIKit.label("Hold LOOK to see behind you - but the longer you stare, the closer it gets.", 18, Color(0.55, 0.5, 0.62)))


func _process(_dt: float) -> void:
	_title.modulate.a = 0.35 if randf() < 0.012 else 1.0   # cheap flicker


func _refresh() -> void:
	for c in _skin_row.get_children():
		c.queue_free()
	for i in GameState.SKINS.size():
		var s: Dictionary = GameState.SKINS[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(68.0, 68.0)
		var unlocked := GameState.skin_unlocked(i)
		var col: Color = s["color"]
		var fill := col if unlocked else col.darkened(0.8)
		var border := Color.WHITE if i == GameState.skin else Color(0.3, 0.28, 0.35)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, UIKit.style(border, fill, 34, 4 if i == GameState.skin else 2))
		if not unlocked:
			b.text = str(s["cost"])
			b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_skin.bind(i))
		_skin_row.add_child(b)
	var nxt := -1
	for i in GameState.SKINS.size():
		if not GameState.skin_unlocked(i):
			nxt = i
			break
	var line := "Best %d  |  %d m  |  Shards %d" % [GameState.best_score, GameState.best_meters, GameState.total_shards]
	if nxt >= 0:
		line += "  |  next scarf at %d" % int(GameState.SKINS[nxt]["cost"])
	_info.text = line


func _on_skin(i: int) -> void:
	if GameState.skin_unlocked(i):
		GameState.skin = i
		GameState.save_data()
		Audio.play(&"ui_click")
		_refresh()
	else:
		_info.text = "Collect %d more shards to unlock the %s scarf" % [int(GameState.SKINS[i]["cost"]) - GameState.total_shards, GameState.SKINS[i]["name"]]


func _add_toggle(parent: Control, label: String, prop: StringName) -> void:
	var b := UIKit.button("", 22, Color(0.5, 0.4, 0.6))
	b.custom_minimum_size = Vector2(200.0, 58.0)
	_set_toggle_text(b, label, prop)
	b.pressed.connect(_on_toggle.bind(b, label, prop))
	parent.add_child(b)


func _set_toggle_text(b: Button, label: String, prop: StringName) -> void:
	b.text = "%s: %s" % [label, "ON" if GameState.get(prop) else "OFF"]


func _on_toggle(b: Button, label: String, prop: StringName) -> void:
	GameState.set(prop, not GameState.get(prop))
	GameState.apply_settings()
	GameState.save_data()
	_set_toggle_text(b, label, prop)
	Audio.play(&"ui_click")


func _on_play() -> void:
	Audio.play(&"ui_click")
	get_tree().change_scene_to_file(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_on_play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
