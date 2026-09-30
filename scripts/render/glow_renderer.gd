extends Node2D
## Emissive layer drawn ABOVE the darkness shader with additive blending: obstacle rims,
## chevrons, shards, pickups, creature eyes, tree eyes, sparks, lantern aura.

var game = null


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func setup(g) -> void:
	game = g


func _draw() -> void:
	if game == null:
		return
	var g = game
	BackgroundDrawer.draw_eyes(self, g.dist, g.t, g.dark)
	for o in g.gen.obstacles:
		var sx: float = o.x - g.dist
		if o.dead or sx > Cfg.VIEW_W + 760.0 or sx + o.w < -760.0:
			continue
		ObstacleDrawer.draw_glow(self, o, sx, g.t)
	# shards
	for s in g.gen.shards:
		var sx: float = s.x - g.dist
		if s.got or sx < -700.0 or sx > Cfg.VIEW_W + 700.0:
			continue
		var y: float = s.y + sin(g.t * 4.0 + s.phase) * 4.0
		Gfx.glow(self, Vector2(sx, y), 24.0, Color(1.0, 0.75, 0.2, 0.3))
		var sc := 1.0 + 0.15 * sin(g.t * 6.0 + s.phase)
		draw_colored_polygon(PackedVector2Array([Vector2(sx, y - 12.0 * sc), Vector2(sx + 8.0, y), Vector2(sx, y + 12.0 * sc), Vector2(sx - 8.0, y)]), Color(1.0, 0.85, 0.35, 0.95))
	# the thing glinting behind you
	var pk = g.pickup
	if pk != null:
		var c: Color = pk.color()
		var pos := Vector2(Cfg.PLAYER_X - pk.off, Cfg.GROUND_Y - 75.0 + sin(g.t * 3.0) * 6.0)
		var a: float = 0.22 + g.look_a * 0.78 + (0.12 * sin(g.t * 9.0) if g.look_a < 0.3 else 0.0)
		Gfx.glow(self, pos, 44.0, Color(c.r, c.g, c.b, 0.85 * a))
		var col := Color(c.r, c.g, c.b, a)
		match pk.kind:
			Pickup.Kind.RELIC:
				draw_polyline(PackedVector2Array([pos + Vector2(0, -16), pos + Vector2(11, 0), pos + Vector2(0, 16), pos + Vector2(-11, 0), pos + Vector2(0, -16)]), col, 3.5, true)
			Pickup.Kind.WARD:
				draw_arc(pos, 15.0, 0.0, TAU, 24, col, 3.5, true)
			_:
				draw_circle(pos, 9.0, col)
		if pk.grab > 0.0:
			draw_arc(pos, 25.0, -PI * 0.5, -PI * 0.5 + pk.grab / Pickup.GRAB_TIME * TAU, 32, Color(1, 1, 1, 0.95), 4.0, true)
	# creature eyes & teeth
	var extra: float = g.die_t * 1.2 if g.is_dying() else 0.0
	CreatureDrawer.draw_glow(self, Cfg.PLAYER_X - g.creature.gap, g.creature, g.look_a, g.t, extra, g.dark)
	# lantern aura
	if g.lantern_t > 0.0:
		var la := clampf(g.lantern_t, 0.0, 1.0)
		Gfx.glow(self, Vector2(Cfg.PLAYER_X, g.player.y - 60.0), 330.0, Color(1.0, 0.6, 0.2, 0.22 * la))
	# false-creature event: eyes flash ahead of you
	if g.event_id == &"lie":
		var e: float = g.event_strength()
		for ex in [1000.0, 1078.0]:
			Gfx.glow(self, Vector2(ex, 300.0), 60.0, Color(1.0, 0.1, 0.12, 0.7 * e))
			draw_rect(Rect2(ex - 18.0, 296.0, 36.0, 8.0), Color(1.0, 0.85, 0.85, e))
	g.ps.draw_pass(self, true)
