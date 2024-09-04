extends Panel

@onready var globals : battle_variables = get_node("../Variables")
signal call_target_menu()
signal get_targets(skill)
var menu_skills : Array[rpg_skill]

var pass_skill : rpg_skill = preload("res://data/Skills/Misc/pass.tres")

func show_skills(skills : Array[rpg_skill]):
	menu_skills = skills
	menu_skills.append(pass_skill)
	for button : button_skill in get_child(0).get_children():
		button.visible = false
	var index = 0
	$AnimationPlayer.play("menu_show")
	
func show_menu():
	$AnimationPlayer.play("menu_show")

func on_button_select_skill(skill):
	globals.selected_move = skill
	get_targets.emit(skill)
	$AnimationPlayer.play("menu_hide")

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "menu_show":
		var index = 0
		for sk in menu_skills:
			var skill_button = get_child(0).get_child(index) as button_skill
			skill_button.selected_skill = sk
			skill_button.current_char = globals.current_character
			skill_button.text = sk.name
			var afford : bool = (globals.current_character.stamina >= sk.get_final_cost(globals.current_character))
			skill_button.show_anim(afford)
			#A hack to make sure that players don't waste stamina
			if sk.power == 0:
				if sk.skill_scope == sk.SCOPE.SELF:
					var has_status : bool = false
					for status in sk.effects_to_add:
						if !globals.current_character.has_status(status.status):
							has_status = true
					skill_button.show_anim(has_status)
			index += 1
		$"../Analyse".visible = true
		$"../Character stats".visible = false
	else: if anim_name == "menu_hide":
		$"../Analyse".force_off()
		call_target_menu.emit()
