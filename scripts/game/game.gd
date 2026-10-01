extends Node2D
## Run controller: owns the simulation (player, creature, world), the camera, events and
## scoring, and exposes state to the renderers / HUD. Also runs as the animated main-menu
## backdrop when `attract` is true.
##
## Coordinates: gameplay lives in a 1280x720 "design" rect. `cam` maps design space to the real
## (possibly wider / taller) viewport, so the world always fills the screen edge to edge.

enum Mode { ATTRACT, PLAY, DYING, DEAD }

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_OVER := preload("res://scenes/game_over.tscn")
const ACTIONS: Array[StringName] = [&"jump", &"slide", &"dash", &"look"]
const WHISPERS: Array[String] = ["it knows your name", "keep running", "don't look", "it's so close", "you can't outrun it", "just one more look"]
const HINTS := {
	Obstacle.Kind.GRAVE: "JUMP",
	Obstacle.Kind.SPIKES: "JUMP",
	Obstacle.Kind.PIT: "JUMP THE GAP",
	Obstacle.Kind.HANGING: "SLIDE",
	Obstacle.Kind.WALL: "DASH THROUGH",
	Obstacle.Kind.CROW: "SLIDE!",
}

var attract := false
var mode: int = Mode.PLAY

var player := PlayerCtl.new()
var creature := Creature.new()
var gen := WorldGen.new()
var ps := ParticleSystem.new()
var pickup: Pickup = null
var cam := Transform2D.IDENTITY
var popups: Array = []   ## floating score text: {pos, text, col, t, life}

var t := 0.0
var dist := 0.0
var meters := 0.0
var dark := 0.0
var score := 0.0
var run_shards := 0
var combo := 0
var relic_t := 0.0
var lantern_t := 0.0
var shield := false
var looking := false
var look_a := 0.0
var shake := 0.0
var zoom_punch := 0.0
var intro := 1.0
var flash_a := 0.0
var flash_col := Color.RED
var hitstop := 0.0
var pulse := 0.0
var die_t := 0.0
var death_desat := 0.0
var msg := ""
var msg_t := 0.0
var msg_dur := 1.0
var event_id: StringName = &""
var event_t := 0.0
var event_len := 1.0

var _next_event := 18.0
var _next_pickup := 6.0
var _attract_t := 0.0
var _smoke_t := 0.0
var _flick_dip := 0.0

@onready var world = $World
@onready var fx = $PostFX/Rect
@onready var grade = $Grade/Rect
@onready var glow = $Glow/GlowRenderer
@onready var hud_layer: CanvasLayer = $HUD
@onready var hud = $HUD/Overlay


func _ready() -> void:
	randomize()
	gen.rng.randomize()
	player.reset()
	creature.reset()
	ps.density = 0.5 if GameState.low_fx else 1.0
	ps.cap = 220 if GameState.low_fx else 420
	mode = Mode.ATTRACT if attract else Mode.PLAY
	if attract:
		creature.gap = 430.0
		hud_layer.visible = false
		intro = 0.0
	else:
		DisplayServer.screen_set_keep_on(true)
		say("DON'T LOOK BACK", 2.6)
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.slide_started.connect(_on_slide_started)
	player.dash_started.connect(_on_dash_started)
	player.stepped.connect(_on_stepped)
	creature.lunged.connect(_on_lunged)
	Audio.beat.connect(_on_beat)
	world.setup(self)
	glow.setup(self)
	fx.setup(self)
	grade.setup(self)
	hud.setup(self)
	_update_camera(0.016)


func _exit_tree() -> void:
	if Audio.beat.is_connected(_on_beat):
		Audio.beat.disconnect(_on_beat)
	get_tree().paused = false
	DisplayServer.screen_set_keep_on(false)


# ------------------------------------------------------------------ queries used by renderers/HUD
func is_playing() -> bool:
	return mode == Mode.PLAY


func is_dying() -> bool:
	return mode == Mode.DYING or mode == Mode.DEAD


func multiplier() -> float:
	return minf(1.0 + float(floori(float(combo) / 8.0)) * 0.5, 3.0) * (2.0 if relic_t > 0.0 else 1.0)


func event_strength() -> float:
	if event_t <= 0.0:
		return 0.0
	return clampf(minf(event_t, event_len - event_t) / 0.5, 0.0, 1.0)


func fog_amount() -> float:
	return event_strength() if event_id == &"fog" else 0.0


