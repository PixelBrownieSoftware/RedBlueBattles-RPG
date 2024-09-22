extends Button
@export var selected_skill : rpg_skill
signal load_skill(skill : rpg_skill)
var style_box :  = preload("res://misc/material/button_texture.tres")

func assign_skill(current_char : battle_character_data):
	var final_cost = selected_skill.get_final_cost(current_char)
	
	var style : StyleBoxTexture= style_box.duplicate()
	var style_pressed : StyleBoxTexture= style_box.duplicate()
	style.modulate_color = selected_skill.skill_element.colour
	style_pressed.modulate_color = selected_skill.skill_element.colour + Color(-0.2,-0.2,-0.2)
	add_theme_stylebox_override("normal",style)
	add_theme_stylebox_override("hover",style_pressed)
	
	var orignal_cost = selected_skill.stamina_cost
	if final_cost >= orignal_cost:
		$StaminaContainer.render_stamina(final_cost, final_cost)
	else:
		$StaminaContainer.render_stamina(final_cost, selected_skill.stamina_cost)
	$ElementIcon.texture = selected_skill.skill_element.icon

func _on_pressed():
	load_skill.emit(selected_skill)
