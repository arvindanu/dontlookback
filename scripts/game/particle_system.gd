class_name ParticleSystem
extends RefCounted
## Lightweight pooled CPU particles drawn straight to a CanvasItem (no nodes per particle).

class P:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 1.0
	var size := 3.0
	var size_end := 1.0
	var color := Color.WHITE
	var gravity := 0.0
	var drag := 0.0
	var additive := false
	var scroll := 0.0      ## fraction of world speed applied (sticks to the ground)
	var is_round := false

var items: Array[P] = []
var cap := 420
var density := 1.0        ## 0.5 on "Low FX"
var _pool: Array[P] = []


func spawn(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, gravity: float = 0.0, additive: bool = false, scroll: float = 0.0, is_round: bool = false, size_end: float = -1.0, drag: float = 0.0) -> void:
	if items.size() >= cap:
		return
	var p: P = _pool.pop_back() if not _pool.is_empty() else P.new()
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.size = size
	p.size_end = size if size_end < 0.0 else size_end
	p.color = color
	p.gravity = gravity
	p.additive = additive
	p.scroll = scroll
	p.is_round = is_round
	p.drag = drag
	items.append(p)


func burst(pos: Vector2, count: int, color: Color, speed: float, life: float, size: float, gravity: float = 700.0, additive: bool = false, angle_min: float = 0.0, angle_max: float = TAU, scroll: float = 0.0) -> void:
	var n := int(ceilf(float(count) * density))
	for i in n:
		var a := randf_range(angle_min, angle_max)
		var s := speed * randf_range(0.35, 1.0)
		spawn(pos, Vector2(cos(a), sin(a)) * s, life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.3), color, gravity, additive, scroll, false, 0.0)


func update(dt: float, world_speed: float) -> void:
	var i := items.size() - 1
	while i >= 0:
		var p := items[i]
		p.life -= dt
		if p.life <= 0.0:
			items.remove_at(i)
			_pool.append(p)
		else:
			p.vel.y += p.gravity * dt
			if p.drag > 0.0:
				p.vel *= maxf(0.0, 1.0 - p.drag * dt)
			p.pos += p.vel * dt
			p.pos.x -= world_speed * p.scroll * dt
		i -= 1


func draw_pass(ci: CanvasItem, additive: bool) -> void:
	for p in items:
		if p.additive != additive:
			continue
		var k := p.life / p.max_life
		var s := lerpf(p.size_end, p.size, k)
		var c := p.color
		c.a *= k
		if p.is_round:
			ci.draw_circle(p.pos, s, c)
		else:
			ci.draw_rect(Rect2(p.pos.x - s * 0.5, p.pos.y - s * 0.5, s, s), c)
