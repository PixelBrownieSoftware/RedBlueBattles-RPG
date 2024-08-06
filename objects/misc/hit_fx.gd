extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_values(number, is_player, colour, pt):
	if is_player == true:
		$Sprite2D.modulate = colour
		$Sprite2D.frame = 2
	else:
		$Sprite2D.modulate = Color.WHITE
		$Sprite2D.frame = 0
	var press_turn : PRESS_TURN.PT = pt
	$AdditionalText.visible = false
	match press_turn:
		PRESS_TURN.PT.MISS:
			$DamageNumber.text ="[center]" + "MISS..."+ "[/center]"
			$AnimationPlayer.play("miss_animation")
		PRESS_TURN.PT.CRITICAL:
			$DamageNumber.text ="[center]" +str(number) + "[/center]"
			$AdditionalText.text = "[center]Critical![/center]"
			$AdditionalText.visible = true
			$AnimationPlayer.play("damage_animation")
		PRESS_TURN.PT.LUCKY:
			$DamageNumber.text ="[center]" +str(number) + "[/center]"
			$AdditionalText.text = "[center]Lucky![/center]"
			$AdditionalText.visible = true
			$AnimationPlayer.play("damage_animation")
		PRESS_TURN.PT.WEAK:
			$DamageNumber.text ="[center]" +str(number) + "[/center]"
			$AdditionalText.text = "[center]Weak![/center]"
			$AdditionalText.visible = true
			$AnimationPlayer.play("damage_animation")
		_:
			$DamageNumber.text ="[center]" +str(number) + "[/center]"
			$AnimationPlayer.play("damage_animation")
		


func _on_anim_finished(anim_name):
	queue_free()
