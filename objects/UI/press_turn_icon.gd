extends Control
@export var player_icon : Texture2D
@export var enemy_icon : Texture2D

func set_player_colour():
	$Icon.texture = player_icon

func set_enemy_colour():
	$Icon.texture = enemy_icon

func disappear():
	$AnimationPlayer.play("disappear")

func appear():
	$AnimationPlayer.play("appear")
	
func glowing():
	$AnimationPlayer.play("glowing")