## Lantern position on screen, in 0..1 viewport UV (drives the lighting shader).
func light_uv() -> Vector2:
	return (cam * player.lantern_world) / Vector2(Cfg.view_w, Cfg.view_h)


func light_radius() -> float:
	var r := 0.40 - dark * 0.12 + (0.2 if lantern_t > 0.0 else 0.0)
	r *= 1.0 + 0.022 * sin(t * 21.0) + 0.016 * sin(t * 9.3 + 1.0)   # flame breathing
	if event_id == &"blackout":
		r = lerpf(r, r * (0.25 + 0.08 * sin(t * 30.0)), event_strength())
	r *= 1.0 - _flick_dip
	return r * (Cfg.VIEW_H / Cfg.view_h)


func say(text: String, dur: float = 2.0) -> void:
	msg = text
	msg_t = dur
	msg_dur = dur


func flash(col: Color, a: float) -> void:
	flash_col = col
	flash_a = a


func popup(text: String, design_pos: Vector2, col: Color) -> void:
	popups.append({"pos": design_pos, "text": text, "col": col, "t": 0.0, "life": 0.9})
	if popups.size() > 8:
		popups.pop_front()


func restart() -> void:
	Transition.reload()


func to_menu() -> void:
	Transition.go(MENU_SCENE)


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if attract:
		return
	var key := event as InputEventKey
	if key != null and key.echo:
		return
	for a in ACTIONS:
		if event.is_action_pressed(a):
			on_action(a, true)
		elif event.is_action_released(a):
			on_action(a, false)


func on_action(action: StringName, pressed: bool) -> void:
	if mode != Mode.PLAY:
		return
	match action:
		&"jump":
			if pressed:
				player.press_jump()
			else:
				player.release_jump()
		&"slide":
			if pressed:
				player.press_slide()
			else:
				player.release_slide()
		&"dash":
			if pressed:
				player.press_dash()
		&"look":
			_set_looking(pressed)


func _set_looking(v: bool) -> void:
	if v == looking:
		return
	looking = v
	Audio.play(&"look_in" if v else &"look_out", -6.0)
	if v:
		GameState.haptic(15)


func toggle_pause() -> void:
	if mode != Mode.PLAY:
		return
	get_tree().paused = not get_tree().paused
	hud.on_pause_changed(get_tree().paused)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			toggle_pause()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if mode == Mode.PLAY and not get_tree().paused:
				toggle_pause()


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if hitstop > 0.0:
		hitstop -= dt
		dt *= 0.06   # freeze-frame impact
	if mode == Mode.DYING:
		dt *= 0.6    # the last moments crawl
	t += dt
	meters = dist / Cfg.PX_PER_M
	dark = clampf(meters / 1400.0, 0.0, 1.0)
	look_a = lerpf(look_a, 1.0 if (looking or is_dying()) else 0.0, 1.0 - exp(-9.0 * dt))
	match mode:
		Mode.ATTRACT:
			_update_attract(dt)
		Mode.PLAY:
			_update_play(dt)
		Mode.DYING:
			_update_dying(dt)
	ps.update(dt, player.speed)
	_update_ambient(dt)
	_update_popups(dt)
	Audio.update_layers(dt, creature.threat(), dark, creature.look_time, mode == Mode.PLAY or mode == Mode.DYING, mode == Mode.DYING)
	_update_camera(dt)
	world.queue_redraw()
	glow.queue_redraw()
	fx.update_fx()
	grade.update_fx()


func _update_attract(dt: float) -> void:
	_attract_t += dt
	player.update(dt, 250.0, looking)
	dist += player.speed * dt
	looking = fmod(_attract_t, 10.0) > 7.0   # the menu peeks back now and then
	creature.gap = 430.0 - look_a * 90.0 + sin(t * 0.7) * 10.0
	creature.look_time = look_a * 1.2
	creature.aggression = look_a * 0.6


func _update_play(dt: float) -> void:
	var target := minf(500.0 + meters * 0.9, 1060.0)
	player.update(dt, target, looking)
	dist += player.speed * dt
	gen.fill(dist, player.speed, meters)
	gen.update(dt, dist)
	creature.update(dt, looking, meters, dark)
	_check_obstacles()
	_announce_crows()
	_check_shards()
	_update_pickup(dt)
	_update_events(dt)
	_update_hints()
	relic_t = maxf(0.0, relic_t - dt)
	lantern_t = maxf(0.0, lantern_t - dt)
	score += player.speed * dt / Cfg.PX_PER_M * multiplier()
	_player_particles(dt)
	if dark > 0.3 and randf() < dt * 0.7 * dark:
		_flick_dip = 0.22
	if creature.gap <= Creature.DEATH_GAP:
		_die()


