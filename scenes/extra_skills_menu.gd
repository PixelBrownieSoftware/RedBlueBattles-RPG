extends Control
@export var chara : battle_character_data
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
		button.load_skill.connect(add_skill)
		button.text = skill.name
		button.visible = true
		skill_ind += 1
	visible = true

func display_skills():
	var description : String = ""
	description += "Name: " + selected_skill.name
	if GlobalVariables.equipped_extra_skills[selected_skill.name] != null:
		var character_colour = chara.assigned_data.character_colour
		description += " ([color=" + character_colour.to_html()+ "]" + GlobalVariables.equipped_extra_skills[selected_skill.name].name+ "[/color])"
	description += "\n"
	description += "Stat requirements:" + "\n"
	description += display_stat("Strength", selected_skill.stat_requirement.strength, chara.strength)
	description += display_stat("Vitality", selected_skill.stat_requirement.vitality, chara.vitality)
	description += display_stat("Dexterity", selected_skill.stat_requirement.dexterity, chara.dexterity)
	description += display_stat("Agility", selected_skill.stat_requirement.agility, chara.agility)
	description += display_stat("Magic power", selected_skill.stat_requirement.magic_pow, chara.magic_pow)
	description += display_stat("Luck", selected_skill.stat_requirement.luck, chara.luck)
	$"MoveDesc/move desk text".text = description
	if selected_skill.requirements_met(chara):
		$"MoveDesc/Equip skill".disabled = false
	else:
		$"MoveDesc/Equip skill".disabled = true

func display_stat(stat_name, stat_req, user_stat) -> String:
	var disp = stat_name + ": " + str(stat_req) + " needed. Has: " + str(user_stat)
	var colour : Color = Color.RED
	if user_stat >= stat_req:
		colour = Color.GREEN 
	return "[color=" +str(colour.to_html())+"]" + disp + "[/color]"  + "\n"
	
func add_skill(move):
	selected_skill = move
	display_skills()

func assign_skill():
	GlobalVariables.assign_skill(chara,selected_skill)
	display_skills()
