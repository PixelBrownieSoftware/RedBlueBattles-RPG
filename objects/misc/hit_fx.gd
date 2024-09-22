extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_values(number, is_player, colour, pt):
	var colour_character : Color = Color.WHITE
	if is_player == true:
		colour_character = colour
		$Sprite2D.frame = 2
	else:
		$Sprite2D.frame = 0
	var colour_text : String = "[color=#"+colour_character.to_html() + "]"
	var press_turn : PRESS_TURN.PT = pt
	$AdditionalText.visible = false
	match press_turn:
		PRESS_TURN.PT.MISS:
			$DamageNumber.text ="[center]" + "MISS..."+ "[/center]" 
			$AnimationPlayer.play("miss_animation")
		PRESS_TURN.PT.VOID:
			$DamageNumber.text ="[center]" + "VOID!"+ "[/center]" 
			$AnimationPlayer.play("block_animation")
		#PRESS_TURN.PT.CRITICAL:
			#$DamageNumber.text =colour_text + "[center]" +str(number) + "[/center]" + "[/color]"
			#$AdditionalText.text = "[center]Critical![/center]"
			#$AdditionalText.visible = true
			#$AnimationPlayer.play("damage_animation")
		PRESS_TURN.PT.LUCKY:
			$DamageNumber.text ="[center]" +str(number) + "[/center]"
			$AdditionalText.text = "[center]Lucky![/center]"
			$AdditionalText.visible = true
			$AnimationPlayer.play("damage_animation")
		PRESS_TURN.PT.WEAK:
			$DamageNumber.text = colour_text + "[center]" +str(number) + "[/center]"+ "[/color]"
			$AdditionalText.text = "[center]Weak![/center]"
			$AdditionalText.visible = true
			$AnimationPlayer.play("damage_animation")
		_:
			$AdditionalText.text = ""
			$DamageNumber.text =colour_text + "[center]" +str(number) + "[/center]"+ "[/color]"
			$AnimationPlayer.play("damage_animation")
		


func _on_anim_finished(anim_name):
	queue_free()
