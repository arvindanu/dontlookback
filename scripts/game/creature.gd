class_name Creature
extends RefCounted
## The thing behind you. `gap` is its distance (px) behind the runner.
## Looking back makes it close in faster the longer you stare, and it remembers:
## look time decays slowly, so repeated peeks add up.

signal lunged

const DEATH_GAP := 90.0
const MAX_GAP := 760.0

var gap := 680.0
var look_time := 0.0
var aggression := 0.0   ## smoothed 0..1, drives visuals/audio
var surge := 0.0        ## seconds of event-driven extra pressure
var _lunge_done := false


func reset() -> void:
	gap = 680.0
	look_time = 0.0
	aggression = 0.0
	surge = 0.0
	_lunge_done = false


## Where the creature settles when you are not looking. Shrinks with distance run.
func rest_gap(meters: float) -> float:
	return maxf(300.0, 640.0 - meters * 0.5)


func threat() -> float:
	return clampf(1.0 - (gap - DEATH_GAP) / 560.0, 0.0, 1.0)


func update(dt: float, looking: bool, meters: float, dark: float) -> void:
	if looking:
		look_time += dt
		gap -= (80.0 + look_time * 230.0 + dark * 90.0) * dt
		if look_time > 1.5 and not _lunge_done:
			_lunge_done = true
			gap -= 120.0
			lunged.emit()
	else:
		_lunge_done = false
		look_time = maxf(0.0, look_time - dt * 1.5)
		var rest := rest_gap(meters)
		gap = move_toward(gap, rest, (60.0 if gap < rest else 25.0) * dt)
	if surge > 0.0:
		surge -= dt
		gap -= 110.0 * dt
	gap = minf(gap, MAX_GAP)
	aggression = lerpf(aggression, clampf(look_time / 2.0, 0.0, 1.0), 1.0 - exp(-6.0 * dt))
