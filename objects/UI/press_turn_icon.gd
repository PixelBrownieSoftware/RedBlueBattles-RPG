extends Control

func disappear():
	$AnimationPlayer.play("disappear")

func appear():
	$AnimationPlayer.play("appear")
	
func glowing():
	$AnimationPlayer.play("glowing")
