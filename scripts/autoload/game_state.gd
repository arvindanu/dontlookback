extends Node
## Autoload "GameState": persistent progress, settings, input map, haptics.

signal settings_changed

const SAVE_PATH := "user://dont_look_back.cfg"   ## file name kept on purpose: existing saves survive the rename to 404: Alive
const DRESS := [
	{"id": &"none", "name": "Plain Coat", "desc": "Just the coat and the lantern.", "color": Color(0.72, 0.69, 0.78), "cost": 0},
	{"id": &"shroud", "name": "Grave Shroud", "desc": "A burial cloth that drags behind you.", "color": Color(0.64, 0.58, 0.90), "cost": 2500},
	{"id": &"mantle", "name": "Raven Mantle", "desc": "Black feathers. They remember who fed them.", "color": Color(0.55, 0.64, 0.98), "cost": 5000},
	{"id": &"antlers", "name": "Antler Crown", "desc": "Something old wore these first.", "color": Color(0.93, 0.88, 0.76), "cost": 8000},
	{"id": &"mask", "name": "Bone Mask", "desc": "It fits a little too well.", "color": Color(0.96, 0.93, 0.84), "cost": 12000},
	{"id": &"veil", "name": "Widow's Veil", "desc": "Worn for everyone you left behind.", "color": Color(0.90, 0.14, 0.26), "cost": 18000},
	{"id": &"halo", "name": "Hollow Halo", "desc": "Broken, but it still burns.", "color": Color(1.0, 0.82, 0.32), "cost": 25000},
]

var best_score := 0
var best_meters := 0
var total_shards := 0
var runs := 0
var dress := 0          ## equipped DRESS / ACCESSORIES index
var tutorial_done := false     ## first-session button tutorials already shown (saved)
var cinematic_done := false    ## first-boot cinematic already played or skipped (saved)
var from_cinematic := false    ## runtime only: this run starts straight out of the cinematic
var sound_on := true
var haptics_on := true
var shake_on := true
var low_fx := false
var fps30 := false
var hints_seen := {}   ## Obstacle.Kind -> true, tutorial prompts already shown
var font: Font          ## default UI font (kept for compatibility)
var f_display: Font     ## Gloock - titles
var f_num: Font         ## Big Shoulders Bold - score numerals
var f_ui: Font          ## Instrument Sans - labels
var f_bold: Font        ## Instrument Sans Bold - buttons
var _spaced := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	load_data()
	_load_fonts()
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()
	apply_settings()


func _setup_input_map() -> void:
	var map := {
		&"jump": [KEY_SPACE, KEY_UP, KEY_W],
		&"slide": [KEY_DOWN, KEY_S],
		&"dash": [KEY_SHIFT, KEY_D, KEY_RIGHT],
		&"look": [KEY_LEFT, KEY_A, KEY_L],
		&"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _load_font(path: String, fallback: PackedStringArray) -> Font:
	if ResourceLoader.exists(path):
		var f := load(path) as Font
		if f != null:
			return f
	var sf := SystemFont.new()   # fallback while a font is still importing / missing
	sf.font_names = fallback
	return sf


func _load_fonts() -> void:
	f_display = _load_font("res://assets/fonts/Gloock-Regular.ttf", PackedStringArray(["Georgia", "Noto Serif", "serif"]))
	f_num = _load_font("res://assets/fonts/BigShoulders-Bold.ttf", PackedStringArray(["Roboto Condensed", "sans-serif"]))
	f_ui = _load_font("res://assets/fonts/InstrumentSans-Regular.ttf", PackedStringArray(["Roboto", "sans-serif"]))
	f_bold = _load_font("res://assets/fonts/InstrumentSans-Bold.ttf", PackedStringArray(["Roboto", "sans-serif"]))
	font = f_ui


## Font with extra letter-spacing (tracking), cached. Used for the small-caps UI labels.
func spaced(base: Font, px: float) -> Font:
	var key := "%d_%d" % [base.get_instance_id(), int(px * 10.0)]
	if not _spaced.has(key):
		var fv := FontVariation.new()
		fv.base_font = base
		fv.spacing_glyph = int(px)
		_spaced[key] = fv
	return _spaced[key]


func _on_resize() -> void:
	Cfg.update_view(get_tree().root)


func apply_settings() -> void:
	Cfg.quality = 0.5 if low_fx else 1.0
	Engine.max_fps = 30 if fps30 else 60
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)
	settings_changed.emit()


