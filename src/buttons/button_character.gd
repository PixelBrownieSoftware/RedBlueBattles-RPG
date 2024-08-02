extends Button
class_name button_character

@export var selected_character : battle_character_data
signal load_character(character : battle_character_data)

func show_anim():
	disabled = true
	$AnimationPlayer.play("button_fade_in")
	
func enable_button():
	disabled = false
	
func hide_anim():
	$AnimationPlayer.play("button_fade_out")
	
func show_hp():
	$HealthBar.max_value = selected_character.max_health
	$HealthBar.value = selected_character.health

func _on_pressed():
	load_character.emit(selected_character)


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "button_fade_in":
		disabled = false