func _update_dying(dt: float) -> void:
	die_t += dt
	death_desat = clampf(die_t / 0.9, 0.0, 1.0) * 0.85
	player.update(dt, 0.0, false)
	dist += player.speed * dt
	creature.gap = move_toward(creature.gap, -50.0, 520.0 * dt)
	creature.aggression = 1.0
	shake = maxf(shake, 8.0)
	if die_t > 1.9 and mode == Mode.DYING:
		_finish()


func _update_camera(dt: float) -> void:
	shake = maxf(0.0, shake - 70.0 * dt)
	zoom_punch = lerpf(zoom_punch, 0.0, 1.0 - exp(-7.0 * dt))
	flash_a = maxf(0.0, flash_a - dt * 2.4)
	pulse = maxf(0.0, pulse - dt * 3.0)
	msg_t -= dt
	_flick_dip = maxf(0.0, _flick_dip - dt * 4.0)
	intro = maxf(0.0, intro - dt * 0.9)
	var s := shake if GameState.shake_on else 0.0
	var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * s
	var ease_in := intro * intro
	var zoom := 1.0 + look_a * 0.05 + zoom_punch + player.dash_curve() * 0.035 + pulse * 0.006 * creature.threat() + ease_in * 0.10
	if mode == Mode.ATTRACT:
		zoom += 0.03
	var d := Vector2(Cfg.ox, Cfg.oy)
	var s0 := Vector2(Cfg.VIEW_W, Cfg.VIEW_H) * 0.5 + d           # zoom about the centre of the design rect
	var pan := Vector2((300.0 if mode == Mode.ATTRACT else 0.0) + look_a * 290.0, 0.0)   # camera swings back to reveal the creature
	cam = Transform2D(0.0, Vector2(zoom, zoom), 0.0, s0 * (1.0 - zoom) + d * zoom + pan + off)
	world.transform = cam
	glow.transform = cam


func _update_popups(dt: float) -> void:
	var i := popups.size() - 1
	while i >= 0:
		popups[i]["t"] += dt
		if popups[i]["t"] >= popups[i]["life"]:
			popups.remove_at(i)
		i -= 1


# ------------------------------------------------------------------ collisions & pickups
func _check_obstacles() -> void:
	var pb := player.box().grow_individual(-5.0, -4.0, -5.0, 0.0)
	for o in gen.obstacles:
		if o.dead:
			continue
		var sx: float = o.x - dist
		if sx > Cfg.PLAYER_X + 260.0 or sx + o.w < Cfg.PLAYER_X - 260.0:
			continue
		var hit := false
		if o.kind == Obstacle.Kind.PIT:
			hit = player.on_ground and Cfg.PLAYER_X > sx + 40.0 and Cfg.PLAYER_X < sx + o.w - 40.0
		else:
			var r: Rect2 = o.hit_rect()
			r.position.x -= dist
			hit = r.intersects(pb)
		if not hit:
			continue
		if player.dash_t > 0.0 and o.kind != Obstacle.Kind.PIT:
			_smash(o)
		elif player.inv <= 0.0:
			_damage(o)


func _announce_crows() -> void:
	for o in gen.obstacles:
		if o.kind == Obstacle.Kind.CROW and not o.announced and o.x - dist < 1250.0:
			o.announced = true
			Audio.play(&"crow", -3.0, randf_range(0.9, 1.15))