func dress_unlocked(i: int) -> bool:
	return total_shards >= int(DRESS[i]["cost"])


## Equipped index, falling back to the free default if the saved one is out of range / locked.
func dress_index() -> int:
	if dress >= 0 and dress < DRESS.size() and dress_unlocked(dress):
		return dress
	return 0


func equipped_dress() -> StringName:
	return DRESS[dress_index()]["id"]


func mark_cinematic_done() -> void:
	if cinematic_done:
		return
	cinematic_done = true
	save_data()


func mark_tutorial_done() -> void:
	if tutorial_done:
		return
	tutorial_done = true
	save_data()


var _hap_until := 0
var _hap_level := 0.0


## Vibrate. `amp` 0..1 (-1 = device default) needs Android 8+; `level` is a priority so a faint
## footstep tick can never cut short a strong dash or hit that is still buzzing.
func haptic(ms: int, amp: float = -1.0, level: float = 0.5) -> void:
	if not haptics_on or not OS.has_feature("android"):
		return
	var now := Time.get_ticks_msec()
	if now < _hap_until and level < _hap_level:
		return
	_hap_until = now + ms
	_hap_level = level
	if amp >= 0.0:
		Input.vibrate_handheld(ms, clampf(amp, 0.0, 1.0))
	else:
		Input.vibrate_handheld(ms)


## Called once per finished run. Returns {new_best: bool, unlocked: Array[String]}.
func record_run(meters: float, score: float, shards: int) -> Dictionary:
	var before := total_shards
	runs += 1
	total_shards += shards
	var new_best := int(score) > best_score
	if new_best:
		best_score = int(score)
	best_meters = maxi(best_meters, int(meters))
	var unlocked: Array[String] = []
	for s in DRESS:
		var cost := int(s["cost"])
		if cost > before and cost <= total_shards:
			unlocked.append(String(s["name"]))
	save_data()
	return {"new_best": new_best, "unlocked": unlocked}


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "best_score", best_score)
	cf.set_value("progress", "best_meters", best_meters)
	cf.set_value("progress", "total_shards", total_shards)
	cf.set_value("progress", "runs", runs)
	cf.set_value("progress", "dress", dress)
	cf.set_value("progress", "tutorial_done", tutorial_done)
	cf.set_value("progress", "cinematic_done", cinematic_done)
	cf.set_value("progress", "hints", hints_seen.keys())
	cf.set_value("settings", "sound_on", sound_on)
	cf.set_value("settings", "haptics_on", haptics_on)
	cf.set_value("settings", "shake_on", shake_on)
	cf.set_value("settings", "low_fx", low_fx)
	cf.set_value("settings", "fps30", fps30)
	cf.save(SAVE_PATH)


func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	best_score = int(cf.get_value("progress", "best_score", 0))
	best_meters = int(cf.get_value("progress", "best_meters", 0))
	total_shards = int(cf.get_value("progress", "total_shards", 0))
	runs = int(cf.get_value("progress", "runs", 0))
	dress = int(cf.get_value("progress", "dress", 0))
	tutorial_done = bool(cf.get_value("progress", "tutorial_done", false))
	cinematic_done = bool(cf.get_value("progress", "cinematic_done", false))
	hints_seen = {}
	for k in cf.get_value("progress", "hints", []):
		hints_seen[int(k)] = true
	sound_on = bool(cf.get_value("settings", "sound_on", true))
	haptics_on = bool(cf.get_value("settings", "haptics_on", true))
	shake_on = bool(cf.get_value("settings", "shake_on", true))
	low_fx = bool(cf.get_value("settings", "low_fx", false))
	fps30 = bool(cf.get_value("settings", "fps30", false))
