extends Node
## First scene of every launch. Routes to the one-time cinematic on the very first boot, and straight
## to the home screen on every launch after that (GameState.cinematic_done is saved locally).


func _ready() -> void:
	call_deferred("_route")


func _route() -> void:
	if GameState.cinematic_done:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/cinematic.tscn")
