extends Control
var chara : battle_character_data
var selected_skill : rpg_skill
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
	selected_skill = move
	var description : String = ""
	description += "Name: " + move.name + "\n"
	description += "Stat requirements:" + "\n"
	description += "Strength: " + str(move.stat_requirement.strength)  + "\n"
	description += "Vitality: " + str(move.stat_requirement.vitality)  + "\n"
	description += "Dexterity: " + str(move.stat_requirement.dexterity)  + "\n"
	description += "Agility: " + str(move.stat_requirement.agility)  + "\n"
	description += "Magic power: " + str(move.stat_requirement.strength)  + "\n"
	description += "Luck: " + str(move.stat_requirement.luck)  + "\n"
	$"MoveDesc/move desk text".text = description

func assign_skill():
	GlobalVariables.assign_skill(chara,selected_skill)
