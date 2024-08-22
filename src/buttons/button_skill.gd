extends Button
class_name button_skill

@export var selected_skill : rpg_skill
var current_char : battle_character_data
signal load_skill(skill : rpg_skill)
var can_afford : bool = true

func show_anim(afford : bool):
	disabled = true
	can_afford = afford
	var final_cost = selected_skill.get_final_cost(current_char)
	$StaminaContainer.render_stamina(final_cost, final_cost)
	$AnimationPlayer.play("button_fade_in")
	
func _on_pressed():
	load_skill.emit(selected_skill)

func enable_button():
	disabled = false
	
func hide_anim():
	$AnimationPlayer.play("button_fade_out")
	
func _on_animation_player_animation_finished(anim_name):
	if anim_name == "button_fade_in":
		disabled = !can_afford
