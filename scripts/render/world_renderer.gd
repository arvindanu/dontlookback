extends Node2D
## World layer: everything that is darkened by the lantern-lighting shader.

var game = null


func setup(g) -> void:
	game = g


func _draw() -> void:
	if game == null:
		return
	var g = game
	BackgroundDrawer.draw(self, g.dist, g.t, g.dark, g.fog_amount())
	var light_x: float = g.player.lantern_world.x
	var lo := -Cfg.ox - 700.0
	var hi := Cfg.view_w - Cfg.ox + 700.0
	for o in g.gen.obstacles:
		var sx: float = o.x - g.dist
		if o.dead or sx > hi or sx + o.w < lo:
			continue
		ObstacleDrawer.draw_shadow(self, o, sx, light_x)
		ObstacleDrawer.draw_body(self, o, sx, g.t, g.dark)
	g.ps.draw_pass(self, false)
	var flip := lerpf(1.0, -1.0, smoothstep(0.2, 0.8, g.look_a))   # turn around to look back
	CharacterDrawer.draw(self, g.player, Vector2(Cfg.PLAYER_X, g.player.y), flip, GameState.equipped_dress())
	var extra: float = g.die_t * 1.2 if g.is_dying() else 0.0
	CreatureDrawer.draw_body(self, Cfg.PLAYER_X - g.creature.gap, g.creature, g.dark, g.look_a, g.t, extra)
	BackgroundDrawer.draw_foreground(self, g.dist, g.t)
