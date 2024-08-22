extends Control

@export var character_data : battle_character_data

func _process(delta):
	if character_data != null:
		$Offset/RichTextLabel.text = character_data.name + " HP " + str(character_data.health) + "/" +str(character_data.max_health) 
		$Offset/ProgressBar.max_value = character_data.max_health
		$Offset/ProgressBar.min_value = 0
		$Offset/ProgressBar.value = character_data.health
		$Offset/ProgressBar.get("theme_override_styles/fill").bg_color = character_data.assigned_data.character_colour
		$Offset/StaminaContainer.render_stamina(character_data.stamina, character_data.max_stamina)

func enable_ui():
	$AnimationPlayer.play("up")

func disable_ui():
	$AnimationPlayer.play("down")
	
func damage():
	$AnimationPlayer.play("damage")