func _smash(o: Obstacle) -> void:
	o.dead = true
	score += 30.0 * multiplier()
	shake = maxf(shake, 14.0)
	hitstop = 0.05
	zoom_punch = 0.03
	var c := ObstacleDrawer.action_color(o)
	var pos := Vector2(o.x - dist + o.w * 0.5, Cfg.GROUND_Y - minf(o.h, 160.0) * 0.5)
	if o.kind == Obstacle.Kind.WALL or o.kind == Obstacle.Kind.HANGING:
		pos.y = Cfg.GROUND_Y - 150.0
	ps.burst(pos, 26, c, 560.0, 0.7, 6.0, 1200.0, true, 0.0, TAU, 0.0, 3)     # sparks
	ps.burst(pos, 18, Color(0.22, 0.17, 0.26), 520.0, 1.0, 9.0, 1500.0, false, 0.0, TAU, 0.0, 2)   # shattered chunks
	ps.burst(pos, 8, Color(c.r, c.g, c.b, 0.9), 240.0, 0.5, 14.0, 0.0, true, 0.0, TAU, 0.0, 4)   # flash puffs
	ps.ring(pos, 150.0, 0.45, c, 6.0, 16.0)
	ps.ring(pos, 90.0, 0.3, Color(1, 1, 1, 0.8), 3.0, 10.0)
	popup("+%d" % int(30.0 * multiplier()), pos + Vector2(0.0, -40.0), c)
	flash(c, 0.12)
	Audio.play(&"thorn_break" if o.kind == Obstacle.Kind.WALL else &"hit", -3.0, randf_range(0.95, 1.1))
	GameState.haptic(30)


func _damage(o: Obstacle) -> void:
	player.take_hit()
	combo = 0
	flash(Color(0.8, 0.0, 0.05), 0.6)
	shake = 26.0
	hitstop = 0.07
	zoom_punch = 0.05
	GameState.haptic(60)
	var at := Vector2(Cfg.PLAYER_X, player.y - 50.0)
	ps.burst(at, 16, Color(0.75, 0.05, 0.1), 360.0, 0.6, 5.0, 900.0, false, 0.0, TAU, 0.0, 2)
	ps.burst(at, 10, Color(1.0, 0.3, 0.3), 420.0, 0.4, 4.0, 400.0, true, 0.0, TAU, 0.0, 3)
	ps.ring(at, 130.0, 0.4, Color(1.0, 0.2, 0.25), 6.0, 12.0)
	if shield:
		shield = false
		Audio.play(&"shield_break")
		ps.ring(at, 170.0, 0.5, Color(0.4, 0.9, 1.0), 5.0, 20.0)
		say("WARD SHATTERED", 1.6)
	else:
		creature.gap -= 170.0
		Audio.play(&"hit")
	if o.kind == Obstacle.Kind.PIT:
		player.bounce(-780.0)


func _check_shards() -> void:
	var pb := player.box().grow(30.0)
	for s in gen.shards:
		if s.got:
			continue
		var sx: float = s.x - dist
		if sx < Cfg.PLAYER_X - 90.0 or sx > Cfg.PLAYER_X + 90.0:
			continue
		if pb.has_point(Vector2(sx, s.y)):
			s.got = true
			run_shards += 1
			combo += 1
			score += 25.0 * multiplier()
			Audio.play(&"shard", -7.0, 1.0 + minf(float(combo), 24.0) * 0.012)
			var at := Vector2(sx, s.y)
			ps.burst(at, 6, Color(1.0, 0.85, 0.3), 260.0, 0.45, 4.0, 0.0, true, 0.0, TAU, 0.0, 3)
			ps.burst(at, 1, Color(1.0, 0.8, 0.3, 0.8), 0.0, 0.3, 12.0, 0.0, true, 0.0, TAU, 0.0, 4)
			if combo % 8 == 0:
				say("x%.1f" % multiplier(), 1.0)
				popup("x%.1f" % multiplier(), Vector2(Cfg.PLAYER_X, player.y - 150.0), Color(0.78, 0.6, 1.0))
				ps.ring(Vector2(Cfg.PLAYER_X, player.y - 60.0), 120.0, 0.45, Color(0.78, 0.6, 1.0), 4.0)


func _update_pickup(dt: float) -> void:
	_next_pickup -= dt
	if pickup == null and _next_pickup <= 0.0:
		if creature.gap > 330.0:
			pickup = Pickup.new()
			pickup.kind = randi() % 3
			say("SOMETHING GLINTS BEHIND YOU", 2.2)
			Audio.play(&"warn", -6.0)
			_next_pickup = randf_range(11.0, 18.0)
		else:
			_next_pickup = 2.0
	if pickup == null:
		return
	pickup.age += dt
	pickup.off += 22.0 * dt
	if looking and look_a > 0.5:
		pickup.grab += dt
	else:
		pickup.grab = maxf(0.0, pickup.grab - dt * 2.0)
	if pickup.grab >= Pickup.GRAB_TIME:
		_collect(pickup)
		pickup = null
	elif pickup.off > creature.gap - 70.0:
		say("IT TOOK IT", 1.4)
		pickup = null


