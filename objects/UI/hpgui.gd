extends Control

@export var character_data : battle_character_data

func _process(delta):
	if character_data != null:
		$RichTextLabel.text = character_data.name + " HP " + str(character_data.health) + "/" +str(character_data.max_health) 
		$ProgressBar.max_value = character_data.max_health
		$ProgressBar.min_value = 0
		$ProgressBar.value = character_data.health
		$ProgressBar.get("theme_override_styles/fill").bg_color = character_data.assigned_data.character_colour
		$StaminaContainer.render_stamina(character_data.stamina, character_data.max_stamina)
