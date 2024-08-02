extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_values(number, is_player, colour):
	if is_player == true:
		$Sprite2D.modulate = colour
		$Sprite2D.frame = 2
	else:
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.frame = 0
	$DamageNumber.text ="[center]" +str(number) + "[/center]"
	$AnimationPlayer.play("damage_animation")


func _on_anim_finished(anim_name):
	queue_free()