func _collect(p: Pickup) -> void:
	score += 150.0 * multiplier()
	Audio.play(&"powerup")
	var at := Vector2(Cfg.PLAYER_X - p.off, Cfg.GROUND_Y - 75.0)
	flash(p.color(), 0.25)
	GameState.haptic(40)
	ps.burst(at, 26, p.color(), 460.0, 0.8, 5.0, 0.0, true, 0.0, TAU, 0.0, 3)
	ps.ring(at, 200.0, 0.6, p.color(), 6.0, 18.0)
	popup("+%d" % int(150.0 * multiplier()), at + Vector2(0.0, -50.0), p.color())
	match p.kind:
		Pickup.Kind.LANTERN:
			lantern_t = 9.0
			creature.gap = minf(creature.gap + 220.0, Creature.MAX_GAP)
			say("LANTERN - IT RECOILS", 2.0)
		Pickup.Kind.RELIC:
			relic_t = 12.0
			say("RELIC - SCORE x2", 2.0)
		_:
			shield = true
			say("WARD - ONE FREE HIT", 2.0)


func _update_hints() -> void:
	for o in gen.obstacles:
		var sx: float = o.x - dist
		if o.dead or sx < Cfg.PLAYER_X + 200.0 or sx > Cfg.PLAYER_X + 800.0:
			continue
		if not GameState.hints_seen.has(o.kind):
			GameState.hints_seen[o.kind] = true
			say(HINTS[o.kind], 1.6)
		break


# ------------------------------------------------------------------ random events
func _update_events(dt: float) -> void:
	if event_t > 0.0:
		event_t -= dt
		if event_t <= 0.0:
			event_id = &""
	_next_event -= dt
	if _next_event > 0.0 or event_id != &"" or meters < 60.0:
		return
	var pool: Array[StringName] = [&"whisper"]
	if meters > 120.0:
		pool.append(&"lie")
	if meters > 200.0:
		pool.append_array([&"blackout", &"fog"])
	if meters > 320.0:
		pool.append(&"surge")
	event_id = pool[randi() % pool.size()]
	_next_event = randf_range(14.0, 24.0)
	match event_id:
		&"whisper":
			event_len = 3.0
			say(WHISPERS.pick_random(), 3.0)
			Audio.play_whisper()
		&"lie":   # a false alarm: eyes flash ahead of you
			event_len = 0.9
			Audio.play(&"sting", -2.0)
			shake = 16.0
			flash(Color.WHITE, 0.3)
		&"blackout":
			event_len = 3.5
			say("THE LIGHT DIES", 2.2)
			Audio.play(&"lunge", -14.0, 1.4)
		&"fog":
			event_len = 8.0
			say("THE FOG RISES", 2.0)
		&"surge":
			event_len = 4.0
			creature.surge = 4.0
			say("IT'S FASTER NOW", 2.0)
			Audio.play(&"lunge", -10.0)
	event_t = event_len


# ------------------------------------------------------------------ death
func _die() -> void:
	if mode != Mode.PLAY:
		return
	mode = Mode.DYING
	die_t = 0.0
	looking = false
	Audio.play(&"die")
	Audio.play(&"lunge", -2.0)
	flash(Color.WHITE, 1.0)
	shake = 30.0
	ps.ring(Vector2(Cfg.PLAYER_X, player.y - 60.0), 260.0, 0.7, Color(1.0, 0.1, 0.15), 8.0, 20.0)
	GameState.haptic(300)


func _finish() -> void:
	mode = Mode.DEAD
	var res := GameState.record_run(meters, score, run_shards)
	var go = GAME_OVER.instantiate()
	go.setup(meters, score, run_shards, res, self)
	add_child(go)


# ------------------------------------------------------------------ juice
func _on_jumped() -> void:
	Audio.play(&"jump", -4.0, randf_range(0.95, 1.08))
	ps.burst(Vector2(Cfg.PLAYER_X, Cfg.GROUND_Y), 7, Color(0.55, 0.48, 0.62, 0.8), 220.0, 0.45, 6.0, 300.0, false, PI, TAU, 0.6, 1)


