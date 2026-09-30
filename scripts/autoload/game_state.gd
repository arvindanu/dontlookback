extends Node
## Autoload "GameState": persistent progress, settings, input map, haptics.

signal settings_changed

const SAVE_PATH := "user://dont_look_back.cfg"
const SKINS := [
	{"name": "Ash", "color": Color(0.72, 0.69, 0.78), "cost": 0},
	{"name": "Ember", "color": Color(1.0, 0.48, 0.16), "cost": 60},
	{"name": "Bone", "color": Color(0.95, 0.92, 0.8), "cost": 180},
	{"name": "Blood", "color": Color(0.88, 0.1, 0.22), "cost": 400},
	{"name": "Void", "color": Color(0.48, 0.36, 1.0), "cost": 800},
	{"name": "Gold", "color": Color(1.0, 0.82, 0.25), "cost": 1500},
]

var best_score := 0
var best_meters := 0
var total_shards := 0
var runs := 0
var skin := 0
var sound_on := true
var haptics_on := true
var shake_on := true
var low_fx := false
var fps30 := false
var hints_seen := {}   ## Obstacle.Kind -> true, tutorial prompts already shown
var font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	load_data()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	font = f
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


func apply_settings() -> void:
	Engine.max_fps = 30 if fps30 else 60
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)
	settings_changed.emit()


func skin_unlocked(i: int) -> bool:
	return total_shards >= int(SKINS[i]["cost"])


func skin_color() -> Color:
	var i := skin if skin_unlocked(skin) else 0
	return SKINS[i]["color"]


func haptic(ms: int) -> void:
	if haptics_on and OS.has_feature("android"):
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
	for s in SKINS:
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
	cf.set_value("progress", "skin", skin)
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
	skin = int(cf.get_value("progress", "skin", 0))
	hints_seen = {}
	for k in cf.get_value("progress", "hints", []):
		hints_seen[int(k)] = true
	sound_on = bool(cf.get_value("settings", "sound_on", true))
	haptics_on = bool(cf.get_value("settings", "haptics_on", true))
	shake_on = bool(cf.get_value("settings", "shake_on", true))
	low_fx = bool(cf.get_value("settings", "low_fx", false))
	fps30 = bool(cf.get_value("settings", "fps30", false))
