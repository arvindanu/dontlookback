class_name Cfg
extends RefCounted
## Shared layout constants. The game is authored at 1280x720 (16:9) and scaled by Godot.

const VIEW_W := 1280.0
const VIEW_H := 720.0
const GROUND_Y := 600.0
const PLAYER_X := 400.0
const PX_PER_M := 100.0   ## 1 "metre" of score/progression

## Colour language: the rim colour of an obstacle tells you the answer.
const COL_JUMP := Color(1.0, 0.72, 0.26)
const COL_SLIDE := Color(0.36, 0.9, 1.0)
const COL_DASH := Color(1.0, 0.2, 0.3)
