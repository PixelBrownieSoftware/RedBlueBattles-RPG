extends Control
@export var chara : battle_character_data
var selected_skill : rpg_skill
var buttons : Array[Button]
signal close_party_menu()

func open_menu(character : battle_character_data):
	chara = character
	close_party_menu.emit()
	for button_horiz in get_child(0).get_children():
		for button in button_horiz.get_children():
			buttons.append(button)
			button.visible = false
	update_skills()
	visible = true
	
func update_skills():
	var skill_ind : int = 0
	for skill in GlobalVariables.extra_skills:
		var button = buttons[skill_ind]
		button.selected_skill = skill
		button.character = chara
		button.load_skill.connect(add_skill)
		button.text = skill.name
		button.visible = true
		skill_ind += 1
		
func display_skills():
	var description : String = ""
	description += "Name: " + selected_skill.name
	var character_skill_assigned : battle_character_data = GlobalVariables.equipped_extra_skills[selected_skill.name]
	if character_skill_assigned != null:
		var character_colour = character_skill_assigned.assigned_data.character_colour
		description += " ([color=" + character_colour.to_html()+ "]" + GlobalVariables.equipped_extra_skills[selected_skill.name].name+ "[/color])"
	description += "\n"
	description += "Stat requirements:" + "\n"
	#var get_potential_modifiers = ch
	var str_req = selected_skill.get_requirements(chara, selected_skill.stat_requirement.strength)
	var vit_req = selected_skill.get_requirements(chara, selected_skill.stat_requirement.vitality)
	var dex_req = selected_skill.get_requirements(chara, selected_skill.stat_requirement.dexterity)
	var agi_req = selected_skill.get_requirements(chara, selected_skill.stat_requirement.agility)
	var mag_req = selected_skill.get_requirements(chara, selected_skill.stat_requirement.magic_pow)
	var luc_req = selected_skill.get_requirements(chara, selected_skill.stat_requirement.luck)
	description += display_stat("Strength",str_req , chara.strength)
	description += display_stat("Vitality", vit_req, chara.vitality)
	description += display_stat("Dexterity", dex_req, chara.dexterity)
	description += display_stat("Agility", agi_req, chara.agility)
	description += display_stat("Magic power", mag_req, chara.magic_pow)
	description += display_stat("Luck", luc_req, chara.luck)
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
	update_skills()