func _on_landed(strength: float) -> void:
	Audio.play(&"land", -6.0 + strength * 5.0, randf_range(0.9, 1.05))
	ps.burst(Vector2(Cfg.PLAYER_X, Cfg.GROUND_Y), 6 + int(strength * 10.0), Color(0.55, 0.48, 0.62, 0.8), 180.0 + strength * 260.0, 0.5, 7.0, 200.0, false, PI * 1.05, PI * 1.95, 0.9, 1)
	if strength > 0.45:
		ps.ring(Vector2(Cfg.PLAYER_X, Cfg.GROUND_Y - 4.0), 70.0 + strength * 70.0, 0.35, Color(0.85, 0.8, 1.0, 0.5), 3.0)
		shake = maxf(shake, 5.0 + strength * 6.0)
		GameState.haptic(12)


func _on_slide_started() -> void:
	Audio.play(&"slide", -4.0)


func _on_dash_started() -> void:
	Audio.play(&"dash", -2.0)
	zoom_punch = 0.04
	shake = maxf(shake, 6.0)
	ps.ring(Vector2(Cfg.PLAYER_X, player.y - 55.0), 130.0, 0.35, Color(1.0, 0.4, 0.5, 0.7), 4.0, 20.0)
	GameState.haptic(20)


func _on_stepped() -> void:
	Audio.play(&"step_a" if randf() < 0.5 else &"step_b", -15.0, randf_range(0.9, 1.15))
	ps.burst(Vector2(Cfg.PLAYER_X + randf_range(-20.0, 12.0), Cfg.GROUND_Y - 2.0), 2, Color(0.55, 0.48, 0.62, 0.55), 90.0, 0.4, 6.0, -60.0, false, PI, TAU, 0.8, 1)


func _on_lunged() -> void:
	shake = 16.0
	flash(Color.WHITE, 0.5)
	Audio.play(&"lunge", -4.0)
	say("IT SAW YOU", 1.6)
	GameState.haptic(60)


func _on_beat() -> void:
	pulse = 1.0


func _player_particles(_dt: float) -> void:
	var feet := Vector2(Cfg.PLAYER_X, player.y)
	if player.sliding and player.on_ground:
		ps.spawn(feet + Vector2(20.0, -2.0), Vector2(-player.speed * 0.3 - randf() * 120.0, -randf() * 160.0), 0.3, 3.0, Color(1.0, 0.7, 0.3), 900.0, true, 0.0, 3)
		ps.spawn(feet + Vector2(-10.0, -4.0), Vector2(-player.speed * 0.25, -randf() * 40.0), 0.5, 9.0, Color(0.55, 0.48, 0.62, 0.45), -30.0, false, 0.6, 1, 2.0)
	if player.dash_t > 0.0:
		ps.spawn(Vector2(Cfg.PLAYER_X - 30.0, player.y - randf_range(10.0, 110.0)), Vector2(-500.0, 0.0), 0.35, 5.0, Color(1.0, 0.3, 0.4, 0.8), 0.0, true, 0.0, 3, 0.5)


func _update_ambient(dt: float) -> void:
	var vr := Cfg.view_w - Cfg.ox
	# drifting embers, more of them (and redder) as the world darkens
	if randf() < dt * (4.0 + dark * 22.0) * ps.density:
		var c := Color(0.75, 0.06, 0.18, 0.9) if (dark > 0.5 and randf() < 0.5) else Color(1.0, 0.54, 0.19, 0.9)
		ps.spawn(Vector2(randf_range(-Cfg.ox - 300.0, vr + 200.0), randf_range(200.0, 720.0)), Vector2(-40.0 - randf() * 50.0, -20.0 - randf() * 40.0), 4.0, 2.5, c, 0.0, true, 0.0, 1, 0.5)
	# wind streaks sell speed
	var over := player.speed - 600.0
	if over > 0.0 and randf() < dt * over * 0.02 * ps.density:
		ps.spawn(Vector2(vr + 80.0, randf_range(60.0, 560.0)), Vector2(-1500.0 - randf() * 700.0, 0.0), 0.45, 2.0, Color(0.75, 0.78, 1.0, 0.13), 0.0, true, 0.0, 3)
	# smoke pouring off the creature
	_smoke_t -= dt
	if _smoke_t <= 0.0 and creature.gap < 620.0:
		_smoke_t = 0.07 / maxf(ps.density, 0.3)
		var base := Vector2(Cfg.PLAYER_X - creature.gap + randf_range(-50.0, 40.0), Cfg.GROUND_Y - randf_range(0.0, 220.0))
		ps.spawn(base, Vector2(30.0, -30.0 - randf() * 40.0), 1.3, 26.0, Color(0.03, 0.0, 0.05, 0.55), 0.0, false, 0.6, 1, 2.0)
