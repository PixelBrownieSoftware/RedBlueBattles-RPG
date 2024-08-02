extends Control
var chara : battle_character_data
var buttons : Array[Button]

func open_menu(character : battle_character_data):
	chara = character
	for button_horiz in get_child(0).get_children():
		for button in button_horiz.get_children():
			buttons.append(button)
			button.visible = false
	
	var skill_ind : int = 0
	for skill in GlobalVariables.extra_skills:
		var button = buttons[skill_ind]
		button.selected_skill = skill
		button.character = chara
		button.text = skill.name
		button.visible = true
		skill_ind += 1
	visible = true

func add_skill(move):
	GlobalVariables.assign_skill(chara,move)
