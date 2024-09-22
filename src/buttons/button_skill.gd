extends Button
class_name button_skill

@export var selected_skill : rpg_skill
var current_char : battle_character_data
signal load_skill(skill : rpg_skill)
signal get_info(skill : rpg_skill)
var can_afford : bool = true
var style_box :  = preload("res://misc/material/button_texture.tres")

func show_anim(afford : bool):
	disabled = true
	$ElementIcon.texture = selected_skill.skill_element.icon
	var style : StyleBoxTexture= style_box.duplicate()
	var style_pressed : StyleBoxTexture= style_box.duplicate()
	style.modulate_color = selected_skill.skill_element.colour
	style_pressed.modulate_color = selected_skill.skill_element.colour + Color(-0.2,-0.2,-0.2)
	add_theme_stylebox_override("normal",style)
	add_theme_stylebox_override("hover",style_pressed)
	can_afford = afford
	var final_cost = selected_skill.get_final_cost(current_char)
	var orignal_cost = selected_skill.stamina_cost
	if final_cost >= orignal_cost:
		$StaminaContainer.render_stamina(final_cost, final_cost)
	else:
		$StaminaContainer.render_stamina(final_cost, selected_skill.stamina_cost)
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


func _on_hover() -> void:
	get_info.emit(selected_skill)
