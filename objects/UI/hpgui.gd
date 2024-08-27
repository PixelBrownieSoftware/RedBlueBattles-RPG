extends Control

@export var character_data : battle_character_data
var old_health


func _process(delta):
	if character_data != null:
		$Offset/RichTextLabel.text = character_data.name + " HP " + str(character_data.health) + "/" +str(character_data.max_health) 
		$Offset/HealthBar.max_value = character_data.max_health
		$Offset/HealthBar.min_value = 0
		$Offset/HealthBar.value = character_data.health
		$Offset/HealthBar.get("theme_override_styles/fill").bg_color = character_data.assigned_data.character_colour
		$Offset/StaminaContainer.render_stamina(character_data.stamina, character_data.max_stamina)

func enable_ui():
	$AnimationPlayer.play("up")

func disable_ui():
	$AnimationPlayer.play("down")
	
func init_dmg_bar():
	old_health = character_data.health
	$Offset/DamageBar.value = old_health
	$Offset/DamageBar.max_value = character_data.max_health
	
func damage():
	$AnimationPlayer.play("damage")
	$Offset/DamageBar.value = old_health
	for i in range(4):
		$Offset/DamageBar.get("theme_override_styles/fill").bg_color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		$Offset/DamageBar.get("theme_override_styles/fill").bg_color = character_data.assigned_data.character_colour
		await get_tree().create_timer(0.1).timeout
	old_health = character_data.health
	$Offset/DamageBar.value = old_health
